import 'package:flutter/material.dart';

import '../../core/services/customer_auth_service.dart';
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
    final state = AppStateScope.of(context);
    try {
      final result = await CustomerAuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      state.signIn(
        emailOrPhone: result.email,
        name: result.name,
        userId: result.userId,
        token: result.token,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Welcome, ${result.name}!')));
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
                      Text('Sign in to manage your meals and subscriptions.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: MessColors.muted)),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email or phone number',
                          hintText: 'e.g. 7250171036 or name@gmail.com',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) => value == null || value.trim().length < 3 ? 'Enter your email or phone number.' : null,
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter account password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _showPassword ? 'Hide password' : 'Show password',
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          ),
                        ),
                        validator: (value) => value == null || value.length < 6 ? 'Password must contain at least 6 characters.' : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: () => Navigator.push(context, messRoute(const ForgotPasswordScreen())), child: const Text('Forgot password?')),
                      ),
                      const SizedBox(height: 8),
                      MessActionButton(label: 'Sign in', loading: _busy, onPressed: _login),
                      const SizedBox(height: 20),
                      const SizedBox(height: 26),
                      Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text('New to MESS? ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MessColors.muted)),
                        TextButton(onPressed: () => Navigator.push(context, messRoute(const RegisterScreen())), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 3)), child: const Text('Create account')),
                      ]),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
      );
}

