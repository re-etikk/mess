import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final subscription = state.activeSubscription;
        final hasSubscription = subscription != null && subscription.isValidToday;
        final subscriptionEligible = state.hasActiveSubscription;
        final provider = state.activeProvider ?? (_providers.isNotEmpty ? _providers.first : null);
        final now = DateTime.now();
        final menuSlot = provider != null ? _featuredSlot(provider, now) : null;
        final nearby = provider != null ? _providers.where((item) => item.id != provider.id).toList() : <MessProvider>[];

        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              sliver: SliverToBoxAdapter(
                child: _Header(
                  location: state.location,
                  onLocationTap: () => _showLocationPicker(context, state),
                  onNotifications: () => _showNotifications(context),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 0),
              sliver: SliverToBoxAdapter(child: _SearchBar(onTap: () => state.selectTab(1))),
            ),
            if (hasSubscription && subscription != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: _SubscriptionCard(
                    subscription: subscription,
                    eligible: subscriptionEligible,
                    onTap: () => Navigator.push(context, messRoute(const PlansScreen())),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: _NoPlanCard(
                    onBrowse: () => Navigator.push(
                      context,
                      messRoute(PlansScreen(provider: provider)),
                    ),
                    onDailyMeal: () => state.selectTab(1),
                  ),
                ),
              ),
            if (provider == null)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(18, 24, 18, 24),
                sliver: SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No Registered Messes Nearby',
                    message: 'No active mess services found in this area. Once kitchen partners register their mess, they will appear here.',
                  ),
                ),
              )
            else ...[
              if (!provider.isOpen)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.6)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_clock_rounded, color: Color(0xFFF87171), size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🔒 MESS OFF / CLOSED TODAY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'This kitchen is marked closed today. Meal redemptions are paused and days are not deducted.',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    height: 1.3,
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
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: _TodayHeading(date: now, onCalendar: () => _showSchedule(context, provider)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 11, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: _MealSlots(
                    provider: provider,
                    state: state,
                    activeSubscription: hasSubscription ? subscription : null,
                    now: now,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: _ScanBanner(
                    enabled: state.canOpenScanner && provider.isOpen,
                    onTap: () {
                      if (!provider.isOpen) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔒 Mess Closed Today: Kitchen is not serving meals today.'),
                            backgroundColor: Color(0xFFC0392B),
                          ),
                        );
                        return;
                      }
                      Navigator.push(context, messRoute(const ScanScreen()));
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: SectionHeading(
                    title: menuSlot == null ? 'Today’s menu' : 'Today at ${provider.name}',
                    actionLabel: 'Full menu',
                    onAction: () => Navigator.push(context, messRoute(MessDetailScreen(provider: provider))),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: _CompactMenu(
                    provider: provider,
                    slot: menuSlot,
                    onOpen: () => Navigator.push(context, messRoute(MessDetailScreen(provider: provider))),
                  ),
                ),
              ),
              if (nearby.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeading(
                      title: 'Nearby messes',
                      actionLabel: 'View all',
                      onAction: () => state.selectTab(1),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                  sliver: SliverList.separated(
                    itemCount: nearby.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) => _ProviderTile(
                      provider: nearby[index],
                      onTap: () => Navigator.push(context, messRoute(MessDetailScreen(provider: nearby[index]))),
                    ),
                  ),
                ),
              ],
            ],
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
        const MessLogo(compact: true),
        const Spacer(),
        PressScale(
          onTap: onLocationTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: MessColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on_rounded, color: MessColors.orange, size: 20),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 132),
                child: Text(location, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, height: 1.2)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
            ]),
          ),
        ),
        const SizedBox(width: 7),
        PressScale(onTap: onNotifications, child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.notifications_none_rounded, size: 25, color: MessColors.navy))),
      ]);
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: MessColors.border), borderRadius: BorderRadius.circular(13)),
          child: Row(children: [
            const Icon(Icons.search_rounded, size: 23, color: MessColors.navy),
            const SizedBox(width: 10),
            Expanded(child: Text('Search mess, food or cuisine', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MessColors.muted))),
            const SizedBox(width: 8),
            const Icon(Icons.tune_rounded, size: 21, color: MessColors.navy),
          ]),
        ),
      );
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
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: MessColors.navy, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x15111F2C), blurRadius: 14, offset: Offset(0, 7))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF31C476), shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text(eligible ? 'ACTIVE SUBSCRIPTION' : 'MEALS USED UP · RENEW TO SCAN', style: const TextStyle(color: Color(0xFFC8D0D6), fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.w700)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 15),
          ]),
          const SizedBox(height: 11),
          Text(subscription.providerName, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -.4)),
          const SizedBox(height: 4),
          Text('${_planTypeLabel(subscription.type)}  ·  ${_slotNames(subscription.slotIds)}', style: const TextStyle(color: Color(0xFFD8E0E5), fontSize: 13)),
          const SizedBox(height: 15),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(total == null ? 'Access plan' : '$remaining / $total meals remaining', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                if (total != null) ...[const SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(MessColors.orange)))],
              ]),
            ),
            const SizedBox(width: 18),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('VALID UNTIL', style: TextStyle(color: Color(0xFFABB7C0), fontSize: 9, letterSpacing: .8, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(formatDate(subscription.endDate), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ]),
      ),
    );
  }
}

