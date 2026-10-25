import 'package:flutter/material.dart';

import '../../core/data/demo_data.dart';
import '../../core/models/mess_models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../mess/mess_detail_screen.dart';
import '../plans/plans_screen.dart';
import '../scan/scan_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final subscription = state.activeSubscription;
        final hasSubscription = subscription != null && subscription.isValidToday;
        final subscriptionEligible = state.hasActiveSubscription;
        final provider = state.activeProvider ?? DemoData.providers.first;
        final now = DateTime.now();
        final menuSlot = _featuredSlot(provider, now);
        final nearby = DemoData.providers.where((item) => item.id != provider.id).toList();
        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverPadding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 0), sliver: SliverToBoxAdapter(child: _Header(location: state.location, onLocationTap: () => _showLocationPicker(context, state), onNotifications: () => _showNotifications(context)))),
            SliverPadding(padding: const EdgeInsets.fromLTRB(18, 17, 18, 0), sliver: SliverToBoxAdapter(child: _SearchBar(onTap: () => state.selectTab(1)))),
            if (hasSubscription && subscription != null)
              SliverPadding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 0), sliver: SliverToBoxAdapter(child: _SubscriptionCard(subscription: subscription, eligible: subscriptionEligible, onTap: () => Navigator.push(context, messRoute(const PlansScreen())))))
            else
              SliverPadding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 0), sliver: SliverToBoxAdapter(child: _NoPlanCard(onBrowse: () => Navigator.push(context, messRoute(PlansScreen(provider: provider))), onDailyMeal: () => state.selectTab(1)))),
            SliverPadding(padding: const EdgeInsets.fromLTRB(18, 22, 18, 0), sliver: SliverToBoxAdapter(child: _TodayHeading(date: now, onCalendar: () => _showSchedule(context, provider)))),
            SliverPadding(padding: const EdgeInsets.fromLTRB(18, 11, 18, 0), sliver: SliverToBoxAdapter(child: _MealSlots(provider: provider, state: state, activeSubscription: hasSubscription ? subscription : null, now: now))),
            SliverPadding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 0), sliver: SliverToBoxAdapter(child: _ScanBanner(enabled: state.canOpenScanner, onTap: () { if (state.canOpenScanner) { Navigator.push(context, messRoute(const ScanScreen())); } else { _showScannerGate(context, state, provider); } }))),
            SliverPadding(padding: const EdgeInsets.fromLTRB(18, 22, 18, 0), sliver: SliverToBoxAdapter(child: SectionHeading(title: menuSlot == null ? 'Today’s menu' : 'Today at ${provider.name}', actionLabel: 'Full menu', onAction: () => Navigator.push(context, messRoute(MessDetailScreen(provider: provider))))),),
            SliverPadding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 0), sliver: SliverToBoxAdapter(child: _CompactMenu(provider: provider, slot: menuSlot, onOpen: () => Navigator.push(context, messRoute(MessDetailScreen(provider: provider))))),),
            SliverPadding(padding: const EdgeInsets.fromLTRB(18, 22, 18, 0), sliver: SliverToBoxAdapter(child: SectionHeading(title: 'Nearby messes', actionLabel: 'View all', onAction: () => state.selectTab(1)))),
            SliverPadding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 22), sliver: SliverList.separated(
              itemCount: nearby.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) => _ProviderTile(provider: nearby[index], onTap: () => Navigator.push(context, messRoute(MessDetailScreen(provider: nearby[index])))),
            )),
          ],
        );
      },
    );
  }

  MealSlot? _featuredSlot(MessProvider provider, DateTime now) {
    final current = provider.mealSlots.where((slot) => slot.enabled && slot.contains(now)).firstOrNull;
    if (current != null) return current;
    for (final slot in provider.mealSlots) {
      if (slot.stateAt(now, redeemed: false) == MealState.upcoming) return slot;
    }
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.location, required this.onLocationTap, required this.onNotifications});
  final String location;
  final VoidCallback onLocationTap;
  final VoidCallback onNotifications;
  @override
  Widget build(BuildContext context) => Row(children: [
    const MessLogo(compact: true), const Spacer(),
    PressScale(onTap: onLocationTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: MessColors.border)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_on_rounded, color: MessColors.orange, size: 20), const SizedBox(width: 5), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 132), child: Text(location, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, height: 1.2))), const SizedBox(width: 4), const Icon(Icons.keyboard_arrow_down_rounded, size: 19)]))),
    const SizedBox(width: 7), PressScale(onTap: onNotifications, child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.notifications_none_rounded, size: 25, color: MessColors.navy))),
  ]);
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressScale(onTap: onTap, child: Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: MessColors.border), borderRadius: BorderRadius.circular(13)), child: Row(children: [const Icon(Icons.search_rounded, size: 23, color: MessColors.navy), const SizedBox(width: 10), Expanded(child: Text('Search mess, food or cuisine', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MessColors.muted))), const SizedBox(width: 8), const Icon(Icons.tune_rounded, size: 21, color: MessColors.navy)])));
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription, required this.eligible, required this.onTap});
  final ActiveSubscription subscription;
  final bool eligible;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final remaining = subscription.mealsRemaining;
    final total = subscription.totalMeals;
    final ratio = total == null || total == 0 ? 0.0 : (remaining! / total).clamp(0.0, 1.0).toDouble();
    return PressScale(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: MessColors.navy, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x15111F2C), blurRadius: 14, offset: Offset(0, 7))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF31C476), shape: BoxShape.circle)), const SizedBox(width: 7), Text(eligible ? 'ACTIVE SUBSCRIPTION' : 'MEALS USED UP · RENEW TO SCAN', style: const TextStyle(color: Color(0xFFC8D0D6), fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.w700)), const Spacer(), const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 15)]),
        const SizedBox(height: 11),
        Text(subscription.providerName, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -.4)),
        const SizedBox(height: 4),
        Text('${_planTypeLabel(subscription.type)}  ·  ${_slotNames(subscription.slotIds)}', style: const TextStyle(color: Color(0xFFD8E0E5), fontSize: 13)),
        const SizedBox(height: 15),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(total == null ? 'Access plan' : '$remaining / $total meals remaining', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
            if (total != null) ...[const SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(MessColors.orange)))],
          ])),
          const SizedBox(width: 18),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('VALID UNTIL', style: TextStyle(color: Color(0xFFABB7C0), fontSize: 9, letterSpacing: .8, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(formatDate(subscription.endDate), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700))]),
        ]),
      ]),
    ));
  }
  String _planTypeLabel(SubscriptionType type) => type == SubscriptionType.fixedPeriod ? 'Fixed period' : type == SubscriptionType.mealTracker ? 'Meal tracker' : 'Daily meal';
  String _slotNames(List<String> ids) => ids.map((id) => id[0].toUpperCase() + id.substring(1)).join(' + ');
}

