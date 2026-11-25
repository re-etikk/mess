import 'package:flutter/material.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

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

  Future<void> _approve(String subId, String customerName, int amountInr) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThaliColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm Counter Cash Received?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Confirm you received ${rupee(amountInr)} in Cash from $customerName. This immediately activates their meal pass.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ThaliColors.green),
            child: const Text('Confirm & Activate'),
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
      showPartnerNotice(context, 'Activated pass for $customerName.');
      await _loadPending();
    } catch (e) {
      if (mounted) {
        showPartnerNotice(context, e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }
  }

  Future<void> _reject(String subId, String customerName) async {
    final reasonController = TextEditingController(text: 'Cash payment not received at counter.');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThaliColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Decline Cash Request', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter reason for declining $customerName:'),
            const SizedBox(height: 10),
            TextField(controller: reasonController, decoration: const InputDecoration(hintText: 'Reason')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ThaliColors.red),
            child: const Text('Decline'),
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
      showPartnerNotice(context, 'Request declined.');
      await _loadPending();
    } catch (e) {
      if (mounted) {
        showPartnerNotice(context, e.toString().replaceAll('Exception: ', ''), isError: true);
      }
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
        title: const Text('Counter Cash Approvals'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPending,
        color: ThaliColors.primary,
        child: loading
            ? const PartnerSkeletonList(itemCount: 3, cardHeight: 112)
            : error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 24),
                      CardSurface(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: ThaliColors.red)),
                            const SizedBox(height: 12),
                            PartnerActionButton(label: 'Retry', height: 42, onPressed: _loadPending),
                          ],
                        ),
                      ),
                    ],
                  )
                : items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.all(24),
                        children: const [
                          SizedBox(height: 48),
                          CardSurface(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_outlined, size: 46, color: ThaliColors.green),
                                SizedBox(height: 12),
                                Text('All Caught Up', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                                SizedBox(height: 6),
                                Text(
                                  'No pending counter cash subscriptions await approval right now.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: ThaliColors.muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final name = item['customer_name']?.toString() ?? 'Subscriber';
                          final phone = item['customer_phone']?.toString() ?? '';
                          final plan = item['plan_name']?.toString() ?? 'Plan';
                          final priceInr = ((item['price_paid_paise'] as num?)?.toInt() ?? 0) ~/ 100;
                          final subId = item['id']?.toString() ?? '';

                          return CardSurface(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                                          if (phone.isNotEmpty)
                                            Text(phone, style: const TextStyle(fontSize: 12, color: ThaliColors.muted)),
                                        ],
                                      ),
                                    ),
                                    Text(rupee(priceInr), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.primary)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: ThaliColors.amberSoft,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: ThaliColors.amberBorder),
                                  ),
                                  child: Text(
                                    '$plan · Pending Counter Cash Confirmation',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThaliColors.amberDark),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: PartnerActionButton(
                                        label: 'Decline',
                                        secondary: true,
                                        color: ThaliColors.red,
                                        height: 42,
                                        onPressed: () => _reject(subId, name),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: PartnerActionButton(
                                        label: 'Approve & Activate',
                                        color: ThaliColors.green,
                                        height: 42,
                                        onPressed: () => _approve(subId, name, priceInr),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
