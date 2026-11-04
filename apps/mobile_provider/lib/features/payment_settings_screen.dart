import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/provider_api_service.dart';

const Color ink = Color(0xFF182435);
const Color orange = Color(0xFFFF6B1A);
const Color muted = Color(0xFF687382);
const Color card = Color(0xFFFFFFFF);
const Color line = Color(0xFFE9E0D5);
const Color cream = Color(0xFFFBF6EE);
const Color green = Color(0xFF16A34A);

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key, required this.session, this.onBack});
  final ProviderSession session;
  final VoidCallback? onBack;

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _upiIdCtrl = TextEditingController();
  final _upiNameCtrl = TextEditingController();
  String _upiQrImage = '';

  // Bank Account Fields
  final _accHolderCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  final _accNumConfirmCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _branchNameCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _lookingUpUpi = false;
  bool _lookingUpIfsc = false;
  String? _ifscVerifiedBank;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _upiIdCtrl.dispose();
    _upiNameCtrl.dispose();
    _accHolderCtrl.dispose();
    _accNumCtrl.dispose();
    _accNumConfirmCtrl.dispose();
    _ifscCtrl.dispose();
    _bankNameCtrl.dispose();
    _branchNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await ProviderApiService.fetchPaymentSettings(widget.session.providerId);
      if (mounted) {
        setState(() {
          _upiIdCtrl.text = (settings['upi_id'] as String?) ?? '';
          _upiNameCtrl.text = (settings['upi_name'] as String?) ?? widget.session.businessName;
          _upiQrImage = (settings['upi_qr_url'] as String?) ?? '';
          _accHolderCtrl.text = (settings['account_holder_name'] as String?) ?? '';
          _accNumCtrl.text = (settings['account_number'] as String?) ?? '';
          _accNumConfirmCtrl.text = (settings['account_number'] as String?) ?? '';
          _ifscCtrl.text = (settings['ifsc_code'] as String?) ?? '';
          _bankNameCtrl.text = (settings['bank_name'] as String?) ?? '';
          _branchNameCtrl.text = (settings['branch_name'] as String?) ?? '';
          if (_bankNameCtrl.text.isNotEmpty) {
            _ifscVerifiedBank = '${_bankNameCtrl.text} (${_branchNameCtrl.text})';
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickQrImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Uri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _upiQrImage = base64Uri;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment QR image selected successfully! Click Save to apply.'),
              backgroundColor: green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick QR image: $e'),
            backgroundColor: const Color(0xFFC0392B),
          ),
        );
      }
    }
  }

  Future<void> _handleUpiLookup(String upiId) async {
    final clean = upiId.trim();
    if (!clean.contains('@') || clean.length < 5) return;
    setState(() => _lookingUpUpi = true);
    try {
      final res = await ProviderApiService.lookupUpi(clean);
      if (res['success'] == true && res['detected_name'] != null) {
        final detected = res['detected_name'].toString();
        if (_upiNameCtrl.text.trim().isEmpty || _upiNameCtrl.text == widget.session.businessName) {
          _upiNameCtrl.text = detected;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('UPI Name Detected: $detected'),
              backgroundColor: green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _lookingUpUpi = false);
  }

  Future<void> _handleIfscLookup(String ifsc) async {
    final code = ifsc.trim().toUpperCase();
    if (code.length != 11) return;
    setState(() => _lookingUpIfsc = true);
    try {
      final res = await ProviderApiService.lookupIfsc(code);
      if (res['success'] == true) {
        final bank = (res['bank_name'] as String?) ?? '';
        final branch = (res['branch'] as String?) ?? '';
        setState(() {
          _bankNameCtrl.text = bank;
          _branchNameCtrl.text = branch;
          _ifscVerifiedBank = '$bank${branch.isNotEmpty ? ' - $branch' : ''}';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bank Identified: $bank ($branch)'),
              backgroundColor: green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() => _ifscVerifiedBank = null);
      }
    } catch (_) {
      setState(() => _ifscVerifiedBank = null);
    }
    if (mounted) setState(() => _lookingUpIfsc = false);
  }

  Future<void> _saveSettings() async {
    final upiId = _upiIdCtrl.text.trim();
    final upiName = _upiNameCtrl.text.trim();
    final accNum = _accNumCtrl.text.trim();
    final accConfirm = _accNumConfirmCtrl.text.trim();

    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Mess UPI ID (e.g. ritikmess@okhdfcbank).')),
      );
      return;
    }

    if (accNum.isNotEmpty && accNum != accConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank account numbers do not match. Please verify.'),
          backgroundColor: Color(0xFFC0392B),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ProviderApiService.savePaymentSettings(
        providerId: widget.session.providerId,
        upiId: upiId,
        upiName: upiName.isNotEmpty ? upiName : widget.session.businessName,
        upiQrUrl: _upiQrImage,
        accountNumber: accNum,
        ifscCode: _ifscCtrl.text.trim().toUpperCase(),
        bankName: _bankNameCtrl.text.trim(),
        branchName: _branchNameCtrl.text.trim(),
        accountHolderName: _accHolderCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UPI & Payment receiving settings saved successfully!'),
          backgroundColor: green,
        ),
      );
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    }
  }

  Widget _buildQrPreviewWidget(String upiPayload) {
    if (_upiQrImage.isNotEmpty) {
      try {
        if (_upiQrImage.startsWith('data:image')) {
          final base64Part = _upiQrImage.split(',').last;
          final bytes = base64Decode(base64Part);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: 190,
              height: 190,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackQr(upiPayload),
            ),
          );
        } else if (_upiQrImage.startsWith('http')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _upiQrImage,
              width: 190,
              height: 190,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackQr(upiPayload),
            ),
          );
        }
      } catch (_) {
        return _buildFallbackQr(upiPayload);
      }
    }
    return _buildFallbackQr(upiPayload);
  }

  Widget _buildFallbackQr(String upiPayload) {
    if (upiPayload.isEmpty) {
      return Container(
        width: 180,
        height: 180,
        alignment: Alignment.center,
        child: const Text('Enter UPI ID to preview QR', style: TextStyle(color: muted, fontSize: 12)),
      );
    }
    return QrImageView(
      data: upiPayload,
      version: QrVersions.auto,
      size: 180,
      backgroundColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final upiId = _upiIdCtrl.text.trim();
    final upiName = _upiNameCtrl.text.trim().isNotEmpty ? _upiNameCtrl.text.trim() : widget.session.businessName;
    final upiPayload = upiId.isNotEmpty ? 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(upiName)}&cu=INR' : '';

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        title: const Text('Payment & Bank Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack) : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: orange))
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  'Counter Payment Reception',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Setup your UPI ID, custom Payment QR photo, and Bank details so customers can pay directly on counter or through scan & pay.',
                  style: TextStyle(color: muted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                  ),
                  const SizedBox(height: 14),
                ],

                // SECTION 1: UPI ID & QR Photo
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code_2, color: orange, size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Mess UPI & QR Code',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // UPI ID
                        const Text('Mess UPI ID *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _upiIdCtrl,
                          onChanged: (val) {
                            setState(() {});
                            if (val.contains('@')) {
                              _handleUpiLookup(val);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'e.g. 9876543210@paytm or mess@okhdfcbank',
                            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                            suffixIcon: _lookingUpUpi
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: orange)),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.check_circle_outline, color: green),
                                    tooltip: 'Detect Name',
                                    onPressed: () => _handleUpiLookup(_upiIdCtrl.text),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Payee Name
                        const Text('Payee Display Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _upiNameCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'e.g. Ritik Mess or Ritik Kumar',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // DIRECT QR IMAGE UPLOAD (OPTIONAL)
                        const Row(
                          children: [
                            Text('Custom QR Standee Image', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
                            SizedBox(width: 6),
                            Text('(Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: orange)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Optional. Thali automatically creates a dynamic QR code directly from your UPI ID for student checkout. Upload only if you prefer displaying your physical standee photo.',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickQrImage,
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: Text(_upiQrImage.isEmpty ? 'Upload QR Photo' : 'Change QR Photo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEFF6FF),
                                foregroundColor: const Color(0xFF1D4ED8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            if (_upiQrImage.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              TextButton.icon(
                                onPressed: () => setState(() => _upiQrImage = ''),
                                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                label: const Text('Remove', style: TextStyle(color: Color(0xFFDC2626))),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // SECTION 2: Bank Account Details
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance, color: orange, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Bank Account Details',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'For settlement and direct IMPS/NEFT bank transfers.',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),

                        // Account Holder Name
                        const Text('Account Holder Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _accHolderCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Ritik Kumar',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Account Number
                        const Text('Bank Account Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _accNumCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Enter account number',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Confirm Account Number
                        const Text('Re-enter Bank Account Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _accNumConfirmCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Re-enter to confirm',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // IFSC Code
                        const Text('IFSC Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _ifscCtrl,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (val) {
                            if (val.trim().length == 11) {
                              _handleIfscLookup(val);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'e.g. SBIN0001234 or HDFC0000001',
                            prefixIcon: const Icon(Icons.numbers_outlined),
                            suffixIcon: _lookingUpIfsc
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: orange)),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.search, color: orange),
                                    tooltip: 'Lookup IFSC',
                                    onPressed: () => _handleIfscLookup(_ifscCtrl.text),
                                  ),
                          ),
                        ),

                        // Verified Bank Name Banner
                        if (_ifscVerifiedBank != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified, color: green, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _ifscVerifiedBank!,
                                    style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Save Button
                FilledButton.icon(
                  onPressed: _saving ? null : _saveSettings,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving...' : 'Save All Settings'),
                  style: FilledButton.styleFrom(
                    backgroundColor: orange,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 24),

                // LIVE PREVIEW CARD
                if (upiId.isNotEmpty || _upiQrImage.isNotEmpty)
                  Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'LIVE CUSTOMER SCAN PREVIEW',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _upiQrImage.isNotEmpty
                                ? 'Customers will see your uploaded QR photo below:'
                                : 'Customers will scan this generated QR code:',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: _buildQrPreviewWidget(upiPayload),
                          ),
                          const SizedBox(height: 14),
                          Text(upiName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                          if (upiId.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(8)),
                              child: Text(upiId, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
