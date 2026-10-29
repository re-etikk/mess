import 'package:flutter/material.dart';
import '../../core/widgets/mess_widgets.dart';
import '../../core/theme/mess_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _controller = TextEditingController();
  final _key = GlobalKey<FormState>();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Reset password')),
        body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Form(key: _key, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 36), const Icon(Icons.lock_reset_rounded, size: 48, color: MessColors.orange), const SizedBox(height: 22),
          Text('Forgot your password?', style: Theme.of(context).textTheme.headlineLarge), const SizedBox(height: 8),
          Text('Enter the email connected to your account. We will send a secure link to your email.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MessColors.muted)),
          const SizedBox(height: 25),
          TextFormField(controller: _controller, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)), validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email address.'),
          const SizedBox(height: 16),
          MessActionButton(label: 'Send reset link', onPressed: () { if (!_key.currentState!.validate()) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset instructions have been dispatched to your email.'))); }),
        ])))))),
      );
}
