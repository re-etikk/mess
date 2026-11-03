import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/mess_models.dart';
import '../../core/repositories/mess_repository.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.provider, this.plan, this.slotId, this.addOns = const []});
  final MessProvider provider;
  final MealPlan? plan;
  final String? slotId;
  final List<CartAddOn> addOns;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _termsAccepted = true;
  bool _busy = false;
  String _paymentMethod = 'Pay on Counter (Cash / Counter UPI)';
  Map<String, dynamic>? _paymentSettings;

  final _utrCtrl = TextEditingController();
  final _receiptCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  @override
  void dispose() {
    _utrCtrl.dispose();
    _receiptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final state = AppStateScope.of(context, listen: false);
      final s = await state.fetchPaymentSettings(widget.provider.id);
      if (mounted) setState(() => _paymentSettings = s);
    } catch (_) {}
  }

  int get _extrasTotal => widget.addOns.fold<int>(0, (sum, entry) => sum + entry.total);
  int get _total => (widget.plan?.price ?? 0) + _extrasTotal;

  Future<void> _payAndConfirm() async {
    final state = AppStateScope.of(context);
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm the plan rules before continuing.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final isDirectUpi = _paymentMethod.contains('Direct UPI');
      final mode = isDirectUpi ? 'direct_upi' : 'counter_cash';

      if (widget.plan != null) {
        if (widget.plan!.type == SubscriptionType.dailyMeal) {
          await state.purchaseDailyMeal(widget.plan!, widget.slotId ?? widget.plan!.slotIds.first);
        } else {
          await state.purchasePlan(
            widget.plan!,
            paymentMode: mode,
            receiptUrl: _receiptCtrl.text.trim(),
            utrReference: _utrCtrl.text.trim(),
          );
        }
      }
      if (widget.addOns.isNotEmpty) {
        state.recordAddOnPayment(providerName: widget.provider.name, addOns: widget.addOns);
      }
      if (!mounted) return;
      setState(() => _busy = false);

      final title = isDirectUpi ? 'Payment Receipt Submitted!' : 'Pass Registered!';
      final content = isDirectUpi
          ? 'Your payment details have been sent to ${widget.provider.name} for verification.\n\nOnce the mess cashier approves your receipt, your meal pass will be active and ready to redeem!'
          : 'Your meal plan has been registered!\n\nPlease pay ₹$_total at the mess counter via Cash or UPI. Once confirmed by counter staff, your meal credits will be ready to scan at ${widget.provider.name}.';

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: MessColors.green, size: 44),
          title: Text(title),
          content: Text(content),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('View Meal Passes'),
            ),
          ],
        ),
      );
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to complete request. Please verify your connection.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final slot = widget.slotId == null ? null : widget.provider.mealSlots.where((s) => s.id == widget.slotId).firstOrNull;
    final isDirectUpi = _paymentMethod.contains('Direct UPI');

    final upiId = _paymentSettings?['upi_id'] ?? 'thalipay@upi';
    final upiName = _paymentSettings?['upi_name'] ?? widget.provider.name;
    final upiPayload = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(upiName)}&am=$_total&cu=INR';

    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Review and confirm')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: MessColors.navy, borderRadius: BorderRadius.circular(17)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.provider.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 21)),
                  const SizedBox(height: 5),
                  Text(plan == null ? 'Optional food extras' : '${plan.name}${slot == null ? '' : ' · ${slot.name}'}', style: const TextStyle(color: Color(0xFFD5DEE5), fontSize: 13)),
                  const SizedBox(height: 15),
                  const Text('Total payable', style: TextStyle(color: Color(0xFFB9C5CE), fontSize: 12)),
                  const SizedBox(height: 3),
                  Text('₹$_total', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Price details', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            CardSurface(
              child: Column(
                children: [
                  if (plan != null) _PriceLine(label: plan.type == SubscriptionType.dailyMeal ? 'Daily meal' : plan.name, amount: plan.price),
                  for (final addOn in widget.addOns) _PriceLine(label: '${addOn.item.name} × ${addOn.quantity}', amount: addOn.total),
                  const Divider(height: 23),
                  _PriceLine(label: 'Total', amount: _total, strong: true),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Payment option', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            CardSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final method in ['Pay on Counter (Cash / Counter UPI)', 'Direct UPI (Scan & Pay at Counter)'])
                    RadioListTile<String>(
                      value: method,
                      groupValue: _paymentMethod,
                      onChanged: (value) => setState(() => _paymentMethod = value!),
                      activeColor: MessColors.orangeDark,
                      title: Text(method, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        method.contains('Cash') ? 'Pay physical cash to mess staff' : 'Scan provider UPI QR and upload receipt',
                        style: const TextStyle(fontSize: 11, color: MessColors.muted),
                      ),
                      secondary: Icon(
                        method.contains('Cash') ? Icons.payments_outlined : Icons.qr_code_scanner_rounded,
                        color: MessColors.navy,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // If Direct UPI selected: show Provider's QR Code & Receipt Upload
            if (isDirectUpi)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MessColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_scanner, color: MessColors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text('Scan & Pay to ${widget.provider.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: MessColors.ink)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_paymentSettings?['upi_qr_url'] != null && _paymentSettings!['upi_qr_url'].toString().startsWith('http'))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _paymentSettings!['upi_qr_url'],
                          height: 180,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _buildQrBox(upiPayload),
                        ),
                      )
                    else
                      _buildQrBox(upiPayload),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('UPI ID: $upiId', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: MessColors.ink)),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16, color: MessColors.orange),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: upiId));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID copied to clipboard!')));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _utrCtrl,
                      decoration: const InputDecoration(
                        hintText: 'UTR / Transaction Reference (12 digits)',
                        prefixIcon: Icon(Icons.receipt_long),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _receiptCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Screenshot Image URL or Receipt Note (Optional)',
                        prefixIcon: Icon(Icons.link),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: MessColors.orangeSoft, borderRadius: BorderRadius.circular(11), border: Border.all(color: MessColors.orange.withOpacity(0.28))),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.storefront_rounded, color: MessColors.orangeDark, size: 19),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Pay on Counter. Simply visit the mess and pay via Cash or UPI. The mess cashier will confirm payment to activate your pass.',
                        style: TextStyle(fontSize: 12, height: 1.4, color: MessColors.navy, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
              activeColor: MessColors.orangeDark,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I have checked the plan rules and expiry.', style: TextStyle(fontSize: 12.5)),
            ),
            const SizedBox(height: 8),
            MessActionButton(
              label: isDirectUpi ? 'Submit Payment Receipt · ₹$_total' : 'Confirm & Pay on Counter · ₹$_total',
              loading: _busy,
              onPressed: _payAndConfirm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrBox(String payload) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MessColors.border),
      ),
      child: QrImageView(
        data: payload,
        version: QrVersions.auto,
        size: 160,
        backgroundColor: Colors.white,
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.amount, this.strong = false});
  final String label;
  final int amount;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 14 : 12.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w500, color: strong ? MessColors.navy : MessColors.muted))),
            Text('₹$amount', style: TextStyle(fontSize: strong ? 17 : 13, fontWeight: strong ? FontWeight.w900 : FontWeight.w700, color: MessColors.navy)),
          ],
        ),
      );
}
