import 'package:flutter/material.dart';

import '../../core/models/mess_models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../checkout/checkout_screen.dart';
import '../plans/plans_screen.dart';

class MessDetailScreen extends StatefulWidget {
  const MessDetailScreen({super.key, required this.provider});

  final MessProvider provider;

  @override
  State<MessDetailScreen> createState() => _MessDetailScreenState();
}

class _MessDetailScreenState extends State<MessDetailScreen> {
  int _selectedSlot = 0;
  final Map<String, int> _extras = <String, int>{};

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final provider = widget.provider;
    if (provider.mealSlots.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(provider.name)),
        body: const EmptyState(
          icon: Icons.restaurant_menu_rounded,
          title: 'Menu not available',
          message: 'This provider has not published meal slots yet.',
        ),
      );
    }

    final slotIndex = _selectedSlot.clamp(0, provider.mealSlots.length - 1).toInt();
    final slot = provider.mealSlots[slotIndex];
    final extras = slot.items.where((item) => item.kind != FoodItemKind.included && item.available).toList();
    final selectedAddOns = <CartAddOn>[
      for (final item in extras)
        if ((_extras[item.id] ?? 0) > 0) CartAddOn(item: item, quantity: _extras[item.id]!),
    ];
    final extrasTotal = selectedAddOns.fold<int>(0, (total, entry) => total + entry.total);
    final dailyPlans = provider.plans.where((plan) => plan.type == SubscriptionType.dailyMeal && plan.slotIds.contains(slot.id)).toList();
    final subscriptionPlans = provider.plans.where((plan) => plan.type != SubscriptionType.dailyMeal).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)),
        title: Text(provider.name),
        actions: [
          IconButton(
            tooltip: 'Share mess',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sharing will be connected in the production build.')),
            ),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: MessColors.navy, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: const Color(0xFFFFE8BF), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.storefront_rounded, color: MessColors.orangeDark, size: 32),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(provider.name, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(provider.area, style: const TextStyle(color: Color(0xFFD5DEE5), fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.circle, size: 8, color: provider.isOpen ? const Color(0xFF39C77A) : MessColors.muted),
                              const SizedBox(width: 5),
                              Text(
                                provider.isOpen ? 'Open' : 'Closed',
                                style: TextStyle(fontSize: 12, color: provider.isOpen ? const Color(0xFF78DEA4) : Colors.white70, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.location_on_outlined, size: 14, color: Colors.white70),
                              Text(provider.distanceLabel, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
            sliver: SliverToBoxAdapter(
              child: SectionHeading(title: 'Today’s menu', subtitle: 'Menu and availability set by the provider'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.mealSlots.asMap().entries.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.value.name),
                    selected: slotIndex == entry.key,
                    onSelected: (_) => setState(() {
                      _selectedSlot = entry.key;
                      _extras.clear();
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            sliver: SliverToBoxAdapter(
              child: CardSurface(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 19, color: MessColors.orangeDark),
                        const SizedBox(width: 8),
                        Text(slot.name, style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        Text(slot.timeLabel, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(slot.menuSummary, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 13),
                    const Divider(height: 1),
                    const SizedBox(height: 7),
                    for (final item in slot.items.where((item) => item.kind == FoodItemKind.included))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: MessColors.green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                            Text(item.portion ?? 'Included', style: const TextStyle(fontSize: 11, color: MessColors.muted)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (extras.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 23, 18, 9),
              sliver: SliverToBoxAdapter(
                child: SectionHeading(title: 'Specials and extras', subtitle: 'Optional items charged separately'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              sliver: SliverList.separated(
                itemCount: extras.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = extras[index];
                  final quantity = _extras[item.id] ?? 0;
                  return CardSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    child: Row(
                      children: [
                        FoodGlyph(name: item.name, size: 45),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              const SizedBox(height: 3),
                              Text(item.portion ?? 'Optional add-on', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Text('₹${item.price}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(width: 12),
                        _QuantityControl(
                          quantity: quantity,
                          onMinus: quantity > 0 ? () => setState(() => _extras[item.id] = quantity - 1) : null,
                          onPlus: quantity < item.maxQuantity ? () => setState(() => _extras[item.id] = quantity + 1) : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 23, 18, 9),
            sliver: SliverToBoxAdapter(
              child: SectionHeading(title: 'Choose how to eat', subtitle: 'Options depend on this provider’s setup'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  CardSurface(
                    padding: const EdgeInsets.all(14),
                    onTap: dailyPlans.isEmpty
                        ? null
                        : () => Navigator.push(
                              context,
                              messRoute(CheckoutScreen(provider: provider, plan: dailyPlans.first, slotId: slot.id, addOns: selectedAddOns)),
                            ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: const Color(0xFFFFE8BF), borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.today_rounded, color: MessColors.orangeDark),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Daily meal', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 3),
                              Text('Pay for this meal only.', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Text(
                          dailyPlans.isEmpty ? 'Not offered' : 'From ₹${dailyPlans.map((p) => p.price).reduce((a, b) => a < b ? a : b)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: MessColors.orangeDark),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.chevron_right_rounded, color: MessColors.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  CardSurface(
                    padding: const EdgeInsets.all(14),
                    onTap: () => Navigator.push(context, messRoute(PlansScreen(provider: provider))),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: const Color(0xFFE9EEF1), borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.calendar_month_rounded, color: MessColors.navy),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Subscription plans', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 3),
                              Text('${subscriptionPlans.length} provider-configured options', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: MessColors.muted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          decoration: const BoxDecoration(color: MessColors.white, border: Border(top: BorderSide(color: MessColors.border))),
          child: Row(
            children: [
              if (extrasTotal > 0)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${selectedAddOns.fold<int>(0, (sum, item) => sum + item.quantity)} extras selected', style: const TextStyle(fontSize: 11, color: MessColors.muted)),
                      Text('₹$extrasTotal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              if (extrasTotal > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: MessActionButton(
                  label: extrasTotal > 0 ? 'Review extras' : 'View plans',
                  onPressed: () {
                    if (extrasTotal > 0) {
                      _startExtrasCheckout(context, state, provider, slot, dailyPlans, selectedAddOns);
                    } else {
                      Navigator.push(context, messRoute(PlansScreen(provider: provider)));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startExtrasCheckout(
    BuildContext context,
    AppState state,
    MessProvider provider,
    MealSlot slot,
    List<MealPlan> dailyPlans,
    List<CartAddOn> extras,
  ) {
    final subscription = state.activeSubscription;
    final subscribedToThisSlot = state.hasActiveSubscription &&
        subscription != null &&
        subscription.providerId == provider.id &&
        subscription.slotIds.contains(slot.id);
    final daily = state.dailyMeal;
    final hasPaidDailyMeal = daily != null &&
        daily.providerId == provider.id &&
        daily.slotId == slot.id &&
        daily.isForToday(DateTime.now());

    if (subscribedToThisSlot || hasPaidDailyMeal) {
      Navigator.push(context, messRoute(CheckoutScreen(provider: provider, addOns: extras)));
      return;
    }
    if (dailyPlans.isNotEmpty) {
      Navigator.push(context, messRoute(CheckoutScreen(provider: provider, plan: dailyPlans.first, slotId: slot.id, addOns: extras)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a valid meal plan before purchasing extras.')));
    Navigator.push(context, messRoute(PlansScreen(provider: provider)));
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({required this.quantity, required this.onMinus, required this.onPlus});

  final int quantity;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (quantity > 0) ...[
          InkWell(
            onTap: onMinus,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(border: Border.all(color: MessColors.border), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.remove_rounded, size: 16),
            ),
          ),
          const SizedBox(width: 7),
          Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 7),
        ],
        InkWell(
          onTap: onPlus,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: MessColors.orange, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.add_rounded, size: 17, color: MessColors.navy),
          ),
        ),
      ],
    );
  }
}
