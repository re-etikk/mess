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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loadProviders();
    }
  }

  Future<void> _loadProviders() async {
    final state = AppStateScope.of(context);
    final list = await state.getProviders();
    if (mounted) {
      setState(() {
        _providers = list;
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
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
      final matchMeal = _mealFilter == 'All meals' || provider.mealSlots.any((slot) => slot.name.toLowerCase() == _mealFilter.toLowerCase());
      final matchType = _typeFilter == 'All plans' || provider.plans.any((plan) => plan.typeLabel == _typeFilter);
      return matchQuery && matchMeal && matchType && (!_openOnly || provider.isOpen);
    }).toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }

  Future<void> _filters() async {
    final result = await showModalBottomSheet<Map<String, Object>>(
      context: context,
      isScrollControlled: true,
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
      body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              Expanded(child: Text('Find your mess', style: Theme.of(context).textTheme.headlineLarge)),
              IconButton(onPressed: _filters, tooltip: 'Filter results', icon: const Icon(Icons.tune_rounded)),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Mess, food item or cuisine',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 11, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Wrap(spacing: 7, runSpacing: 7, children: [
              _FilterChip(label: _mealFilter, active: _mealFilter != 'All meals', onTap: _filters),
              _FilterChip(label: _typeFilter, active: _typeFilter != 'All plans', onTap: _filters),
              if (_openOnly) _FilterChip(label: 'Open now', active: true, onTap: () => setState(() => _openOnly = false)),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 9),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              Text('Nearby messes', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text('${results.length} available', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
        if (!_loaded)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(color: MessColors.orange)),
          )
        else if (results.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No registered messes found',
              message: 'Try another food item, area, or check back once kitchen partners register.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverList.separated(
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _MessSearchTile(
                provider: results[index],
                onTap: () => Navigator.push(context, messRoute(MessDetailScreen(provider: results[index]))),
              ),
            ),
          ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFE8BF) : Colors.white,
            border: Border.all(color: active ? MessColors.orange : MessColors.border),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: active ? MessColors.orangeDark : MessColors.ink)),
            const SizedBox(width: 5),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          ]),
        ),
      );
}

class _MessSearchTile extends StatelessWidget {
  const _MessSearchTile({required this.provider, required this.onTap});
  final MessProvider provider;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final fromPrice = provider.plans.isEmpty ? 95 : provider.plans.map((p) => p.price).reduce((a, b) => a < b ? a : b);
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: MessColors.border)),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: const Color(0xFFFFF0D8), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.storefront_rounded, color: MessColors.orangeDark, size: 26),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(provider.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: MessColors.ink)),
              const SizedBox(height: 2),
              Text(provider.area, style: const TextStyle(fontSize: 12, color: MessColors.muted)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.near_me_rounded, size: 13, color: MessColors.muted),
                const SizedBox(width: 4),
                Text(provider.distanceLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: MessColors.muted)),
                const SizedBox(width: 8),
                Text(provider.isOpen ? 'Open today' : 'Closed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: provider.isOpen ? MessColors.green : MessColors.muted)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('From', style: TextStyle(fontSize: 10, color: MessColors.muted)),
            Text('₹$fromPrice', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: MessColors.ink)),
            const SizedBox(height: 3),
            const Icon(Icons.chevron_right_rounded, size: 18, color: MessColors.muted),
          ]),
        ]),
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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Filters', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _meal = 'All meals';
                  _type = 'All plans';
                  _open = false;
                }),
                child: const Text('Reset'),
              ),
            ]),
            const SizedBox(height: 14),
            const Text('MEAL SLOT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: MessColors.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 7, children: ['All meals', 'Breakfast', 'Lunch', 'Dinner'].map((m) => ChoiceChip(label: Text(m), selected: _meal == m, onSelected: (_) => setState(() => _meal = m))).toList()),
            const SizedBox(height: 16),
            const Text('PLAN TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: MessColors.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 7, children: ['All plans', 'Fixed-period', 'Meal tracker', 'Daily meal'].map((t) => ChoiceChip(label: Text(t), selected: _type == t, onSelected: (_) => setState(() => _type = t))).toList()),
            const SizedBox(height: 16),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Open now only', style: TextStyle(fontWeight: FontWeight.w700)), value: _open, onChanged: (v) => setState(() => _open = v)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context, {'meal': _meal, 'type': _type, 'open': _open}),
              style: FilledButton.styleFrom(backgroundColor: MessColors.orange, foregroundColor: MessColors.ink, minimumSize: const Size.fromHeight(48)),
              child: const Text('Apply filters', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      );
}