class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard({required this.onBrowse, required this.onDailyMeal});
  final VoidCallback onBrowse;
  final VoidCallback onDailyMeal;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: MessColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.shield_outlined, color: MessColors.orange, size: 20),
            const SizedBox(width: 7),
            Text('NO ACTIVE PLAN', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: MessColors.muted, letterSpacing: 1.0)),
          ]),
          const SizedBox(height: 8),
          const Text('Subscribe or buy a meal pass', style: TextStyle(color: MessColors.ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Scan works only with an active subscription or single meal ticket.', style: TextStyle(color: MessColors.muted, fontSize: 12.5)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: onBrowse,
                style: FilledButton.styleFrom(backgroundColor: MessColors.orange, foregroundColor: MessColors.ink),
                child: const Text('View plans', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onDailyMeal,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: MessColors.border)),
                child: const Text('Find mess', style: TextStyle(color: MessColors.ink, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      );
}

class _TodayHeading extends StatelessWidget {
  const _TodayHeading({required this.date, required this.onCalendar});
  final DateTime date;
  final VoidCallback onCalendar;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Today’s status', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text('${_weekday(date.weekday)}, ${date.day} ${_month(date.month)}', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        PressScale(
          onTap: onCalendar,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: MessColors.border)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: MessColors.navy),
              SizedBox(width: 5),
              Text('Schedule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: MessColors.navy)),
            ]),
          ),
        ),
      ]);
}

class _MealSlots extends StatelessWidget {
  const _MealSlots({required this.provider, required this.state, required this.activeSubscription, required this.now});
  final MessProvider provider;
  final AppState state;
  final ActiveSubscription? activeSubscription;
  final DateTime now;
  @override
  Widget build(BuildContext context) => Row(
        children: provider.mealSlots.map((slot) {
          final redeemed = state.isSlotRedeemed(provider.id, slot.id, now);
          final slotState = slot.stateAt(now, redeemed: redeemed);
          final covered = activeSubscription?.slotIds.contains(slot.id) ?? false;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: slot == provider.mealSlots.last ? 0 : 8),
              child: _SlotCard(slot: slot, state: slotState, coveredByPlan: covered),
            ),
          );
        }).toList(),
      );
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, required this.state, required this.coveredByPlan});
  final MealSlot slot;
  final MealState state;
  final bool coveredByPlan;
  @override
  Widget build(BuildContext context) {
    final (bg, border, text, badge, badgeBg) = switch (state) {
      MealState.available => (const Color(0xFFFFF6E8), MessColors.orange, MessColors.ink, 'LIVE', MessColors.orange),
      MealState.redeemed => (const Color(0xFFEDF8F1), const Color(0xFF90DDB0), const Color(0xFF14532D), 'DONE', MessColors.green),
      MealState.upcoming => (Colors.white, MessColors.border, MessColors.ink, 'NEXT', const Color(0xFF6B7280)),
      MealState.ended => (const Color(0xFFF3F4F6), MessColors.border, const Color(0xFF6B7280), 'CLOSED', const Color(0xFF9CA3AF)),
      MealState.unavailable => (Colors.white, MessColors.border, const Color(0xFF9CA3AF), 'OFF', const Color(0xFF9CA3AF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border, width: state == MealState.available ? 1.5 : 1), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(slot.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: text))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(5)), child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: .5))),
        ]),
        const SizedBox(height: 5),
        Text(slot.timeLabel, style: const TextStyle(fontSize: 10, color: MessColors.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        Text(coveredByPlan ? 'Plan covered' : 'Pay extra', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: coveredByPlan ? MessColors.green : MessColors.muted)),
      ]),
    );
  }
}

