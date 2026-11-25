import 'package:flutter/material.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

class PlansManagementTab extends StatefulWidget {
  const PlansManagementTab({super.key, required this.session});
  final ProviderSession session;

  @override
  State<PlansManagementTab> createState() => _PlansManagementTabState();
}

class _PlansManagementTabState extends State<PlansManagementTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loading = true);
    try {
      final list = await ProviderApiService.fetchProviderPlans(widget.session.providerId);
      if (mounted) {
        setState(() {
          _plans = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletePlan(String planId, String name) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThaliColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Archive Plan?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Remove "$name" from new customer checkouts? Active subscribers retain access.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThaliColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ProviderApiService.deletePlan(providerId: widget.session.providerId, planId: planId);
      if (mounted) {
        showPartnerNotice(context, 'Removed $name');
        await _loadPlans();
      }
    } catch (e) {
      if (mounted) showPartnerNotice(context, '$e', isError: true);
    }
  }

  Future<void> _savePlanSheet([Map<String, dynamic>? existing]) async {
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description']?.toString() ?? '');
    final daysCtrl = TextEditingController(text: (existing?['duration_days'] ?? 30).toString());
    final priceCtrl = TextEditingController(text: ((existing?['price_inr'] ?? existing?['price'] ?? 3000) as num).round().toString());
    final creditsCtrl = TextEditingController(text: (existing?['meal_credits'] ?? 60).toString());
    String planType = existing?['plan_type']?.toString() ?? 'fixed_period';
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: ThaliColors.stroke, borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  existing == null ? 'Create Subscription Plan' : 'Edit Subscription Plan',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Plan Title (e.g. Monthly 2-Meal Plan)')),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Short Description')),
                const SizedBox(height: 12),
                const Text('Plan Model', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Fixed Period'),
                      selected: planType == 'fixed_period',
                      selectedColor: ThaliColors.primarySoft,
                      onSelected: (_) => setSheetState(() => planType = 'fixed_period'),
                    ),
                    ChoiceChip(
                      label: const Text('Meal Tracker'),
                      selected: planType == 'meal_credits',
                      selectedColor: ThaliColors.primarySoft,
                      onSelected: (_) => setSheetState(() => planType = 'meal_credits'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: daysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Duration Days'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price (INR)', prefixText: '₹ '),
                      ),
                    ),
                  ],
                ),
                if (planType == 'meal_credits') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: creditsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Included Meal Credits'),
                  ),
                ],
                const SizedBox(height: 18),
                PartnerActionButton(
                  label: existing == null ? 'Publish Plan' : 'Save Changes',
                  loading: saving,
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final days = int.tryParse(daysCtrl.text.trim()) ?? 30;
                    final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                    if (name.isEmpty || price <= 0) return;
                    setSheetState(() => saving = true);
                    try {
                      await ProviderApiService.savePlan(
                        providerId: widget.session.providerId,
                        planId: existing?['id']?.toString(),
                        name: name,
                        description: descCtrl.text.trim(),
                        planType: planType,
                        durationDays: days,
                        priceInr: price,
                        mealCredits: planType == 'meal_credits' ? (int.tryParse(creditsCtrl.text.trim()) ?? 30) : null,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        showPartnerNotice(context, 'Saved $name');
                        await _loadPlans();
                      }
                    } catch (e) {
                      setSheetState(() => saving = false);
                      if (mounted) showPartnerNotice(context, '$e', isError: true);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              color: ThaliColors.card,
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Subscription Plans',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _savePlanSheet(),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: ThaliColors.primary),
                    label: const Text('New Plan', style: TextStyle(color: ThaliColors.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                color: ThaliColors.primary,
                onRefresh: _loadPlans,
                child: _loading
                    ? const PartnerSkeletonList(itemCount: 3, cardHeight: 120)
                    : _plans.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.all(24),
                            children: [
                              CardSurface(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    const Icon(Icons.card_membership_outlined, size: 44, color: ThaliColors.primary),
                                    const SizedBox(height: 12),
                                    const Text('No Plans Published', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Create Weekly, Monthly, or Meal-Credit plans for subscribers to purchase online or at counter.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: ThaliColors.muted, fontSize: 13),
                                    ),
                                    const SizedBox(height: 16),
                                    PartnerActionButton(label: 'Create First Plan', onPressed: () => _savePlanSheet()),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 118),
                            itemCount: _plans.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final p = _plans[i];
                              final id = p['id']?.toString() ?? '';
                              final name = p['name']?.toString() ?? 'Plan';
                              final price = ((p['price_inr'] ?? p['price'] ?? 0) as num).round();
                              final days = (p['duration_days'] as num?)?.toInt() ?? 30;
                              final type = p['plan_type']?.toString() == 'meal_credits' ? 'Meal Tracker' : 'Fixed Period';
                              final credits = (p['meal_credits'] as num?)?.toInt();

                              return CardSurface(
                                onTap: () => _savePlanSheet(p),
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                                        ),
                                        Text(rupee(price), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.primary)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$type · $days days${credits != null ? ' · $credits meals' : ''}',
                                      style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted, fontWeight: FontWeight.w600),
                                    ),
                                    if ((p['description']?.toString() ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(p['description'].toString(), style: const TextStyle(fontSize: 12.5, color: ThaliColors.body)),
                                    ],
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () => _savePlanSheet(p),
                                          child: const Text('Edit', style: TextStyle(color: ThaliColors.primary, fontWeight: FontWeight.w700)),
                                        ),
                                        if (id.isNotEmpty)
                                          TextButton(
                                            onPressed: () => _deletePlan(id, name),
                                            child: const Text('Remove', style: TextStyle(color: ThaliColors.red, fontWeight: FontWeight.w700)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
