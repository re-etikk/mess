import 'package:flutter/material.dart';

import '../../core/models/mess_models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../checkout/checkout_screen.dart';
import '../plans/plans_screen.dart';
import '../chat/customer_chat_screen.dart';

class MessDetailScreen extends StatefulWidget {
  const MessDetailScreen({super.key, required this.provider});

  final MessProvider provider;

  @override
  State<MessDetailScreen> createState() => _MessDetailScreenState();
}

class _MessDetailScreenState extends State<MessDetailScreen> {
  int _selectedSlot = 0;
  final Map<String, int> _extras = <String, int>{};
  late MessProvider _currentProvider;

  @override
  void initState() {
    super.initState();
    _currentProvider = widget.provider;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchLive());
  }

  Future<void> _fetchLive() async {
    if (!mounted) return;
    try {
      final repo = AppStateScope.of(context, listen: false).repository;
      final live = await repo.fetchLiveProvider(widget.provider.id);
      if (live != null && mounted) {
        setState(() {
          _currentProvider = live;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final provider = _currentProvider;
    if (provider.mealSlots.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)),
          title: Text(provider.name),
          actions: [
            IconButton(
              tooltip: 'Chat with Mess',
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerChatScreen(
                      providerId: provider.id,
                      providerName: provider.name,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _fetchLive,
          color: MessColors.orange,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 40),
              const Center(
                child: Icon(Icons.restaurant_menu_rounded, size: 64, color: MessColors.orangeDark),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('Menu Updating Soon', style: Theme.of(context).textTheme.headlineMedium),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'The mess owner is preparing today’s meal items. Pull down to refresh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MessColors.muted),
                ),
              ),
              const SizedBox(height: 24),
              if (provider.plans.isNotEmpty) ...[
                const SectionHeading(title: 'Available Subscription Plans', subtitle: 'View pricing & subscribe in advance'),
                const SizedBox(height: 12),
                for (final plan in provider.plans) ...[
                  CardSurface(
                    padding: const EdgeInsets.all(14),
                    onTap: () => Navigator.push(
                      context,
                      messRoute(CheckoutScreen(
                        provider: provider,
                        plan: plan,
                        slotId: 'lunch',
                        addOns: const [],
                      )),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sell_outlined, color: MessColors.orangeDark),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              Text('${plan.durationDays} days · ₹${plan.price}', style: const TextStyle(color: MessColors.muted, fontSize: 13)),
                            ],
                          ),
                        ),
                        Text('₹${plan.price}', style: const TextStyle(fontWeight: FontWeight.w900, color: MessColors.orangeDark, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
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
            tooltip: 'Chat with Mess',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CustomerChatScreen(
                    providerId: provider.id,
                    providerName: provider.name,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Share mess',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sharing will be connected in the production build.')),
            ),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLive,
        color: MessColors.orange,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CustomerChatScreen(
                                    providerId: provider.id,
                                    providerName: provider.name,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF38BDF8)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Chat with Mess',
                                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
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
                    label: Text('${entry.value.name} (${entry.value.timeLabel})'),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDE0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFD4B2)),
                          ),
                          child: Text(
                            slot.timeLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: MessColors.orangeDark,
                            ),
                          ),
                        ),
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
              child: SectionHeading(
                title: 'Plans & Pricing',
                subtitle: 'Subscribe to start enjoying hot daily meals',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  for (final plan in subscriptionPlans) ...[
                    CardSurface(
                      padding: const EdgeInsets.all(15),
                      onTap: () => Navigator.push(
                        context,
                        messRoute(CheckoutScreen(
                          provider: provider,
                          plan: plan,
                          slotId: slot.id,
                          addOns: selectedAddOns,
                        )),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: plan.type == SubscriptionType.mealTracker
                                  ? const Color(0xFFE0F2FE)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              plan.type == SubscriptionType.mealTracker
                                  ? Icons.confirmation_number_outlined
                                  : Icons.calendar_month_outlined,
                              color: plan.type == SubscriptionType.mealTracker
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        plan.name,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: MessColors.ink),
                                      ),
                                    ),
                                    Text(
                                      '₹${plan.price}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: MessColors.orangeDark),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: plan.type == SubscriptionType.mealTracker
                                            ? const Color(0xFFE0F2FE)
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        plan.type == SubscriptionType.mealTracker ? 'COUNTING PLAN' : 'FIXED PLAN',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: plan.type == SubscriptionType.mealTracker
                                              ? const Color(0xFF0369A1)
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      plan.type == SubscriptionType.mealTracker
                                          ? '${plan.includedMeals ?? 30} meals · ${plan.durationDays} days validity'
                                          : '${plan.durationDays} days · Lunch & Dinner',
                                      style: const TextStyle(fontSize: 12, color: MessColors.muted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: MessColors.muted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                  ],
                  if (dailyPlans.isNotEmpty) ...[
                    CardSurface(
                      padding: const EdgeInsets.all(15),
                      onTap: () => Navigator.push(
                        context,
                        messRoute(CheckoutScreen(
                          provider: provider,
                          plan: dailyPlans.first,
                          slotId: slot.id,
                          addOns: selectedAddOns,
                        )),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: const Color(0xFFFFE8BF), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.today_rounded, color: MessColors.orangeDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Daily Single Meal', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 3),
                                const Text('Pay for one meal only.', style: TextStyle(fontSize: 12, color: MessColors.muted)),
                              ],
                            ),
                          ),
                          Text('₹${dailyPlans.first.price}', style: const TextStyle(fontWeight: FontWeight.w800, color: MessColors.orangeDark, fontSize: 16)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: MessColors.muted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                  ],
                  CardSurface(
                    padding: const EdgeInsets.all(13),
                    onTap: () => Navigator.push(context, messRoute(PlansScreen(provider: provider))),
                    child: const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: MessColors.navy, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Compare all plans & upgrade rules',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MessColors.navy),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: MessColors.muted),
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