class _ScanBanner extends StatelessWidget {
  const _ScanBanner({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: MessColors.orange, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x28F59A16), blurRadius: 14, offset: Offset(0, 6))]),
          child: const Row(children: [
            Icon(Icons.qr_code_scanner_rounded, size: 30, color: MessColors.ink),
            SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Scan mess QR code', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: MessColors.ink)),
                SizedBox(height: 2),
                Text('Point at the counter QR to redeem your meal', style: TextStyle(color: MessColors.ink, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            Icon(Icons.arrow_forward_rounded, color: MessColors.ink, size: 20),
          ]),
        ),
      );
}

class _CompactMenu extends StatelessWidget {
  const _CompactMenu({required this.provider, required this.slot, required this.onOpen});
  final MessProvider provider;
  final MealSlot? slot;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    if (slot == null) {
      return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: MessColors.border)), child: const Text('Menu schedule not available for this time.', style: TextStyle(color: MessColors.muted)));
    }
    final included = slot!.items.where((i) => i.kind == FoodItemKind.included).toList();
    final addons = slot!.items.where((i) => i.kind == FoodItemKind.addOn).toList();
    return PressScale(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: MessColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${slot!.name} menu', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: MessColors.ink)),
            const Spacer(),
            Text(slot!.timeLabel, style: const TextStyle(fontSize: 11, color: MessColors.muted, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: included.map((item) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF5F2EB), borderRadius: BorderRadius.circular(8)), child: Text(item.name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: MessColors.ink)))).toList()),
          if (addons.isNotEmpty) ...[
            const SizedBox(height: 11),
            Row(children: [
              const Icon(Icons.add_circle_outline_rounded, size: 14, color: MessColors.orangeDark),
              const SizedBox(width: 5),
              Expanded(child: Text('Extras: ${addons.map((a) => '${a.name} (₹${a.price})').join(', ')}', style: const TextStyle(fontSize: 11, color: MessColors.muted, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.onTap});
  final MessProvider provider;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final from = provider.plans.isEmpty ? null : provider.plans.map((p) => p.price).reduce((a, b) => a < b ? a : b);
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: MessColors.border)),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFFFF0D8), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.storefront_rounded, color: MessColors.orangeDark, size: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(provider.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: MessColors.ink)),
              const SizedBox(height: 2),
              Text(provider.area, style: const TextStyle(fontSize: 11.5, color: MessColors.muted)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.near_me_rounded, size: 12, color: MessColors.muted),
                const SizedBox(width: 3),
                Text(provider.distanceLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: MessColors.muted)),
                const SizedBox(width: 8),
                Text(provider.isOpen ? 'Open today' : 'Closed', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: provider.isOpen ? MessColors.green : MessColors.muted)),
              ]),
            ]),
          ),
          const SizedBox(width: 7),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(from == null ? 'View plans' : 'From', style: Theme.of(context).textTheme.bodySmall),
            if (from != null) Text('₹$from', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            const Icon(Icons.chevron_right_rounded, size: 18, color: MessColors.muted),
          ]),
        ]),
      ),
    );
  }
}

Future<void> _showLocationPicker(BuildContext context, AppState state) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _GoogleMapsLocationPickerSheet(currentLocation: state.location),
  );
  if (result != null && result.trim().isNotEmpty) {
    state.updateLocation(result.trim());
  }
}

