import 'package:flutter/material.dart';

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
  String _paymentMethod = 'UPI';

  int get _extrasTotal => widget.addOns.fold<int>(0, (sum, entry) => sum + entry.total);
  int get _total => (widget.plan?.price ?? 0) + _extrasTotal;

  Future<void> _payDemo() async {
    final state = AppStateScope.of(context);
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm the plan rules before continuing.')));
      return;
    }
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    try {
      String message;
      if (widget.plan != null) {
        if (widget.plan!.type == SubscriptionType.dailyMeal) {
          await state.purchaseDailyMealDemo(widget.plan!, widget.slotId ?? widget.plan!.slotIds.first);
          message = 'Daily meal entitlement created locally for demo testing.';
        } else {
          await state.purchasePlanDemo(widget.plan!);
          message = 'Subscription activated locally for demo testing.';
        }
      } else {
        state.recordDemoAddOnPayment(providerName: widget.provider.name, addOns: widget.addOns);
        message = 'Add-on transaction recorded locally for demo testing.';
      }
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog<void>(context: context, barrierDismissible: false, builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.info_outline_rounded, color: MessColors.orangeDark, size: 38),
        title: const Text('Demo checkout completed'),
        content: Text('$message\n\nNo real payment was processed. A live payment gateway and server verification are required before launch.'),
        actions: [FilledButton(onPressed: () { Navigator.pop(dialogContext); Navigator.of(context).popUntil((route) => route.isFirst); }, child: const Text('Back to MESS'))],
      ));
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to complete this demo action. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final slot = widget.slotId == null ? null : widget.provider.mealSlots.where((s) => s.id == widget.slotId).firstOrNull;
    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Review and pay')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 22), children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: MessColors.navy, borderRadius: BorderRadius.circular(17)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.provider.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 21)), const SizedBox(height: 5), Text(plan == null ? 'Optional food extras' : '${plan.name}${slot == null ? '' : ' · ${slot.name}'}', style: const TextStyle(color: Color(0xFFD5DEE5), fontSize: 13)), const SizedBox(height: 15), const Text('Total payable', style: TextStyle(color: Color(0xFFB9C5CE), fontSize: 12)), const SizedBox(height: 3), Text('₹$_total', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900))])),
        const SizedBox(height: 22),
        Text('Price details', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 10),
        CardSurface(child: Column(children: [if (plan != null) _PriceLine(label: plan.type == SubscriptionType.dailyMeal ? 'Daily meal' : plan.name, amount: plan.price), for (final addOn in widget.addOns) _PriceLine(label: '${addOn.item.name} × ${addOn.quantity}', amount: addOn.total), const Divider(height: 23), _PriceLine(label: 'Total', amount: _total, strong: true)])),
        const SizedBox(height: 22),
        Text('Payment method', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 10),
        CardSurface(padding: EdgeInsets.zero, child: Column(children: [for (final method in ['UPI', 'Credit or debit card', 'Net banking']) RadioListTile<String>(value: method, groupValue: _paymentMethod, onChanged: (value) => setState(() => _paymentMethod = value!), activeColor: MessColors.orangeDark, title: Text(method, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), secondary: Icon(method == 'UPI' ? Icons.account_balance_wallet_outlined : method == 'Credit or debit card' ? Icons.credit_card_rounded : Icons.account_balance_rounded, color: MessColors.navy))])),
        const SizedBox(height: 18),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF0D5), borderRadius: BorderRadius.circular(11)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, color: MessColors.orangeDark, size: 19), SizedBox(width: 9), Expanded(child: Text('Demo checkout only. This does not charge money. Connect a payment gateway and verify the payment on the server before production.', style: TextStyle(fontSize: 12, height: 1.4, color: MessColors.navy)))])),
        const SizedBox(height: 14),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _termsAccepted, onChanged: (v) => setState(() => _termsAccepted = v ?? false), activeColor: MessColors.orangeDark, controlAffinity: ListTileControlAffinity.leading, title: const Text('I have checked the plan rules and expiry.', style: TextStyle(fontSize: 12.5))),
        const SizedBox(height: 8), MessActionButton(label: 'Test checkout · ₹$_total', loading: _busy, onPressed: _payDemo),
      ])),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.amount, this.strong = false});
  final String label;
  final int amount;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 14 : 12.5, fontWeight: strong ? FontWeight.w800 : FontWeight.w500, color: strong ? MessColors.navy : MessColors.muted))), Text('₹$amount', style: TextStyle(fontSize: strong ? 17 : 13, fontWeight: strong ? FontWeight.w900 : FontWeight.w700, color: MessColors.navy))]));
}

extension _FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
