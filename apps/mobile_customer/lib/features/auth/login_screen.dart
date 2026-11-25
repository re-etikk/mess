import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/services/customer_auth_service.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool _isPhoneMode = false;
  bool _isPasswordMode = false;
  bool _isOtpStep = false;
  bool _verified = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String? _devOtpHint;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _identifierController.dispose();
    _passwordController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 25);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
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

  String get _otpValue => _otpControllers.map((c) => c.text.trim()).join();

  Future<void> _sendOtp() async {
    final id = _identifierController.text.trim();
    if (id.isEmpty) {
      setState(() => _error = _isPhoneMode ? 'Enter your 10-digit phone number.' : 'Enter your email address.');
      return;
    }
    if (!_isPhoneMode && !id.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_isPhoneMode && id.replaceAll(RegExp(r'\D'), '').length < 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _devOtpHint = null;
    });

    try {
      final res = await CustomerAuthService.sendOtp(identifier: id, purpose: 'signin');
      if (!mounted) return;
      _startTimer();
      setState(() {
        _isOtpStep = true;
        _verified = false;
        _devOtpHint = res['test_otp']?.toString();
      });
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _otpFocus.first.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpValue;
    if (code.length != 6) {
      setState(() => _error = 'Enter all 6 digits of your OTP.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await CustomerAuthService.verifyOtpSignIn(
        identifier: _identifierController.text.trim(),
        otp: code,
      );
      if (!mounted) return;
      setState(() => _verified = true);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final appState = AppStateScope.of(context);
      appState.signIn(
        emailOrPhone: result.email.isNotEmpty ? result.email : result.phone,
        name: result.name,
        userId: result.userId,
        token: result.token,
        refreshToken: result.refreshToken,
        needsSetup: result.needsProfileSetup,
        foodPref: result.foodPreference,
        locality: result.locality,
        city: result.city,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithPassword() async {
    final id = _identifierController.text.trim();
    final pass = _passwordController.text;
    if (id.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await CustomerAuthService.login(email: id, password: pass);
      if (!mounted) return;
      AppStateScope.of(context).signIn(
        emailOrPhone: res.email,
        name: res.name,
        userId: res.userId,
        token: res.token,
        refreshToken: res.refreshToken,
        needsSetup: res.needsProfileSetup,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildAuthHeader() {
    return Container(
      width: double.infinity,
      height: 156,
      decoration: const BoxDecoration(
        color: ThaliColors.heroSubtle,
        border: Border(bottom: BorderSide(color: Color(0xFFFDE4DA))),
      ),
      child: Stack(
        children: [
          Positioned(left: 18, top: 26, child: Icon(Icons.restaurant_outlined, size: 22, color: ThaliColors.primary.withValues(alpha: 0.22))),
          Positioned(right: 24, top: 24, child: Icon(Icons.rice_bowl_outlined, size: 22, color: ThaliColors.primary.withValues(alpha: 0.22))),
          Positioned(left: 48, bottom: 20, child: Icon(Icons.local_cafe_outlined, size: 20, color: ThaliColors.primary.withValues(alpha: 0.22))),
          Positioned(right: 52, bottom: 22, child: Icon(Icons.delivery_dining_outlined, size: 24, color: ThaliColors.primary.withValues(alpha: 0.22))),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                ThaliLogoMark(size: 46),
                SizedBox(width: 10),
                Text(
                  'Thali',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: ThaliColors.ink, letterSpacing: -0.9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identifierText = _identifierController.text.trim();
    final canContinue = _isPasswordMode
        ? (identifierText.isNotEmpty && _passwordController.text.isNotEmpty)
        : identifierText.isNotEmpty;

    return Scaffold(
      backgroundColor: ThaliColors.card,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAuthHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                child: _isOtpStep ? _buildOtpView() : _buildEntryView(canContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryView(bool canContinue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isPasswordMode || _isPhoneMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              onTap: () => setState(() {
                _isPasswordMode = false;
                _isPhoneMode = false;
                _error = null;
              }),
              child: Row(
                children: [
                  const Icon(Icons.chevron_left_rounded, size: 22, color: ThaliColors.ink),
                  const SizedBox(width: 4),
                  Text(
                    _isPasswordMode ? 'Sign in with password' : 'Continue with Phone',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                  ),
                ],
              ),
            ),
          ),
        Text(
          _isPhoneMode ? 'Mobile Number' : 'Email Address',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThaliColors.ink),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _identifierController,
          keyboardType: _isPhoneMode ? TextInputType.phone : TextInputType.emailAddress,
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            hintText: _isPhoneMode ? 'Enter 10-digit mobile number' : 'Enter your email address',
            prefixText: _isPhoneMode ? '+91 ' : null,
          ),
        ),
        if (_isPasswordMode) ...[
          const SizedBox(height: 14),
          const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              hintText: 'Enter password',
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19, color: ThaliColors.muted),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(context, messRoute(const ForgotPasswordScreen())),
              child: const Text('Forgot password?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.primary)),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ThaliColors.redSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: ThaliColors.redBorder)),
            child: Text(_error!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ThaliColors.red)),
          ),
        ],
        const SizedBox(height: 18),
        MessActionButton(
          label: 'Continue',
          loading: _loading,
          onPressed: canContinue ? (_isPasswordMode ? _loginWithPassword : _sendOtp) : null,
        ),
        const SizedBox(height: 22),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or continue with', style: TextStyle(fontSize: 12, color: ThaliColors.hint, fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AuthOptionTile(
              icon: Icons.phone_outlined,
              label: _isPhoneMode ? 'Use Email' : 'Phone OTP',
              onTap: () => setState(() {
                _isPhoneMode = !_isPhoneMode;
                _isPasswordMode = false;
                _identifierController.clear();
                _error = null;
              }),
            ),
            const SizedBox(width: 12),
            _AuthOptionTile(
              icon: Icons.lock_outline_rounded,
              label: _isPasswordMode ? 'Email OTP' : 'Password',
              onTap: () => setState(() {
                _isPasswordMode = !_isPasswordMode;
                _isPhoneMode = false;
                _error = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => Navigator.push(context, messRoute(const RegisterScreen())),
          child: const Text('New to Thali? Create account with password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThaliColors.primary)),
        ),
        const SizedBox(height: 16),
        const Text(
          'By continuing you agree to our Terms of Service and Privacy Policy',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: ThaliColors.muted),
        ),
      ],
    );
  }

  Widget _buildOtpView() {
    final codeComplete = _otpValue.length == 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() {
            _isOtpStep = false;
            _verified = false;
            _error = null;
            for (final c in _otpControllers) {
              c.clear();
            }
          }),
          child: Row(
            children: [
              const Icon(Icons.chevron_left_rounded, size: 22, color: ThaliColors.ink),
              const SizedBox(width: 4),
              Text(
                _isPhoneMode ? 'Verify your phone' : 'Verify your email',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ThaliColors.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_verified)
          Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: ThaliColors.green, size: 18),
              SizedBox(width: 6),
              Text('Verified!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.green)),
            ],
          )
        else
          RichText(
            text: TextSpan(
              style: const TextStyle(fontFamily: 'Urbanist', fontSize: 13, color: ThaliColors.body),
              children: [
                const TextSpan(text: 'Enter the 6-digit code sent to '),
                TextSpan(
                  text: _identifierController.text.trim(),
                  style: const TextStyle(color: ThaliColors.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        if (_devOtpHint != null && _devOtpHint!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: ThaliColors.primarySoft, borderRadius: BorderRadius.circular(8), border: Border.all(color: ThaliColors.primary)),
            child: Text('Verification code: $_devOtpHint', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThaliColors.primaryDark)),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: List.generate(6, (i) {
            final bd = _verified
                ? ThaliColors.green
                : (_otpControllers[i].text.isNotEmpty || _otpFocus[i].hasFocus ? ThaliColors.primary : ThaliColors.stroke);
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
                child: TextField(
                  controller: _otpControllers[i],
                  focusNode: _otpFocus[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _verified ? ThaliColors.green : ThaliColors.ink,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: true,
                    fillColor: _verified ? ThaliColors.greenSoft : ThaliColors.card,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: bd, width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThaliColors.primary, width: 1.8)),
                  ),
                  onChanged: (v) {
                    setState(() => _error = null);
                    if (v.isNotEmpty && i < 5) {
                      _otpFocus[i + 1].requestFocus();
                    } else if (v.isEmpty && i > 0) {
                      _otpFocus[i - 1].requestFocus();
                    }
                    if (_otpValue.length == 6 && !_verified) {
                      _verifyOtp();
                    }
                  },
                ),
              ),
            );
          }),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ThaliColors.redSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: ThaliColors.redBorder)),
            child: Text(_error!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ThaliColors.red)),
          ),
        ],
        const SizedBox(height: 20),
        MessActionButton(
          label: 'Verify',
          loading: _loading,
          onPressed: codeComplete && !_verified ? _verifyOtp : null,
        ),
        const SizedBox(height: 14),
        Center(
          child: _resendSeconds > 0
              ? Text(
                  'Resend code in ${_resendSeconds}s',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThaliColors.primary),
                )
              : TextButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: const Text('Resend verification code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThaliColors.primary)),
                ),
        ),
      ],
    );
  }
}

class _AuthOptionTile extends StatelessWidget {
  const _AuthOptionTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: ThaliColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThaliColors.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: ThaliColors.ink),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThaliColors.ink)),
          ],
        ),
      ),
    );
  }
}
