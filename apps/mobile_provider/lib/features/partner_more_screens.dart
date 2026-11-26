import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';
import 'customer_chats_screen.dart';
import 'delivery_staff_screen.dart';
import 'edit_kitchen_profile_screen.dart';
import 'kitchen_queue_screen.dart';
import 'notifications_screen.dart';
import 'payment_settings_screen.dart';
import 'pending_approvals_screen.dart';
import 'reviews_screen.dart';
import 'settlements_screen.dart';

class PartnerMoreScreen extends StatefulWidget {
  const PartnerMoreScreen({
    super.key,
    required this.session,
    required this.onSignOut,
    this.onSessionUpdated,
  });
  final ProviderSession session;
  final VoidCallback onSignOut;
  final ValueChanged<ProviderSession>? onSessionUpdated;

  @override
  State<PartnerMoreScreen> createState() => _PartnerMoreScreenState();
}

class _PartnerMoreScreenState extends State<PartnerMoreScreen> {
  late ProviderSession _session;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      final prof = await ProviderApiService.fetchProviderProfile(_session.providerId);
      if (!mounted) return;
      final logo = prof['logo_path']?.toString();
      if (logo != null && logo.isNotEmpty) {
        setState(() => _logoPath = logo);
      }
    } catch (_) {}
  }

  Future<void> _openEditProfile() async {
    final res = await Navigator.push<Map<String, dynamic>>(
      context,
      partnerRoute(EditKitchenProfileScreen(session: _session)),
    );
    if (res != null && mounted) {
      final updated = ProviderSession(
        token: _session.token,
        refreshToken: _session.refreshToken,
        userId: _session.userId,
        email: res['public_email']?.toString().isNotEmpty == true ? res['public_email'].toString() : _session.email,
        providerId: _session.providerId,
        businessName: res['display_name']?.toString().isNotEmpty == true ? res['display_name'].toString() : _session.businessName,
        locality: res['locality']?.toString() ?? _session.locality,
        city: res['city']?.toString() ?? _session.city,
      );
      setState(() {
        _session = updated;
        final lp = res['logo_path']?.toString();
        if (lp != null && lp.isNotEmpty) _logoPath = lp;
      });
      widget.onSessionUpdated?.call(updated);
    }
  }

  Widget _kitchenAvatar() {
    final p = (_logoPath ?? '').trim();
    if (p.startsWith('data:image/')) {
      try {
        return ClipOval(
          child: SizedBox(width: 52, height: 52, child: Image.memory(base64Decode(p.split(',').last), fit: BoxFit.cover)),
        );
      } catch (_) {}
    } else if (p.startsWith('http')) {
      return ClipOval(
        child: SizedBox(
          width: 52,
          height: 52,
          child: Image.network(p, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ThaliLogoMark(size: 46, whiteContainer: true)),
        ),
      );
    }
    return const ThaliLogoMark(size: 46, whiteContainer: true);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(title: const Text('Kitchen Hub & Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          CardSurface(
            padding: const EdgeInsets.all(16),
            onTap: _openEditProfile,
            child: Row(
              children: [
                _kitchenAvatar(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.businessName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.email,
                        style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                      ),
                      if (session.locality.isNotEmpty || session.city.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [session.locality, session.city].where((s) => s.isNotEmpty).join(', '),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThaliColors.primaryDark),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit Kitchen Profile',
                  onPressed: _openEditProfile,
                  icon: const Icon(Icons.edit_outlined, size: 20, color: ThaliColors.primary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _KitchenSettingsQuickCard(session: session),

          const SizedBox(height: 16),
          const SectionHeader(title: 'Operations'),
          const SizedBox(height: 8),
          CardSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _item(
                  icon: Icons.storefront_outlined,
                  title: 'Edit Kitchen Profile',
                  accent: true,
                  onTap: _openEditProfile,
                ),
                const Divider(height: 1),
                _item(
                  icon: Icons.kitchen_rounded,
                  title: 'Live Kitchen Queue',
                  accent: true,
                  onTap: () => Navigator.push(context, partnerRoute(KitchenQueueScreen(session: session))),
                ),
                const Divider(height: 1),
                _item(
                  icon: Icons.delivery_dining_rounded,
                  title: 'My Delivery Staff',
                  accent: true,
                  onTap: () => Navigator.push(context, partnerRoute(DeliveryStaffScreen(session: session))),
                ),
                const Divider(height: 1),
                _item(
                  icon: Icons.groups_rounded,
                  title: 'Active Subscribers',
                  onTap: () => Navigator.push(context, partnerRoute(SubscribersScreen(session: session))),
                ),
                const Divider(height: 1),
                _item(
                  icon: Icons.pending_actions_rounded,
                  title: 'Counter Cash Approvals',
                  onTap: () => Navigator.push(
                    context,
                    partnerRoute(PendingApprovalsScreen(session: session, onBack: () => Navigator.pop(context))),
                  ),
                ),
                const Divider(height: 1),
                _item(
                  icon: Icons.schedule_rounded,
                  title: 'Meal Timings',
                  onTap: () => Navigator.push(context, partnerRoute(OrderTimingsScreen(session: session))),
                ),
                const Divider(height: 1),
                _item(
                  icon: Icons.receipt_long_rounded,
                  title: 'Daily Walk-In Orders',
                  onTap: () => Navigator.push(context, partnerRoute(DailyOrdersScreen(session: session))),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const SectionHeader(title: 'Earnings & Engagement'),
          const SizedBox(height: 8),
          CardSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _item(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Settlements & Ledger',
                  onTap: () => Navigator.push(
                    context,
                    partnerRoute(SettlementsPayoutScreen(session: session, onBack: () => Navigator.pop(context))),
                  ),
                ),
                const Divider(height: 1),
                _item(
                  icon: Icons.account_balance_rounded,
                  title: 'Payout Settings',
                  onTap: () => Navigator.push(
                    context,
                    partnerRoute(PaymentSettingsScreen(session: session, onBack: () => Navigator.pop(context))),
                  ),
                ),
                const Divider(height: 1),
                _item(
                  icon: Icons.star_rounded,
                  title: 'Ratings & Reviews',
                  onTap: () => Navigator.push(context, partnerRoute(PartnerReviewsScreen(session: session))),
                ),
                const Divider(height: 1),
                _item(
                  icon: Icons.forum_rounded,
                  title: 'Customer Messages',
                  onTap: () => Navigator.push(
                    context,
                    partnerRoute(CustomerChatsScreen(session: session, onBack: () => Navigator.pop(context))),
                  ),
                ),
                const Divider(height: 1),
                _item(
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  onTap: () => Navigator.push(
                    context,
                    partnerRoute(NotificationsScreen(session: session, onBack: () => Navigator.pop(context))),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          CardSurface(
            padding: EdgeInsets.zero,
            child: _item(
              icon: Icons.support_agent_rounded,
              title: 'Partner Support',
              onTap: () => _openSupportSheet(context),
            ),
          ),
          const SizedBox(height: 20),
          PartnerActionButton(
            label: 'Sign Out',
            secondary: true,
            color: ThaliColors.red,
            onPressed: () {
              Navigator.pop(context);
              widget.onSignOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent ? ThaliColors.primarySoft : ThaliColors.subtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent ? ThaliColors.primary : ThaliColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: ThaliColors.muted),
          ],
        ),
      ),
    );
  }

  void _openSupportSheet(BuildContext context) {
    final subjectCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    bool sending = false;

    showModalBottomSheet<void>(
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
              const Text('Partner Support Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(controller: subjectCtrl, decoration: const InputDecoration(hintText: 'Subject')),
              const SizedBox(height: 10),
              TextField(controller: msgCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe your question...')),
              const SizedBox(height: 14),
              PartnerActionButton(
                label: 'Send Ticket',
                loading: sending,
                onPressed: () async {
                  if (subjectCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) return;
                  setSheetState(() => sending = true);
                  try {
                    await ProviderApiService.submitSupportTicket(
                      name: _session.businessName,
                      email: _session.email,
                      phone: _session.providerId,
                      role: 'provider',
                      subject: subjectCtrl.text.trim(),
                      message: msgCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) showPartnerNotice(context, 'Support ticket submitted.');
                  } catch (e) {
                    setSheetState(() => sending = false);
                    if (context.mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'submit ticket'), isError: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubscribersScreen extends StatefulWidget {
  const SubscribersScreen({super.key, required this.session});
  final ProviderSession session;

  @override
  State<SubscribersScreen> createState() => _SubscribersScreenState();
}

class _SubscribersScreenState extends State<SubscribersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _subscribers = [];
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final subs = await ProviderApiService.fetchSubscribers(widget.session.providerId);
      final plans = await ProviderApiService.fetchProviderPlans(widget.session.providerId);
      if (mounted) {
        setState(() {
          _subscribers = subs;
          _plans = plans;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMemberSheet() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String? planId = _plans.isNotEmpty ? _plans.first['id']?.toString() : null;
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
                const Text('Add Counter Cash Subscriber', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name')),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number'),
                ),
                if (_plans.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: planId,
                    items: _plans
                        .map((p) => DropdownMenuItem(
                              value: p['id']?.toString(),
                              child: Text('${p['name']} (${rupee((p['price_inr'] as num?) ?? 0)})'),
                            ))
                        .toList(),
                    onChanged: (v) => setSheetState(() => planId = v),
                    decoration: const InputDecoration(labelText: 'Plan'),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cash Paid (INR)', prefixText: '₹ '),
                ),
                const SizedBox(height: 16),
                PartnerActionButton(
                  label: 'Activate Subscriber',
                  loading: saving,
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
                    setSheetState(() => saving = true);
                    try {
                      await ProviderApiService.createManualSubscriber(
                        providerId: widget.session.providerId,
                        customerName: nameCtrl.text.trim(),
                        customerPhone: phoneCtrl.text.trim(),
                        planId: planId,
                        paymentMode: 'counter_cash',
                        amountPaid: double.tryParse(amountCtrl.text.trim()),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        showPartnerNotice(context, 'Subscriber added.');
                        _load();
                      }
                    } catch (e) {
                      setSheetState(() => saving = false);
                      if (mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'add subscriber'), isError: true);
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
      appBar: AppBar(
        title: const Text('Subscribers'),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_alt_1_outlined), onPressed: _addMemberSheet),
        ],
      ),
      body: RefreshIndicator(
        color: ThaliColors.primary,
        onRefresh: _load,
        child: _loading
            ? const PartnerSkeletonList(itemCount: 3, cardHeight: 112)
            : _subscribers.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 40),
                      CardSurface(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('No Subscribers Yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            const Text(
                              'Diners subscribing online or approved at counter appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ThaliColors.muted, fontSize: 13),
                            ),
                            const SizedBox(height: 14),
                            PartnerActionButton(label: 'Add Counter Subscriber', onPressed: _addMemberSheet),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    itemCount: _subscribers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final s = _subscribers[i];
                      final name = s['customer_name']?.toString() ?? 'Subscriber';
                      final phone = s['customer_phone']?.toString() ?? '';
                      final plan = s['plan_name']?.toString() ?? s['plan_name_snapshot']?.toString() ?? 'Plan';
                      final status = s['status']?.toString() ?? 'active';
                      final subId = s['id']?.toString() ?? '';

                      return CardSurface(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                                      if (phone.isNotEmpty) Text(phone, style: const TextStyle(fontSize: 12, color: ThaliColors.muted)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: status == 'active' ? ThaliColors.greenSoft : ThaliColors.subtle,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: status == 'active' ? ThaliColors.greenDark : ThaliColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(plan, style: const TextStyle(fontSize: 12.5, color: ThaliColors.body)),
                            if (status != 'active' && subId.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              PartnerActionButton(
                                label: 'Renew Pass (30 Days · Cash)',
                                secondary: true,
                                height: 38,
                                onPressed: () async {
                                  await ProviderApiService.reactivateSubscription(
                                    providerId: widget.session.providerId,
                                    subscriptionId: subId,
                                    paymentMode: 'counter_cash',
                                  );
                                  if (mounted) {
                                    showPartnerNotice(context, 'Renewed $name');
                                    _load();
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class OrderTimingsScreen extends StatefulWidget {
  const OrderTimingsScreen({super.key, required this.session});
  final ProviderSession session;

  @override
  State<OrderTimingsScreen> createState() => _OrderTimingsScreenState();
}

class _OrderTimingsScreenState extends State<OrderTimingsScreen> {
  bool _loading = true;
  bool _saving = false;

  final Map<String, bool> _enabled = {'breakfast': true, 'lunch': true, 'snacks': false, 'dinner': true};
  final Map<String, TextEditingController> _startCtrls = {
    'breakfast': TextEditingController(text: '07:30 AM'),
    'lunch': TextEditingController(text: '12:00 PM'),
    'snacks': TextEditingController(text: '04:30 PM'),
    'dinner': TextEditingController(text: '07:30 PM'),
  };
  final Map<String, TextEditingController> _endCtrls = {
    'breakfast': TextEditingController(text: '10:00 AM'),
    'lunch': TextEditingController(text: '03:00 PM'),
    'snacks': TextEditingController(text: '06:30 PM'),
    'dinner': TextEditingController(text: '10:30 PM'),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _startCtrls.values) {
      c.dispose();
    }
    for (final c in _endCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await ProviderApiService.fetchTimings(widget.session.providerId);
      if (!mounted) return;
      for (final slot in ['breakfast', 'lunch', 'snacks', 'dinner']) {
        final cfg = t[slot];
        if (cfg is Map) {
          _enabled[slot] = cfg['enabled'] != false;
          if (cfg['start'] != null) _startCtrls[slot]!.text = cfg['start'].toString();
          if (cfg['end'] != null) _endCtrls[slot]!.text = cfg['end'].toString();
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ProviderApiService.updateTimings(
        providerId: widget.session.providerId,
        timings: {
          for (final slot in ['breakfast', 'lunch', 'snacks', 'dinner'])
            slot: {
              'enabled': _enabled[slot] == true,
              'start': _startCtrls[slot]!.text.trim(),
              'end': _endCtrls[slot]!.text.trim(),
            },
        },
      );
      if (mounted) showPartnerNotice(context, 'Meal service hours updated.');
    } catch (e) {
      if (mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'save timings'), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TimeOfDay _parseClock(String raw, TimeOfDay fallback) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$', caseSensitive: false).firstMatch(raw.trim());
    if (match == null) return fallback;
    int h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final meridiem = match.group(3)?.toUpperCase();
    if (meridiem == 'AM' && h == 12) h = 0;
    if (meridiem == 'PM' && h < 12) h += 12;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  String _formatClock(TimeOfDay tod) {
    final hour12 = tod.hour % 12 == 0 ? 12 : tod.hour % 12;
    final suffix = tod.hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _pickClock(TextEditingController ctrl, TimeOfDay fallback) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseClock(ctrl.text, fallback),
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
    if (picked != null && mounted) {
      setState(() => ctrl.text = _formatClock(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(title: const Text('Order & Meal Timings')),
      body: RefreshIndicator(
        color: ThaliColors.primary,
        onRefresh: _load,
        child: _loading
            ? const PartnerSkeletonList(itemCount: 3, cardHeight: 118)
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  ...['breakfast', 'lunch', 'snacks', 'dinner'].map((slot) {
                    final title = slot[0].toUpperCase() + slot.substring(1);
                    final defStart = slot == 'breakfast'
                        ? const TimeOfDay(hour: 7, minute: 30)
                        : slot == 'lunch'
                            ? const TimeOfDay(hour: 12, minute: 0)
                            : slot == 'snacks'
                                ? const TimeOfDay(hour: 16, minute: 30)
                                : const TimeOfDay(hour: 19, minute: 30);
                    final defEnd = slot == 'breakfast'
                        ? const TimeOfDay(hour: 10, minute: 0)
                        : slot == 'lunch'
                            ? const TimeOfDay(hour: 15, minute: 0)
                            : slot == 'snacks'
                                ? const TimeOfDay(hour: 18, minute: 30)
                                : const TimeOfDay(hour: 22, minute: 30);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CardSurface(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                SlotIconTile(slot: slot, size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                ),
                                Switch.adaptive(
                                  activeColor: ThaliColors.primary,
                                  value: _enabled[slot] ?? true,
                                  onChanged: (v) => setState(() => _enabled[slot] = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pickClock(_startCtrls[slot]!, defStart),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: ThaliColors.scaffold,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: ThaliColors.stroke),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Opens At', style: TextStyle(fontSize: 11, color: ThaliColors.muted, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 3),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(_startCtrls[slot]!.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                                              const Icon(Icons.access_time_rounded, size: 16, color: ThaliColors.primary),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _pickClock(_endCtrls[slot]!, defEnd),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: ThaliColors.scaffold,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: ThaliColors.stroke),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Closes At', style: TextStyle(fontSize: 11, color: ThaliColors.muted, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 3),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(_endCtrls[slot]!.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                                              const Icon(Icons.access_time_rounded, size: 16, color: ThaliColors.primary),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  PartnerActionButton(label: 'Save Service Timings', loading: _saving, onPressed: _save),
                ],
              ),
      ),
    );
  }
}

class DailyOrdersScreen extends StatefulWidget {
  const DailyOrdersScreen({super.key, required this.session});
  final ProviderSession session;

  @override
  State<DailyOrdersScreen> createState() => _DailyOrdersScreenState();
}

class _DailyOrdersScreenState extends State<DailyOrdersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ProviderApiService.fetchOrders(widget.session.providerId);
      if (mounted) {
        setState(() {
          _orders = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrderSheet() async {
    final nameCtrl = TextEditingController();
    final itemsCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Log Walk-In / Extra Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name')),
              const SizedBox(height: 10),
              TextField(controller: itemsCtrl, decoration: const InputDecoration(labelText: 'Items (e.g. Full Thali + Curd)')),
              const SizedBox(height: 10),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (INR)', prefixText: '₹ '),
              ),
              const SizedBox(height: 16),
              PartnerActionButton(
                label: 'Save Walk-In Order',
                loading: saving,
                onPressed: () async {
                  final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
                  if (nameCtrl.text.trim().isEmpty || amt <= 0) return;
                  setSheetState(() => saving = true);
                  try {
                    await ProviderApiService.createOrder(
                      providerId: widget.session.providerId,
                      customerName: nameCtrl.text.trim(),
                      itemsSummary: itemsCtrl.text.trim().isNotEmpty ? itemsCtrl.text.trim() : 'Thali Meal',
                      totalAmount: amt,
                      paymentMode: 'counter_cash',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      showPartnerNotice(context, 'Order logged.');
                      _load();
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(
        title: const Text('Walk-In & Extra Orders'),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline_rounded), onPressed: _addOrderSheet),
        ],
      ),
      body: RefreshIndicator(
        color: ThaliColors.primary,
        onRefresh: _load,
        child: _loading
            ? const PartnerSkeletonList(itemCount: 3, cardHeight: 86)
            : _orders.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 40),
                      CardSurface(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('No Walk-In Orders Logged', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            PartnerActionButton(label: 'Log First Order', onPressed: _addOrderSheet),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final o = _orders[i];
                      return CardSurface(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o['customer_name']?.toString() ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(o['items_summary']?.toString() ?? 'Meal', style: const TextStyle(fontSize: 12, color: ThaliColors.muted)),
                                ],
                              ),
                            ),
                            Text(rupee((o['total_amount_inr'] as num?) ?? 0), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.primary)),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _KitchenSettingsQuickCard extends StatefulWidget {
  const _KitchenSettingsQuickCard({required this.session});
  final ProviderSession session;

  @override
  State<_KitchenSettingsQuickCard> createState() => _KitchenSettingsQuickCardState();
}

class _KitchenSettingsQuickCardState extends State<_KitchenSettingsQuickCard> {
  bool _supportsDelivery = false;
  String? _coverPath;
  bool _busy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final prov = await ProviderApiService.fetchProviderProfile(widget.session.providerId);
      if (!mounted) return;
      setState(() {
        _supportsDelivery = prov['supports_delivery'] == true;
        final cp = prov['cover_path']?.toString();
        if (cp != null && cp.isNotEmpty) _coverPath = cp;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleDelivery(bool v) async {
    final prev = _supportsDelivery;
    setState(() {
      _supportsDelivery = v;
      _busy = true;
    });
    try {
      await ProviderApiService.updateProviderProfile(
        providerId: widget.session.providerId,
        supportsDelivery: v,
      );
      if (mounted) {
        showPartnerNotice(context, v ? 'Self tiffin delivery enabled for customers.' : 'Switched to counter pickup & dine-in only.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _supportsDelivery = prev);
        showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'update delivery setting'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 78);
      if (xfile == null) return;
      setState(() => _busy = true);
      final bytes = await xfile.readAsBytes();
      final ext = xfile.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      final dataUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
      final res = await ProviderApiService.updateProviderProfile(
        providerId: widget.session.providerId,
        coverImageBase64: dataUrl,
      );
      if (!mounted) return;
      setState(() => _coverPath = res['cover_path']?.toString() ?? dataUrl);
      showPartnerNotice(context, 'Kitchen cover photo updated.');
    } catch (e) {
      if (mounted) {
        showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'update cover photo'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _thumb() {
    final p = (_coverPath ?? '').trim();
    if (p.startsWith('data:image/')) {
      try {
        return Image.memory(base64Decode(p.split(',').last), fit: BoxFit.cover);
      } catch (_) {}
    } else if (p.startsWith('http')) {
      return Image.network(p, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _emptyThumb());
    }
    return _emptyThumb();
  }

  Widget _emptyThumb() => Container(
        color: ThaliColors.primarySoft,
        child: const Icon(Icons.restaurant_menu_rounded, color: ThaliColors.primary, size: 22),
      );

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 48, height: 48, child: _thumb()),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Kitchen Cover Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _pickAndUploadPhoto,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: ThaliColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _busy ? 'Saving...' : (_coverPath == null ? 'Upload' : 'Change'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.primary),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: ThaliColors.subtle, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delivery_dining_rounded, size: 18, color: ThaliColors.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _loading
                      ? 'Self Delivery'
                      : (_supportsDelivery ? 'Self Delivery · On' : 'Self Delivery · Pickup only'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                ),
              ),
              Switch.adaptive(
                activeColor: ThaliColors.primary,
                value: _supportsDelivery,
                onChanged: (_busy || _loading) ? null : _toggleDelivery,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
