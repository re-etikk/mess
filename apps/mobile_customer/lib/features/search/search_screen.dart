import 'package:flutter/material.dart';

import '../../core/models/mess_models.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../mess/mess_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  String _mealFilter = 'All meals';
  String _typeFilter = 'All plans';
  bool _openOnly = false;
  List<MessProvider> _providers = [];
  bool _loaded = false;
  bool _hasError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loadProviders();
    }
  }

  Future<void> _loadProviders() async {
    setState(() {
      _hasError = false;
    });
    try {
      final state = AppStateScope.of(context);
      final list = await state.getProviders();
      if (mounted) {
        setState(() {
          _providers = list;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _loaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _mealFilter != 'All meals' || _typeFilter != 'All plans' || _openOnly || _query.text.isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _query.clear();
      _mealFilter = 'All meals';
      _typeFilter = 'All plans';
      _openOnly = false;
    });
  }

  List<MessProvider> get _results {
    final query = _query.text.trim().toLowerCase();
    return _providers.where((provider) {
      final text = [
        provider.name,
        provider.area,
        provider.description,
        ...provider.mealSlots.map((s) => '${s.name} ${s.menuSummary}'),
        ...provider.mealSlots.expand((s) => s.items.map((i) => i.name)),
      ].join(' ').toLowerCase();
      final matchQuery = query.isEmpty || text.contains(query);
      final matchMeal = _mealFilter == 'All meals' ||
          provider.mealSlots.any((slot) => slot.name.toLowerCase() == _mealFilter.toLowerCase());
      final matchType = _typeFilter == 'All plans' || provider.plans.any((plan) => plan.typeLabel == _typeFilter);
      return matchQuery && matchMeal && matchType && (!_openOnly || provider.isOpen);
    }).toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }

  Future<void> _filters() async {
    final result = await showModalBottomSheet<Map<String, Object>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _FilterSheet(meal: _mealFilter, type: _typeFilter, openOnly: _openOnly),
    );
    if (result == null) return;
    setState(() {
      _mealFilter = result['meal']! as String;
      _typeFilter = result['type']! as String;
      _openOnly = result['open']! as bool;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Scaffold(
      backgroundColor: MessColors.cream,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // A. Header: Page Title & Top-Right Filter Control
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Find your mess',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: MessColors.navy,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    InkWell(
                      onTap: _filters,
                      borderRadius: BorderRadius.circular(MessColors.radiusControl),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _hasActiveFilters ? MessColors.orangeSoft : MessColors.white,
                          borderRadius: BorderRadius.circular(MessColors.radiusControl),
                          border: Border.all(
                            color: _hasActiveFilters ? MessColors.orange : MessColors.border,
                          ),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: _hasActiveFilters ? MessColors.orange : MessColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // B. Search Field
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: MessColors.white,
                    borderRadius: BorderRadius.circular(MessColors.radiusFeature),
                    border: Border.all(color: MessColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C2A1F14),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      color: MessColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Mess, food item or cuisine',
                      hintStyle: const TextStyle(
                        color: MessColors.muted,
                        fontSize: 14.5,
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 10),
                        child: Icon(Icons.search_rounded, color: MessColors.muted, size: 22),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _query.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded, size: 18, color: MessColors.muted),
                            ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
            ),

            // C. Compact Functional Filters
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _FilterControl(
                        label: _mealFilter,
                        active: _mealFilter != 'All meals',
                        onTap: _filters,
                      ),
                      const SizedBox(width: 8),
                      _FilterControl(
                        label: _typeFilter,
                        active: _typeFilter != 'All plans',
                        onTap: _filters,
                      ),
                      const SizedBox(width: 8),
                      _FilterControl(
                        label: 'Open now',
                        active: _openOnly,
                        onTap: () => setState(() => _openOnly = !_openOnly),
                        showDropdown: false,
                      ),
                      if (_hasActiveFilters) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _clearAllFilters,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: MessColors.white,
                              borderRadius: BorderRadius.circular(MessColors.radiusControl),
                              border: Border.all(color: MessColors.border),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MessColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // D. Nearby Messes Section Heading
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      'Nearby messes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: MessColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Spacer(),
                    if (_loaded && !_hasError)
                      Text(
                        '${results.length} available',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: MessColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // E. Content: Loading Skeleton / Error State / Truthful Empty State / Real Results
            if (!_loaded)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const _SkeletonTile(),
                    childCount: 3,
                  ),
                ),
              )
            else if (_hasError)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: MessColors.white,
                      borderRadius: BorderRadius.circular(MessColors.radiusCard),
                      border: Border.all(color: MessColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 44, color: MessColors.muted),
                        const SizedBox(height: 12),
                        const Text(
                          'Unable to load messes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: MessColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Could not connect to the network. Please check your internet connection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: MessColors.muted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadProviders,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MessColors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MessColors.radiusControl),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (results.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: MessColors.white,
                      borderRadius: BorderRadius.circular(MessColors.radiusCard),
                      border: Border.all(color: MessColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A2A1F14),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: MessColors.orangeSoft,
                            borderRadius: BorderRadius.circular(MessColors.radiusControl),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            size: 28,
                            color: MessColors.orange,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No messes found here yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: MessColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try adjusting your food search, clearing filters, or check back once kitchen partners in this area join.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: MessColors.muted,
                            height: 1.4,
                          ),
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(height: 18),
                          OutlinedButton(
                            onPressed: _clearAllFilters,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: MessColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(MessColors.radiusControl),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: const Text(
                              'Reset filters & search',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MessColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _MessSearchTile(
                    provider: results[index],
                    onTap: () => Navigator.push(
                      context,
                      messRoute(MessDetailScreen(provider: results[index])),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterControl extends StatelessWidget {
  const _FilterControl({
    required this.label,
    required this.active,
    required this.onTap,
    this.showDropdown = true,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool showDropdown;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? MessColors.orangeSoft : MessColors.white,
          border: Border.all(
            color: active ? MessColors.orange : MessColors.border,
            width: active ? 1.2 : 1.0,
          ),
          borderRadius: BorderRadius.circular(MessColors.radiusControl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? MessColors.orangeDark : MessColors.ink,
              ),
            ),
            if (showDropdown) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: active ? MessColors.orangeDark : MessColors.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessSearchTile extends StatelessWidget {
  const _MessSearchTile({required this.provider, required this.onTap});

  final MessProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Only display lowest plan price if real plans exist
    final int? fromPrice = provider.plans.isNotEmpty
        ? provider.plans.map((p) => p.price).reduce((a, b) => a < b ? a : b)
        : null;

    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MessColors.white,
          borderRadius: BorderRadius.circular(MessColors.radiusCard),
          border: Border.all(color: MessColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D2A1F14), // rgba(42, 31, 20, 0.05)
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Provider Visual Icon / Glyph
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: MessColors.orangeSoft,
                borderRadius: BorderRadius.circular(MessColors.radiusControl),
              ),
              child: Center(
                child: Text(
                  provider.name.isNotEmpty ? provider.name.substring(0, 1).toUpperCase() : 'M',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: MessColors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Provider Info Hierarchy
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      color: MessColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    provider.area,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: MessColors.muted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (provider.distanceLabel.isNotEmpty) ...[
                        const Icon(Icons.near_me_rounded, size: 12, color: MessColors.muted),
                        const SizedBox(width: 3),
                        Text(
                          provider.distanceLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: MessColors.muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: provider.isOpen ? MessColors.greenSoft : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          provider.isOpen ? 'Open today' : 'Closed',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: provider.isOpen ? MessColors.green : MessColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Pricing & Minimal Navigation Affordance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (fromPrice != null) ...[
                  const Text(
                    'From',
                    style: TextStyle(fontSize: 10.5, color: MessColors.muted, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '₹$fromPrice',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: MessColors.ink,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded, size: 20, color: MessColors.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MessColors.white,
        borderRadius: BorderRadius.circular(MessColors.radiusCard),
        border: Border.all(color: MessColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEE6),
              borderRadius: BorderRadius.circular(MessColors.radiusControl),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEE6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 90,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEE6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.meal, required this.type, required this.openOnly});

  final String meal;
  final String type;
  final bool openOnly;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _meal = widget.meal;
  late String _type = widget.type;
  late bool _open = widget.openOnly;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: MessColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _meal = 'All meals';
                      _type = 'All plans';
                      _open = false;
                    }),
                    child: const Text(
                      'Reset',
                      style: TextStyle(color: MessColors.orange, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'MEAL SLOT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: MessColors.muted, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All meals', 'Breakfast', 'Lunch', 'Dinner'].map((m) {
                  final isSelected = _meal == m;
                  return ChoiceChip(
                    label: Text(m),
                    selected: isSelected,
                    selectedColor: MessColors.orangeSoft,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? MessColors.orange : MessColors.border),
                    labelStyle: TextStyle(
                      color: isSelected ? MessColors.orangeDark : MessColors.ink,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (_) => setState(() => _meal = m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const Text(
                'PLAN TYPE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: MessColors.muted, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All plans', 'Fixed-period', 'Meal tracker', 'Daily meal'].map((t) {
                  final isSelected = _type == t;
                  return ChoiceChip(
                    label: Text(t),
                    selected: isSelected,
                    selectedColor: MessColors.orangeSoft,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? MessColors.orange : MessColors.border),
                    labelStyle: TextStyle(
                      color: isSelected ? MessColors.orangeDark : MessColors.ink,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (_) => setState(() => _type = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: MessColors.orange,
                title: const Text('Open now only', style: TextStyle(fontWeight: FontWeight.w700, color: MessColors.ink)),
                value: _open,
                onChanged: (v) => setState(() => _open = v),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, {'meal': _meal, 'type': _type, 'open': _open}),
                style: FilledButton.styleFrom(
                  backgroundColor: MessColors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MessColors.radiusControl),
                  ),
                ),
                child: const Text('Apply filters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
        ),
      );
}
