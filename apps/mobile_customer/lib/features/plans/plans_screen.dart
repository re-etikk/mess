import 'package:flutter/material.dart';

import '../../core/models/mess_models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../checkout/checkout_screen.dart';
import '../mess/mess_detail_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key, this.provider});
  final MessProvider? provider;
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  SubscriptionType? _filter;
  MessProvider? _resolvedProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveProvider();
  }

  Future<void> _resolveProvider() async {
    if (widget.provider != null) {
      setState(() => _resolvedProvider = widget.provider);
      return;
    }
    final appState = AppStateScope.of(context);
    if (appState.activeProvider != null) {
      setState(() => _resolvedProvider = appState.activeProvider);
      return;
    }
    final list = await appState.getProviders();
    if (mounted && list.isNotEmpty) {
      setState(() => _resolvedProvider = list.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final provider = _resolvedProvider ?? widget.provider ?? appState.activeProvider;

    if (provider == null) {
      return Scaffold(
        backgroundColor: MessColors.cream,
        appBar: AppBar(backgroundColor: MessColors.cream, title: const Text('Plans & Pricing')),
        body: const Center(
          child: EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No mess selected',
            message: 'Browse nearby messes and view their subscription plans.',
          ),
        ),
      );
    }

    final plans = provider.plans.where((plan) => _filter == null || plan.type == _filter).toList()
      ..sort((a, b) {
        if (a.type != b.type) return a.type.index.compareTo(b.type.index);
        return a.durationDays.compareTo(b.durationDays);
      });
    final current = appState.activeSubscription;

    return Scaffold(
      backgroundColor: MessColors.cream,
      body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Plans', style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 3),
                  Text('Clear pricing. Choose how you eat.', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
              IconButton(
                onPressed: () => Navigator.push(context, messRoute(MessDetailScreen(provider: provider))),
                tooltip: 'View mess',
                icon: const Icon(Icons.storefront_outlined),
              ),
            ]),
          ),
        ),
        if (current != null && current.isValidToday)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 0),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: MessColors.navy, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('YOUR CURRENT PLAN', style: TextStyle(color: Color(0xFFBDC8D0), fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  Text(current.providerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
                  const SizedBox(height: 4),
                  Text(current.planName, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                  const SizedBox(height: 9),
                  Row(children: [
                    Expanded(
                      child: Text(
                        current.mealsRemaining == null ? 'Active until ${formatDate(current.endDate)}' : '${current.mealsRemaining} meals remaining',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF45CA83), size: 18),
                  ]),
                ]),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
          sliver: SliverToBoxAdapter(child: Text(provider.name, style: Theme.of(context).textTheme.titleLarge)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Wrap(spacing: 7, runSpacing: 7, children: [
              _PlanFilterChip(label: 'All plans', selected: _filter == null, onTap: () => setState(() => _filter = null)),
              _PlanFilterChip(label: 'Fixed period', selected: _filter == SubscriptionType.fixedPeriod, onTap: () => setState(() => _filter = SubscriptionType.fixedPeriod)),
              _PlanFilterChip(label: 'Meal tracker', selected: _filter == SubscriptionType.mealTracker, onTap: () => setState(() => _filter = SubscriptionType.mealTracker)),
              _PlanFilterChip(label: 'Daily meal', selected: _filter == SubscriptionType.dailyMeal, onTap: () => setState(() => _filter = SubscriptionType.dailyMeal)),
            ]),
          ),
        ),
        if (plans.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(icon: Icons.event_busy_rounded, title: 'No plans in this category', message: 'Choose another plan type or check with the provider.'),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
            sliver: SliverList.separated(
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _PlanCard(plan: plans[index], onTap: () => _startCheckout(context, provider, plans[index])),
            ),
          ),
      ]),
    );
  }

  Future<void> _startCheckout(BuildContext context, MessProvider provider, MealPlan plan) async {
    String? slotId;
    if (plan.type == SubscriptionType.dailyMeal && plan.slotIds.length > 1) {
      slotId = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Choose a meal', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              for (final id in plan.slotIds)
                ListTile(
                  leading: const Icon(Icons.restaurant_menu_rounded, color: MessColors.orangeDark),
                  title: Text(id[0].toUpperCase() + id.substring(1)),
                  onTap: () => Navigator.pop(context, id),
                ),
            ]),
          ),
        ),
      );
      if (slotId == null) return;
    } else if (plan.slotIds.isNotEmpty) {
      slotId = plan.slotIds.first;
    }
    if (!context.mounted) return;
    Navigator.push(context, messRoute(CheckoutScreen(provider: provider, plan: plan, slotId: slotId)));
  }
}

class _PlanFilterChip extends StatelessWidget {
  const _PlanFilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? MessColors.navy : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: selected ? MessColors.navy : MessColors.border),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : MessColors.navy)),
        ),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onTap});

  final MealPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = switch (plan.type) {
      SubscriptionType.fixedPeriod => 'Access for ${plan.durationLabel}. Daily meal limits apply; no meal credits are deducted.',
      SubscriptionType.mealTracker => '${plan.includedMeals ?? 0} meals within ${plan.durationLabel}. Credits reduce after a successful redemption.',
      SubscriptionType.dailyMeal => 'One meal for today. Extras, if any, are charged separately.',
    };

    return CardSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      plan.typeLabel,
                      style: const TextStyle(fontSize: 12, color: MessColors.orangeDark, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                plan.durationLabel,
                style: const TextStyle(color: MessColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MessColors.muted)),
          const SizedBox(height: 13),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              PriceText(amount: plan.price),
              const Spacer(),
              if (plan.discountPercent > 0) StatusTag(label: 'Save ${plan.discountPercent}%', color: MessColors.green),
              const SizedBox(width: 9),
              const Icon(Icons.arrow_forward_rounded, color: MessColors.orangeDark, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
