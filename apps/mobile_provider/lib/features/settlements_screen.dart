import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';
import 'payment_settings_screen.dart';

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

  String _modeFilter = 'All';

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
          _summary = Map<String, dynamic>.from((data['summary'] as Map?) ?? _summary);
          _paid = ((data['paid'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _history = ((data['history'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _monthlySummary = ((data['monthly_summary'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isCash(Map<String, dynamic> item) {
    final m = (item['payment_mode']?.toString() ?? '').toLowerCase();
    return m == 'counter_cash' || m == 'cash';
  }

  @override
  Widget build(BuildContext context) {
    final totalCollected = (_summary['total_collected_inr'] as num?)?.toInt() ?? 0;
    final onlineCollected = (_summary['upi_collected_inr'] as num?)?.toInt() ?? 0;
    final cashCollected = (_summary['cash_collected_inr'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 26), onPressed: widget.onBack)
            : null,
        title: const Text('Settlements & Ledger'),
        actions: [
          IconButton(
            tooltip: 'Payout Bank Settings',
            icon: const Icon(Icons.account_balance_outlined),
            onPressed: () => Navigator.push(
              context,
              partnerRoute(PaymentSettingsScreen(session: widget.session)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: ThaliColors.card,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                CardSurface(
                  color: ThaliColors.ink,
                  borderColor: ThaliColors.ink,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL SETTLED & COLLECTED',
                        style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.7),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rupee(totalCollected),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Cashfree Online', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                                const SizedBox(height: 2),
                                Text(rupee(onlineCollected), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 28, color: Colors.white24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Counter Cash', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                                const SizedBox(height: 2),
                                Text(rupee(cashCollected), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TabBar(
                  controller: _tabController,
                  labelColor: ThaliColors.primary,
                  unselectedLabelColor: ThaliColors.muted,
                  indicatorColor: ThaliColors.primary,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Verified'),
                    Tab(text: 'All Ledger'),
                    Tab(text: 'Monthly'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const PartnerSkeletonList(itemCount: 3, cardHeight: 96)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTxList(_paid),
                      _buildAllLedgerTab(),
                      _buildMonthlyTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllLedgerTab() {
    final filtered = _history.where((item) {
      if (_modeFilter == 'Online') return !_isCash(item);
      if (_modeFilter == 'Cash') return _isCash(item);
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: ['All', 'Online', 'Cash'].map((mode) {
              final active = _modeFilter == mode;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(mode),
                  selected: active,
                  selectedColor: ThaliColors.primarySoft,
                  onSelected: (_) => setState(() => _modeFilter = mode),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(child: _buildTxList(filtered)),
      ],
    );
  }

  Widget _buildTxList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return RefreshIndicator(
        color: ThaliColors.primary,
        onRefresh: _loadSettlements,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 60),
            Center(
              child: Text('No transactions recorded yet.', style: TextStyle(color: ThaliColors.muted, fontSize: 13.5)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: ThaliColors.primary,
      onRefresh: _loadSettlements,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final item = items[i];
          final name = item['customer_name']?.toString() ?? 'Subscriber';
          final plan = item['plan_name']?.toString() ?? 'Plan';
          final amt = (item['amount_inr'] as num?)?.toInt() ?? 0;
          final isCash = _isCash(item);
          final txnId = item['transaction_id']?.toString() ?? '';
          final st = item['status']?.toString() ?? 'paid';

          return CardSurface(
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
                          Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                          const SizedBox(height: 2),
                          Text(
                            '$plan · ${isCash ? 'Counter Cash' : 'Cashfree Online'}',
                            style: const TextStyle(fontSize: 12, color: ThaliColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(rupee(amt), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThaliColors.greenDark)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (txnId.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: txnId));
                          showPartnerNotice(context, 'Reference copied.');
                        }
                      },
                      child: Text(
                        txnId,
                        style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: st == 'paid' ? ThaliColors.greenSoft : ThaliColors.amberSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        st == 'paid' ? 'Settled' : st,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: st == 'paid' ? ThaliColors.greenDark : ThaliColors.amberDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthlyTab() {
    if (_monthlySummary.isEmpty) {
      return RefreshIndicator(
        color: ThaliColors.primary,
        onRefresh: _loadSettlements,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 60),
            Center(
              child: Text('Monthly breakdowns appear once transactions complete.', style: TextStyle(color: ThaliColors.muted)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: ThaliColors.primary,
      onRefresh: _loadSettlements,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
      itemCount: _monthlySummary.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = _monthlySummary[i];
        return CardSurface(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: ThaliColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['month']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    Text('${m['count'] ?? 0} subscriptions', style: const TextStyle(fontSize: 12, color: ThaliColors.muted)),
                  ],
                ),
              ),
              Text(rupee((m['amount'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
        );
      },
      ),
    );
  }
}
