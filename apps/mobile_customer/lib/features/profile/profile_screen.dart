import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/state/app_state.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../history/history_screen.dart';
import '../mess/mess_detail_screen.dart';
import '../plans/plans_screen.dart';
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
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  Expanded(child: Text('Profile', style: Theme.of(context).textTheme.headlineLarge)),
                  IconButton(onPressed: () => _showSettings(context), tooltip: 'Settings', icon: const Icon(Icons.settings_outlined)),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 0),
              sliver: SliverToBoxAdapter(
                child: CardSurface(
                  padding: const EdgeInsets.all(17),
                  child: Row(children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(color: Color(0xFFFFE8BF), shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, color: MessColors.orangeDark, size: 31),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(state.customerName, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(state.customerEmail, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 5),
                        Text(state.location, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MessColors.orangeDark)),
                      ]),
                    ),
                    IconButton(onPressed: () => _editProfile(context, state), tooltip: 'Edit profile', icon: const Icon(Icons.edit_outlined, color: MessColors.muted)),
                  ]),
                ),
              ),
            ),
            if (subscription != null && subscription.isValidToday)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: MessColors.navy, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('CURRENT PLAN', style: TextStyle(color: Color(0xFFC3CFD7), fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 7),
                      Text(subscription.providerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subscription.planName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: Text(
                            subscription.mealsRemaining == null ? 'Valid till ${formatDate(subscription.endDate)}' : '${subscription.mealsRemaining} meals remaining',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(context, messRoute(const PlansScreen())),
                          child: const Text('Manage', style: TextStyle(color: MessColors.orange)),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 9),
              sliver: SliverToBoxAdapter(child: Text('Your account', style: Theme.of(context).textTheme.titleLarge)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              sliver: SliverToBoxAdapter(
                child: CardSurface(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _ProfileRow(icon: Icons.calendar_month_outlined, title: 'My plans', subtitle: 'Active and previous subscriptions', onTap: () => Navigator.push(context, messRoute(const PlansScreen()))),
                    const Divider(height: 1, indent: 54),
                    _ProfileRow(icon: Icons.receipt_long_outlined, title: 'Meal history', subtitle: 'View redeemed meals and activity', onTap: () => Navigator.push(context, messRoute(const HistoryScreen()))),
                    const Divider(height: 1, indent: 54),
                    _ProfileRow(icon: Icons.location_on_outlined, title: 'Location', subtitle: state.location, onTap: () => _editLocation(context, state)),
                    const Divider(height: 1, indent: 54),
                    _ProfileRow(icon: Icons.storefront_outlined, title: 'Selected mess', subtitle: state.activeProvider?.name ?? 'Browse messes', onTap: () {
                      final provider = state.activeProvider;
                      if (provider != null) Navigator.push(context, messRoute(MessDetailScreen(provider: provider)));
                    }),
                    const Divider(height: 1, indent: 54),
                    _ProfileRow(icon: Icons.help_outline_rounded, title: 'Help & support', subtitle: 'Frequently asked questions & ticket assistance', onTap: () => _showHelp(context)),
                    const Divider(height: 1, indent: 54),
                    _ProfileRow(icon: Icons.description_outlined, title: 'Terms and conditions', onTap: () => Navigator.push(context, messRoute(const LegalScreen(isPrivacy: false)))),
                    const Divider(height: 1, indent: 54),
                    _ProfileRow(icon: Icons.privacy_tip_outlined, title: 'Privacy policy', onTap: () => Navigator.push(context, messRoute(const LegalScreen(isPrivacy: true)))),
                  ]),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
              sliver: SliverToBoxAdapter(
                child: MessActionButton(label: 'Sign out', secondary: true, icon: Icons.logout_rounded, onPressed: () => _confirmSignOut(context, state)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editProfile(BuildContext context, AppState state) async {
    final name = TextEditingController(text: state.customerName);
    final email = TextEditingController(text: state.customerEmail);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, [name.text.trim(), email.text.trim()]), child: const Text('Save')),
        ],
      ),
    );
    name.dispose();
    email.dispose();
    if (result != null && result.first.isNotEmpty && result.last.isNotEmpty) {
      state.signIn(emailOrPhone: result.last, name: result.first);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    }
  }

  Future<void> _editLocation(BuildContext context, AppState state) async {
    final text = TextEditingController(text: state.location);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Location'),
        content: TextField(controller: text, decoration: const InputDecoration(labelText: 'Hostel, area or landmark')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, text.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    text.dispose();
    if (result != null && result.isNotEmpty) state.updateLocation(result);
  }

  void _showHelp(BuildContext context) {
    final state = AppStateScope.of(context);
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String category = 'general';
    bool submitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFFFE8C5), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.support_agent, color: MessColors.orange, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Student Support Desk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: MessColors.ink)),
                              Text('Sends directly to support@thali.store', style: TextStyle(fontSize: 12, color: MessColors.muted)),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: MessColors.ink)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ['general', 'meal_quality', 'scanner', 'refund'].map((c) {
                        return ChoiceChip(
                          label: Text(c.toUpperCase()),
                          selected: category == c,
                          selectedColor: MessColors.orange,
                          onSelected: (v) => setSheetState(() => category = c),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text('Subject', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: MessColors.ink)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: subjectCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Scanner error during lunch or payment query',
                        filled: true,
                        fillColor: MessColors.cream,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MessColors.border)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Message / Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: MessColors.ink)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: messageCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe what happened, mess name, meal slot...',
                        filled: true,
                        fillColor: MessColors.cream,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MessColors.border)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final sub = subjectCtrl.text.trim();
                                final msg = messageCtrl.text.trim();
                                if (sub.isEmpty || msg.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in both subject and message.')));
                                  return;
                                }
                                setSheetState(() => submitting = true);
                                try {
                                  final uri = Uri.parse('https://mess-beta.vercel.app/api/support/ticket');
                                  await http.post(
                                    uri,
                                    headers: {'Content-Type': 'application/json'},
                                    body: jsonEncode({
                                      'name': state.customerName,
                                      'email': state.customerEmail.isNotEmpty ? state.customerEmail : 'student@gmail.com',
                                      'phone': state.customerId,
                                      'role': 'customer',
                                      'subject': sub,
                                      'message': msg,
                                      'category': category,
                                    }),
                                  ).timeout(const Duration(seconds: 12));

                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('✅ Support ticket sent! Support team will respond via email.')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    setSheetState(() => submitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to submit ticket: $e')),
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: MessColors.orange,
                          foregroundColor: MessColors.ink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        child: submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: MessColors.ink, strokeWidth: 2))
                            : const Text('Send Support Request'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSettings(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        builder: (context) => const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: MessColors.navy)),
              SizedBox(height: 10),
              Text('Manage meal reminders, notification preferences, language, and linked payment credentials.', style: TextStyle(color: MessColors.muted, height: 1.5)),
            ]),
          ),
        ),
      );

  Future<void> _confirmSignOut(BuildContext context, AppState state) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to access meal redemptions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirm == true) state.signOut();
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.title, this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(children: [
            Icon(icon, size: 21, color: MessColors.navySoft),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: MessColors.muted))],
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: MessColors.muted),
          ]),
        ),
      );
}
