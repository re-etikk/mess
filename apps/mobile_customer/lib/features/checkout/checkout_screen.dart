import 'package:flutter/material.dart';

import '../../core/models/mess_models.dart';
import '../../core/repositories/mess_repository.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.provider,
    this.plan,
    this.slotId,
    this.addOns = const [],
  });

  final MessProvider provider;
  final MealPlan? plan;
  final String? slotId;
  final List<CartAddOn> addOns;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _CheckoutPaymentMode { cashfreeOnline, counterCash }

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _termsAccepted = true;
  bool _busy = false;
  _CheckoutPaymentMode _mode = _CheckoutPaymentMode.cashfreeOnline;

  int get _extrasTotal => widget.addOns.fold<int>(0, (sum, entry) => sum + entry.total);
  int get _total => (widget.plan?.price ?? 0) + _extrasTotal;

  Future<void> _payAndConfirm() async {
    final state = AppStateScope.of(context, listen: false);
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm the plan rules before continuing.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (_mode == _CheckoutPaymentMode.cashfreeOnline) {
        final purpose = widget.plan == null
            ? 'add_ons'
            : (widget.plan!.type == SubscriptionType.dailyMeal
                ? 'single_meal_purchase'
                : 'subscription_purchase');

        await state.payWithCashfree(
          purpose: purpose,
          provider: widget.provider,
          plan: widget.plan,
          slotId: widget.slotId,
          addOnsPaise: _extrasTotal * 100,
        );

        if (widget.addOns.isNotEmpty) {
          state.recordAddOnPayment(providerName: widget.provider.name, addOns: widget.addOns);
        }

        if (!mounted) return;
        setState(() => _busy = false);

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.verified_rounded, color: MessColors.green, size: 46),
            title: const Text('Payment Successful!'),
            content: Text(
              '₹$_total paid securely via Cashfree.\n\nYour meal pass at ${widget.provider.name} is now active and ready to scan at the counter!',
            ),
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
        return;
      }

      // Pay Cash at Mess Counter
      if (widget.plan != null) {
        if (widget.plan!.type == SubscriptionType.dailyMeal) {
          await state.purchaseDailyMeal(widget.plan!, widget.slotId ?? widget.plan!.slotIds.first);
        } else {
          await state.purchasePlan(
            widget.plan!,
            paymentMode: 'counter_cash',
          );
        }
      }
      if (widget.addOns.isNotEmpty) {
        state.recordAddOnPayment(providerName: widget.provider.name, addOns: widget.addOns);
      }

      if (!mounted) return;
      setState(() => _busy = false);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: MessColors.green, size: 44),
          title: const Text('Pass Registered!'),
          content: Text(
            'Your meal plan has been registered!\n\nPlease pay ₹$_total in Cash at the ${widget.provider.name} counter. Once confirmed by counter staff, your meal pass will be ready to scan.',
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFC0392B),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to complete payment. Please check your connection and retry.'),
          backgroundColor: Color(0xFFC0392B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final slot = widget.slotId == null
        ? null
        : widget.provider.mealSlots.where((s) => s.id == widget.slotId).firstOrNull;
    final isCashfree = _mode == _CheckoutPaymentMode.cashfreeOnline;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Review and confirm'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MessColors.navy,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.provider.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    plan == null
                        ? 'Optional food extras'
                        : '${plan.name}${slot == null ? '' : ' · ${slot.name}'}',
                    style: const TextStyle(color: Color(0xFFD5DEE5), fontSize: 13),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Total payable',
                    style: TextStyle(color: Color(0xFFB9C5CE), fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '₹$_total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Price details', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            CardSurface(
              child: Column(
                children: [
                  if (plan != null)
                    _PriceLine(
                      label: plan.type == SubscriptionType.dailyMeal ? 'Daily meal' : plan.name,
                      amount: plan.price,
                    ),
                  for (final addOn in widget.addOns)
                    _PriceLine(
                      label: '${addOn.item.name} × ${addOn.quantity}',
                      amount: addOn.total,
                    ),
                  const Divider(height: 23),
                  _PriceLine(label: 'Total', amount: _total, strong: true),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Payment method', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            CardSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  RadioListTile<_CheckoutPaymentMode>(
                    value: _CheckoutPaymentMode.cashfreeOnline,
                    groupValue: _mode,
                    onChanged: (value) => setState(() => _mode = value!),
                    activeColor: MessColors.orangeDark,
                    title: Row(
                      children: [
                        const Text(
                          'Pay Online via Cashfree',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'INSTANT',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: const Text(
                      'UPI (GPay / PhonePe / Paytm), Cards, Netbanking',
                      style: TextStyle(fontSize: 11.5, color: MessColors.muted),
                    ),
                    secondary: const Icon(Icons.credit_card_rounded, color: MessColors.green),
                  ),
                  const Divider(height: 1),
                  RadioListTile<_CheckoutPaymentMode>(
                    value: _CheckoutPaymentMode.counterCash,
                    groupValue: _mode,
                    onChanged: (value) => setState(() => _mode = value!),
                    activeColor: MessColors.orangeDark,
                    title: const Text(
                      'Pay Cash at Mess Counter',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Pay physical cash to mess counter staff',
                      style: TextStyle(fontSize: 11.5, color: MessColors.muted),
                    ),
                    secondary: const Icon(Icons.payments_outlined, color: MessColors.navy),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isCashfree)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Secured by Cashfree Payments',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF14532D),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Pay securely with any UPI app, Debit/Credit Card, or Netbanking inside Cashfree Checkout. Your pass activates immediately.',
                            style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MessColors.orangeSoft,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: MessColors.orange.withOpacity(0.28)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.storefront_rounded, color: MessColors.orangeDark, size: 19),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Pay Cash on Counter. Visit the mess counter and pay cash directly. The mess cashier will verify and activate your pass.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: MessColors.navy,
                          fontWeight: FontWeight.w500,
                        ),
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
              title: const Text(
                'I have checked the plan rules and expiry.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 8),
            MessActionButton(
              label: isCashfree
                  ? 'Pay ₹$_total Online (Cashfree)'
                  : 'Confirm & Pay Cash on Counter · ₹$_total',
              loading: _busy,
              onPressed: _payAndConfirm,
            ),
          ],
        ),
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
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: strong ? 14 : 12.5,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                  color: strong ? MessColors.navy : MessColors.muted,
                ),
              ),
            ),
            Text(
              '₹$amount',
              style: TextStyle(
                fontSize: strong ? 17 : 13,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                color: MessColors.navy,
              ),
            ),
          ],
        ),
      );
}