class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard({required this.onBrowse, required this.onDailyMeal});
  final VoidCallback onBrowse;
  final VoidCallback onDailyMeal;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: MessColors.navy, borderRadius: BorderRadius.circular(17)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Eat today, your way.', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
    const SizedBox(height: 5), const Text('Find today’s menu or choose a subscription when you are ready.', style: TextStyle(color: Color(0xFFD5DDE2), fontSize: 12.5, height: 1.4)),
    const SizedBox(height: 14), Row(children: [Expanded(child: MessActionButton(label: 'Find a meal today', icon: Icons.restaurant_menu_rounded, onPressed: onDailyMeal, height: 44)), const SizedBox(width: 9), Expanded(child: MessActionButton(label: 'View plans', secondary: true, icon: Icons.calendar_month_rounded, onPressed: onBrowse, height: 44))]),
  ]));
}

class _TodayHeading extends StatelessWidget {
  const _TodayHeading({required this.date, required this.onCalendar});

  final DateTime date;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 3),
              Text(
                '${_weekday(date.weekday)}, ${date.day} ${_month(date.month)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        PressScale(
          onTap: onCalendar,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: MessColors.border),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_outlined, size: 17),
                SizedBox(width: 6),
                Text('Schedule', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _weekday(int day) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];
  String _month(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
}

class _MealSlots extends StatelessWidget {
  const _MealSlots({required this.provider, required this.state, required this.activeSubscription, required this.now});
  final MessProvider provider;
  final AppState state;
  final ActiveSubscription? activeSubscription;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final slots = provider.mealSlots.where((s) => s.enabled).toList();
    return LayoutBuilder(builder: (context, constraints) {
      final gap = 8.0;
      final width = (constraints.maxWidth - gap * (slots.length - 1)) / slots.length;
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var index = 0; index < slots.length; index++) ...[
          if (index > 0) SizedBox(width: gap),
          SizedBox(width: width, child: _MealSlotCard(slot: slots[index], state: state, provider: provider, now: now, activeSubscription: activeSubscription)),
        ],
      ]);
    });
  }
}

