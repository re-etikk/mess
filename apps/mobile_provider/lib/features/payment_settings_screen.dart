import 'package:flutter/material.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

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
  final _accHolderCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  final _accConfirmCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _lookingUpIfsc = false;
  String? _ifscStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _upiIdCtrl.dispose();
    _upiNameCtrl.dispose();
    _accHolderCtrl.dispose();
    _accNumCtrl.dispose();
    _accConfirmCtrl.dispose();
    _ifscCtrl.dispose();
    _bankCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await ProviderApiService.fetchPaymentSettings(widget.session.providerId);
      if (!mounted) return;
      _upiIdCtrl.text = (settings['upi_id']?.toString() ?? '');
      _upiNameCtrl.text = (settings['upi_name']?.toString() ?? widget.session.businessName);
      _accHolderCtrl.text = (settings['account_holder_name']?.toString() ?? '');
      _accNumCtrl.text = (settings['account_number']?.toString() ?? '');
      _accConfirmCtrl.text = (settings['account_number']?.toString() ?? '');
      _ifscCtrl.text = (settings['ifsc_code']?.toString() ?? '');
      _bankCtrl.text = (settings['bank_name']?.toString() ?? '');
      _branchCtrl.text = (settings['branch_name']?.toString() ?? '');
      if (_bankCtrl.text.isNotEmpty) {
        _ifscStatus = '${_bankCtrl.text} (${_branchCtrl.text})';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _lookupIfsc() async {
    final code = _ifscCtrl.text.trim().toUpperCase();
    if (code.length < 6) return;
    setState(() => _lookingUpIfsc = true);
    try {
      final res = await ProviderApiService.lookupIfsc(code);
      if (!mounted) return;
      if (res['bank'] != null) {
        _bankCtrl.text = res['bank'].toString();
        _branchCtrl.text = res['branch']?.toString() ?? '';
        setState(() => _ifscStatus = '${_bankCtrl.text} (${_branchCtrl.text})');
      } else {
        showPartnerNotice(context, 'Bank details not found for IFSC $code.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _lookingUpIfsc = false);
    }
  }

  Future<void> _save() async {
    final acc = _accNumCtrl.text.trim();
    final conf = _accConfirmCtrl.text.trim();
    if (acc.isNotEmpty && acc != conf) {
      showPartnerNotice(context, 'Bank account numbers do not match.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ProviderApiService.savePaymentSettings(
        providerId: widget.session.providerId,
        upiId: _upiIdCtrl.text.trim(),
        upiName: _upiNameCtrl.text.trim().isNotEmpty ? _upiNameCtrl.text.trim() : widget.session.businessName,
        accountNumber: acc,
        ifscCode: _ifscCtrl.text.trim().toUpperCase(),
        bankName: _bankCtrl.text.trim(),
        branchName: _branchCtrl.text.trim(),
        accountHolderName: _accHolderCtrl.text.trim(),
      );
      if (!mounted) return;
      showPartnerNotice(context, 'Payout bank settings saved.');
    } catch (e) {
      if (mounted) showPartnerNotice(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 26), onPressed: widget.onBack)
            : null,
        title: const Text('Payout & Settlement Bank'),
      ),
      body: _loading
          ? const PartnerSkeletonList(itemCount: 3, cardHeight: 100)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                CardSurface(
                  color: ThaliColors.primarySoft,
                  borderColor: ThaliColors.stroke,
                  padding: const EdgeInsets.all(14),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: ThaliColors.primaryDark, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Online payments via Cashfree are settled to your registered bank account. Cash counter payments remain with your kitchen.',
                          style: TextStyle(fontSize: 12.5, color: ThaliColors.primaryDark, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CardSurface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bank Settlement Account', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                      const SizedBox(height: 12),
                      TextField(controller: _accHolderCtrl, decoration: const InputDecoration(labelText: 'Account Holder Name')),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _accNumCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Account Number'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _accConfirmCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Confirm Account Number'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ifscCtrl,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(labelText: 'IFSC Code'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _lookingUpIfsc ? null : _lookupIfsc,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: ThaliColors.primary),
                                foregroundColor: ThaliColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(_lookingUpIfsc ? 'Checking...' : 'Verify IFSC'),
                            ),
                          ),
                        ],
                      ),
                      if (_ifscStatus != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _ifscStatus!,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.greenDark),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(controller: _bankCtrl, decoration: const InputDecoration(labelText: 'Bank Name')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                CardSurface(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Settlement VPA / Beneficiary Label', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      TextField(controller: _upiIdCtrl, decoration: const InputDecoration(labelText: 'Payout UPI VPA (optional)')),
                      const SizedBox(height: 12),
                      TextField(controller: _upiNameCtrl, decoration: const InputDecoration(labelText: 'Beneficiary Display Name')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PartnerActionButton(label: 'Save Payout Settings', loading: _saving, onPressed: _save),
              ],
            ),
    );
  }
}
