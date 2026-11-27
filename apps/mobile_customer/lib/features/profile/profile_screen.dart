import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/app_notification.dart';
import '../../core/repositories/mess_repository.dart';
import '../../core/services/customer_auth_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../history/history_screen.dart';
import '../plans/plans_screen.dart';
import '../setup/profile_location_setup_screen.dart';
import 'legal_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final subscription = state.activeSubscription;
        final unreadCount = state.unreadNotificationsCount;

        return Scaffold(
          backgroundColor: ThaliColors.scaffold,
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
            ),
            title: const Text('Account & Profile'),
          ),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
            children: [
              // Profile Identity Card
              CardSurface(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildAvatar(state.customerAvatar, size: 58),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.customerName.isNotEmpty ? state.customerName : 'Thali Member',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                          ),
                          if (state.customerEmail.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              state.customerEmail,
                              style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                            ),
                          ],
                          if (state.customerPhone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              state.customerPhone,
                              style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (state.location.isNotEmpty)
                                _pill(state.location, ThaliColors.primarySoft, ThaliColors.primaryDark),
                              _pill(
                                state.foodPreference == 'non_veg' ? 'Non-Veg' : 'Veg',
                                state.foodPreference == 'non_veg' ? ThaliColors.redSoft : ThaliColors.greenSoft,
                                state.foodPreference == 'non_veg' ? ThaliColors.red : ThaliColors.greenDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit profile',
                      onPressed: () => Navigator.push(
                        context,
                        messRoute(const CustomerEditProfileScreen()),
                      ),
                      icon: const Icon(Icons.edit_outlined, color: ThaliColors.muted),
                    ),
                  ],
                ),
              ),

              if (subscription != null && subscription.isValidToday) ...[
                const SizedBox(height: 14),
                CardSurface(
                  color: ThaliColors.ink,
                  borderColor: ThaliColors.ink,
                  padding: const EdgeInsets.all(16),
                  onTap: () => Navigator.push(
                    context,
                    messRoute(ManageSubscriptionScreen(subscription: subscription)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ThaliColors.green.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subscription.isPaused ? 'PAUSED PLAN' : 'ACTIVE PLAN',
                              style: const TextStyle(color: ThaliColors.greenBorder, fontSize: 10.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            '${subscription.daysRemaining}d remaining',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subscription.providerName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${subscription.planName} · Valid until ${formatDate(subscription.endDate)}',
                        style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const SectionHeader(title: 'Preferences & Activity'),
              const SizedBox(height: 8),

              CardSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _row(
                      icon: Icons.location_on_outlined,
                      title: 'Delivery Locality & Pin',
                      subtitle: state.location.isNotEmpty ? state.location : null,
                      onTap: () => Navigator.push(
                        context,
                        messRoute(const ProfileLocationSetupScreen(locationOnly: true)),
                      ),
                    ),
                    const Divider(height: 1),
                    _row(
                      icon: Icons.bookmark_border_rounded,
                      title: 'Saved Addresses',
                      onTap: () => _openAddressesSheet(context, state),
                    ),
                    const Divider(height: 1),
                    _row(
                      icon: Icons.history_rounded,
                      title: 'Meal Redemption History',
                      subtitle: state.history.isNotEmpty ? '${state.history.length} check-ins' : null,
                      onTap: () => Navigator.push(context, messRoute(const HistoryScreen())),
                    ),
                    const Divider(height: 1),
                    _row(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      trailing: unreadCount > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ThaliColors.primary,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            )
                          : null,
                      onTap: () => _showNotificationsSheet(context, state),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const SectionHeader(title: 'Support & Policies'),
              const SizedBox(height: 8),

              CardSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _row(
                      icon: Icons.support_agent_outlined,
                      title: 'Customer Support',
                      onTap: () => _showSupportSheet(context, state),
                    ),
                    const Divider(height: 1),
                    _row(
                      icon: Icons.confirmation_number_outlined,
                      title: 'My Support Tickets',
                      onTap: () => _showSupportTicketsSheet(context, state),
                    ),
                    const Divider(height: 1),
                    _row(
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      onTap: () => Navigator.push(context, messRoute(const LegalScreen(isPrivacy: false))),
                    ),
                    const Divider(height: 1),
                    _row(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () => Navigator.push(context, messRoute(const LegalScreen(isPrivacy: true))),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              MessActionButton(
                label: 'Sign Out',
                secondary: true,
                onPressed: () => _confirmSignOut(context, state),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _confirmDeleteAccount(context, state),
                child: const Text(
                  'Delete Account & Data',
                  style: TextStyle(color: ThaliColors.red, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ThaliColors.subtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: ThaliColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: ThaliColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, size: 20, color: ThaliColors.muted),
          ],
        ),
      ),
    );
  }

  static Widget _buildAvatar(String avatarData, {double size = 58}) {
    if (avatarData.startsWith('data:image')) {
      try {
        final idx = avatarData.indexOf(',');
        final raw = idx != -1 ? avatarData.substring(idx + 1) : avatarData;
        return ClipOval(
          child: Image.memory(base64Decode(raw), width: size, height: size, fit: BoxFit.cover),
        );
      } catch (_) {}
    } else if (avatarData.startsWith('http')) {
      return ClipOval(
        child: Image.network(avatarData, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: ThaliColors.primarySoft, shape: BoxShape.circle),
      child: Icon(Icons.person_rounded, color: ThaliColors.primary, size: size * 0.5),
    );
  }

  Future<void> _openAddressesSheet(BuildContext context, AppState state) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _SavedAddressesSheet(state: state),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AppState state) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThaliColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('You can sign back in anytime using your email or phone OTP.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThaliColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await state.signOut();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, AppState state) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThaliColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Account Permanently?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Your profile, saved addresses, and active session will be permanently deleted and active passes cancelled.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThaliColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await state.deleteAccount();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _showSupportSheet(BuildContext context, AppState state) {
    final subjectCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String category = 'Meal & Delivery';
    bool submitting = false;

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
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 22,
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
                const Text(
                  'Thali Support Desk',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tell us what happened and our team will respond shortly.',
                  style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Meal & Delivery', 'Subscription & Billing', 'QR Check-in', 'Account']
                      .map((c) => ChoiceChip(
                            label: Text(c),
                            selected: category == c,
                            selectedColor: ThaliColors.primarySoft,
                            onSelected: (_) => setSheetState(() => category = c),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(hintText: 'Subject'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: msgCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Describe the details cleanly...'),
                ),
                const SizedBox(height: 14),
                MessActionButton(
                  label: 'Send Support Request',
                  loading: submitting,
                  onPressed: () async {
                    final sub = subjectCtrl.text.trim();
                    final msg = msgCtrl.text.trim();
                    if (sub.isEmpty || msg.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter subject and message.')),
                      );
                      return;
                    }
                    setSheetState(() => submitting = true);
                    try {
                      final uri = Uri.parse('${CustomerAuthService.baseUrl}/api/support/ticket');
                      final res = await http.post(
                        uri,
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'name': state.customerName,
                          'email': state.customerEmail,
                          'phone': state.customerPhone.isNotEmpty ? state.customerPhone : state.customerId,
                          'role': 'customer',
                          'category': category,
                          'subject': sub,
                          'message': msg,
                        }),
                      ).timeout(const Duration(seconds: 12));
                      if (res.statusCode >= 400) {
                        throw Exception('Failed to submit (${res.statusCode}).');
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Support request sent successfully.')),
                        );
                      }
                    } catch (e) {
                      setSheetState(() => submitting = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
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

  void _showSupportTicketsSheet(BuildContext context, AppState state) {
    List<Map<String, dynamic>> tickets = [];
    bool loading = true;
    bool fetched = false;
    final replyCtrls = <String, TextEditingController>{};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (!fetched) {
            fetched = true;
            state.repository.fetchSupportTickets().then((rows) {
              if (!ctx.mounted) return;
              setSheetState(() {
                tickets = rows;
                loading = false;
              });
            }).catchError((_) {
              if (!ctx.mounted) return;
              setSheetState(() => loading = false);
            });
          }

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
              padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
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
                  const SizedBox(height: 14),
                  const Text('My Support Tickets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                  const SizedBox(height: 10),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: ThaliLoadingView(label: 'Loading tickets...')),
                    )
                  else if (tickets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No support tickets raised yet.', style: TextStyle(color: ThaliColors.muted))),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: tickets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final t = tickets[i];
                          final id = t['id']?.toString() ?? '';
                          final status = (t['status']?.toString() ?? 'open').replaceAll('_', ' ').toUpperCase();
                          final promo = t['promo_code_granted']?.toString() ?? '';
                          final resNote = t['resolution_note']?.toString() ?? '';
                          final msgs = (t['messages'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                          final ctrl = replyCtrls.putIfAbsent(id, TextEditingController.new);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ThaliColors.scaffold,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: ThaliColors.stroke),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        t['subject']?.toString() ?? 'Support Request',
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: ThaliColors.primarySoft, borderRadius: BorderRadius.circular(99)),
                                      child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ThaliColors.primary)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(t['description']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: ThaliColors.body)),
                                if (promo.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: ThaliColors.amberSoft, borderRadius: BorderRadius.circular(8)),
                                    child: Text('Apology Coupon: $promo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ThaliColors.amberDark)),
                                  ),
                                ],
                                if (resNote.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text('Resolution: $resNote', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ThaliColors.greenDark)),
                                ],
                                for (final m in msgs) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: m['sender_role'] == 'admin' ? ThaliColors.primarySoft : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${m['sender_role'] == 'admin' ? 'Thali Team' : 'You'}: ${m['message'] ?? ''}',
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                                ],
                                if (t['status'] != 'resolved' && t['status'] != 'closed') ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: ctrl,
                                          decoration: const InputDecoration(hintText: 'Write reply...', isDense: true),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton(
                                        onPressed: () async {
                                          if (ctrl.text.trim().isEmpty || id.isEmpty) return;
                                          await state.repository.replySupportTicket(ticketId: id, message: ctrl.text.trim());
                                          ctrl.clear();
                                          final refreshed = await state.repository.fetchSupportTickets();
                                          if (ctx.mounted) setSheetState(() => tickets = refreshed);
                                        },
                                        child: const Text('Send', style: TextStyle(fontWeight: FontWeight.w800)),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final notifs = state.notifications;
          final unread = state.unreadNotificationsCount;
          return SafeArea(
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                        ),
                      ),
                      if (unread > 0)
                        TextButton(
                          onPressed: () => state.markAllNotificationsRead(),
                          child: const Text('Mark all read', style: TextStyle(color: ThaliColors.primary, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (notifs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text('No notifications yet.', style: TextStyle(color: ThaliColors.muted)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: notifs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final n = notifs[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: n.type == NotificationType.subscription
                                  ? ThaliColors.greenSoft
                                  : ThaliColors.primarySoft,
                              child: Icon(
                                n.type == NotificationType.subscription
                                    ? Icons.verified_rounded
                                    : Icons.notifications_none_rounded,
                                color: n.type == NotificationType.subscription ? ThaliColors.green : ThaliColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                                color: ThaliColors.ink,
                              ),
                            ),
                            subtitle: Text(n.message, style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted)),
                            onTap: () => state.markNotificationRead(n.id),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SavedAddressesSheet extends StatefulWidget {
  const _SavedAddressesSheet({required this.state});
  final AppState state;

  @override
  State<_SavedAddressesSheet> createState() => _SavedAddressesSheetState();
}

class _SavedAddressesSheetState extends State<_SavedAddressesSheet> {
  List<Map<String, dynamic>> _addresses = const [];
  bool _loading = true;
  final _labelCtrl = TextEditingController(text: 'Home');
  final _lineCtrl = TextEditingController();
  final _localityCtrl = TextEditingController();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _lineCtrl.dispose();
    _localityCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.state.customerId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final list = await widget.state.repository.fetchAddresses(widget.state.customerId);
      if (mounted) {
        setState(() {
          _addresses = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAddress() async {
    final line = _lineCtrl.text.trim();
    final loc = _localityCtrl.text.trim();
    if (line.isEmpty || loc.isEmpty) return;
    setState(() => _adding = true);
    try {
      await widget.state.repository.saveAddress({
        'customer_id': widget.state.customerId,
        'label': _labelCtrl.text.trim().isNotEmpty ? _labelCtrl.text.trim() : 'Home',
        'address_line1': line,
        'locality': loc,
        'city': widget.state.selectedCity,
        'is_default': _addresses.isEmpty,
      });
      _lineCtrl.clear();
      _localityCtrl.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
            const SizedBox(height: 14),
            const Text('Saved Addresses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: ThaliLoadingView(label: 'Loading addresses...'),
              )
            else ...[
              if (_addresses.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text('No saved addresses yet. Add one below.', style: TextStyle(color: ThaliColors.muted, fontSize: 13)),
                )
              else
                ..._addresses.map((a) {
                  final loc = a['locality']?.toString() ?? '';
                  final line = (a['address_line1'] ?? a['address_line'])?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CardSurface(
                      onTap: () {
                        if (loc.isNotEmpty) {
                          widget.state.updateLocation(loc, city: a['city']?.toString() ?? '');
                          Navigator.pop(context);
                        }
                      },
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.home_outlined, color: ThaliColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['label']?.toString() ?? 'Address', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                Text('$line · $loc', style: const TextStyle(fontSize: 12, color: ThaliColors.muted)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final id = a['id']?.toString() ?? '';
                              if (id.isNotEmpty) {
                                await widget.state.repository.deleteAddress(id, widget.state.customerId);
                                await _load();
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: ThaliColors.muted),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const Divider(height: 20),
              const Text('Add New Address', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
              const SizedBox(height: 8),
              TextField(controller: _labelCtrl, decoration: const InputDecoration(hintText: 'Label (Home / Hostel / Office)')),
              const SizedBox(height: 8),
              TextField(controller: _lineCtrl, decoration: const InputDecoration(hintText: 'Flat / Hostel Room / Building')),
              const SizedBox(height: 8),
              TextField(controller: _localityCtrl, decoration: const InputDecoration(hintText: 'Area / Sector / Landmark')),
              const SizedBox(height: 12),
              MessActionButton(label: 'Save Address', loading: _adding, height: 46, onPressed: _addAddress),
            ],
          ],
        ),
      ),
    );
  }
}

class CustomerEditProfileScreen extends StatefulWidget {
  const CustomerEditProfileScreen({super.key});

  @override
  State<CustomerEditProfileScreen> createState() => _CustomerEditProfileScreenState();
}

class _CustomerEditProfileScreenState extends State<CustomerEditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  String _foodPref = 'veg';
  String _avatarData = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = AppStateScope.of(context, listen: false);
    _nameCtrl = TextEditingController(text: state.customerName);
    _emailCtrl = TextEditingController(text: state.customerEmail);
    _phoneCtrl = TextEditingController(text: state.customerPhone);
    _foodPref = state.foodPreference.isNotEmpty ? state.foodPreference : 'veg';
    _avatarData = state.customerAvatar;

    SharedPreferences.getInstance().then((prefs) {
      final savedAvatar = prefs.getString('thali_customer_avatar_${state.customerId}') ??
          prefs.getString('thali_customer_avatar_global');
      if (savedAvatar != null && savedAvatar.isNotEmpty && mounted && _avatarData.isEmpty) {
        setState(() => _avatarData = savedAvatar);
        state.updateProfile(avatar: savedAvatar);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 600);
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() => _avatarData = dataUri);
        final state = AppStateScope.of(context, listen: false);
        state.updateProfile(avatar: dataUri);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('thali_customer_avatar_${state.customerId}', dataUri);
        await prefs.setString('thali_customer_avatar_global', dataUri);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyCustomerError(e, action: 'update photo'))),
        );
      }
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your full name.')),
      );
      return;
    }

    setState(() => _saving = true);
    final state = AppStateScope.of(context, listen: false);
    final email = _emailCtrl.text.trim().toLowerCase();
    final phone = _phoneCtrl.text.trim();

    try {
      state.updateProfile(
        name: name,
        email: email.isNotEmpty ? email : null,
        phone: phone,
        avatar: _avatarData,
        foodPref: _foodPref,
      );
      if (state.customerId.isNotEmpty) {
        await state.repository.saveProfile(
          userId: state.customerId,
          displayName: name,
          foodPreference: _foodPref,
          email: email.isNotEmpty ? email : null,
          phone: phone.isNotEmpty ? phone : null,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyCustomerError(e, action: 'save profile'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Center(
            child: PressScale(
              onTap: _pickImage,
              child: Stack(
                children: [
                  ProfileScreen._buildAvatar(_avatarData, size: 88),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: ThaliColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          CardSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Your full name')),
                const SizedBox(height: 14),
                const Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'name@example.com'),
                ),
                const SizedBox(height: 14),
                const Text('Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '10-digit mobile number'),
                ),
                const SizedBox(height: 14),
                const Text('Food Preference', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: CardSurface(
                        onTap: () => setState(() => _foodPref = 'veg'),
                        color: _foodPref == 'veg' ? ThaliColors.greenSoft : ThaliColors.card,
                        borderColor: _foodPref == 'veg' ? ThaliColors.green : ThaliColors.stroke,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            VegIndicator(isVeg: true),
                            SizedBox(width: 8),
                            Text('Veg', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CardSurface(
                        onTap: () => setState(() => _foodPref = 'non_veg'),
                        color: _foodPref == 'non_veg' ? ThaliColors.primarySoft : ThaliColors.card,
                        borderColor: _foodPref == 'non_veg' ? ThaliColors.primary : ThaliColors.stroke,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            VegIndicator(isVeg: false),
                            SizedBox(width: 8),
                            Text('Non-Veg', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          MessActionButton(label: 'Save Profile', loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