class _GoogleMapsLocationPickerSheet extends StatefulWidget {
  const _GoogleMapsLocationPickerSheet({required this.currentLocation});
  final String currentLocation;
  @override
  State<_GoogleMapsLocationPickerSheet> createState() => _GoogleMapsLocationPickerSheetState();
}

class _GoogleMapsLocationPickerSheetState extends State<_GoogleMapsLocationPickerSheet> {
  final _controller = TextEditingController();
  List<String> _suggestions = [];
  bool _searching = false;

  final List<String> _quickLocations = const [
    'Sector 62, Noida, Uttar Pradesh',
    'Knowledge Park, Greater Noida',
    'BTM Layout, Bengaluru, Karnataka',
    'Koramangala, Bengaluru, Karnataka',
    'Marathahalli, Bengaluru, Karnataka',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onQueryChanged(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final url = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': q,
          'key': 'AIzaSyDnD2JUGtjeZvTETWi4bz7nBvu364T11ds',
          'components': 'country:in',
        },
      );
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final preds = (data['predictions'] as List<dynamic>? ?? []);
        final list = preds.map((p) => p['description']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        if (mounted) setState(() => _suggestions = list);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 16,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Delivery Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MessColors.ink),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search hostel, landmark or city (Google Maps)',
              prefixIcon: const Icon(Icons.search, color: MessColors.orangeDark),
              suffixIcon: _searching
                  ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: MessColors.orangeDark)))
                  : (_controller.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _controller.clear(); _onQueryChanged(''); })
                      : null),
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.my_location_rounded, color: Color(0xFF2E7D32)),
            ),
            title: const Text('Use Live Detected Location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: MessColors.ink)),
            subtitle: const Text('Auto-detect your hostel or campus area', style: TextStyle(fontSize: 12, color: MessColors.muted)),
            onTap: () => Navigator.pop(context, 'Sector 62, Noida (Live GPS)'),
          ),
          const Divider(height: 20),
          if (_suggestions.isNotEmpty) ...[
            const Text('Google Maps Suggestions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: MessColors.muted)),
            const SizedBox(height: 8),
            ..._suggestions.take(5).map((loc) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined, color: MessColors.orangeDark),
              title: Text(loc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: MessColors.ink)),
              trailing: widget.currentLocation == loc ? const Icon(Icons.check, color: MessColors.green) : null,
              onTap: () => Navigator.pop(context, loc),
            )),
          ] else ...[
            const Text('Popular Areas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: MessColors.muted)),
            const SizedBox(height: 8),
            ..._quickLocations.map((loc) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined, color: MessColors.muted),
              title: Text(loc, style: const TextStyle(fontSize: 13, color: MessColors.ink)),
              trailing: widget.currentLocation == loc ? const Icon(Icons.check, color: MessColors.green) : null,
              onTap: () => Navigator.pop(context, loc),
            )),
          ],
        ],
      ),
      ),
    );
  }
}

void _showNotifications(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'You’re all caught up',
            message: 'Subscription updates and meal reminders will appear here.',
          ),
        ),
      ),
    );

void _showSchedule(BuildContext context, MessProvider provider) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Meal schedule', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(provider.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MessColors.muted)),
            const SizedBox(height: 14),
            for (final slot in provider.mealSlots)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded, color: MessColors.orangeDark),
                title: Text(slot.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(slot.timeLabel),
                trailing: Text(slot.menuSummary, textAlign: TextAlign.end, style: const TextStyle(fontSize: 11, color: MessColors.muted)),
              ),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    );

String _weekday(int value) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][value - 1];
String _month(int value) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][value - 1];
String _planTypeLabel(SubscriptionType type) => type == SubscriptionType.fixedPeriod ? 'Fixed period' : type == SubscriptionType.mealTracker ? 'Meal tracker' : 'Daily meal';
String _slotNames(List<String> ids) => ids.map((id) => id[0].toUpperCase() + id.substring(1)).join(' + ');

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