class _MealSlotCard extends StatelessWidget {
  const _MealSlotCard({required this.slot, required this.state, required this.provider, required this.now, required this.activeSubscription});
  final MealSlot slot;
  final AppState state;
  final MessProvider provider;
  final DateTime now;
  final ActiveSubscription? activeSubscription;
  @override
  Widget build(BuildContext context) {
    final redeemed = state.isSlotRedeemed(provider.id, slot.id, now);
    final status = slot.stateAt(now, redeemed: redeemed);
    final subscriptionCovers = activeSubscription != null && activeSubscription!.providerId == provider.id && activeSubscription!.isValidToday && activeSubscription!.slotIds.contains(slot.id) && activeSubscription!.hasMealsRemaining;
    final dailyCovers = state.dailyMeal != null && state.dailyMeal!.providerId == provider.id && state.dailyMeal!.slotId == slot.id && state.dailyMeal!.isPaid && state.dailyMeal!.isForToday(now);
    final notIncluded = (activeSubscription != null && !subscriptionCovers) || (activeSubscription == null && state.dailyMeal != null && !dailyCovers);
    final statusText = notIncluded ? 'Not in plan' : activeSubscription == null && !dailyCovers && status == MealState.available ? 'Buy meal' : switch (status) { MealState.redeemed => 'Redeemed', MealState.available => 'Available', MealState.upcoming => 'Upcoming', MealState.ended => 'Ended', MealState.unavailable => 'Unavailable' };
    final effectiveStatus = notIncluded ? MealState.unavailable : status;
    final isSelected = effectiveStatus == MealState.available;
    final color = effectiveStatus == MealState.redeemed ? MessColors.green : effectiveStatus == MealState.available ? MessColors.orangeDark : statusText == 'Buy meal' ? MessColors.orangeDark : MessColors.muted;
    return Container(padding: const EdgeInsets.fromLTRB(10, 12, 8, 11), decoration: BoxDecoration(color: effectiveStatus == MealState.redeemed ? const Color(0xFFF0F8F0) : Colors.white, border: Border.all(color: isSelected ? MessColors.orange : MessColors.border, width: isSelected ? 1.3 : .8), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(_icon(slot.id), color: color, size: 21), const SizedBox(height: 9),
      Text(slot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.3, fontWeight: FontWeight.w800, color: MessColors.navy)),
      const SizedBox(height: 4),
      Text(slot.timeLabel.replaceAll(' ', ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.8, color: MessColors.muted)),
      const SizedBox(height: 9),
      Row(children: [Icon(status == MealState.redeemed ? Icons.check_circle_rounded : status == MealState.available ? Icons.schedule_rounded : Icons.circle_outlined, size: 13, color: color), const SizedBox(width: 4), Expanded(child: Text(statusText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.6, color: color, fontWeight: FontWeight.w700)))]),
    ]));
  }
  IconData _icon(String id) => id == 'breakfast' ? Icons.wb_sunny_outlined : id == 'lunch' ? Icons.wb_sunny_rounded : Icons.nightlight_outlined;
}

class _ScanBanner extends StatelessWidget {
  const _ScanBanner({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressScale(onTap: onTap, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: MessColors.navy, borderRadius: BorderRadius.circular(16)), child: Row(children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: MessColors.orange, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.qr_code_scanner_rounded, size: 28, color: MessColors.navy)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(enabled ? 'Scan mess QR' : 'Scan mess QR', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(enabled ? 'Scan the provider’s daily code to redeem a meal.' : 'Scan after you have an active plan or paid daily meal.', style: const TextStyle(color: Color(0xFFD6DEE4), fontSize: 11.5, height: 1.35))])), const SizedBox(width: 7), const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 17)])));
}

