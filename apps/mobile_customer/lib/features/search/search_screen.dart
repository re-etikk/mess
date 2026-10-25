import 'package:flutter/material.dart';

import '../../core/data/demo_data.dart';
import '../../core/models/mess_models.dart';
import '../../core/theme/mess_theme.dart';
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

  @override
  void dispose() { _query.dispose(); super.dispose(); }

  List<MessProvider> get _results {
    final query = _query.text.trim().toLowerCase();
    return DemoData.providers.where((provider) {
      final text = [provider.name, provider.area, provider.description, ...provider.mealSlots.map((s) => '${s.name} ${s.menuSummary}'), ...provider.mealSlots.expand((s) => s.items.map((i) => i.name))].join(' ').toLowerCase();
      final matchQuery = query.isEmpty || text.contains(query);
      final matchMeal = _mealFilter == 'All meals' || provider.mealSlots.any((slot) => slot.name.toLowerCase() == _mealFilter.toLowerCase());
      final matchType = _typeFilter == 'All plans' || provider.plans.any((plan) => plan.typeLabel == _typeFilter);
      return matchQuery && matchMeal && matchType && (!_openOnly || provider.isOpen);
    }).toList()..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }

  Future<void> _filters() async {
    final result = await showModalBottomSheet<Map<String, Object>>(context: context, isScrollControlled: true, builder: (context) => _FilterSheet(meal: _mealFilter, type: _typeFilter, openOnly: _openOnly));
    if (result == null) return;
    setState(() { _mealFilter = result['meal']! as String; _typeFilter = result['type']! as String; _openOnly = result['open']! as bool; });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: MessColors.cream,
      body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
        SliverPadding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 0), sliver: SliverToBoxAdapter(child: Row(children: [Expanded(child: Text('Find your mess', style: Theme.of(context).textTheme.headlineLarge)), IconButton(onPressed: _filters, tooltip: 'Filter results', icon: const Icon(Icons.tune_rounded))]))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 0), sliver: SliverToBoxAdapter(child: TextField(controller: _query, onChanged: (_) => setState(() {}), textInputAction: TextInputAction.search, decoration: InputDecoration(hintText: 'Mess, food item or cuisine', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _query.text.isEmpty ? null : IconButton(onPressed: () { _query.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded))))),),
        SliverPadding(padding: const EdgeInsets.fromLTRB(18, 11, 18, 0), sliver: SliverToBoxAdapter(child: Wrap(spacing: 7, runSpacing: 7, children: [
          _FilterChip(label: _mealFilter, active: _mealFilter != 'All meals', onTap: _filters),
          _FilterChip(label: _typeFilter, active: _typeFilter != 'All plans', onTap: _filters),
          if (_openOnly) _FilterChip(label: 'Open now', active: true, onTap: () => setState(() => _openOnly = false)),
        ]))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(18, 20, 18, 9), sliver: SliverToBoxAdapter(child: Row(children: [Text('Nearby', style: Theme.of(context).textTheme.titleLarge), const Spacer(), Text('${results.length} results', style: Theme.of(context).textTheme.bodySmall)]))),
        if (results.isEmpty)
          const SliverToBoxAdapter(child: EmptyState(icon: Icons.search_off_rounded, title: 'No matching messes', message: 'Try another food item, location or meal filter.'))
        else
          SliverPadding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), sliver: SliverList.separated(itemCount: results.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, index) => _MessSearchTile(provider: results[index], onTap: () => Navigator.push(context, messRoute(MessDetailScreen(provider: results[index])))))),
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
  Widget build(BuildContext context) => PressScale(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: active ? const Color(0xFFFFE8BF) : Colors.white, border: Border.all(color: active ? MessColors.orange : MessColors.border), borderRadius: BorderRadius.circular(9)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: active ? MessColors.orangeDark : MessColors.ink)), const SizedBox(width: 5), const Icon(Icons.keyboard_arrow_down_rounded, size: 16)])));
}

class _MessSearchTile extends StatelessWidget {
  const _MessSearchTile({required this.provider, required this.onTap});
  final MessProvider provider;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final daily = provider.plans.where((p) => p.type == SubscriptionType.dailyMeal).firstOrNull;
    final monthly = provider.plans.where((p) => p.type != SubscriptionType.dailyMeal).map((p) => p.price).toList();
    final amount = daily?.price ?? (monthly.isEmpty ? null : monthly.reduce((a, b) => a < b ? a : b));
    return CardSurface(onTap: onTap, padding: const EdgeInsets.all(13), child: Row(children: [
      Container(width: 68, height: 72, decoration: BoxDecoration(color: const Color(0xFFFFE8BF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.storefront_rounded, size: 31, color: MessColors.orangeDark)),
      const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(provider.name, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 3), Text('${provider.area} · ${provider.distanceLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 7), Wrap(spacing: 5, runSpacing: 4, children: [for (final slot in provider.mealSlots.take(3)) StatusTag(label: slot.name, color: MessColors.navySoft, background: const Color(0xFFF4ECDD))]), const SizedBox(height: 6), Text(daily == null ? 'Subscriptions available' : 'Daily meal from ₹${daily.price}', style: const TextStyle(fontSize: 11, color: MessColors.orangeDark, fontWeight: FontWeight.w700))])),
      const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [if (provider.isOpen) const StatusTag(label: 'Open', color: MessColors.green), const SizedBox(height: 8), if (amount != null) Text('₹$amount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: MessColors.navy)), const Icon(Icons.chevron_right_rounded, color: MessColors.muted)]),
    ]));
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
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 7, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Filters', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 18),
    Text('Meal time', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
    Wrap(spacing: 7, runSpacing: 7, children: ['All meals', 'Breakfast', 'Lunch', 'Dinner'].map((v) => ChoiceChip(label: Text(v), selected: _meal == v, onSelected: (_) => setState(() => _meal = v))).toList()),
    const SizedBox(height: 16), Text('Plan type', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
    Wrap(spacing: 7, runSpacing: 7, children: ['All plans', 'Fixed-period', 'Meal tracker', 'Daily meal'].map((v) => ChoiceChip(label: Text(v), selected: _type == v, onSelected: (_) => setState(() => _type = v))).toList()),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Open now'), value: _open, onChanged: (value) => setState(() => _open = value), activeColor: MessColors.orange),
    const SizedBox(height: 12), Row(children: [Expanded(child: MessActionButton(label: 'Reset', secondary: true, onPressed: () => setState(() { _meal = 'All meals'; _type = 'All plans'; _open = false; }))), const SizedBox(width: 10), Expanded(child: MessActionButton(label: 'Apply filters', onPressed: () => Navigator.pop(context, <String, Object>{'meal': _meal, 'type': _type, 'open': _open})))])
  ])));
}

extension _FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
