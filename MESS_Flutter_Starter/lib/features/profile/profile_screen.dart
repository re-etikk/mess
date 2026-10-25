import 'package:flutter/material.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../auth/login_screen.dart';
import '../history/history_screen.dart';
import '../mess/mess_detail_screen.dart';
import '../plans/plans_screen.dart';
import 'legal_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(animation: state, builder: (context, _) {
      final subscription = state.activeSubscription;
      return CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
        SliverPadding(padding: const EdgeInsets.fromLTRB(18, 20, 18, 0), sliver: SliverToBoxAdapter(child: Row(children: [Expanded(child: Text('Profile', style: Theme.of(context).textTheme.headlineLarge)), IconButton(onPressed: () => _showSettings(context), tooltip: 'Settings', icon: const Icon(Icons.settings_outlined))]))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(18, 17, 18, 0), sliver: SliverToBoxAdapter(child: CardSurface(padding: const EdgeInsets.all(17), child: Row(children: [Container(width: 58, height: 58, decoration: const BoxDecoration(color: Color(0xFFFFE8BF), shape: BoxShape.circle), child: const Icon(Icons.person_rounded, color: MessColors.orangeDark, size: 31)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(state.customerName, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 4), Text(state.customerEmail, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 5), Text(state.location, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MessColors.orangeDark))])), IconButton(onPressed: () => _editProfile(context, state), tooltip: 'Edit profile', icon: const Icon(Icons.edit_outlined, color: MessColors.muted))])))),
        if (subscription != null && subscription.isValidToday)
          SliverPadding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 0), sliver: SliverToBoxAdapter(child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: MessColors.navy, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('CURRENT PLAN', style: TextStyle(color: Color(0xFFC3CFD7), fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w700)), const SizedBox(height: 7), Text(subscription.providerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subscription.planName, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 10), Row(children: [Expanded(child: Text(subscription.mealsRemaining == null ? 'Valid till ${formatDate(subscription.endDate)}' : '${subscription.mealsRemaining} meals remaining', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))), TextButton(onPressed: () => Navigator.push(context, messRoute(const PlansScreen())), child: const Text('Manage', style: TextStyle(color: MessColors.orange)))]),])))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(18, 22, 18, 9), sliver: SliverToBoxAdapter(child: Text('Your account', style: Theme.of(context).textTheme.titleLarge))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 0), sliver: SliverToBoxAdapter(child: CardSurface(padding: EdgeInsets.zero, child: Column(children: [
          _ProfileRow(icon: Icons.calendar_month_outlined, title: 'My plans', subtitle: 'Active and previous subscriptions', onTap: () => Navigator.push(context, messRoute(const PlansScreen()))),
          const Divider(height: 1, indent: 54),
          _ProfileRow(icon: Icons.receipt_long_outlined, title: 'Meal history', subtitle: 'View redeemed meals and activity', onTap: () => Navigator.push(context, messRoute(const HistoryScreen()))),
          const Divider(height: 1, indent: 54),
          _ProfileRow(icon: Icons.location_on_outlined, title: 'Location', subtitle: state.location, onTap: () => _editLocation(context, state)),
          const Divider(height: 1, indent: 54),
          _ProfileRow(icon: Icons.storefront_outlined, title: 'Selected mess', subtitle: state.activeProvider?.name ?? 'Browse messes', onTap: () { final provider = state.activeProvider; if (provider != null) Navigator.push(context, messRoute(MessDetailScreen(provider: provider))); }),
          const Divider(height: 1, indent: 54),
          _ProfileRow(icon: Icons.help_outline_rounded, title: 'Help and support', subtitle: 'Get help with your plan or meal', onTap: () => _showHelp(context)),
          const Divider(height: 1, indent: 54),
          _ProfileRow(icon: Icons.description_outlined, title: 'Terms and conditions', onTap: () => Navigator.push(context, messRoute(const LegalScreen(isPrivacy: false)))),
          const Divider(height: 1, indent: 54),
          _ProfileRow(icon: Icons.privacy_tip_outlined, title: 'Privacy policy', onTap: () => Navigator.push(context, messRoute(const LegalScreen(isPrivacy: true)))),
        ])))),
        if (state.isDemoMode) ...[
          SliverPadding(padding: const EdgeInsets.fromLTRB(18, 21, 18, 8), sliver: SliverToBoxAdapter(child: Text('Demo preview tools', style: Theme.of(context).textTheme.titleLarge))),
          SliverPadding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 0), sliver: SliverToBoxAdapter(child: CardSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Preview both customer states while building.', style: TextStyle(fontSize: 12, color: MessColors.muted)), const SizedBox(height: 12), Row(children: [Expanded(child: MessActionButton(label: 'With plan', secondary: true, onPressed: state.previewTrackerSubscription)), const SizedBox(width: 9), Expanded(child: MessActionButton(label: 'No plan', secondary: true, onPressed: state.previewNoSubscription))]), const SizedBox(height: 7), const Text('Remove this developer-only section before production.', style: TextStyle(fontSize: 10.5, color: MessColors.red))])))),
        ],
        SliverPadding(padding: const EdgeInsets.fromLTRB(18, 17, 18, 28), sliver: SliverToBoxAdapter(child: MessActionButton(label: 'Sign out', secondary: true, icon: Icons.logout_rounded, onPressed: () => _confirmSignOut(context, state)))),
      ]);
    });
  }

  Future<void> _editProfile(BuildContext context, AppState state) async {
    final name = TextEditingController(text: state.customerName);
    final email = TextEditingController(text: state.customerEmail);
    final result = await showDialog<List<String>>(context: context, builder: (context) => AlertDialog(title: const Text('Edit profile'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), const SizedBox(height: 12), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, [name.text.trim(), email.text.trim()]), child: const Text('Save'))]));
    name.dispose(); email.dispose();
    if (result != null && result.first.isNotEmpty && result.last.isNotEmpty) {
      state.signInDemo(emailOrPhone: result.last, name: result.first);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated in local demo only.')));
    }
  }

  Future<void> _editLocation(BuildContext context, AppState state) async {
    final text = TextEditingController(text: state.location);
    final result = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Set location'), content: TextField(controller: text, decoration: const InputDecoration(labelText: 'Hostel, area or landmark')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, text.text.trim()), child: const Text('Save'))]));
    text.dispose();
    if (result != null && result.isNotEmpty) state.updateLocation(result);
  }

  void _showHelp(BuildContext context) => showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Help and support'), content: const Text('In production, connect this area to a support form, help email and ticket history. No support ticket service is connected in this demo.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));

  void _showSettings(BuildContext context) => showModalBottomSheet<void>(context: context, builder: (context) => const SafeArea(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: MessColors.navy)), SizedBox(height: 10), Text('Production settings should include notification preferences, privacy controls, account deletion and linked sign-in methods. These are not connected in this starter.', style: TextStyle(color: MessColors.muted, height: 1.5))]))));

  Future<void> _confirmSignOut(BuildContext context, AppState state) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Sign out?'), content: const Text('You can sign in again to view your meal details.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out'))]));
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
  Widget build(BuildContext context) => PressScale(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12), child: Row(children: [Icon(icon, size: 21, color: MessColors.navySoft), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)), if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: MessColors.muted))]])), const Icon(Icons.chevron_right_rounded, size: 20, color: MessColors.muted)])));
}
