import 'package:flutter/material.dart';

import '../../core/models/mess_models.dart';
import '../../core/repositories/mess_repository.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';

class PlanUpgradeSheet extends StatefulWidget {
  const PlanUpgradeSheet({super.key, required this.subscription});
  final ActiveSubscription subscription;

  static Future<void> show(BuildContext context, ActiveSubscription subscription) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
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
  List<MealPlan> _availablePlans = const [];
  MealPlan? _selectedPlan;
  Map<String, dynamic>? _quote;
  String? _quoteError;
  String _paymentMode = 'cashfree_online'; // Option B only

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final state = AppStateScope.of(context, listen: false);
    try {
      final p = await state.getProvider(widget.subscription.providerId);
      if (!mounted) return;
      final candidates = (p?.plans ?? []).where((pl) => pl.name != widget.subscription.planName).toList();
      final plans = candidates.isNotEmpty ? candidates : (p?.plans ?? const <MealPlan>[]);
      setState(() {
        _provider = p;
        _availablePlans = plans;
        _selectedPlan = plans.isNotEmpty ? plans.first : null;
        _loading = false;
      });
      if (_selectedPlan != null) {
        await _fetchQuote(_selectedPlan!);
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
      final q = await state.repository.getUpgradeQuote(
        subscriptionId: widget.subscription.id,
        targetPlanId: targetPlan.id,
        currentSub: widget.subscription,
        targetPlan: targetPlan,
      );
      if (mounted) setState(() => _quote = q);
    } catch (e) {
      if (mounted) {
        setState(() => _quoteError = friendlyCustomerError(e, action: 'load upgrade quote'));
      }
    }
  }

  Future<void> _submitUpgrade() async {
    if (_selectedPlan == null) return;
    setState(() => _submitting = true);
    final state = AppStateScope.of(context, listen: false);

    try {
      if (_paymentMode == 'cashfree_online') {
        final targetProvider = _provider ??
            MessProvider(
              id: widget.subscription.providerId,
              name: widget.subscription.providerName,
              area: '',
              distanceMeters: 0,
              description: '',
              isOpen: true,
              mealSlots: const [],
              plans: _availablePlans,
            );
        await state.payWithCashfree(
          purpose: 'plan_upgrade',
          provider: targetProvider,
          plan: _selectedPlan,
          currentSub: widget.subscription,
        );
        if (!mounted) return;
        Navigator.pop(context);
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ThaliColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(Icons.verified_rounded, color: ThaliColors.green, size: 46),
            title: const Text('Plan Upgraded', style: TextStyle(fontWeight: FontWeight.w800)),
            content: Text(
              'Payment via Cashfree succeeded. Your pass is now upgraded to ${_selectedPlan!.name} at ${targetProvider.name}.',
              textAlign: TextAlign.center,
            ),
            actions: [
              MessActionButton(label: 'Done', height: 44, onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        );
        return;
      }

      await state.repository.requestPlanUpgrade(
        subscriptionId: widget.subscription.id,
        targetPlanId: _selectedPlan!.id,
        paymentMode: 'counter_cash',
        currentSub: widget.subscription,
        targetPlan: _selectedPlan,
      );
      await state.refreshSubscriptionsFromServer();
      if (!mounted) return;
      Navigator.pop(context);
      final payable = _quote?['upgrade_payable_inr'] ?? _selectedPlan!.price;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThaliColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.check_circle_rounded, color: ThaliColors.green, size: 46),
          title: const Text('Upgrade Requested', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
            'Upgrade request to ${_selectedPlan!.name} sent. Please pay ₹$payable cash at ${_provider?.name ?? widget.subscription.providerName} counter for activation.',
            textAlign: TextAlign.center,
          ),
          actions: [
            MessActionButton(label: 'Got it', height: 44, onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyCustomerError(e, action: 'upgrade plan'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final payableInr = (_quote?['upgrade_payable_inr'] as num?)?.toInt() ?? _selectedPlan?.price ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _loading
          ? const SizedBox(
              height: 220,
              child: ThaliLoadingView(label: 'Calculating upgrade quote...'),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: ThaliColors.stroke, borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Upgrade Your Plan',
                    style: TextStyle(fontSize: 18.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current plan: ${widget.subscription.planName}',
                    style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                  ),
                  const SizedBox(height: 16),
                  if (_availablePlans.isEmpty)
                    const CardSurface(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No alternate plans are configured for this kitchen yet.',
                        style: TextStyle(color: ThaliColors.muted, fontSize: 13),
                      ),
                    )
                  else ...[
                    ..._availablePlans.map((plan) {
                      final active = _selectedPlan?.id == plan.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CardSurface(
                          onTap: () {
                            setState(() => _selectedPlan = plan);
                            _fetchQuote(plan);
                          },
                          color: active ? ThaliColors.primarySoft : ThaliColors.card,
                          borderColor: active ? ThaliColors.primary : ThaliColors.stroke,
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            children: [
                              Icon(
                                active ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: active ? ThaliColors.primary : ThaliColors.muted,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    Text(plan.durationLabel, style: const TextStyle(fontSize: 12, color: ThaliColors.muted)),
                                  ],
                                ),
                              ),
                              Text(
                                rupee(plan.price),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ThaliColors.ink),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (_quoteError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(_quoteError!, style: const TextStyle(fontSize: 12.5, color: ThaliColors.red)),
                      )
                    else if (_quote != null) ...[
                      CardSurface(
                        color: ThaliColors.scaffold,
                        padding: const EdgeInsets.all(13),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Prorated Upgrade Difference', style: TextStyle(fontSize: 13, color: ThaliColors.body)),
                            Text(
                              rupee(payableInr),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThaliColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Text(
                      'Payment Method',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                    ),
                    const SizedBox(height: 8),
                    _payOption(
                      value: 'cashfree_online',
                      title: 'Cashfree Online (UPI / Cards)',
                      subtitle: 'Instant plan upgrade verification',
                      icon: Icons.bolt_rounded,
                    ),
                    const SizedBox(height: 8),
                    _payOption(
                      value: 'counter_cash',
                      title: 'Pay Cash at Counter',
                      subtitle: 'Kitchen approves upgrade once paid at counter',
                      icon: Icons.payments_outlined,
                    ),
                    const SizedBox(height: 18),
                    MessActionButton(
                      label: _paymentMode == 'cashfree_online' ? 'Pay ${rupee(payableInr)} & Upgrade' : 'Request Cash Upgrade',
                      loading: _submitting,
                      onPressed: _selectedPlan == null ? null : _submitUpgrade,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _payOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final active = _paymentMode == value;
    return CardSurface(
      onTap: () => setState(() => _paymentMode = value),
      color: active ? ThaliColors.primarySoft : ThaliColors.card,
      borderColor: active ? ThaliColors.primary : ThaliColors.stroke,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 20, color: active ? ThaliColors.primary : ThaliColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted)),
              ],
            ),
          ),
          Icon(
            active ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 20,
            color: active ? ThaliColors.primary : ThaliColors.muted,
          ),
        ],
      ),
    );
  }
}
