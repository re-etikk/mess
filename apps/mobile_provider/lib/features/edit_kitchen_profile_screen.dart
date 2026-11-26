import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

class EditKitchenProfileScreen extends StatefulWidget {
  const EditKitchenProfileScreen({
    super.key,
    required this.session,
    this.onProfileSaved,
  });

  final ProviderSession session;
  final ValueChanged<Map<String, dynamic>>? onProfileSaved;

  @override
  State<EditKitchenProfileScreen> createState() => _EditKitchenProfileScreenState();
}

class _EditKitchenProfileScreenState extends State<EditKitchenProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _localityCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _sendingOtp = false;
  bool _otpSent = false;
  int _resendSec = 0;
  Timer? _timer;

  String _initialPhone = '';
  String _initialEmail = '';
  String? _logoPath;
  String? _coverPath;
  String? _logoBase64;
  String? _coverBase64;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.session.businessName;
    _localityCtrl.text = widget.session.locality;
    _cityCtrl.text = widget.session.city;
    _emailCtrl.text = widget.session.email;
    _initialEmail = widget.session.email.trim().toLowerCase();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _localityCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await ProviderApiService.fetchProviderProfile(widget.session.providerId);
      if (!mounted) return;
      _nameCtrl.text = p['display_name']?.toString() ?? widget.session.businessName;
      _descCtrl.text = p['description']?.toString() ?? '';
      _addressCtrl.text = p['address_line1']?.toString() ?? '';
      _localityCtrl.text = p['locality']?.toString() ?? widget.session.locality;
      _cityCtrl.text = p['city']?.toString() ?? widget.session.city;
      _initialPhone = p['public_phone']?.toString().trim() ?? '';
      _phoneCtrl.text = _initialPhone;
      final pubEmail = p['public_email']?.toString().trim() ?? '';
      _initialEmail = pubEmail.toLowerCase();
      _emailCtrl.text = pubEmail.isNotEmpty ? pubEmail : widget.session.email;
      _logoPath = p['logo_path']?.toString();
      _coverPath = p['cover_path']?.toString();
    } catch (e) {
      if (mounted) {
        showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'load profile'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _contactChanged {
    final phoneNow = _phoneCtrl.text.trim();
    final emailNow = _emailCtrl.text.trim().toLowerCase();
    final origEmail = _initialEmail.isNotEmpty ? _initialEmail : widget.session.email.trim().toLowerCase();
    return phoneNow != _initialPhone || emailNow != origEmail;
  }

  String get _verificationTargetEmail {
    final typedEmail = _emailCtrl.text.trim().toLowerCase();
    if (_initialEmail.contains('@')) return _initialEmail;
    if (widget.session.email.contains('@')) return widget.session.email.trim().toLowerCase();
    return typedEmail;
  }

  Future<void> _pickImage(bool isLogo) async {
    try {
      final xfile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: isLogo ? 700 : 1280,
        imageQuality: 78,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final ext = xfile.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      final dataUri = 'data:image/$ext;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _logoBase64 = dataUri;
          _logoPath = dataUri;
        } else {
          _coverBase64 = dataUri;
          _coverPath = dataUri;
        }
      });
    } catch (e) {
      if (mounted) {
        showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'pick image'), isError: true);
      }
    }
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSec = 25);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSec <= 1) {
        t.cancel();
        setState(() => _resendSec = 0);
      } else {
        setState(() => _resendSec--);
      }
    });
  }

  Future<void> _sendVerificationOtp() async {
    final email = _verificationTargetEmail;
    if (!email.contains('@')) {
      showPartnerNotice(context, 'Enter a valid email address for confirmation.', isError: true);
      return;
    }
    setState(() => _sendingOtp = true);
    try {
      await ProviderApiService.sendOtp(identifier: email, purpose: 'profile_update');
      if (!mounted) return;
      _startResendTimer();
      setState(() => _otpSent = true);
      showPartnerNotice(context, 'Confirmation code sent to $email');
    } catch (e) {
      if (mounted) {
        showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'send confirmation code'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showPartnerNotice(context, 'Kitchen name is required.', isError: true);
      return;
    }
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    if (_contactChanged) {
      if (phone.isNotEmpty && phone.replaceAll(RegExp(r'\D'), '').length < 10) {
        showPartnerNotice(context, 'Enter a valid 10-digit phone number.', isError: true);
        return;
      }
      if (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        showPartnerNotice(context, 'Enter a valid email address.', isError: true);
        return;
      }
      if (_otpCtrl.text.trim().length != 6) {
        if (!_otpSent) {
          await _sendVerificationOtp();
        } else {
          showPartnerNotice(context, 'Enter the 6-digit email verification code.', isError: true);
        }
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final res = await ProviderApiService.updateProviderProfile(
        providerId: widget.session.providerId,
        displayName: name,
        description: _descCtrl.text.trim(),
        addressLine1: _addressCtrl.text.trim(),
        locality: _localityCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        coverImageBase64: _coverBase64,
        logoImageBase64: _logoBase64,
        publicPhone: _contactChanged ? phone : null,
        publicEmail: _contactChanged ? email : null,
        otpCode: _contactChanged ? _otpCtrl.text.trim() : null,
        verificationEmail: _contactChanged ? _verificationTargetEmail : null,
      );
      if (!mounted) return;
      final prov = Map<String, dynamic>.from((res['provider'] as Map?) ?? {});
      widget.onProfileSaved?.call(prov);
      showPartnerNotice(context, 'Kitchen profile updated.');
      Navigator.pop(context, prov);
    } catch (e) {
      if (mounted) {
        showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'save kitchen profile'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _mediaPreview(String? path, {required bool isLogo}) {
    final p = (path ?? '').trim();
    Widget child;
    if (p.startsWith('data:image/')) {
      try {
        child = Image.memory(base64Decode(p.split(',').last), fit: BoxFit.cover);
      } catch (_) {
        child = _placeholder(isLogo);
      }
    } else if (p.startsWith('http')) {
      child = Image.network(p, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder(isLogo));
    } else {
      child = _placeholder(isLogo);
    }
    return child;
  }

  Widget _placeholder(bool isLogo) => Container(
        color: ThaliColors.primarySoft,
        alignment: Alignment.center,
        child: Icon(
          isLogo ? Icons.storefront_rounded : Icons.restaurant_menu_rounded,
          size: isLogo ? 34 : 30,
          color: ThaliColors.primary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final needOtp = _contactChanged;
    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(title: const Text('Edit Kitchen Profile')),
      body: _loading
          ? const PartnerSkeletonList(itemCount: 3, cardHeight: 110)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              children: [
                // Cover Photo + Circular Kitchen DP
                CardSurface(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomCenter,
                        children: [
                          GestureDetector(
                            onTap: () => _pickImage(false),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 132,
                                width: double.infinity,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _mediaPreview(_coverPath, isLogo: false),
                                    Positioned(
                                      right: 10,
                                      top: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.62),
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.photo_camera_outlined, size: 14, color: Colors.white),
                                            SizedBox(width: 5),
                                            Text('Cover', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -26,
                            child: GestureDetector(
                              onTap: () => _pickImage(true),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4))],
                                    ),
                                    child: ClipOval(child: _mediaPreview(_logoPath, isLogo: true)),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: ThaliColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Center(
                        child: Text(
                          'Tap banner or logo to update photos',
                          style: TextStyle(fontSize: 12, color: ThaliColors.muted, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                CardSurface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kitchen Details', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Kitchen Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'About Kitchen'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(labelText: 'Street Address'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _localityCtrl,
                              decoration: const InputDecoration(labelText: 'Locality'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _cityCtrl,
                              decoration: const InputDecoration(labelText: 'City'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                CardSurface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Contact Info', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: ThaliColors.amberSoft,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: ThaliColors.amberBorder),
                            ),
                            child: const Text(
                              'Email OTP on edit',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ThaliColors.amberDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined, size: 19),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Contact Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
                        ),
                      ),
                      if (needOtp) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ThaliColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ThaliColors.primary.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Verify via code sent to $_verificationTargetEmail',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.primaryDark),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _otpCtrl,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: const InputDecoration(
                                        hintText: '6-digit code',
                                        counterText: '',
                                        fillColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton(
                                    onPressed: (_sendingOtp || _resendSec > 0) ? null : _sendVerificationOtp,
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(color: ThaliColors.primary),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: Text(
                                      _sendingOtp
                                          ? 'Sending...'
                                          : (_resendSec > 0 ? '${_resendSec}s' : (_otpSent ? 'Resend' : 'Send Code')),
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                PartnerActionButton(
                  label: needOtp ? 'Verify & Save Profile' : 'Save Changes',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
    );
  }
}
