import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/provider_api_service.dart';

const Color ink = Color(0xFF182435);
const Color orange = Color(0xFFFF6B1A);
const Color muted = Color(0xFF687382);
const Color card = Color(0xFFFFFFFF);
const Color line = Color(0xFFE9E0D5);
const Color cream = Color(0xFFFBF6EE);

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
  final _upiQrUrlCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
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
    _upiQrUrlCtrl.dispose();
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
          _upiQrUrlCtrl.text = (settings['upi_qr_url'] as String?) ?? '';
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

  Future<void> _saveSettings() async {
    final upiId = _upiIdCtrl.text.trim();
    final upiName = _upiNameCtrl.text.trim();
    final upiQrUrl = _upiQrUrlCtrl.text.trim();

    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid UPI ID (e.g. messowner@upi).')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ProviderApiService.savePaymentSettings(
        providerId: widget.session.providerId,
        upiId: upiId,
        upiName: upiName.isNotEmpty ? upiName : widget.session.businessName,
        upiQrUrl: upiQrUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI & Payment QR settings saved successfully!'), backgroundColor: Color(0xFF16A34A)),
      );
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: const Color(0xFFC0392B)),
      );
    }
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
        title: const Text('UPI & Payment QR Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
                  'Configure your UPI ID and payment QR so students and customers can pay directly into your bank account when choosing Direct UPI Scan & Pay.',
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

                // Form Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mess UPI ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _upiIdCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'e.g. 9876543210@paytm or thali.mess@okaxis',
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                        const Text('Custom QR Screenshot URL (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _upiQrUrlCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'https://example.com/my-gpay-qr.jpg',
                            prefixIcon: Icon(Icons.image_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _saving ? null : _saveSettings,
                          icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                          label: Text(_saving ? 'Saving...' : 'Save Payment Settings'),
                          style: FilledButton.styleFrom(
                            backgroundColor: orange,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Live Preview Card
                if (upiId.isNotEmpty)
                  Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'LIVE CUSTOMER PREVIEW',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'This is what customers see when selecting Direct UPI:',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: QrImageView(
                              data: upiPayload,
                              version: QrVersions.auto,
                              size: 180,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(upiName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(8)),
                            child: Text(upiId, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
