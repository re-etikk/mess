import 'package:flutter/material.dart';

import '../../core/models/mess_models.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../setup/profile_location_setup_screen.dart';

/// Stage 1: Create Subscription -> Start Date Sheet -> Stage 2: Review Subscription (Option B) -> Stage 3: Congratulations
class CreateSubscriptionScreen extends StatefulWidget {
  const CreateSubscriptionScreen({super.key, required this.provider});
  final MessProvider provider;

  @override
  State<CreateSubscriptionScreen> createState() => _CreateSubscriptionScreenState();
}

class _CreateSubscriptionScreenState extends State<CreateSubscriptionScreen> {
  int _stage = 0; // 0 = Create Sub, 1 = Review Sub, 2 = Congratulations
  MealPlan? _selectedPlan;
  final Set<int> _deliveryDays = {1, 2, 3, 4, 5, 6}; // Mon..Sat
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  final Map<String, String> _preferredTimes = {
    'breakfast': '07:30 AM - 08:30 AM',
    'lunch': '12:00 PM - 01:00 PM',
    'dinner': '07:30 PM - 08:30 PM',
  };

  String _packaging = 'reusable_tiffin'; // reusable_tiffin | disposable | dine_in
  final _instructionsController = TextEditingController();
  final _promoController = TextEditingController();
  String _appliedPromo = '';
  int _discountInr = 0;
  String? _promoMessage;
  bool _applyingPromo = false;

  String _optionBMethod = 'cashfree_online'; // Strict Option B: cashfree_online | counter_cash
  bool _submitting = false;
  DateTime? _confirmedValidTill;
  String _confirmedStatus = 'active';

