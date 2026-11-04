import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/provider_api_service.dart';
import '../features/payment_settings_screen.dart';

class SettlementsPayoutScreen extends StatefulWidget {
  const SettlementsPayoutScreen({super.key, required this.session, this.onBack});
  final ProviderSession session;
  final VoidCallback? onBack;

  @override
  State<SettlementsPayoutScreen> createState() => _SettlementsPayoutScreenState();
}

class _SettlementsPayoutScreenState extends State<SettlementsPayoutScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;

  Map<String, dynamic> _summary = {
    'total_collected_inr': 0,
    'upi_collected_inr': 0,
    'cash_collected_inr': 0,
    'active_subscribers': 0,
    'total_transactions': 0,
  };
  List<Map<String, dynamic>> _paid = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _monthlySummary = [];

  String _historyFilter = 'All';
  String _searchQuery = '';

  static const Color orange = Color(0xFFE8590C);
  static const Color ink = Color(0xFF1E252B);
  static const Color muted = Color(0xFF6B7280);
  static const Color cream = Color(0xFFFBF8F3);
  static const Color line = Color(0xFFEADCCB);
  static const Color green = Color(0xFF2E7D32);
  static const Color amber = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettlements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettlements() async {
    setState(() => _loading = true);
    try {
      final data = await ProviderApiService.fetchSettlements(widget.session.providerId);
      if (mounted) {
        setState(() {
          _summary = data['summary'] as Map<String, dynamic>? ?? _summary;
          _paid = (data['paid'] as List<dynamic>? ?? []).map((e) => e as Map<String, dynamic>).toList();
          _history = (data['history'] as List<dynamic>? ?? []).map((e) => e as Map<String, dynamic>).toList();
          _monthlySummary = (data['monthly_summary'] as List<dynamic>? ?? []).map((e) => e as Map<String, dynamic>).toList();
        });
      }
    } catch (_) {
      // Local fallback handles graceful offline viewing
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showReceiptDialog(String receiptUrl, String customerName, String utr) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Payment Receipt · $customerName',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              if (utr.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: cream, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Text('UTR / Ref: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: muted)),
                      Text(utr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ink)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: orange),
                        onPressed: () => _copyText(utr, 'UTR reference'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildReceiptImage(receiptUrl),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(backgroundColor: ink),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64Part = url.split(',').last;
        final bytes = base64Decode(base64Part);
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 350),
          child: Image.memory(bytes, fit: BoxFit.contain),
        );
      } catch (_) {}
    } else if (url.startsWith('http')) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 350),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Could not load screenshot preview', style: TextStyle(color: muted)),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text('No receipt screenshot attached', style: TextStyle(color: muted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        title: const Text('Settlements & Payouts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack) : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadSettlements,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Payment Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => PaymentSettingsScreen(
                    session: widget.session,
                    onBack: () => Navigator.pop(ctx),
                  ),
                ),
              ).then((_) => _loadSettlements());
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: orange,
          unselectedLabelColor: muted,
          indicatorColor: orange,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 16),
                  const SizedBox(width: 6),
                  Text('Paid (${_paid.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 16),
                  const SizedBox(width: 6),
                  Text('History (${_history.length})'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assessment_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('Statement'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: orange))
          : RefreshIndicator(
              onRefresh: _loadSettlements,
              color: orange,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPaidTab(),
                  _buildHistoryTab(),
                  _buildStatementTab(),
                ],
              ),
            ),
    );
  }

  // TAB 1: PAID / RECEIVED PAYMENTS
  Widget _buildPaidTab() {
    if (_paid.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: orange.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.payments_outlined, color: orange, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('No Received Payments Yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: ink)),
              const SizedBox(height: 6),
              const Text(
                'When students scan your counter QR or pay at the counter and you approve their pass, the completed payment with Transaction ID will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final totalCollected = _summary['total_collected_inr'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total summary banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Received Collections', style: TextStyle(color: Color(0xFFD5DEE5), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('₹$totalCollected', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, color: Colors.greenAccent, size: 14),
                    const SizedBox(width: 4),
                    Text('${_paid.length} Passes Active', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Verified Student Payments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final item in _paid) _buildPaidCard(item),
      ],
    );
  }

  Widget _buildPaidCard(Map<String, dynamic> item) {
    final name = item['customer_name']?.toString() ?? 'Student';
    final plan = item['plan_name']?.toString() ?? 'Meal Pass';
    final amount = item['amount_inr'] ?? (item['price_inr'] ?? 0);
    final mode = item['payment_mode']?.toString() ?? 'counter_upi';
    final isUpi = mode.toLowerCase().contains('upi');
    final txnId = item['transaction_id']?.toString() ?? item['utr_reference']?.toString() ?? 'TXN-${item['id'].toString().substring(0, 8).toUpperCase()}';
    final utr = item['utr_reference']?.toString() ?? '';
    final receiptUrl = item['receipt_url']?.toString() ?? '';
    final dateStr = item['paid_at']?.toString() ?? item['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isUpi ? const Color(0xFF0F766E).withOpacity(0.12) : const Color(0xFFD97706).withOpacity(0.12),
                  child: Icon(isUpi ? Icons.qr_code_2 : Icons.payments_outlined, color: isUpi ? const Color(0xFF0F766E) : const Color(0xFFD97706), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ink)),
                      Text(plan, style: const TextStyle(color: muted, fontSize: 11)),
                    ],
                  ),
                ),
                Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: green)),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Transaction ID & UTR Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: cream, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('ID: ', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
                      Text(txnId, style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 15, color: orange),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Copy ID',
                  onPressed: () => _copyText(txnId, 'Transaction ID'),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isUpi ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isUpi ? 'UPI QR' : 'Cash',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isUpi ? const Color(0xFF0369A1) : const Color(0xFFB45309),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFDDF2E6), borderRadius: BorderRadius.circular(6)),
                  child: const Text('PAID & ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: green)),
                ),
              ],
            ),

            if (receiptUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showReceiptDialog(receiptUrl, name, utr),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, size: 14, color: Color(0xFF2563EB)),
                      SizedBox(width: 6),
                      Text('View Uploaded Payment Screenshot', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],

            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Paid on: ${dateStr.contains('T') ? dateStr.split('T')[0] : dateStr}',
                style: const TextStyle(color: muted, fontSize: 10.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // TAB 2: HISTORY
  Widget _buildHistoryTab() {
    final filtered = _history.where((item) {
      if (_historyFilter == 'Pending' && item['status'] != 'pending_payment') return false;
      if (_historyFilter == 'Paid' && item['status'] != 'paid' && item['status'] != 'active') return false;
      if (_historyFilter == 'Rejected' && item['status'] != 'rejected' && item['status'] != 'cancelled') return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (item['customer_name'] ?? '').toString().toLowerCase();
        final utr = (item['utr_reference'] ?? '').toString().toLowerCase();
        final txn = (item['transaction_id'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !utr.contains(q) && !txn.contains(q)) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Chips & Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by Student Name or UTR Number...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in ['All', 'Pending', 'Paid', 'Rejected'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: _historyFilter == f,
                          selectedColor: orange,
                          labelStyle: TextStyle(
                            color: _historyFilter == f ? Colors.white : ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setState(() => _historyFilter = f),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No matching transactions found.', style: TextStyle(color: muted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _buildHistoryCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final name = item['customer_name']?.toString() ?? 'Student';
    final plan = item['plan_name']?.toString() ?? 'Meal Pass';
    final amount = item['amount_inr'] ?? (item['price_inr'] ?? 0);
    final status = item['status']?.toString() ?? 'pending';
    final isPaid = status == 'paid' || status == 'active';
    final isPending = status == 'pending_payment';
    final utr = item['utr_reference']?.toString() ?? '';
    final receiptUrl = item['receipt_url']?.toString() ?? '';
    final dateStr = item['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ink)),
                      Text(plan, style: const TextStyle(color: muted, fontSize: 11)),
                    ],
                  ),
                ),
                Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ink)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFDDF2E6) : (isPending ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? 'PAID' : (isPending ? 'PENDING' : 'REJECTED'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isPaid ? green : (isPending ? amber : const Color(0xFFDC2626)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // UTR reference matching section
            if (utr.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: cream, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 14, color: muted),
                    const SizedBox(width: 6),
                    const Text('UTR Ref: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
                    Text(utr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: ink)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 15, color: orange),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copy UTR',
                      onPressed: () => _copyText(utr, 'UTR reference'),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                if (receiptUrl.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showReceiptDialog(receiptUrl, name, utr),
                    icon: const Icon(Icons.image_outlined, size: 15, color: Color(0xFF2563EB)),
                    label: const Text('View Receipt', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                const Spacer(),
                if (dateStr.isNotEmpty)
                  Text(dateStr.contains('T') ? dateStr.split('T')[0] : dateStr, style: const TextStyle(fontSize: 11, color: muted)),
              ],
            ),

            if (isPending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          await ProviderApiService.rejectSubscription(
                            subscriptionId: id,
                            providerId: widget.session.providerId,
                            reason: 'Payment details could not be matched.',
                          );
                          _loadSettlements();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        try {
                          await ProviderApiService.approveSubscription(
                            subscriptionId: id,
                            providerId: widget.session.providerId,
                          );
                          _loadSettlements();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Confirm Payment'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // TAB 3: STATEMENT
  Widget _buildStatementTab() {
    final total = _summary['total_collected_inr'] ?? 0;
    final upi = _summary['upi_collected_inr'] ?? 0;
    final cash = _summary['cash_collected_inr'] ?? 0;
    final subs = _summary['active_subscribers'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Cards Grid
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Total Revenue',
                value: '₹$total',
                note: 'Total collected',
                color: const Color(0xFFDDF2E6),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Paying Students',
                value: '$subs',
                note: 'Active subscriptions',
                color: const Color(0xFFFFE8C5),
                icon: Icons.people_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Via UPI QR',
                value: '₹$upi',
                note: 'Direct UPI receipts',
                color: const Color(0xFFE0F2FE),
                icon: Icons.qr_code_2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Via Counter Cash',
                value: '₹$cash',
                note: 'Physical cash received',
                color: const Color(0xFFFEF3C7),
                icon: Icons.payments_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Monthly Breakdown
        Text('Monthly Statements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (_monthlySummary.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: line)),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No monthly statement records yet.', style: TextStyle(color: muted))),
            ),
          )
        else
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)),
            child: Column(
              children: [
                for (int i = 0; i < _monthlySummary.length; i++) ...[
                  ListTile(
                    title: Text(_monthlySummary[i]['month']?.toString() ?? 'Month', style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
                    subtitle: Text('${_monthlySummary[i]['count']} paid student subscriptions', style: const TextStyle(color: muted, fontSize: 12)),
                    trailing: Text('₹${_monthlySummary[i]['amount']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: green)),
                  ),
                  if (i < _monthlySummary.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Download / Export statement
        FilledButton.icon(
          onPressed: () {
            final summaryText = 'THALI SETTLEMENT SUMMARY\nProvider: ${widget.session.businessName}\nTotal Collections: ₹$total\nUPI QR: ₹$upi\nCash: ₹$cash\nActive Subscribers: $subs\nGenerated on: ${DateTime.now().toLocal()}';
            _copyText(summaryText, 'Settlement statement summary');
          },
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Export Statement Summary', style: TextStyle(fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({required String title, required String value, required String note, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ink)),
              Icon(icon, size: 18, color: ink),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(fontSize: 10.5, color: muted)),
        ],
      ),
    );
  }
}
