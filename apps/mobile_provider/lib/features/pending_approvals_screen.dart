import 'package:flutter/material.dart';
import '../services/provider_api_service.dart';

const Color ink = Color(0xFF182435);
const Color orange = Color(0xFFFF6B1A);
const Color green = Color(0xFF16A34A);
const Color muted = Color(0xFF687382);
const Color card = Color(0xFFFFFFFF);
const Color line = Color(0xFFE9E0D5);
const Color cream = Color(0xFFFBF6EE);

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key, required this.session, this.onBack});
  final ProviderSession session;
  final VoidCallback? onBack;

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await ProviderApiService.fetchPendingSubscriptions(widget.session.providerId);
      if (mounted) {
        setState(() {
          items = list;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceAll('Exception: ', '');
          loading = false;
        });
      }
    }
  }

  Future<void> _approve(String subId, String customerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment Received?'),
        content: Text('Are you sure you have received payment from $customerName?\n\nThis will immediately activate their pass and add meal credits.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: green),
            child: const Text('Yes, Confirm & Activate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ProviderApiService.approveSubscription(
        providerId: widget.session.providerId,
        subscriptionId: subId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pass activated successfully for $customerName!'),
          backgroundColor: green,
        ),
      );
      _loadPending();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    }
  }

  Future<void> _reject(String subId, String customerName) async {
    final reasonController = TextEditingController(text: 'Payment not received at counter.');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Payment Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Decline request for $customerName. Enter a brief reason:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'Reason for declining'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
            child: const Text('Decline Request'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ProviderApiService.rejectSubscription(
        providerId: widget.session.providerId,
        subscriptionId: subId,
        reason: reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment request declined.'), backgroundColor: ink),
      );
      _loadPending();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: const Color(0xFFC0392B)),
      );
    }
  }

  void _showReceiptDialog(String receiptUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Payment Receipt Screenshot',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      receiptUrl.startsWith('http')
                          ? Image.network(
                              receiptUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('Unable to load receipt image.'),
                              ),
                            )
                          : const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('Receipt image reference saved.'),
                            ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(backgroundColor: ink, radius: 14, child: Icon(Icons.close, size: 16, color: Colors.white)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        title: const Text('Pending Payment Approvals', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack) : null,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: orange), onPressed: _loadPending),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: orange))
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: muted),
                        const SizedBox(height: 12),
                        Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _loadPending, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                              child: const Icon(Icons.check_circle_outline, size: 48, color: green),
                            ),
                            const SizedBox(height: 16),
                            const Text('No Pending Payments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
                            const SizedBox(height: 8),
                            const Text(
                              'When customers choose Pay on Counter or Scan & Pay via UPI, their orders will appear here for your confirmation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPending,
                      color: orange,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          final id = item['id']?.toString() ?? '';
                          final name = item['customer_name']?.toString() ?? 'Customer';
                          final phone = item['customer_phone']?.toString() ?? '';
                          final planName = item['plan_name']?.toString() ?? 'Meal Plan';
                          final priceInr = item['price_inr'] ?? ((item['price_paise'] as num?)?.toDouble() ?? 0) / 100;
                          final mode = item['payment_mode']?.toString() ?? 'counter_cash';
                          final receiptUrl = item['receipt_url']?.toString() ?? '';
                          final utr = item['utr_reference']?.toString() ?? '';
                          final isUpgrade = item['upgrade_from_subscription_id'] != null || item['upgrade_details'] != null;

                          String modeLabel = 'Cash at Counter';
                          IconData modeIcon = Icons.payments_outlined;
                          if (mode == 'direct_upi') {
                            modeLabel = 'Direct UPI (Scan & Pay)';
                            modeIcon = Icons.qr_code_scanner;
                          } else if (mode == 'counter_upi') {
                            modeLabel = 'Counter UPI QR';
                            modeIcon = Icons.qr_code;
                          }

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isUpgrade ? const Color(0xFFEDE9FE) : const Color(0xFFFFF0E5),
                                        radius: 20,
                                        child: Icon(isUpgrade ? Icons.upgrade_rounded : modeIcon, color: isUpgrade ? const Color(0xFF7C3AED) : orange, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                                                ),
                                                Text('₹${priceInr.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ink)),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            if (phone.isNotEmpty)
                                              Text(phone, style: const TextStyle(color: muted, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20, color: line),
                                  // Plan & Mode Badges
                                  Row(
                                    children: [
                                      if (isUpgrade) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(6)),
                                          child: const Text('PLAN UPGRADE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                        child: Text(modeLabel, style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w600)),
                                      ),
                                      const Spacer(),
                                      Text(planName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)),
                                    ],
                                  ),
                                  if (utr.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('UTR / Ref: $utr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                                  ],
                                  if (receiptUrl.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    InkWell(
                                      onTap: () => _showReceiptDialog(receiptUrl),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBFDBFE))),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.image_outlined, size: 16, color: Color(0xFF2563EB)),
                                            SizedBox(width: 6),
                                            Text('View Payment Screenshot', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  // Action Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _reject(id, name),
                                          icon: const Icon(Icons.close, size: 16),
                                          label: const Text('Decline'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFC0392B),
                                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 2,
                                        child: FilledButton.icon(
                                          onPressed: () => _approve(id, name),
                                          icon: const Icon(Icons.check, size: 18),
                                          label: const Text('Confirm & Activate'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: green,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
