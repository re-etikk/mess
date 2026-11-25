import 'package:flutter/material.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';
import 'customer_chats_screen.dart';
import 'kitchen_queue_screen.dart';
import 'notifications_screen.dart';
import 'partner_more_screens.dart';
import 'pending_approvals_screen.dart';
import 'reviews_screen.dart';
import 'settlements_screen.dart';

class PartnerOverviewTab extends StatefulWidget {
  const PartnerOverviewTab({
    super.key,
    required this.session,
    required this.onSignOut,
    required this.onSwitchTab,
  });

  final ProviderSession session;
  final VoidCallback onSignOut;
  final ValueChanged<int> onSwitchTab;

  @override
  State<PartnerOverviewTab> createState() => _PartnerOverviewTabState();
}

class _PartnerOverviewTabState extends State<PartnerOverviewTab> {
  bool _loading = true;
  bool _isOpenToday = ProviderApiService.staticKitchenStatus ?? true;
  DashboardMetrics? _metrics;
  KitchenQueueResponse? _queueSummary;
  int _unreadNotifs = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final isOpen = await ProviderApiService.fetchKitchenStatus(widget.session.providerId);
      final metrics = await ProviderApiService.fetchDashboard(widget.session.providerId);
      KitchenQueueResponse? queue;
      try {
        queue = await ProviderApiService.fetchKitchenQueue(
          providerId: widget.session.providerId,
          slot: metrics.currentSlot,
        );
      } catch (_) {}
      int unread = 0;
      try {
        final notifRes = await ProviderApiService.fetchNotifications(widget.session.providerId);
        unread = (notifRes['unread_count'] as num?)?.toInt() ?? 0;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _isOpenToday = isOpen;
        _metrics = metrics;
        _queueSummary = queue;
        _unreadNotifs = unread;
      });
    } catch (e) {
      if (mounted) showPartnerNotice(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStatus(bool nextOpen) async {
    setState(() => _isOpenToday = nextOpen);
    try {
      await ProviderApiService.toggleKitchenStatus(
        providerId: widget.session.providerId,
        isOpen: nextOpen,
      );
      if (!mounted) return;
      showPartnerNotice(context, nextOpen ? 'Kitchen marked Open for today' : 'Kitchen marked Closed for today');
    } catch (e) {
      if (mounted) showPartnerNotice(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _metrics;
    final localityLabel = (m?.locality.isNotEmpty == true)
        ? '${m!.locality}${m.city.isNotEmpty ? ', ${m.city}' : ''}'
        : (widget.session.locality.isNotEmpty ? widget.session.locality : widget.session.email);

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Behance Clean Partner Top Header
            Container(
              color: ThaliColors.card,
              padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
              child: Row(
                children: [
                  const ThaliLogoMark(size: 32, subtitle: 'Partner'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                        ),
                        Text(
                          localityLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            partnerRoute(
                              NotificationsScreen(
                                session: widget.session,
                                onBack: () => Navigator.pop(context),
                                onOpenPending: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    partnerRoute(
                                      PendingApprovalsScreen(session: widget.session, onBack: () => Navigator.pop(context)),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                          _loadAll();
                        },
                        icon: const Icon(Icons.notifications_none_rounded, color: ThaliColors.ink),
                      ),
                      if (_unreadNotifs > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: ThaliColors.primary, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                  PressScale(
                    onTap: () => Navigator.push(
                      context,
                      partnerRoute(PartnerMoreScreen(session: widget.session, onSignOut: widget.onSignOut)),
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ThaliColors.primarySoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThaliColors.stroke),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.session.businessName.isNotEmpty ? widget.session.businessName[0].toUpperCase() : 'K',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.primaryDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                color: ThaliColors.primary,
                onRefresh: _loadAll,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 118),
                  children: [
                    // Kitchen Serving Toggle Card
                    CardSurface(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _isOpenToday ? ThaliColors.green : ThaliColors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isOpenToday ? 'Kitchen is Open Today' : 'Kitchen Closed Today',
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                                ),
                                Text(
                                  _isOpenToday
                                      ? 'Visible in customer search · Current slot: ${m?.currentSlot ?? 'LUNCH'}'
                                      : 'Paused from taking new orders today',
                                  style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            activeColor: ThaliColors.green,
                            value: _isOpenToday,
                            onChanged: _toggleStatus,
                          ),
                        ],
                      ),
                    ),

                    if ((m?.pendingCashCount ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      CardSurface(
                        color: ThaliColors.amberSoft,
                        borderColor: ThaliColors.amberBorder,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            partnerRoute(
                              PendingApprovalsScreen(session: widget.session, onBack: () => Navigator.pop(context)),
                            ),
                          );
                          _loadAll();
                        },
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.pending_actions_rounded, color: ThaliColors.amberDark, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${m!.pendingCashCount} Pending Cash Approval${m.pendingCashCount == 1 ? '' : 's'}',
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: ThaliColors.amberDark),
                                  ),
                                  Text(
                                    'Collect ${rupee(m.pendingCashInr)} at counter to activate passes',
                                    style: const TextStyle(fontSize: 11.5, color: ThaliColors.amberDark),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: ThaliColors.amberDark),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // 2x2 Real KPI Grid (No fake data)
                    if (_loading && m == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: PartnerLoadingView(label: 'Loading kitchen summary...'),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              title: 'Today Check-Ins',
                              value: '${m?.todayScans ?? 0}',
                              sub: '${m?.totalScans ?? 0} total',
                              icon: Icons.qr_code_scanner_rounded,
                              onTap: () => widget.onSwitchTab(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _kpiCard(
                              title: 'Active Subscribers',
                              value: '${m?.activeSubscribers ?? 0}',
                              sub: '${m?.activePlans ?? 0} active plans',
                              icon: Icons.groups_outlined,
                              onTap: () => Navigator.push(
                                context,
                                partnerRoute(SubscribersScreen(session: widget.session)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _kpiCard(
                              title: 'Online Settled',
                              value: rupee(m?.onlineSettledInr ?? 0),
                              sub: 'Cashfree payouts',
                              icon: Icons.account_balance_wallet_outlined,
                              onTap: () => Navigator.push(
                                context,
                                partnerRoute(SettlementsPayoutScreen(session: widget.session, onBack: () => Navigator.pop(context))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _kpiCard(
                              title: 'Kitchen Rating',
                              value: m?.averageRating != null ? '${m!.averageRating!.toStringAsFixed(1)} / 5' : 'New',
                              sub: '${m?.reviewsCount ?? 0} reviews',
                              icon: Icons.star_outline_rounded,
                              onTap: () => Navigator.push(
                                context,
                                partnerRoute(PartnerReviewsScreen(session: widget.session)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Live Kitchen Queue Summary Card
                    CardSurface(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'Live Kitchen Queue (${m?.currentSlot ?? 'LUNCH'})',
                            actionLabel: 'Manage Queue',
                            onAction: () => Navigator.push(
                              context,
                              partnerRoute(
                                KitchenQueueScreen(session: widget.session, initialSlot: m?.currentSlot ?? 'LUNCH'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _queueChip('Scheduled', _queueSummary?.scheduled ?? 0, ThaliColors.blueSoft, ThaliColors.blue),
                              const SizedBox(width: 8),
                              _queueChip('Preparing', _queueSummary?.preparing ?? 0, ThaliColors.amberSoft, ThaliColors.amberDark),
                              const SizedBox(width: 8),
                              _queueChip('Out/Ready', _queueSummary?.outCount ?? 0, ThaliColors.greenSoft, ThaliColors.greenDark),
                              const SizedBox(width: 8),
                              _queueChip('Done', _queueSummary?.delivered ?? 0, ThaliColors.subtle, ThaliColors.ink),
                            ],
                          ),
                          const SizedBox(height: 12),
                          PartnerActionButton(
                            label: 'Open Kitchen Preparation Queue',
                            height: 44,
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                partnerRoute(
                                  KitchenQueueScreen(session: widget.session, initialSlot: m?.currentSlot ?? 'LUNCH'),
                                ),
                              );
                              _loadAll();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quick Management Row
                    const SectionHeader(title: 'Quick Operations'),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.35,
                      children: [
                        _quickTile(
                          icon: Icons.payments_outlined,
                          title: 'Cash Approvals',
                          sub: '${m?.pendingCashCount ?? 0} awaiting',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              partnerRoute(
                                PendingApprovalsScreen(session: widget.session, onBack: () => Navigator.pop(context)),
                              ),
                            );
                            _loadAll();
                          },
                        ),
                        _quickTile(
                          icon: Icons.forum_outlined,
                          title: 'Customer Chats',
                          sub: 'Direct messages',
                          onTap: () => Navigator.push(
                            context,
                            partnerRoute(
                              CustomerChatsScreen(session: widget.session, onBack: () => Navigator.pop(context)),
                            ),
                          ),
                        ),
                        _quickTile(
                          icon: Icons.schedule_rounded,
                          title: 'Meal Timings',
                          sub: 'B / L / D hours',
                          onTap: () => Navigator.push(
                            context,
                            partnerRoute(OrderTimingsScreen(session: widget.session)),
                          ),
                        ),
                        _quickTile(
                          icon: Icons.receipt_long_outlined,
                          title: 'Daily Orders',
                          sub: 'Walk-ins & extras',
                          onTap: () => Navigator.push(
                            context,
                            partnerRoute(DailyOrdersScreen(session: widget.session)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    SectionHeader(title: 'Recent Counter Check-Ins (${m?.recentRedemptions.length ?? 0})'),
                    const SizedBox(height: 8),
                    if (m == null || m.recentRedemptions.isEmpty)
                      const CardSurface(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No meal redemptions recorded yet today.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                        ),
                      )
                    else
                      ...m.recentRedemptions.take(6).map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: CardSurface(
                              padding: const EdgeInsets.all(13),
                              child: Row(
                                children: [
                                  SlotIconTile(slot: r['slot']?.toString() ?? 'LUNCH', size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r['customer_name']?.toString() ?? 'Subscriber',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                                        ),
                                        Text(
                                          r['slot']?.toString() ?? 'LUNCH',
                                          style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const MealStatusBadge(status: 'redeemed'),
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return CardSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ThaliColors.muted)),
              Icon(icon, size: 16, color: ThaliColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 11, color: ThaliColors.muted)),
        ],
      ),
    );
  }

  Widget _queueChip(String label, int count, Color bg, Color fg) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: [
              Text('$count', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      );

  Widget _quickTile({
    required IconData icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return CardSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ThaliColors.primarySoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: ThaliColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: ThaliColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
