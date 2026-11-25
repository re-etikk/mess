import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

class ProviderLoginScreen extends StatefulWidget {
  const ProviderLoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onRegister,
  });

  final ValueChanged<ProviderSession> onLoginSuccess;
  final VoidCallback onRegister;

  @override
  State<ProviderLoginScreen> createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool _isPasswordMode = false;
  bool _isOtpStep = false;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;
  String? _testOtpHint;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 25);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _otpCode => _otpCtrls.map((c) => c.text.trim()).join();

  Future<void> _sendOtp() async {
    final id = _identifierCtrl.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(id)) {
      setState(() => _error = 'Enter a valid partner email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _testOtpHint = null;
    });
    try {
      final res = await ProviderApiService.sendOtp(identifier: id, purpose: 'signin');
      if (!mounted) return;
      _startTimer();
      setState(() {
        _isOtpStep = true;
        _testOtpHint = res['test_otp']?.toString();
      });
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _otpFocus.first.requestFocus();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCode;
    if (code.length != 6) {
      setState(() => _error = 'Enter the full 6-digit verification code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ProviderApiService.verifyOtpSignIn(
        identifier: _identifierCtrl.text.trim(),
        otp: code,
      );
      if (!mounted) return;
      showPartnerNotice(context, 'Signed in to ${session.businessName}');
      widget.onLoginSuccess(session);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _passwordSignIn() async {
    final emailText = _identifierCtrl.text.trim();
    final passText = _passwordCtrl.text.trim();
    if (emailText.isEmpty || passText.isEmpty) {
      setState(() => _error = 'Enter both your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ProviderApiService.login(email: emailText, password: passText);
      if (!mounted) return;
      showPartnerNotice(context, 'Signed in to ${session.businessName}');
      widget.onLoginSuccess(session);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.card,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Warm Brand Banner (Matches Behance AU01 + Partner badge)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
                decoration: const BoxDecoration(
                  color: ThaliColors.primarySoft,
                  border: Border(bottom: BorderSide(color: ThaliColors.stroke)),
                ),
                child: Column(
                  children: [
                    if (_isOtpStep)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => setState(() {
                            _isOtpStep = false;
                            _error = null;
                          }),
                          icon: const Icon(Icons.chevron_left_rounded, size: 28, color: ThaliColors.ink),
                        ),
                      ),
                    const ThaliLogoMark(size: 44, withWordmark: true, subtitle: 'Partner'),
                    const SizedBox(height: 10),
                    Text(
                      _isOtpStep ? 'Verify your identity' : 'Kitchen Partner Portal',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isOtpStep
                          ? 'Enter the 6-digit verification code sent to ${_identifierCtrl.text.trim()}'
                          : 'Manage orders, daily menus, plans, and counter QR attendance.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: ThaliColors.body),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isOtpStep) ...[
                      // Mode Toggle (OTP vs Password)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: ThaliColors.subtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ThaliColors.stroke),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _modeTab(
                                label: 'OTP Sign In',
                                active: !_isPasswordMode,
                                onTap: () => setState(() {
                                  _isPasswordMode = false;
                                  _error = null;
                                }),
                              ),
                            ),
                            Expanded(
                              child: _modeTab(
                                label: 'Password',
                                active: _isPasswordMode,
                                onTap: () => setState(() {
                                  _isPasswordMode = true;
                                  _error = null;
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Partner Email',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _identifierCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'owner@kitchen.com',
                          prefixIcon: const Icon(Icons.mail_outline_rounded, color: ThaliColors.muted),
                        ),
                      ),
                      if (_isPasswordMode) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Password',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          onSubmitted: (_) => _passwordSignIn(),
                          decoration: InputDecoration(
                            hintText: 'Enter partner password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: ThaliColors.muted),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      if (_testOtpHint != null && _testOtpHint!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ThaliColors.amberSoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ThaliColors.amberBorder),
                          ),
                          child: Text(
                            'Test OTP: $_testOtpHint',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThaliColors.amberDark),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (idx) {
                          return SizedBox(
                            width: 46,
                            height: 54,
                            child: TextField(
                              controller: _otpCtrls[idx],
                              focusNode: _otpFocus[idx],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                              decoration: const InputDecoration(counterText: '', contentPadding: EdgeInsets.zero),
                              onChanged: (v) {
                                if (v.isNotEmpty && idx < 5) {
                                  _otpFocus[idx + 1].requestFocus();
                                } else if (v.isEmpty && idx > 0) {
                                  _otpFocus[idx - 1].requestFocus();
                                }
                              },
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: _resendSeconds > 0
                            ? Text(
                                'Resend code in ${_resendSeconds}s',
                                style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                              )
                            : TextButton(
                                onPressed: _loading ? null : _sendOtp,
                                child: const Text(
                                  'Resend OTP',
                                  style: TextStyle(color: ThaliColors.primary, fontWeight: FontWeight.w700),
                                ),
                              ),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThaliColors.redSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ThaliColors.redBorder),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(fontSize: 12.5, color: ThaliColors.red, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    PartnerActionButton(
                      label: _isOtpStep
                          ? 'Verify & Open Dashboard'
                          : (_isPasswordMode ? 'Sign In' : 'Continue with OTP'),
                      loading: _loading,
                      onPressed: _isOtpStep
                          ? _verifyOtp
                          : (_isPasswordMode ? _passwordSignIn : _sendOtp),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'New kitchen partner?',
                          style: TextStyle(fontSize: 13, color: ThaliColors.muted),
                        ),
                        TextButton(
                          onPressed: widget.onRegister,
                          child: const Text(
                            'Register Kitchen',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThaliColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTab({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? ThaliColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: active ? Border.all(color: ThaliColors.stroke) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? ThaliColors.ink : ThaliColors.muted,
          ),
        ),
      ),
    );
  }
}

class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({super.key, required this.onComplete});
  final ValueChanged<ProviderSession> onComplete;

  @override
  State<ProviderOnboardingScreen> createState() => _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  final _businessCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  int _step = 0;
  bool _submitting = false;
  bool _supportsDelivery = false;

  @override
  void dispose() {
    _businessCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    if (!email.contains('@') || pass.length < 6) {
      showPartnerNotice(context, 'Enter a valid email and at least 6 characters password.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = await ProviderApiService.register(
        businessName: _businessCtrl.text.trim(),
        ownerName: _ownerCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: email,
        password: pass,
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        supportsDelivery: _supportsDelivery,
      );
      if (!mounted) return;
      showPartnerNotice(context, 'Kitchen registered: ${session.businessName}');
      widget.onComplete(session);
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        showPartnerNotice(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(title: const Text('Register Your Kitchen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          CardSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _step == 0 ? 'Step 1 of 2 · Kitchen Profile' : 'Step 2 of 2 · Account Credentials',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThaliColors.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  _step == 0 ? 'Tell customers where you serve' : 'Create your partner login',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 16),
                if (_step == 0) ...[
                  TextField(controller: _businessCtrl, decoration: const InputDecoration(labelText: 'Kitchen / Mess Name')),
                  const SizedBox(height: 12),
                  TextField(controller: _ownerCtrl, decoration: const InputDecoration(labelText: 'Owner Full Name')),
                  const SizedBox(height: 12),
                  TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Locality / Street Address')),
                  const SizedBox(height: 12),
                  TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'City')),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: ThaliColors.scaffold,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ThaliColors.stroke),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: ThaliColors.primarySoft,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.delivery_dining_outlined, size: 18, color: ThaliColors.primary),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Self Tiffin Delivery', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                              Text(
                                'Off = Counter Pickup / Dine-in only. You can toggle later anytime.',
                                style: TextStyle(fontSize: 11.5, color: ThaliColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          activeColor: ThaliColors.primary,
                          value: _supportsDelivery,
                          onChanged: (v) => setState(() => _supportsDelivery = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  PartnerActionButton(
                    label: 'Next: Account Setup',
                    onPressed: () {
                      if (_businessCtrl.text.trim().isEmpty || _ownerCtrl.text.trim().isEmpty) {
                        showPartnerNotice(context, 'Enter your kitchen name and owner name.', isError: true);
                        return;
                      }
                      setState(() => _step = 1);
                    },
                  ),
                ] else ...[
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: '10-Digit Mobile Number'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Partner Email Address'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password (min 6 characters)'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: PartnerActionButton(
                          label: 'Back',
                          secondary: true,
                          onPressed: _submitting ? null : () => setState(() => _step = 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: PartnerActionButton(
                          label: 'Create Kitchen',
                          loading: _submitting,
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
