import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/mess_models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';

class PlanUpgradeSheet extends StatefulWidget {
  const PlanUpgradeSheet({super.key, required this.subscription});
  final ActiveSubscription subscription;

  static Future<void> show(BuildContext context, ActiveSubscription subscription) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PlanUpgradeSheet(subscription: subscription),
    );
  }

  @override
  State<PlanUpgradeSheet> createState() => _PlanUpgradeSheetState();
}

class _PlanUpgradeSheetState extends State<PlanUpgradeSheet> {
  bool _loading = true;
  bool _submitting = false;
  MessProvider? _provider;
  List<MealPlan> _availablePlans = [];
  MealPlan? _selectedPlan;
  Map<String, dynamic>? _quote;
  String? _quoteError;
  String _paymentMode = 'counter_cash'; // 'counter_cash' or 'direct_upi'
  Map<String, dynamic>? _paymentSettings;

  final _utrCtrl = TextEditingController();
  final _receiptCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlansAndSettings();
  }

  @override
  void dispose() {
    _utrCtrl.dispose();
    _receiptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlansAndSettings() async {
    final state = AppStateScope.of(context, listen: false);
    try {
      final p = await state.getProvider(widget.subscription.providerId);
      final settings = await state.fetchPaymentSettings(widget.subscription.providerId);
      if (mounted) {
        setState(() {
          _provider = p;
          _paymentSettings = settings;
          // Filter out current plan if matched, show others
          _availablePlans = (p?.plans ?? []).where((pl) => pl.name != widget.subscription.planName).toList();
          if (_availablePlans.isEmpty && (p?.plans.isNotEmpty == true)) {
            _availablePlans = p!.plans;
          }
          if (_availablePlans.isNotEmpty) {
            _selectedPlan = _availablePlans.first;
          }
          _loading = false;
        });
        if (_selectedPlan != null) {
          _fetchQuote(_selectedPlan!);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchQuote(MealPlan targetPlan) async {
    setState(() {
      _quote = null;
      _quoteError = null;
    });
    final state = AppStateScope.of(context, listen: false);
    try {
      final q = await state.getUpgradeQuote(
        subscriptionId: widget.subscription.id,
        targetPlanId: targetPlan.id,
      );
      if (mounted) setState(() => _quote = q);
    } catch (e) {
      if (mounted) setState(() => _quoteError = e.toString().replaceAll('RepositoryException: ', ''));
    }
  }

  Future<void> _submitUpgrade() async {
    if (_selectedPlan == null) return;
    setState(() => _submitting = true);
    final state = AppStateScope.of(context, listen: false);
    try {
      await state.requestPlanUpgrade(
        subscriptionId: widget.subscription.id,
        targetPlanId: _selectedPlan!.id,
        paymentMode: _paymentMode,
        receiptUrl: _receiptCtrl.text.trim(),
        utrReference: _utrCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: MessColors.green, size: 48),
          title: const Text('Upgrade Request Submitted!'),
          content: Text(
            'Your upgrade request to ${_selectedPlan!.name} has been sent to ${_provider?.name ?? "the mess"}.\n\n'
            'Please pay the difference of ₹${(_quote?['upgrade_payable_inr'] ?? _selectedPlan!.price).toString()} at the mess counter or via UPI. Once confirmed, your new pass will be activated with fresh validity!',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('RepositoryException: ', '')), backgroundColor: const Color(0xFFC0392B)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _loading
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: MessColors.orange)))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.upgrade_rounded, color: Color(0xFF7C3AED), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Upgrade Your Meal Pass', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: MessColors.ink)),
                            Text('Switch to flexi tracker or higher duration', style: TextStyle(color: MessColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Current Pass Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: MessColors.border)),
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card_outlined, color: MessColors.muted, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current Pass: ${widget.subscription.planName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: MessColors.ink)),
                              Text('Valid until: ${widget.subscription.endDate.day}/${widget.subscription.endDate.month}/${widget.subscription.endDate.year}', style: const TextStyle(fontSize: 11.5, color: MessColors.muted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                          child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w800, fontSize: 10)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('Select New Target Plan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: MessColors.ink)),
                  const SizedBox(height: 8),

                  if (_availablePlans.isEmpty)
                    const Text('No other plans available for this kitchen.', style: TextStyle(color: MessColors.muted, fontSize: 13))
                  else
                    ..._availablePlans.map((plan) {
                      final isSelected = _selectedPlan?.id == plan.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedPlan = plan);
                            _fetchQuote(plan);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFAF5FF) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF7C3AED) : MessColors.border,
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSelected ? const Color(0xFF7C3AED) : MessColors.muted,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: MessColors.ink)),
                                      Text('${plan.durationDays} Days · ${plan.type == SubscriptionType.mealTracker ? "${plan.includedMeals} Meals" : "Daily Unlimited"}', style: const TextStyle(fontSize: 11.5, color: MessColors.muted)),
                                    ],
                                  ),
                                ),
                                Text('₹${plan.price}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: MessColors.ink)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 12),

                  // Pro-Rata Price Quote Breakdown
                  if (_quoteError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _quoteError!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_quote != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF4FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF0ABFC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: Color(0xFF9333EA), size: 18),
                              const SizedBox(width: 8),
                              const Text('Pro-Rata OTT Upgrade Calculation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF701A75))),
                            ],
                          ),
                          const Divider(height: 16, color: Color(0xFFF0ABFC)),
                          _quoteRow('New Plan Price', '₹${_quote!['target_plan_price_inr']}'),
                          _quoteRow(
                            'Unused Current Pass Credit',
                            '-₹${_quote!['residual_credit_inr']}',
                            isGreen: true,
                            note: '(${_quote!['days_remaining'] ?? 0} days remaining credited)',
                          ),
                          const Divider(height: 16, color: Color(0xFFF0ABFC)),
                          Row(
                            children: [
                              const Text('Net Upgrade Payable Today', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: MessColors.ink)),
                              const Spacer(),
                              Text('₹${_quote!['upgrade_payable_inr']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF9333EA))),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: MessColors.ink)),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('💵 Pay on Counter')),
                          selected: _paymentMode == 'counter_cash',
                          selectedColor: const Color(0xFFFFD199),
                          onSelected: (v) => setState(() => _paymentMode = 'counter_cash'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('📱 Scan & Pay (UPI)')),
                          selected: _paymentMode == 'direct_upi',
                          selectedColor: const Color(0xFFFFD199),
                          onSelected: (v) => setState(() => _paymentMode = 'direct_upi'),
                        ),
                      ),
                    ],
                  ),

                  // If Direct UPI, show Mess QR & Receipt Upload
                  if (_paymentMode == 'direct_upi') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: MessColors.border),
                      ),
                      child: Column(
                        children: [
                          const Text('Mess Partner Counter UPI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: MessColors.ink)),
                          const SizedBox(height: 8),
                          if (_paymentSettings?['upi_qr_url'] != null && _paymentSettings!['upi_qr_url'].toString().startsWith('http'))
                            Image.network(
                              _paymentSettings!['upi_qr_url'],
                              height: 160,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _renderDynamicQr(),
                            )
                          else
                            _renderDynamicQr(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'UPI ID: ${_paymentSettings?['upi_id'] ?? "thalipay@upi"}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: MessColors.ink),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16, color: MessColors.orange),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _paymentSettings?['upi_id'] ?? 'thalipay@upi'));
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
                              hintText: 'Screenshot Image URL or Receipt Note',
                              prefixIcon: Icon(Icons.link),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _submitUpgrade,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            'Request Upgrade · ₹${(_quote?['upgrade_payable_inr'] ?? _selectedPlan?.price ?? 0).toString()}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _renderDynamicQr() {
    final upi = _paymentSettings?['upi_id'] ?? 'thalipay@upi';
    final name = _paymentSettings?['upi_name'] ?? 'Mess Counter';
    final amount = _quote?['upgrade_payable_inr'] ?? 100;
    final payload = 'upi://pay?pa=$upi&pn=${Uri.encodeComponent(name)}&am=$amount&cu=INR';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: QrImageView(
        data: payload,
        version: QrVersions.auto,
        size: 140,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _quoteRow(String label, String value, {bool isGreen = false, String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12.5, color: MessColors.ink)),
                if (note != null) Text(note, style: const TextStyle(fontSize: 11, color: MessColors.green, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: isGreen ? MessColors.green : MessColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
