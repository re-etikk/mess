import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
                    _ProfileRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit Profile & Details',
                      subtitle: 'Update DP, name, phone, and verified email',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerEditProfileScreen())),
                    ),
                    const Divider(height: 1, indent: 54),
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
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
              sliver: SliverToBoxAdapter(
                child: MessActionButton(label: 'Sign out', secondary: true, icon: Icons.logout_rounded, onPressed: () => _confirmSignOut(context, state)),
              ),
            ),
            // PLAY STORE COMPLIANT ACCOUNT DELETION
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
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
      if (!contentType.contains('application/json')) {
        throw Exception('Service is temporarily unavailable (${sendRes.statusCode}). Please try again.');
      }

      final data = jsonDecode(sendRes.body);
      if (sendRes.statusCode >= 400 || data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to send verification code');
      }

      final testOtp = data['test_otp']?.toString();
      if (testOtp != null && testOtp.isNotEmpty) {
        otpCtrl.text = testOtp;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send OTP: $e')));
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

    // If email changed and not verified
    if (email.isNotEmpty && email != state.customerEmail && email != _verifiedEmail) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify your new email address with OTP before saving.')));
      return;
    }

    // If phone changed and not verified
    if (phone.isNotEmpty && phone != state.customerPhone && phone != _verifiedPhone) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify your new phone number with OTP before saving.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await http.post(
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

      final data = jsonDecode(res.body);
      if (res.statusCode >= 400 || data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to update profile.');
      }

      state.updateProfile(
        name: name,
        email: email,
        phone: phone,
        avatar: _avatarData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Profile updated successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      // Offline fallback: save locally
      state.updateProfile(name: name, email: email, phone: phone, avatar: _avatarData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated on device.')));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
