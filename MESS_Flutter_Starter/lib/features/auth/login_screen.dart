import 'package:flutter/material.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final state = AppStateScope.of(context);
    state.signInDemo(emailOrPhone: _emailController.text, name: '');
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo session started. Connect the real authentication service before release.')));
  }

  void _googleSignIn() {
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Google sign-in setup required'),
      content: const Text('This starter includes the Google sign-in UI, but OAuth is not connected. Antigravity must connect Google OAuth through the configured authentication provider before production.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, compact ? 20 : 36, 24, 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Center(child: MessLogo()),
                      SizedBox(height: compact ? 34 : 52),
                      Text('Welcome back', style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 8),
                      Text('Sign in to manage your meals.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: MessColors.muted)),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email or phone number', prefixIcon: Icon(Icons.person_outline_rounded)),
                        validator: (value) => value == null || value.trim().length < 3 ? 'Enter your email or phone number.' : null,
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(tooltip: _showPassword ? 'Hide password' : 'Show password', onPressed: () => setState(() => _showPassword = !_showPassword), icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
                        ),
                        validator: (value) => value == null || value.length < 6 ? 'Password must contain at least 6 characters.' : null,
                      ),
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.push(context, messRoute(const ForgotPasswordScreen())), child: const Text('Forgot password?'))),
                      const SizedBox(height: 8),
                      MessActionButton(label: 'Sign in', loading: _busy, onPressed: _login),
                      const SizedBox(height: 20),
                      const _OrDivider(),
                      const SizedBox(height: 20),
                      _GoogleButton(onPressed: _googleSignIn),
                      const SizedBox(height: 26),
                      Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text('New to MESS? ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MessColors.muted)),
                        TextButton(onPressed: () => Navigator.push(context, messRoute(const RegisterScreen())), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 3)), child: const Text('Create account')),
                      ]),
                      const SizedBox(height: 12),
                      Text('By continuing, you agree to the Terms and Privacy Policy.\nLocal demo mode. Authentication is not connected.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 13), child: Text('OR', style: Theme.of(context).textTheme.bodySmall)), const Expanded(child: Divider())]);
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onPressed,
        child: Container(
          height: 51,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: MessColors.border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const _GoogleG(), const SizedBox(width: 12), Text('Continue with Google', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
          ]),
        ),
      );
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 23, child: Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4285F4), letterSpacing: -1)));
}
