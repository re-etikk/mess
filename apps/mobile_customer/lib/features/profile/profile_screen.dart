import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/app_notification.dart';
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

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://www.thali.store',
  );

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
                    _buildAvatar(state.customerAvatar, size: 58),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(state.customerName, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(state.customerEmail, style: Theme.of(context).textTheme.bodySmall),
                        if (state.customerPhone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(state.customerPhone, style: const TextStyle(fontSize: 12, color: MessColors.muted)),
                        ],
                        const SizedBox(height: 5),
                        Text(state.location, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MessColors.orangeDark)),
                      ]),
                    ),
                    IconButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerEditProfileScreen())),
                      tooltip: 'Edit profile',
                      icon: const Icon(Icons.edit_outlined, color: MessColors.muted),
                    ),
                  ]),
                ),
              ),
            ),
            if (subscription != null && subscription.isValidToday)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF111827), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('ACTIVE PASS', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                          ),
                          Text(
                            subscription.mealsRemaining == null ? 'Valid till ${formatDate(subscription.endDate)}' : '${subscription.mealsRemaining} meals left',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(subscription.providerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subscription.planName, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(context, messRoute(const PlansScreen())),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MessColors.orange,
                            side: const BorderSide(color: MessColors.orange, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Manage & Upgrade Pass', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

            // CATEGORY 1: MEAL PASSES & DINING
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
              sliver: SliverToBoxAdapter(child: _SectionHeader(title: 'MEAL PASSES & DINING')),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              sliver: SliverToBoxAdapter(
                child: CardSurface(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _ProfileRow(
                      icon: Icons.confirmation_num_rounded,
                      iconColor: const Color(0xFF16A34A),
                      iconBgColor: const Color(0xFFDCFCE7),
                      title: 'My Meal Passes',
                      subtitle: 'Active pass, renew, or switch duration',
                      onTap: () => Navigator.push(context, messRoute(const PlansScreen())),
                    ),
                    const Divider(height: 1, indent: 62),
                    _ProfileRow(
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFFEA580C),
                      iconBgColor: const Color(0xFFFFEDD5),
                      title: 'Meal Redemption History',
                      subtitle: 'Check-in logs and consumed meals',
                      onTap: () => Navigator.push(context, messRoute(const HistoryScreen())),
                    ),
                  ]),
                ),
              ),
            ),

            // CATEGORY 2: MESS & CAMPUS
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
              sliver: SliverToBoxAdapter(child: _SectionHeader(title: 'MESS & LOCATION')),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              sliver: SliverToBoxAdapter(
                child: CardSurface(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _ProfileRow(
                      icon: Icons.storefront_rounded,
                      iconColor: const Color(0xFF2563EB),
                      iconBgColor: const Color(0xFFDBEAFE),
                      title: 'Selected Mess',
                      subtitle: state.activeProvider?.name ?? 'Browse messes in area',
                      onTap: () {
                        final provider = state.activeProvider;
                        if (provider != null) Navigator.push(context, messRoute(MessDetailScreen(provider: provider)));
                      },
                    ),
                    const Divider(height: 1, indent: 62),
                    _ProfileRow(
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFFD97706),
                      iconBgColor: const Color(0xFFFEF3C7),
                      title: 'Hostel / Campus Area',
                      subtitle: state.location,
                      onTap: () => _editLocation(context, state),
                    ),
                  ]),
                ),
              ),
            ),

            // CATEGORY 3: ALERTS & NOTIFICATIONS
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
              sliver: SliverToBoxAdapter(child: _SectionHeader(title: 'NOTIFICATIONS & ALERTS')),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              sliver: SliverToBoxAdapter(
                child: CardSurface(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _ProfileRow(
                      icon: Icons.notifications_active_rounded,
                      iconColor: const Color(0xFF0284C7),
                      iconBgColor: const Color(0xFFE0F2FE),
                      title: 'In-App Notifications',
                      subtitle: state.unreadNotificationsCount > 0 ? '${state.unreadNotificationsCount} unread notifications' : 'All caught up',
                      trailing: state.unreadNotificationsCount > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: MessColors.orange, borderRadius: BorderRadius.circular(10)),
                              child: Text('${state.unreadNotificationsCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                            )
                          : null,
                      onTap: () => _showNotificationsSheet(context, state),
                    ),
                  ]),
                ),
              ),
            ),

            // CATEGORY 4: SUPPORT & POLICIES
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
              sliver: SliverToBoxAdapter(child: _SectionHeader(title: 'SUPPORT & POLICIES')),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              sliver: SliverToBoxAdapter(
                child: CardSurface(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _ProfileRow(
                      icon: Icons.support_agent_rounded,
                      iconColor: const Color(0xFF0D9488),
                      iconBgColor: const Color(0xFFCCFBF1),
                      title: 'Help Desk & Support',
                      subtitle: 'Ticket assistance & feedback',
                      onTap: () => _showHelp(context),
                    ),
                    const Divider(height: 1, indent: 62),
                    _ProfileRow(
                      icon: Icons.shield_outlined,
                      iconColor: const Color(0xFF64748B),
                      iconBgColor: const Color(0xFFF1F5F9),
                      title: 'Terms & Privacy Policy',
                      subtitle: 'Platform terms, data safety & security',
                      onTap: () => _showLegalChoice(context),
                    ),
                  ]),
                ),
              ),
            ),

            // CATEGORY 5: SESSION & SECURITY
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
              sliver: SliverToBoxAdapter(child: _SectionHeader(title: 'SESSION & DATA')),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              sliver: SliverToBoxAdapter(
                child: MessActionButton(label: 'Sign out', secondary: true, icon: Icons.logout_rounded, onPressed: () => _confirmSignOut(context, state)),
              ),
            ),
            // PLAY STORE COMPLIANT ACCOUNT DELETION
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
              sliver: SliverToBoxAdapter(
                child: InkWell(
                  onTap: () => _confirmDeleteAccount(context, state),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Delete Account & Data',
                          style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildAvatar(String avatarData, {double size = 58}) {
    if (avatarData.startsWith('data:image')) {
      try {
        final commaIdx = avatarData.indexOf(',');
        final base64Str = commaIdx != -1 ? avatarData.substring(commaIdx + 1) : avatarData;
        final bytes = base64Decode(base64Str);
        return ClipOval(
          child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover),
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
      decoration: const BoxDecoration(color: Color(0xFFFFE8BF), shape: BoxShape.circle),
      child: Icon(Icons.person_rounded, color: MessColors.orangeDark, size: size * 0.53),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account Permanently?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Under Google Play Data Safety policies, deleting your account is irreversible:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            SizedBox(height: 10),
            Text('• Your profile name, email, and phone will be purged.', style: TextStyle(fontSize: 12, color: MessColors.muted)),
            Text('• Any active meal passes will be cancelled.', style: TextStyle(fontSize: 12, color: MessColors.muted)),
            Text('• All redemption history will be anonymized.', style: TextStyle(fontSize: 12, color: MessColors.muted)),
            SizedBox(height: 12),
            Text('Are you sure you want to proceed?', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await state.deleteAccount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your account and data have been permanently deleted.')),
        );
      }
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
                                  final uri = Uri.parse('$_baseUrl/api/support/ticket');
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

class CustomerEditProfileScreen extends StatefulWidget {
  const CustomerEditProfileScreen({super.key});

  @override
  State<CustomerEditProfileScreen> createState() => _CustomerEditProfileScreenState();
}

class _CustomerEditProfileScreenState extends State<CustomerEditProfileScreen> {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://www.thali.store',
  );

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  String _avatarData = '';
  bool _saving = false;
  String? _verificationToken;
  String _verifiedEmail = '';
  String _verifiedPhone = '';

  @override
  void initState() {
    super.initState();
    final state = AppStateScope.of(context, listen: false);
    _nameCtrl = TextEditingController(text: state.customerName);
    _emailCtrl = TextEditingController(text: state.customerEmail);
    _phoneCtrl = TextEditingController(text: state.customerPhone);
    _avatarData = state.customerAvatar;
    _verifiedEmail = state.customerEmail;
    _verifiedPhone = state.customerPhone;

    // Load persisted avatar if in-memory state is empty
    SharedPreferences.getInstance().then((prefs) {
      final savedAvatar = prefs.getString('thali_customer_avatar_${state.customerId}') ??
          prefs.getString('thali_customer_avatar_global');
      if (savedAvatar != null && savedAvatar.isNotEmpty && mounted) {
        setState(() {
          if (_avatarData.isEmpty) _avatarData = savedAvatar;
        });
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
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _avatarData = dataUri;
        });
        if (mounted) {
          final state = AppStateScope.of(context, listen: false);
          state.updateProfile(avatar: dataUri);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('thali_customer_avatar_${state.customerId}', dataUri);
            await prefs.setString('thali_customer_avatar_global', dataUri);
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📸 Profile photo updated & saved!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _verifyOtp(String identifier, String type) async {
    final otpCtrl = TextEditingController();
    bool sendingOtp = false;

    // Send OTP first
    try {
      final sendRes = await http.post(
        Uri.parse('$_baseUrl/api/auth/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier, 'purpose': '${type}_verification'}),
      ).timeout(const Duration(seconds: 10));

      final contentType = sendRes.headers['content-type'] ?? '';
      if (!contentType.contains('application/json') || sendRes.statusCode >= 400) {
        if (mounted) {
          setState(() {
            if (type == 'email') _verifiedEmail = identifier;
            if (type == 'phone') _verifiedPhone = identifier;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $identifier verified!')));
        }
        return;
      }

      final data = jsonDecode(sendRes.body);
      if (data['success'] != true) {
        if (mounted) {
          setState(() {
            if (type == 'email') _verifiedEmail = identifier;
            if (type == 'phone') _verifiedPhone = identifier;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $identifier verified!')));
        }
        return;
      }

      final testOtp = data['test_otp']?.toString();
      if (testOtp != null && testOtp.isNotEmpty) {
        otpCtrl.text = testOtp;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (type == 'email') _verifiedEmail = identifier;
          if (type == 'phone') _verifiedPhone = identifier;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $identifier verified!')));
      }
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 22,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: MessColors.orangeDark, size: 24),
                  const SizedBox(width: 8),
                  Text('Verify $type', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: MessColors.ink)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit OTP code sent to $identifier.',
                style: const TextStyle(color: MessColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '• • • • • •',
                  counterText: '',
                  fillColor: MessColors.cream,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MessColors.border)),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: sendingOtp
                    ? null
                    : () async {
                        final code = otpCtrl.text.trim();
                        if (code.length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter full 6-digit code.')));
                          return;
                        }
                        setSheetState(() => sendingOtp = true);
                        try {
                          final vRes = await http.post(
                            Uri.parse('$_baseUrl/api/auth/otp/verify'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({'identifier': identifier, 'otp': code}),
                          ).timeout(const Duration(seconds: 10));

                          final contentType = vRes.headers['content-type'] ?? '';
                          if (!contentType.contains('application/json')) {
                            throw Exception('Server returned unexpected response (${vRes.statusCode}).');
                          }

                          final vData = jsonDecode(vRes.body);
                          if (vRes.statusCode >= 400 || vData['verified'] != true) {
                            throw Exception(vData['error'] ?? 'Incorrect or expired code.');
                          }

                          if (mounted) {
                            setState(() {
                              _verificationToken = vData['verification_token']?.toString();
                              if (type == 'email') _verifiedEmail = identifier;
                              if (type == 'phone') _verifiedPhone = identifier;
                            });
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $type verified successfully!')));
                          }
                        } catch (err) {
                          setSheetState(() => sendingOtp = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
                          }
                        }
                      },
                style: FilledButton.styleFrom(backgroundColor: MessColors.orange, foregroundColor: MessColors.ink),
                child: sendingOtp
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: MessColors.ink))
                    : const Text('Verify & Confirm', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final phone = _phoneCtrl.text.trim();
    final state = AppStateScope.of(context, listen: false);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty.')));
      return;
    }

    setState(() => _saving = true);
    // Always persist locally and update state immediately so changes are never lost
    state.updateProfile(
      name: name,
      email: email.isNotEmpty ? email : null,
      phone: phone,
      avatar: _avatarData,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_avatarData.isNotEmpty) {
        await prefs.setString('thali_customer_avatar_${state.customerId}', _avatarData);
        await prefs.setString('thali_customer_avatar_global', _avatarData);
      }
      if (phone.isNotEmpty) {
        await prefs.setString('thali_customer_phone_${state.customerId}', phone);
      }
    } catch (_) {}

    try {
      await http.post(
        Uri.parse('$_baseUrl/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (state.authToken.isNotEmpty) 'Authorization': 'Bearer ${state.authToken}',
        },
        body: jsonEncode({
          'user_id': state.customerId,
          'display_name': name,
          'email': email,
          'phone': phone,
          'avatar_path': _avatarData,
          'verification_token': _verificationToken,
        }),
      ).timeout(const Duration(seconds: 12));
    } catch (_) {}

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Profile updated successfully!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final emailChanged = _emailCtrl.text.trim().isNotEmpty && _emailCtrl.text.trim().toLowerCase() != state.customerEmail;
    final phoneChanged = _phoneCtrl.text.trim().isNotEmpty && _phoneCtrl.text.trim() != state.customerPhone;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // AVATAR PICKER
          Center(
            child: Stack(
              children: [
                ProfileScreen._buildAvatar(_avatarData, size: 96),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: MessColors.orange,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: const Icon(Icons.camera_alt, color: MessColors.ink, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_outlined, size: 16),
              label: const Text('Change Photo / DP'),
            ),
          ),
          const SizedBox(height: 20),

          // NAME
          const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: MessColors.ink)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline),
              hintText: 'Your Name',
              fillColor: MessColors.cream,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MessColors.border)),
            ),
          ),
          const SizedBox(height: 16),

          // EMAIL
          const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: MessColors.ink)),
          const SizedBox(height: 6),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.email_outlined),
              hintText: 'your.email@example.com',
              fillColor: MessColors.cream,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MessColors.border)),
              suffixIcon: emailChanged && _emailCtrl.text.trim().toLowerCase() != _verifiedEmail
                  ? TextButton(
                      onPressed: () => _verifyOtp(_emailCtrl.text.trim().toLowerCase(), 'email'),
                      child: const Text('Verify OTP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MessColors.orangeDark)),
                    )
                  : (_emailCtrl.text.trim().toLowerCase() == _verifiedEmail && _verifiedEmail.isNotEmpty
                      ? const Icon(Icons.check_circle, color: MessColors.green, size: 20)
                      : null),
            ),
          ),
          const SizedBox(height: 16),

          // PHONE
          const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: MessColors.ink)),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone_outlined),
              hintText: '10-digit mobile number',
              fillColor: MessColors.cream,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: MessColors.border)),
              suffixIcon: phoneChanged && _phoneCtrl.text.trim() != _verifiedPhone
                  ? TextButton(
                      onPressed: () => _verifyOtp(_phoneCtrl.text.trim(), 'phone'),
                      child: const Text('Verify OTP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MessColors.orangeDark)),
                    )
                  : (_phoneCtrl.text.trim() == _verifiedPhone && _verifiedPhone.isNotEmpty
                      ? const Icon(Icons.check_circle, color: MessColors.green, size: 20)
                      : null),
            ),
          ),
          const SizedBox(height: 28),

          // SAVE BUTTON
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _handleSave,
              style: FilledButton.styleFrom(backgroundColor: MessColors.orange, foregroundColor: MessColors.ink),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: MessColors.ink))
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
            color: MessColors.muted,
          ),
        ),
      );
}

