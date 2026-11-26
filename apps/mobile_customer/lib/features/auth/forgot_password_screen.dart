import 'package:flutter/material.dart';

import '../../core/theme/thali_theme.dart';
import '../../core/widgets/mess_widgets.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.card,
      appBar: AppBar(title: const Text('Account Access')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
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
                child: const Icon(Icons.mark_email_read_outlined, size: 28, color: ThaliColors.primary),
              ),
              const SizedBox(height: 18),
              const Text(
                'Sign in with Email OTP',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ThaliColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Thali uses instant 6-digit email verification codes instead of password reset emails. Return to Sign In and choose the Email OTP tab with your registered email address.',
                style: TextStyle(fontSize: 13.5, color: ThaliColors.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              MessActionButton(
                label: 'Continue with Email OTP',
                onPressed: () => Navigator.maybePop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
