import 'package:flutter/material.dart';

import '../../core/theme/thali_theme.dart';
import '../../core/widgets/mess_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _sent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reset instructions sent to ${_email.text.trim()}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.card,
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
          child: Form(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: ThaliColors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, size: 30, color: ThaliColors.primary),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Reset Password',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your email or sign in directly using Email/Mobile OTP from the login screen.',
                  style: TextStyle(fontSize: 13.5, color: ThaliColors.muted, height: 1.45),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (v) => v != null && v.contains('@') && v.contains('.') ? null : 'Enter a valid email.',
                ),
                const SizedBox(height: 18),
                MessActionButton(label: _sent ? 'Resend Link' : 'Send Reset Link', onPressed: _send),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
