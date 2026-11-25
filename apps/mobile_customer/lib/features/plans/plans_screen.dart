import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/mess_models.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../chat/customer_chat_screen.dart';
import '../checkout/create_subscription_screen.dart';
import '../history/history_screen.dart';
import '../mess/mess_detail_screen.dart';
import 'plan_upgrade_sheet.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key, this.provider});
  final MessProvider? provider;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSubscriptions());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshSubscriptions() async {
    final appState = AppStateScope.of(context, listen: false);
    if (appState.customerId.isEmpty) return;
    setState(() => _refreshing = true);
    try {
      await appState.refreshSubscriptionsFromServer();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _renewMess(ActiveSubscription sub) async {
    final appState = AppStateScope.of(context, listen: false);
    final provider = await appState.getProvider(sub.providerId);
    if (!mounted) return;
    if (provider != null) {
      await Navigator.push(context, messRoute(CreateSubscriptionScreen(provider: provider)));
    } else {
      appState.selectTab(0);
    }
  }

  Future<void> _openProviderProfile(ActiveSubscription sub) async {
    final appState = AppStateScope.of(context, listen: false);
    final provider = await appState.getProvider(sub.providerId);
    if (!mounted) return;
    if (provider != null) {
      await Navigator.push(context, messRoute(MessDetailScreen(provider: provider)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final activeSubs = appState.activeSubscriptions;
    final pastSubs = appState.pastSubscriptions;

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: ThaliColors.card,
                border: Border(bottom: BorderSide(color: ThaliColors.stroke)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
                    child: Row(
                      children: [
                        if (Navigator.canPop(context))
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.chevron_left_rounded, size: 24, color: ThaliColors.ink),
                          ),
                        const Expanded(
                          child: Text(
                            'Your Subscriptions',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: ThaliColors.ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Meal redemption log',
                          onPressed: () => Navigator.push(context, messRoute(const HistoryScreen())),
                          icon: const Icon(Icons.receipt_long_outlined, color: ThaliColors.ink, size: 21),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    labelColor: ThaliColors.primary,
                    unselectedLabelColor: ThaliColors.muted,
                    indicatorColor: ThaliColors.primary,
                    indicatorWeight: 2.5,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    tabs: [
                      Tab(text: 'Active (${activeSubs.length})'),
                      Tab(text: 'Past (${pastSubs.length})'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  RefreshIndicator(
                    color: ThaliColors.primary,
                    onRefresh: _refreshSubscriptions,
                    child: _refreshing && activeSubs.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 118),
                            children: const [ThaliListSkeleton(itemCount: 2, cardHeight: 170)],
                          )
                        : activeSubs.isEmpty
                            ? _buildEmptyState(
                                appState: appState,
                                title: 'No active subscription',
                                subtitle: 'Compare kitchens around you and start a flexible weekly or monthly plan.',
                                ctaLabel: 'Explore Messes',
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 118),
                                itemCount: activeSubs.length,
                                itemBuilder: (_, i) => _buildActiveCard(activeSubs[i]),
                              ),
                  ),
                  RefreshIndicator(
                    color: ThaliColors.primary,
                    onRefresh: _refreshSubscriptions,
                    child: _refreshing && pastSubs.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 118),
                            children: const [ThaliListSkeleton(itemCount: 2, cardHeight: 150)],
                          )
                        : pastSubs.isEmpty
                            ? _buildEmptyState(
                                appState: appState,
                                title: 'No past subscriptions',
                                subtitle: 'Completed, expired, or cancelled meal plans will appear here.',
                                ctaLabel: 'Browse Messes',
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 118),
                                itemCount: pastSubs.length,
                                itemBuilder: (_, i) => _buildPastCard(pastSubs[i]),
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required dynamic appState,
    required String title,
    required String subtitle,
    required String ctaLabel,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(24, 38, 24, 118),
      children: [
        CardSurface(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          child: Column(
            children: [
              SvgPicture.asset(
                'assets/images/ui/illus_empty_sub.svg',
                height: 155,
                placeholderBuilder: (_) => const Icon(
                  Icons.card_membership_outlined,
                  size: 64,
                  color: ThaliColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: ThaliColors.muted, height: 1.45),
              ),
              const SizedBox(height: 20),
              MessActionButton(
                label: ctaLabel,
                onPressed: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  appState.selectTab(0);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCard(ActiveSubscription sub) {
    final totalDays = sub.totalDays > 0 ? sub.totalDays : 30;
    final elapsedDays = (totalDays - sub.daysRemaining).clamp(0, totalDays);
    final progress = (elapsedDays / totalDays).clamp(0.0, 1.0);
    final remainingSkips = (sub.skipAllowance - sub.skipsUsed).clamp(0, 99);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CardSurface(
        padding: const EdgeInsets.all(16),
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
                      GestureDetector(
                        onTap: () => _openProviderProfile(sub),
                        child: Text(
                          sub.providerName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: ThaliColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${sub.planName}${sub.providerLocality.isNotEmpty ? ' · ${sub.providerLocality}' : ''}',
                        style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sub.isPaused ? ThaliColors.amberSoft : ThaliColors.greenSoft,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: sub.isPaused ? ThaliColors.amberBorder : ThaliColors.greenBorder,
                    ),
                  ),
                  child: Text(
                    sub.isPaused ? 'Paused' : 'Active',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: sub.isPaused ? ThaliColors.amberDark : ThaliColors.greenDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: ThaliColors.subtle,
                valueColor: AlwaysStoppedAnimation<Color>(
                  sub.isPaused ? ThaliColors.amber : ThaliColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${sub.daysRemaining} days left',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                ),
                if (sub.totalMeals != null)
                  Text(
                    '${sub.mealsRemaining ?? 0} of ${sub.totalMeals} meals left',
                    style: const TextStyle(fontSize: 12, color: ThaliColors.muted),
                  )
                else
                  Text(
                    'Skip Days: $remainingSkips/${sub.skipAllowance}',
                    style: const TextStyle(fontSize: 12, color: ThaliColors.muted),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: ThaliColors.scaffold,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ThaliColors.stroke),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Meals included', style: TextStyle(fontSize: 11, color: ThaliColors.muted)),
                        const SizedBox(height: 2),
                        Text(
                          sub.slotIds.isNotEmpty
                              ? sub.slotIds.map((s) => s[0].toUpperCase() + s.substring(1)).join(', ')
                              : 'All slots',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 26, color: ThaliColors.stroke),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Renews / Ends', style: TextStyle(fontSize: 11, color: ThaliColors.muted)),
                        const SizedBox(height: 2),
                        Text(
                          formatDate(sub.endDate),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (sub.isPaused && sub.pauseStartDate != null && sub.pauseEndDate != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ThaliColors.amberSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ThaliColors.amberBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pause_circle_outline_rounded, size: 17, color: ThaliColors.amberDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Paused ${formatDate(sub.pauseStartDate!)} - ${formatDate(sub.pauseEndDate!)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThaliColors.amberDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: MessActionButton(
                    label: 'Manage Plan',
                    height: 44,
                    onPressed: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        messRoute(ManageSubscriptionScreen(subscription: sub)),
                      );
                      if (changed == true && mounted) {
                        await _refreshSubscriptions();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MessActionButton(
                    label: 'Upgrade',
                    secondary: true,
                    height: 44,
                    onPressed: () => PlanUpgradeSheet.show(context, sub),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastCard(ActiveSubscription sub) {
    final isCancelled = sub.status == 'cancelled';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CardSurface(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.providerName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub.planName,
                        style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCancelled ? ThaliColors.redSoft : ThaliColors.subtle,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: isCancelled ? ThaliColors.redBorder : ThaliColors.stroke),
                  ),
                  child: Text(
                    isCancelled ? 'Cancelled' : 'Expired',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isCancelled ? ThaliColors.red : ThaliColors.body,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Period: ${formatDate(sub.startDate)} - ${formatDate(sub.endDate)}',
              style: const TextStyle(fontSize: 12, color: ThaliColors.muted),
            ),
            const SizedBox(height: 12),
            MessActionButton(
              label: 'Renew Subscription',
              secondary: true,
              height: 42,
              onPressed: () => _renewMess(sub),
            ),
          ],
        ),
      ),
    );
  }
}

class ManageSubscriptionScreen extends StatefulWidget {
  const ManageSubscriptionScreen({super.key, required this.subscription});
  final ActiveSubscription subscription;

  @override
  State<ManageSubscriptionScreen> createState() => _ManageSubscriptionScreenState();
}

class _ManageSubscriptionScreenState extends State<ManageSubscriptionScreen> {
  late ActiveSubscription _sub;
  late Set<int> _repeatDays;
  late bool _autoRenewal;
  late bool _whatsappUpdates;
  late int _reminderDays;
  bool _saving = false;
  bool _changed = false;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _sub = widget.subscription;
    _repeatDays = _sub.repeatDays.isNotEmpty ? _sub.repeatDays.toSet() : {1, 2, 3, 4, 5, 6, 7};
    _autoRenewal = _sub.autoRenewal;
    _whatsappUpdates = _sub.whatsappUpdates;
    _reminderDays = _sub.reminderDaysBefore;
  }

  Future<void> _savePreferences() async {
    if (_repeatDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one delivery weekday.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final appState = AppStateScope.of(context, listen: false);
      await appState.repository.manageSubscription(
        action: 'update_preferences',
        subscriptionId: _sub.id,
        customerId: appState.customerId,
        repeatDays: _repeatDays.toList()..sort(),
        autoRenewal: _autoRenewal,
        reminderDaysBefore: _reminderDays,
        whatsappUpdates: _whatsappUpdates,
      );
      await appState.refreshSubscriptionsFromServer();
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription preferences saved.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('RepositoryException: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resumeSubscription() async {
    setState(() => _saving = true);
    try {
      final appState = AppStateScope.of(context, listen: false);
      await appState.repository.manageSubscription(
        action: 'resume',
        subscriptionId: _sub.id,
        customerId: appState.customerId,
      );
      await appState.refreshSubscriptionsFromServer();
      final refreshed = appState.activeSubscriptions.where((s) => s.id == _sub.id).firstOrNull;
      if (!mounted) return;
      setState(() {
        _changed = true;
        if (refreshed != null) _sub = refreshed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription resumed.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('RepositoryException: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPauseFlow() async {
    final res = await Navigator.push<bool>(
      context,
      messRoute(_PauseSubscriptionScreen(subscription: _sub)),
    );
    if (res == true && mounted) {
      final appState = AppStateScope.of(context, listen: false);
      await appState.refreshSubscriptionsFromServer();
      final refreshed = appState.activeSubscriptions.where((s) => s.id == _sub.id).firstOrNull;
      setState(() {
        _changed = true;
        if (refreshed != null) _sub = refreshed;
      });
    }
  }

  Future<void> _openCancelFlow() async {
    final cancelled = await Navigator.push<bool>(
      context,
      messRoute(_CancelSubscriptionScreen(subscription: _sub)),
    );
    if (cancelled == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDays = _sub.totalDays > 0 ? _sub.totalDays : 30;
    final elapsedDays = (totalDays - _sub.daysRemaining).clamp(0, totalDays);
    final progress = (elapsedDays / totalDays).clamp(0.0, 1.0);
    final remainingSkips = (_sub.skipAllowance - _sub.skipsUsed).clamp(0, 99);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: ThaliColors.scaffold,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context, _changed),
            icon: const Icon(Icons.chevron_left_rounded, size: 26),
          ),
          title: const Text('Manage Subscription'),
        ),
        body: Stack(
          children: [
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              children: [
                // Summary Progress Card
                CardSurface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _sub.providerName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                                ),
                                const SizedBox(height: 2),
                                Text(_sub.planName, style: const TextStyle(fontSize: 13, color: ThaliColors.muted)),
                              ],
                            ),
                          ),
                          if (_sub.priceInr > 0)
                            Text(
                              rupee(_sub.priceInr),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: ThaliColors.subtle,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _sub.isPaused ? ThaliColors.amber : ThaliColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Started ${formatDate(_sub.startDate)}',
                            style: const TextStyle(fontSize: 12, color: ThaliColors.muted),
                          ),
                          Text(
                            'Renews ${formatDate(_sub.endDate)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                          ),
                        ],
                      ),
                      const Divider(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _metricCell('Days Remaining', '${_sub.daysRemaining} days'),
                          ),
                          Expanded(
                            child: _metricCell('Skip Allowance', '$remainingSkips of ${_sub.skipAllowance} left'),
                          ),
                          Expanded(
                            child: _metricCell(
                              'Packaging',
                              _sub.packagingPreference == 'disposable' ? 'Disposable' : 'Tiffin Box',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Pause / Resume Card
                CardSurface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pause & Vacation Hold',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sub.isPaused && _sub.pauseStartDate != null && _sub.pauseEndDate != null
                            ? 'Paused from ${formatDate(_sub.pauseStartDate!)} to ${formatDate(_sub.pauseEndDate!)}. Validity is extended automatically.'
                            : 'Travelling or away? Pause your plan and extend your end date.',
                        style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      if (_sub.isPaused)
                        MessActionButton(
                          label: 'Resume Subscription',
                          color: ThaliColors.green,
                          height: 46,
                          onPressed: _resumeSubscription,
                        )
                      else
                        MessActionButton(
                          label: 'Pause Subscription',
                          secondary: true,
                          height: 46,
                          onPressed: _openPauseFlow,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Repeat Delivery Days Circles
                CardSurface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Repeat Days',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Toggle the weekdays your meals should be scheduled.',
                        style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (idx) {
                          final dayNum = idx + 1;
                          final active = _repeatDays.contains(dayNum);
                          return PressScale(
                            onTap: () {
                              setState(() {
                                if (active && _repeatDays.length > 1) {
                                  _repeatDays.remove(dayNum);
                                } else {
                                  _repeatDays.add(dayNum);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: active ? ThaliColors.primary : ThaliColors.subtle,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: active ? ThaliColors.primary : ThaliColors.stroke,
                                ),
                              ),
                              child: Text(
                                _dayLabels[idx],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: active ? Colors.white : ThaliColors.body,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _presetChip('Daily', () => setState(() => _repeatDays = {1, 2, 3, 4, 5, 6, 7})),
                          const SizedBox(width: 8),
                          _presetChip('Weekdays', () => setState(() => _repeatDays = {1, 2, 3, 4, 5})),
                          const SizedBox(width: 8),
                          _presetChip('Mon-Sat', () => setState(() => _repeatDays = {1, 2, 3, 4, 5, 6})),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Payment & Renewal Settings
                CardSurface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment & Renewal',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mode: ${_sub.paymentMode == 'counter_cash' ? 'Pay Cash at Counter' : 'Cashfree Online'}',
                        style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        activeColor: ThaliColors.primary,
                        title: const Text('Renewal Reminder Alerts', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        subtitle: const Text('Notify before plan expiry', style: TextStyle(fontSize: 12, color: ThaliColors.muted)),
                        value: _autoRenewal,
                        onChanged: (v) => setState(() => _autoRenewal = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        activeColor: ThaliColors.primary,
                        title: const Text('WhatsApp Meal Updates', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        subtitle: const Text('Menu changes and dispatch alerts', style: TextStyle(fontSize: 12, color: ThaliColors.muted)),
                        value: _whatsappUpdates,
                        onChanged: (v) => setState(() => _whatsappUpdates = v),
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      const Text('Remind Before Expiry', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [1, 2, 3, 5].map((d) {
                          final active = _reminderDays == d;
                          return ChoiceChip(
                            label: Text('$d day${d == 1 ? '' : 's'}'),
                            selected: active,
                            selectedColor: ThaliColors.primarySoft,
                            onSelected: (_) => setState(() => _reminderDays = d),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      MessActionButton(
                        label: 'Save Schedule & Preferences',
                        height: 46,
                        onPressed: _savePreferences,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Quick Support & Cancel
                CardSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.upgrade_rounded, color: ThaliColors.primary),
                        title: const Text('Upgrade Plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: const Text('Switch to another plan at this mess', style: TextStyle(fontSize: 12, color: ThaliColors.muted)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => PlanUpgradeSheet.show(context, _sub),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.chat_bubble_outline_rounded, color: ThaliColors.ink),
                        title: const Text('Message Kitchen', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          messRoute(
                            CustomerChatScreen(providerId: _sub.providerId, providerName: _sub.providerName),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.cancel_outlined, color: ThaliColors.red),
                        title: const Text(
                          'Cancel Subscription',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ThaliColors.red),
                        ),
                        subtitle: const Text('Stop upcoming deliveries and archive plan', style: TextStyle(fontSize: 12, color: ThaliColors.muted)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: ThaliColors.red),
                        onTap: _openCancelFlow,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_saving)
              Container(
                color: Colors.black26,
                child: const ThaliLoadingView(label: 'Updating plan...'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricCell(String label, String val) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: ThaliColors.muted)),
          const SizedBox(height: 2),
          Text(val, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
        ],
      );

  Widget _presetChip(String label, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: const BorderSide(color: ThaliColors.stroke),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
      );
}

class _PauseSubscriptionScreen extends StatefulWidget {
  const _PauseSubscriptionScreen({required this.subscription});
  final ActiveSubscription subscription;

  @override
  State<_PauseSubscriptionScreen> createState() => _PauseSubscriptionScreenState();
}

class _PauseSubscriptionScreenState extends State<_PauseSubscriptionScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  String _reason = 'Travelling';
  bool _confirmStep = false;
  bool _submitting = false;
  bool _completed = false;

  static const _reasons = ['Travelling', 'Going home', 'Exams / Schedule change', 'Other'];

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _startDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _endDate = _startDate.add(const Duration(days: 2));
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get _pauseDays => (_endDate.difference(_startDate).inDays + 1).clamp(1, 30);

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: ThaliColors.primary,
            onPrimary: Colors.white,
            onSurface: ThaliColors.ink,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (range != null && mounted) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  Future<void> _submitPause() async {
    setState(() => _submitting = true);
    try {
      final appState = AppStateScope.of(context, listen: false);
      await appState.repository.manageSubscription(
        action: 'pause',
        subscriptionId: widget.subscription.id,
        customerId: appState.customerId,
        pauseStartDate: _iso(_startDate),
        pauseEndDate: _iso(_endDate),
        reason: _reason,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _completed = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('RepositoryException: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) {
      return Scaffold(
        backgroundColor: ThaliColors.green,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.pause_rounded, size: 42, color: ThaliColors.green),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Subscription Paused',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your meals at ${widget.subscription.providerName} are paused from ${formatDate(_startDate)} to ${formatDate(_endDate)} ($_pauseDays days). Plan validity is extended accordingly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.92), height: 1.45),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: ThaliColors.greenDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Back to Plan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final extendedEnd = widget.subscription.endDate.add(Duration(days: _pauseDays));

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(title: const Text('Pause Subscription')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          CardSurface(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                SvgPicture.asset(
                  'assets/images/ui/illus_paused_cal.svg',
                  height: 120,
                  placeholderBuilder: (_) => const Icon(Icons.date_range_rounded, size: 54, color: ThaliColors.primary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select pause window',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Paused days automatically extend your subscription end date.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!_confirmStep) ...[
            CardSurface(
              onTap: _pickDateRange,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: ThaliColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pause Dates', style: TextStyle(fontSize: 12, color: ThaliColors.muted)),
                        const SizedBox(height: 3),
                        Text(
                          '${formatDate(_startDate)}  ->  ${formatDate(_endDate)} ($_pauseDays days)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                        ),
                      ],
                    ),
                  ),
                  const Text('Change', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThaliColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('Reason for pause', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((r) {
                final active = _reason == r;
                return ChoiceChip(
                  label: Text(r),
                  selected: active,
                  selectedColor: ThaliColors.primarySoft,
                  onSelected: (_) => setState(() => _reason = r),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            MessActionButton(
              label: 'Review Pause Summary',
              onPressed: () => setState(() => _confirmStep = true),
            ),
          ] else ...[
            CardSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Review Pause Impact', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                  const SizedBox(height: 12),
                  _kv('Mess Kitchen', widget.subscription.providerName),
                  _kv('Pause Window', '${formatDate(_startDate)} - ${formatDate(_endDate)}'),
                  _kv('Paused Days', '$_pauseDays days'),
                  _kv('New Validity Ends', formatDate(extendedEnd)),
                  _kv('Reason', _reason),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: MessActionButton(
                    label: 'Edit Dates',
                    secondary: true,
                    onPressed: _submitting ? null : () => setState(() => _confirmStep = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: MessActionButton(
                    label: 'Confirm Pause',
                    loading: _submitting,
                    onPressed: _submitPause,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(fontSize: 13, color: ThaliColors.muted)),
            Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
          ],
        ),
      );
}

class _CancelSubscriptionScreen extends StatefulWidget {
  const _CancelSubscriptionScreen({required this.subscription});
  final ActiveSubscription subscription;

  @override
  State<_CancelSubscriptionScreen> createState() => _CancelSubscriptionScreenState();
}

class _CancelSubscriptionScreenState extends State<_CancelSubscriptionScreen> {
  String _reason = 'Moving out of area';
  final _notesCtrl = TextEditingController();
  int _step = 0; // 0 = summary warning, 1 = survey reason, 2 = cancelled done
  bool _submitting = false;

  static const _reasons = [
    'Moving out of area',
    'Food quality concern',
    'Schedule changed',
    'Too expensive',
    'Trying another kitchen',
    'Other',
  ];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmCancel() async {
    setState(() => _submitting = true);
    try {
      final appState = AppStateScope.of(context, listen: false);
      final reasonText = _notesCtrl.text.trim().isNotEmpty
          ? '$_reason: ${_notesCtrl.text.trim()}'
          : _reason;
      await appState.repository.manageSubscription(
        action: 'cancel',
        subscriptionId: widget.subscription.id,
        customerId: appState.customerId,
        reason: reasonText,
      );
      await appState.refreshSubscriptionsFromServer();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('RepositoryException: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 2) {
      return Scaffold(
        backgroundColor: ThaliColors.card,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: ThaliColors.redSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: ThaliColors.redBorder),
                  ),
                  child: const Icon(Icons.check_rounded, size: 40, color: ThaliColors.red),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Subscription Cancelled',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your ${widget.subscription.planName} at ${widget.subscription.providerName} has been moved to Past Subscriptions.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: ThaliColors.muted, height: 1.45),
                ),
                const Spacer(),
                MessActionButton(
                  label: 'Done',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(title: const Text('Cancel Subscription')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (_step == 0) ...[
            CardSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Before you cancel',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You still have ${widget.subscription.daysRemaining} day(s) remaining on ${widget.subscription.planName} at ${widget.subscription.providerName}.',
                    style: const TextStyle(fontSize: 13.5, color: ThaliColors.body, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThaliColors.amberSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ThaliColors.amberBorder),
                    ),
                    child: const Text(
                      'If you are only travelling temporarily, consider pausing your plan so your remaining days extend automatically.',
                      style: TextStyle(fontSize: 12.5, color: ThaliColors.amberDark, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            MessActionButton(
              label: 'Keep Plan Active',
              onPressed: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 10),
            MessActionButton(
              label: 'Continue to Cancellation',
              secondary: true,
              color: ThaliColors.red,
              onPressed: () => setState(() => _step = 1),
            ),
          ] else ...[
            const Text(
              'Why are you cancelling?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your feedback helps kitchens improve daily meal quality.',
              style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
            ),
            const SizedBox(height: 14),
            ..._reasons.map((r) {
              final active = _reason == r;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CardSurface(
                  onTap: () => setState(() => _reason = r),
                  color: active ? ThaliColors.primarySoft : ThaliColors.card,
                  borderColor: active ? ThaliColors.primary : ThaliColors.stroke,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        active ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 20,
                        color: active ? ThaliColors.primary : ThaliColors.muted,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        r,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: active ? ThaliColors.primaryDark : ThaliColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Additional feedback (optional)...'),
            ),
            const SizedBox(height: 18),
            MessActionButton(
              label: 'Confirm Cancellation',
              color: ThaliColors.red,
              loading: _submitting,
              onPressed: _confirmCancel,
            ),
          ],
        ],
      ),
    );
  }
}
