import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/mess_models.dart';
import '../../core/repositories/mess_repository.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../mess/mess_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<MessProvider> _results = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  Map<String, dynamic>? _smartFilters;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool _looksNaturalQuery(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return false;
    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words >= 2 || RegExp(r'\d').hasMatch(trimmed)) return true;
    final lower = trimmed.toLowerCase();
    return ['veg', 'jain', 'lunch', 'snacks', 'snack', 'dinner', 'breakfast', 'delivery', 'budget', 'under']
        .any((kw) => lower.contains(kw));
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) _search(q);
    });
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
      if (q.trim().isEmpty) _smartFilters = null;
    });
    final appState = AppStateScope.of(context);
    try {
      if (_looksNaturalQuery(q)) {
        try {
          final parsed = await appState.repository.smartSearchParse(q);
          final filters = parsed['filters'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(parsed['filters'] as Map)
              : <String, dynamic>{};

          final dietary = filters['dietary']?.toString() ?? 'all';
          final slot = filters['slot']?.toString() ?? '';
          final deliveryOnly = filters['delivery_only'] == true;
          final maxBudget = (filters['max_monthly_inr'] as num?)?.toInt();
          final keywords = filters['keywords']?.toString().trim() ?? '';

          final apiDietary = dietary == 'veg'
              ? 'vegetarian'
              : (dietary == 'non_veg' ? 'non_vegetarian' : (dietary == 'jain' ? 'jain' : null));

          var list = await appState.getProviders(
            slot: slot.isNotEmpty ? slot.toUpperCase() : null,
            openNow: filters['open_now'] == true,
            deliveryOnly: deliveryOnly,
            dietary: apiDietary,
          );
          if (filters['open_now'] == true) {
            list = list.where((p) => p.isOpen).toList();
          }

          if (keywords.isNotEmpty) {
            final kwLower = keywords.toLowerCase();
            final matched = list
                .where((p) =>
                    p.name.toLowerCase().contains(kwLower) ||
                    p.area.toLowerCase().contains(kwLower) ||
                    p.city.toLowerCase().contains(kwLower) ||
                    p.description.toLowerCase().contains(kwLower))
                .toList();
            if (matched.isNotEmpty) list = matched;
          }

          if (maxBudget != null && maxBudget > 0) {
            list = list.where((p) {
              if (p.plans.isNotEmpty) {
                return p.plans.any((pl) => pl.price <= maxBudget);
              }
              if (p.startingMealPrice != null) {
                return (p.startingMealPrice! * 30) <= maxBudget;
              }
              return true;
            }).toList();
          }

          if (!mounted) return;
          setState(() {
            _smartFilters = (dietary != 'all' || slot.isNotEmpty || deliveryOnly || maxBudget != null || keywords.isNotEmpty)
                ? filters
                : null;
            _results = list;
          });
          return;
        } catch (_) {
          // Gracefully fall back to standard keyword search if smart parse is unavailable.
        }
      }

      final list = await appState.searchProviders(q);
      if (!mounted) return;
      setState(() {
        _smartFilters = null;
        _results = list;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _error = friendlyCustomerError(e, action: 'search kitchens');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final recent = appState.recentSearches;
    final smartChips = <String>[];
    final sf = _smartFilters;
    if (sf != null) {
      final d = sf['dietary']?.toString() ?? 'all';
      if (d == 'veg') smartChips.add('Pure Veg');
      if (d == 'jain') smartChips.add('Jain');
      if (d == 'non_veg') smartChips.add('Non-Veg');
      final s = sf['slot']?.toString() ?? '';
      if (s.isNotEmpty) smartChips.add(s[0].toUpperCase() + s.substring(1));
      if (sf['delivery_only'] == true) smartChips.add('Self Delivery');
      final maxB = (sf['max_monthly_inr'] as num?)?.toInt();
      if (maxB != null && maxB > 0) smartChips.add('Under ₹$maxB');
      final kw = sf['keywords']?.toString().trim() ?? '';
      if (kw.isNotEmpty) smartChips.add('"$kw"');
    }

    return Scaffold(
      backgroundColor: ThaliColors.card,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  appState.recordRecentSearch(v);
                  _search(v);
                },
                decoration: InputDecoration(
                  hintText: 'Try "pure veg lunch under 3500 delivery"',
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: ThaliColors.ink),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _debounce?.cancel();
                            _controller.clear();
                            _search('');
                          },
                        )
                      : const Icon(Icons.tune_rounded, color: ThaliColors.muted, size: 18),
                ),
              ),
              if (smartChips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.tune_rounded, size: 14, color: ThaliColors.muted),
                    const Text('Filters:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ThaliColors.muted)),
                    for (final c in smartChips)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: ThaliColors.subtle,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: ThaliColors.stroke),
                        ),
                        child: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThaliColors.ink)),
                      ),
                  ],
                ),
              ],
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('YOUR RECENT SEARCHES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThaliColors.muted, letterSpacing: 0.6)),
                    GestureDetector(
                      onTap: () => appState.clearRecentSearches(),
                      child: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThaliColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in recent)
                      InkWell(
                        onTap: () {
                          _controller.text = q;
                          _search(q);
                        },
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: ThaliColors.card,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: ThaliColors.stroke),
                          ),
                          child: Text(q, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ThaliColors.ink)),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _controller.text.trim().isEmpty ? 'Suggested' : 'Results',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: RefreshIndicator(
                  color: ThaliColors.primary,
                  onRefresh: () => _search(_controller.text),
                  child: _loading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [ThaliListSkeleton(itemCount: 3, cardHeight: 132)],
                        )
                      : _error != null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 28),
                                CardSurface(
                                  child: Column(
                                    children: [
                                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: ThaliColors.body, fontSize: 13.5)),
                                      const SizedBox(height: 12),
                                      MessActionButton(label: 'Retry', onPressed: () => _search(_controller.text), height: 42),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : _results.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 60),
                                    Center(child: Text('No matching messes found.', style: TextStyle(color: ThaliColors.muted))),
                                  ],
                                )
                              : GridView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.78,
                                  ),
                                  itemCount: _results.length,
                                  itemBuilder: (_, i) {
                                    final p = _results[i];
                                    final isClosed = !p.isOpen;
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        if (_controller.text.trim().isNotEmpty) {
                                          appState.recordRecentSearch(_controller.text.trim());
                                        }
                                        Navigator.push(context, messRoute(MessDetailScreen(provider: p)));
                                      },
                                      child: Container(
                                        padding: isClosed ? const EdgeInsets.all(6) : EdgeInsets.zero,
                                        decoration: isClosed
                                            ? BoxDecoration(
                                                color: const Color(0xFF141416),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(color: const Color(0xFF27272A)),
                                              )
                                            : null,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            MessCoverVisual(
                                              imageUrl: p.coverPath,
                                              height: isClosed ? 100 : 108,
                                              radius: 10,
                                              closed: isClosed,
                                              caption: p.startingMealPrice != null ? '₹${p.startingMealPrice}/meal' : null,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: isClosed ? Colors.white : ThaliColors.ink,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                RatingBadge(rating: p.rating, compact: true),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    isClosed ? 'Closed Today' : (p.supportsDelivery ? 'Self Delivery' : 'Pickup'),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: isClosed
                                                          ? const Color(0xFFE4E4E7)
                                                          : (p.supportsDelivery ? ThaliColors.primary : ThaliColors.muted),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