class _CompactMenu extends StatelessWidget {
  const _CompactMenu({required this.provider, required this.slot, required this.onOpen});
  final MessProvider provider;
  final MealSlot? slot;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    if (slot == null) return CardSurface(padding: const EdgeInsets.all(14), onTap: onOpen, child: const Row(children: [Icon(Icons.restaurant_menu_rounded, size: 24, color: MessColors.orangeDark), SizedBox(width: 12), Expanded(child: Text('No more meal slots today. Check tomorrow’s menu or view other messes.', style: TextStyle(color: MessColors.muted, fontSize: 13))), Icon(Icons.chevron_right_rounded)]));
    final included = slot!.items.where((item) => item.kind == FoodItemKind.included).toList();
    final extras = slot!.items.where((item) => item.kind != FoodItemKind.included && item.available).take(2).toList();
    return CardSurface(padding: const EdgeInsets.all(14), onTap: onOpen, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 43, height: 43, decoration: BoxDecoration(color: const Color(0xFFFFE8BF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.restaurant_menu_rounded, color: MessColors.orangeDark, size: 23)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(slot!.name, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 2), Text(slot!.menuSummary, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)])), const Icon(Icons.chevron_right_rounded, color: MessColors.muted)]),
      if (included.isNotEmpty) ...[const SizedBox(height: 11), Wrap(spacing: 6, runSpacing: 6, children: included.take(5).map((item) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFF7F1E7), borderRadius: BorderRadius.circular(6)), child: Text(item.name, style: const TextStyle(fontSize: 10.5, color: MessColors.navy, fontWeight: FontWeight.w600)))).toList())],
      if (extras.isNotEmpty) ...[const SizedBox(height: 12), const Divider(height: 1), const SizedBox(height: 8), for (final item in extras) Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(children: [Expanded(child: Text(item.name, style: const TextStyle(fontSize: 12, color: MessColors.muted))), Text('₹${item.price}${item.portion == null ? '' : ' ${item.portion}'}', style: const TextStyle(fontSize: 11.5, color: MessColors.orangeDark, fontWeight: FontWeight.w800))]))],
    ]));
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.onTap});
  final MessProvider provider;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final prices = provider.plans.where((p) => p.type != SubscriptionType.dailyMeal).map((p) => p.price).toList();
    final from = prices.isEmpty ? provider.plans.firstOrNull?.price : prices.reduce((a, b) => a < b ? a : b);
    return CardSurface(onTap: onTap, padding: const EdgeInsets.all(12), child: Row(children: [
      Container(width: 58, height: 58, decoration: BoxDecoration(color: const Color(0xFFFFE8BF), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.storefront_rounded, color: MessColors.orangeDark, size: 28)),
      const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(provider.name, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 3), Text('${provider.area} · ${provider.distanceLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 7), Wrap(spacing: 5, children: provider.mealSlots.take(3).map((s) => Text(s.name, style: const TextStyle(color: MessColors.orangeDark, fontSize: 10.5, fontWeight: FontWeight.w700))).toList())])),
      const SizedBox(width: 7), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(from == null ? 'View plans' : 'From', style: Theme.of(context).textTheme.bodySmall), if (from != null) Text('₹$from', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 2), const Icon(Icons.chevron_right_rounded, size: 18, color: MessColors.muted)]),
    ]));
  }
}

Future<void> _showLocationPicker(BuildContext context, AppState state) async {
  final locations = ['IIT Hostel, Sector 62', 'Knowledge Park, Greater Noida', 'A Block, Student Hostel', 'Enter location manually'];
  final selected = await showModalBottomSheet<String>(context: context, builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your location', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 8), for (final location in locations) ListTile(leading: const Icon(Icons.location_on_outlined, color: MessColors.orangeDark), title: Text(location), trailing: state.location == location ? const Icon(Icons.check_circle_rounded, color: MessColors.green) : null, onTap: () => Navigator.pop(context, location))]))));
  if (selected == null) return;
  if (selected == 'Enter location manually') {
    final controller = TextEditingController(text: state.location);
    final result = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Enter location'), content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Hostel, area or landmark')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save'))]));
    controller.dispose();
    if (result != null && result.isNotEmpty) state.updateLocation(result);
  } else {
    state.updateLocation(selected);
  }
}

Future<void> _showScannerGate(BuildContext context, AppState state, MessProvider provider) async {
  final choice = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
    icon: const Icon(Icons.qr_code_scanner_rounded, size: 38, color: MessColors.orangeDark),
    title: const Text('Meal access required'),
    content: const Text('To scan a mess QR, you need an active subscription or a paid meal for today.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialogContext, 'daily'), child: const Text('Find today’s meal')),
      FilledButton(onPressed: () => Navigator.pop(dialogContext, 'plans'), child: const Text('View plans')),
    ],
  ));
  if (!context.mounted || choice == null) return;
  if (choice == 'plans') {
    Navigator.push(context, messRoute(PlansScreen(provider: provider)));
  } else {
    state.selectTab(1);
  }
}

void _showNotifications(BuildContext context) => showModalBottomSheet<void>(context: context, builder: (context) => const SafeArea(child: Padding(padding: EdgeInsets.all(24), child: EmptyState(icon: Icons.notifications_none_rounded, title: 'You’re all caught up', message: 'Subscription updates and meal reminders will appear here.'))));

void _showSchedule(BuildContext context, MessProvider provider) => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(22, 8, 22, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Meal schedule', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 6), Text(provider.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MessColors.muted)), const SizedBox(height: 14), for (final slot in provider.mealSlots) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.schedule_rounded, color: MessColors.orangeDark), title: Text(slot.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(slot.timeLabel), trailing: Text(slot.menuSummary, textAlign: TextAlign.end, style: const TextStyle(fontSize: 11, color: MessColors.muted))), const SizedBox(height: 10)]))));

String _weekday(int value) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][value - 1];
String _month(int value) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][value - 1];
String _planTypeLabel(SubscriptionType type) => type == SubscriptionType.fixedPeriod ? 'Fixed period' : type == SubscriptionType.mealTracker ? 'Meal tracker' : 'Daily meal';
String _slotNames(List<String> ids) => ids.map((id) => id[0].toUpperCase() + id.substring(1)).join(' + ');

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
