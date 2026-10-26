import 'package:flutter/material.dart';

import '../../core/services/customer_auth_service.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import 'login_screen.dart';

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
  bool _showPassword = false;
  bool _terms = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_key.currentState!.validate()) return;
    if (!_terms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please accept the Terms and Privacy Policy to continue.')));
      return;
    }
    setState(() => _busy = true);
    final state = AppStateScope.of(context);
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
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account created for ${result.name}!')));
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: MessColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Create account')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Form(
                  key: _key,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Center(child: MessLogo(compact: true)),
                    const SizedBox(height: 22),
                    Text('Join MESS', style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 6),
                    Text('One account for your plans and meal history.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MessColors.muted)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)),
                      validator: (v) => v == null || v.trim().length < 2 ? 'Enter your full name.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
                      validator: (v) => v != null && v.contains('@') && v.contains('.') ? null : 'Enter a valid email address.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(labelText: 'Phone number (optional)', prefixIcon: Icon(Icons.phone_outlined)),
                      validator: (v) => v != null && v.trim().isNotEmpty && v.trim().length < 10 ? 'Enter a valid phone number.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Create password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                          icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        ),
                      ),
                      validator: (v) => v == null || v.length < 8 ? 'Use at least 8 characters.' : null,
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _terms,
                      onChanged: (value) => setState(() => _terms = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('I agree to the Terms and Privacy Policy.', style: TextStyle(fontSize: 12.5)),
                      activeColor: MessColors.orange,
                      dense: true,
                    ),
                    const SizedBox(height: 10),
                    MessActionButton(label: 'Create account', loading: _busy, onPressed: _register),
                    const SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Already have an account? ', style: TextStyle(color: MessColors.muted)),
                        TextButton(onPressed: () => Navigator.pushReplacement(context, messRoute(const LoginScreen())), child: const Text('Sign in')),
                      ],
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
