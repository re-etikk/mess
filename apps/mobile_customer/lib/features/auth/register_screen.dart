import 'package:flutter/material.dart';

import '../../core/repositories/mess_repository.dart';
import '../../core/services/customer_auth_service.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../setup/profile_location_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _agree = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Terms of Service and Privacy Policy.')),
      );
      return;
    }

    final state = AppStateScope.of(context, listen: false);
    setState(() => _busy = true);
    try {
      final result = await CustomerAuthService.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      state.signIn(
        emailOrPhone: result.email,
        name: result.name,
        userId: result.userId,
        token: result.token,
        refreshToken: result.refreshToken,
      );
      Navigator.of(context).pushAndRemoveUntil(
        messRoute(const ProfileLocationSetupScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyCustomerError(e, action: 'create account'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.card,
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: ThaliLogoMark(size: 40, withWordmark: true)),
                    const SizedBox(height: 22),
                    const Text(
                      'Join Thali',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Create one account for daily tiffin subscriptions, skips, and counter check-ins.',
                      style: TextStyle(fontSize: 13.5, color: ThaliColors.muted, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => v == null || v.trim().length < 2 ? 'Enter your full name.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) => v != null && v.contains('@') && v.contains('.') ? null : 'Enter a valid email.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number (optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => v != null && v.trim().isNotEmpty && v.trim().length < 10
                          ? 'Enter a valid 10-digit number.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (v) => v == null || v.length < 8 ? 'Minimum 8 characters required.' : null,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _agree,
                      activeColor: ThaliColors.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I agree to the Terms of Service and Privacy Policy.',
                        style: TextStyle(fontSize: 12.5, color: ThaliColors.body),
                      ),
                      onChanged: (v) => setState(() => _agree = v ?? false),
                    ),
                    const SizedBox(height: 16),
                    MessActionButton(
                      label: 'Create Account',
                      loading: _busy,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account?', style: TextStyle(color: ThaliColors.muted, fontSize: 13)),
                        TextButton(
                          onPressed: () => Navigator.maybePop(context),
                          child: const Text('Sign In', style: TextStyle(color: ThaliColors.primary, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