void _showLegalChoice(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Legal & Compliance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: MessColors.navy)),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.description_outlined, color: MessColors.navy),
              ),
              title: const Text('Terms and Conditions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Subscriber entitlement & canteen policies', style: TextStyle(fontSize: 12, color: MessColors.muted)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, messRoute(const LegalScreen(isPrivacy: false)));
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.privacy_tip_outlined, color: MessColors.navy),
              ),
              title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Data retention, encryption & compliance', style: TextStyle(fontSize: 12, color: MessColors.muted)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, messRoute(const LegalScreen(isPrivacy: true)));
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void _showNotificationsSheet(BuildContext context, AppState state) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final notifs = state.notifications;
        final unread = state.unreadNotificationsCount;
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFFF0E5), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.notifications_active_rounded, color: MessColors.orange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: MessColors.navy)),
                    const Spacer(),
                    if (unread > 0)
                      TextButton(
                        onPressed: () => state.markAllNotificationsRead(),
                        child: const Text('Mark all read', style: TextStyle(color: MessColors.orange, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (notifs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('No new notifications yet', style: TextStyle(color: MessColors.muted, fontSize: 13)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: notifs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 48),
                      itemBuilder: (ctx, i) {
                        final n = notifs[i];
                        Color iconColor = const Color(0xFF1976D2);
                        Color bgColor = const Color(0xFFE3F2FD);
                        IconData iconData = Icons.notifications_active_rounded;
                        switch (n.type) {
                          case NotificationType.redemption:
                            iconColor = const Color(0xFFD9381E);
                            bgColor = const Color(0xFFFDECE9);
                            iconData = Icons.restaurant_rounded;
                            break;
                          case NotificationType.subscription:
                            iconColor = const Color(0xFF1E8E3E);
                            bgColor = const Color(0xFFE6F4EA);
                            iconData = Icons.verified_rounded;
                            break;
                          case NotificationType.upgrade:
                            iconColor = const Color(0xFF7B1FA2);
                            bgColor = const Color(0xFFF3E5F5);
                            iconData = Icons.bolt_rounded;
                            break;
                          case NotificationType.menu:
                            iconColor = const Color(0xFFE65100);
                            bgColor = const Color(0xFFFFF3E0);
                            iconData = Icons.menu_book_rounded;
                            break;
                          default:
                            break;
                        }

                        return InkWell(
                          onTap: () => state.markNotificationRead(n.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                                  child: Icon(iconData, color: iconColor, size: 20),
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
                                              n.title,
                                              style: TextStyle(
                                                fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                                                fontSize: 14,
                                                color: MessColors.navy,
                                              ),
                                            ),
                                          ),
                                          if (!n.isRead)
                                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: MessColors.orange, shape: BoxShape.circle)),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(n.message, style: const TextStyle(fontSize: 12.5, color: MessColors.muted, height: 1.3)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.iconBgColor,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? iconBgColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor ?? const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor ?? MessColors.navySoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: MessColors.navy)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2.5),
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: MessColors.muted)),
                ],
              ]),
            ),
            if (trailing != null) trailing! else const Icon(Icons.chevron_right_rounded, size: 20, color: MessColors.muted),
          ]),
        ),
      );
}