  @override
  void initState() {
    super.initState();
    if (!widget.provider.supportsDelivery) {
      _packaging = 'dine_in';
    }
    if (widget.provider.plans.isNotEmpty) {
      _selectedPlan = widget.provider.plans.first;
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDateSheet() async {
    final now = DateTime.now();
    DateTime temp = _startDate;
    await showModalBottomSheet(
      context: context,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose start delivery day', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                const SizedBox(height: 12),
                for (int i = 0; i < 6; i++) ...[
                  Builder(builder: (_) {
                    final d = DateTime(now.year, now.month, now.day + i + 1);
                    final isSel = temp.year == d.year && temp.month == d.month && temp.day == d.day;
                    return InkWell(
                      onTap: () => setModalState(() => temp = d),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isSel ? ThaliColors.primarySoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          formatDate(d),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                            color: isSel ? ThaliColors.primary : ThaliColors.body,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: MessActionButton(
                        label: 'Cancel',
                        secondary: true,
                        height: 44,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MessActionButton(
                        label: 'Save',
                        height: 44,
                        onPressed: () {
                          setState(() => _startDate = temp);
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyPromo(int baseSubtotalInr) async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _applyingPromo = true;
      _promoMessage = null;
    });
    try {
      final res = await AppStateScope.of(context).repository.validatePromo(
            code: code,
            orderAmountPaise: baseSubtotalInr * 100,
            providerId: widget.provider.id,
          );
      setState(() {
        _appliedPromo = res['code']?.toString() ?? code.toUpperCase();
        _discountInr = (res['discount_inr'] as num?)?.toInt() ?? 0;
        _promoMessage = res['message']?.toString();
      });
    } catch (e) {
      setState(() {
        _appliedPromo = '';
        _discountInr = 0;
        _promoMessage = e.toString().replaceFirst('RepositoryException: ', '');
      });
    } finally {
      if (mounted) setState(() => _applyingPromo = false);
    }
  }

  Future<void> _submitOrder(int netTotalInr, int addOnsPaise) async {
    final plan = _selectedPlan;
    if (plan == null) return;
    final state = AppStateScope.of(context);
    setState(() => _submitting = true);

    final slotsMap = <String, dynamic>{};
    for (final entry in state.mealCart.entries) {
      slotsMap[entry.key] = {
        'quantity': entry.value.quantity,
        'time_slot': _preferredTimes[entry.key] ?? entry.value.preferredWindow,
        'addons': entry.value.addOns.entries.map((a) => {'name': a.key.name, 'price': a.key.price, 'qty': a.value}).toList(),
      };
    }

    try {
      if (_optionBMethod == 'cashfree_online') {
        final verified = await state.payWithCashfree(
          purpose: 'subscription_purchase',
          provider: widget.provider,
          plan: plan,
          addOnsPaise: addOnsPaise,
          discountPaise: _discountInr * 100,
          promoCode: _appliedPromo,
          selectedSlots: slotsMap,
          repeatDays: _deliveryDays.toList()..sort(),
          packagingPreference: _packaging,
          deliveryInstructions: _instructionsController.text.trim(),
          startsAt: _startDate,
        );
        final subMap = verified['subscription'] as Map<String, dynamic>?;
        setState(() {
          _confirmedStatus = 'active';
          _confirmedValidTill = DateTime.tryParse(subMap?['expires_at']?.toString() ?? '') ?? plan.expiryFrom(_startDate);
          _stage = 2;
        });
      } else {
        final sub = await state.purchaseCounterCashPlan(
          plan: plan,
          selectedSlots: slotsMap,
          repeatDays: _deliveryDays.toList()..sort(),
          packagingPreference: _packaging,
          deliveryInstructions: _instructionsController.text.trim(),
          promoCode: _appliedPromo,
          discountPaise: _discountInr * 100,
          startsAt: _startDate,
        );
        setState(() {
          _confirmedStatus = sub.status;
          _confirmedValidTill = sub.endDate;
          _stage = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('RepositoryException: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final plan = _selectedPlan;
    final planPrice = plan?.price ?? 0;
    final addOnsPerDay = state.mealCart.values.fold<int>(0, (s, e) => s + e.addOnsTotal * e.quantity);
    final packFee = _packaging == 'disposable' ? widget.provider.disposableFeeInr * (plan?.durationDays ?? 1) : 0;
    final totalBeforeDiscount = planPrice + addOnsPerDay + packFee;
    final netTotal = (totalBeforeDiscount - _discountInr).clamp(0, totalBeforeDiscount);

    if (_stage == 2) {
      return Scaffold(
        backgroundColor: ThaliColors.card,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    color: ThaliColors.green,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0xFFDCFCE7), spreadRadius: 10)],
                  ),
                  child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 22),
                Text(
                  _confirmedStatus == 'pending_payment' ? 'Order Submitted' : 'Congratulations',
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  _confirmedStatus == 'pending_payment'
                      ? 'Pay ₹$netTotal cash at counter to activate at'
                      : 'You subscribed successfully to',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: ThaliColors.body),
                ),
                const SizedBox(height: 4),
                Text(widget.provider.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.primary)),
                if (_confirmedValidTill != null) ...[
                  const SizedBox(height: 18),
                  const Text('VALID TILL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThaliColors.muted, letterSpacing: 0.7)),
                  const SizedBox(height: 3),
                  Text(formatDate(_confirmedValidTill!), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ThaliColors.green)),
                ],
                const Spacer(),
                MessActionButton(
                  label: 'View Subscription',
                  onPressed: () {
                    state.selectTab(2);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 26),
          onPressed: () {
            if (_stage == 1) {
              setState(() => _stage = 0);
            } else {
              Navigator.maybePop(context);
            }
          },
        ),
        title: Text(_stage == 0 ? 'Create Subscription' : 'Review Subscription'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _stage == 0
                ? _buildCreateBody(state)
                : _buildReviewBody(state, planPrice, addOnsPerDay, packFee, netTotal),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: const BoxDecoration(
              color: ThaliColors.card,
              border: Border(top: BorderSide(color: ThaliColors.stroke)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _stage == 0 ? 'Estimated total' : (_optionBMethod == 'cashfree_online' ? 'Cashfree UPI/Cards' : 'Cash at Counter'),
                      style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted, fontWeight: FontWeight.w600),
                    ),
                    Text('₹$netTotal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MessActionButton(
                    label: _stage == 0 ? 'Review & subscribe' : (_optionBMethod == 'cashfree_online' ? 'Pay ₹$netTotal' : 'Confirm Counter Cash'),
                    loading: _submitting,
                    onPressed: plan == null
                        ? null
                        : () {
                            if (_stage == 0) {
                              setState(() => _stage = 1);
                            } else {
                              _submitOrder(netTotal, (addOnsPerDay + packFee) * 100);
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateBody(state) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.mealCart.isNotEmpty) ...[
          const Text('Selected Meals', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
          const SizedBox(height: 8),
          for (final item in state.mealCart.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CardSurface(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const VegIndicator(isVeg: true),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.slotLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                          if (item.isCustomized) const Text('Customised', style: TextStyle(fontSize: 11, color: ThaliColors.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Text('₹${item.total}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(onTap: () => state.adjustMealQuantity(item.slotId, -1), child: const Icon(Icons.remove_circle_outline, size: 20, color: ThaliColors.muted)),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w800))),
                        InkWell(onTap: () => state.adjustMealQuantity(item.slotId, 1), child: const Icon(Icons.add_circle_outline, size: 20, color: ThaliColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
        const Text('Choose Your Plan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
        const SizedBox(height: 8),
        if (widget.provider.plans.isEmpty)
          const CardSurface(child: Text('No subscription plans published by this mess yet.', style: TextStyle(color: ThaliColors.muted)))
        else
          for (final p in widget.provider.plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CardSurface(
                borderColor: _selectedPlan?.id == p.id ? ThaliColors.primary : null,
                color: _selectedPlan?.id == p.id ? const Color(0xFFFFFBF8) : ThaliColors.card,
                onTap: () => setState(() => _selectedPlan = p),
                child: Row(
                  children: [
                    Radio<String>(
                      value: p.id,
                      groupValue: _selectedPlan?.id,
                      activeColor: ThaliColors.primary,
                      onChanged: (_) => setState(() => _selectedPlan = p),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                          Text(p.description.isNotEmpty ? p.description : p.durationLabel, style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted)),
                        ],
                      ),
                    ),
                    Text('₹${p.price}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 12),
        const Text('Delivery / Dining Days', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final dayNum = i + 1;
            final active = _deliveryDays.contains(dayNum);
            return InkWell(
              onTap: () => setState(() {
                if (active && _deliveryDays.length > 1) {
                  _deliveryDays.remove(dayNum);
                } else {
                  _deliveryDays.add(dayNum);
                }
              }),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active ? ThaliColors.primary : ThaliColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: active ? ThaliColors.primary : ThaliColors.stroke),
                ),
                alignment: Alignment.center,
                child: Text(days[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: active ? Colors.white : ThaliColors.muted)),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        const Text('Start Date', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
        const SizedBox(height: 8),
        CardSurface(
          onTap: _pickStartDateSheet,
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: ThaliColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(formatDate(_startDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink))),
              const Icon(Icons.chevron_right_rounded, color: ThaliColors.muted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewBody(state, int planPrice, int addOns, int packFee, int netTotal) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ThaliColors.greenSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ThaliColors.greenBorder),
          ),
          child: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: ThaliColors.green, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Almost Done', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF166534))),
                    Text('Review everything before starting your subscription', style: TextStyle(fontSize: 11.5, color: ThaliColors.greenDark)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardSurface(
          child: Row(
            children: [
              SizedBox(width: 56, height: 48, child: MessCoverVisual(imageUrl: widget.provider.coverPath, height: 48, radius: 8)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.provider.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                    Text(widget.provider.address ?? widget.provider.area, style: const TextStyle(fontSize: 12, color: ThaliColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        CardSurface(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.home_outlined, color: ThaliColors.primary),
                title: Text(widget.provider.supportsDelivery ? 'Delivery Area' : 'Kitchen Location', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  widget.provider.supportsDelivery
                      ? (state.location.isEmpty ? 'Set location' : state.location)
                      : (widget.provider.address ?? widget.provider.area),
                ),
                trailing: widget.provider.supportsDelivery ? const Icon(Icons.chevron_right_rounded) : null,
                onTap: widget.provider.supportsDelivery
                    ? () => Navigator.push(context, messRoute(const ProfileLocationSetupScreen(locationOnly: true)))
                    : null,
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.calendar_today_outlined, color: ThaliColors.primary),
                title: Text(widget.provider.supportsDelivery ? 'Your First Delivery' : 'Starts On', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: Text(formatDate(_startDate)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickStartDateSheet,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!widget.provider.supportsDelivery) ...[
          const Text('Dining / Pickup Mode', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
          const SizedBox(height: 8),
          CardSurface(
            borderColor: ThaliColors.primary,
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined, color: ThaliColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dine-in / Counter Pickup Only', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        widget.provider.allowsTakeaway
                            ? 'This kitchen serves at counter & takeaway (home delivery not available).'
                            : 'This kitchen serves dine-in meals at counter only.',
                        style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: ThaliColors.greenSoft, borderRadius: BorderRadius.circular(99)),
                  child: const Text('Included', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThaliColors.greenDark)),
                ),
              ],
            ),
          ),
        ] else ...[
          const Text('Packaging & Dining Preference', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
          const SizedBox(height: 8),
          CardSurface(
            borderColor: _packaging == 'reusable_tiffin' ? ThaliColors.primary : null,
            onTap: () => setState(() => _packaging = 'reusable_tiffin'),
            child: Row(
              children: [
                Radio<String>(value: 'reusable_tiffin', groupValue: _packaging, activeColor: ThaliColors.primary, onChanged: (v) => setState(() => _packaging = v!)),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Reusable Tiffin', style: TextStyle(fontWeight: FontWeight.w700)), Text('No charges applied', style: TextStyle(fontSize: 11.5, color: ThaliColors.muted))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: ThaliColors.greenSoft, borderRadius: BorderRadius.circular(99)), child: const Text('Included', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThaliColors.greenDark))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          CardSurface(
            borderColor: _packaging == 'disposable' ? ThaliColors.primary : null,
            onTap: () => setState(() => _packaging = 'disposable'),
            child: Row(
              children: [
                Radio<String>(value: 'disposable', groupValue: _packaging, activeColor: ThaliColors.primary, onChanged: (v) => setState(() => _packaging = v!)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Disposable Container', style: TextStyle(fontWeight: FontWeight.w700)), Text('+ ₹${widget.provider.disposableFeeInr} per day charges apply', style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted))])),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text('Special Instructions', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
        const SizedBox(height: 6),
        TextField(
          controller: _instructionsController,
          decoration: const InputDecoration(hintText: 'Write instruction for the mess (e.g. Less oil / Leave at door)'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promoController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Promo code (e.g. THALI50)',
                  suffixText: _appliedPromo.isNotEmpty ? 'APPLIED' : null,
                  suffixStyle: const TextStyle(color: ThaliColors.green, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: MessActionButton(
                label: 'Apply',
                loading: _applyingPromo,
                height: 48,
                onPressed: () => _applyPromo(planPrice + addOns + packFee),
              ),
            ),
          ],
        ),
        if (_promoMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(_promoMessage!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _appliedPromo.isNotEmpty ? ThaliColors.greenDark : ThaliColors.red)),
          ),
        const SizedBox(height: 12),
        CardSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Subscription Summary', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _SumRow('Plan (${_selectedPlan?.name ?? ''})', '₹$planPrice'),
              if (addOns > 0) _SumRow('Meal Customisations', '₹$addOns'),
              if (packFee > 0) _SumRow('Disposable Containers', '₹$packFee'),
              if (_discountInr > 0) _SumRow('Coupon Discount ($_appliedPromo)', '- ₹$_discountInr', green: true),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('₹$netTotal', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text('PAYMENT METHOD (OPTION B)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThaliColors.muted, letterSpacing: 0.6)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _optionBMethod = 'cashfree_online'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: _optionBMethod == 'cashfree_online' ? ThaliColors.primarySoft : ThaliColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _optionBMethod == 'cashfree_online' ? ThaliColors.primary : ThaliColors.stroke, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.credit_card_rounded, size: 17, color: _optionBMethod == 'cashfree_online' ? ThaliColors.primary : ThaliColors.body),
                      const SizedBox(width: 6),
                      Text('Cashfree Online', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _optionBMethod == 'cashfree_online' ? ThaliColors.primary : ThaliColors.ink)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _optionBMethod = 'counter_cash'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: _optionBMethod == 'counter_cash' ? ThaliColors.primarySoft : ThaliColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _optionBMethod == 'counter_cash' ? ThaliColors.primary : ThaliColors.stroke, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_outlined, size: 17, color: _optionBMethod == 'counter_cash' ? ThaliColors.primary : ThaliColors.body),
                      const SizedBox(width: 6),
                      Text('Cash at Counter', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _optionBMethod == 'counter_cash' ? ThaliColors.primary : ThaliColors.ink)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SumRow extends StatelessWidget {
  const _SumRow(this.label, this.val, {this.green = false});
  final String label;
  final String val;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: ThaliColors.body)),
          Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: green ? ThaliColors.green : ThaliColors.ink)),
        ],
      ),
    );
  }
}
