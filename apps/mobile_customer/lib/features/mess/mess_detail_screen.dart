import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/mess_models.dart';
import '../../core/repositories/mess_repository.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../chat/customer_chat_screen.dart';
import '../checkout/create_subscription_screen.dart';

class MessDetailScreen extends StatefulWidget {
  const MessDetailScreen({super.key, required this.provider});
  final MessProvider provider;

  @override
  State<MessDetailScreen> createState() => _MessDetailScreenState();
}

class _MessDetailScreenState extends State<MessDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MessProvider _provider;
  ReviewSummaryData? _reviews;
  bool _loadingReviews = false;
  String _selectedDay = 'Daily';
  final Set<String> _expandedSlots = {'breakfast', 'lunch', 'dinner'};

  static const _days = ['Daily', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStateScope.of(context).setSelectedProvider(_provider.id);
      _refreshLiveProvider();
      _loadReviews();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshLiveProvider() async {
    final live = await AppStateScope.of(context).repository.fetchLiveProvider(_provider.id, day: _selectedDay);
    if (live != null && mounted) {
      setState(() => _provider = live);
    }
  }

  Future<void> _loadReviews() async {
    setState(() => _loadingReviews = true);
    try {
      final rev = await AppStateScope.of(context).repository.fetchMessReviews(_provider.id);
      if (mounted) setState(() => _reviews = rev);
    } finally {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  void _openCustomizeSheet(MealSlot slot) {
    final appState = AppStateScope.of(context);
    final existing = appState.mealCart[slot.id];
    final extras = slot.items.where((i) => i.kind == FoodItemKind.addOn).toList();
    final specials = slot.items.where((i) => i.kind == FoodItemKind.special).toList();
    final chosen = <MenuItem, int>{if (existing != null) ...existing.addOns};
    int qty = existing?.quantity ?? 1;
    final basePrice = (slot.startingPrice != null && slot.startingPrice! > 0) ? slot.startingPrice! : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final addOnSum = chosen.entries.fold<int>(0, (s, e) => s + e.key.price * e.value);
          final unitTotal = basePrice + addOnSum;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ThaliColors.stroke, borderRadius: BorderRadius.circular(99)))),
                  const SizedBox(height: 14),
                  Text(slot.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                  const SizedBox(height: 4),
                  Text(slot.menuSummary, style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted)),
                  const SizedBox(height: 14),
                  if (extras.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text('Customize Your Meal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                    const Text('Add extra items to your meal', style: TextStyle(fontSize: 12, color: ThaliColors.muted)),
                    const SizedBox(height: 8),
                    for (final item in extras)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: ThaliColors.primary,
                        value: (chosen[item] ?? 0) > 0,
                        title: Text(item.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        secondary: Text(item.priceLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                        onChanged: (v) => setModalState(() {
                          if (v == true) {
                            chosen[item] = 1;
                          } else {
                            chosen.remove(item);
                          }
                        }),
                      ),
                  ],
                  if (specials.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text('Specials', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                    const Text('Add something extra to meal', style: TextStyle(fontSize: 12, color: ThaliColors.muted)),
                    const SizedBox(height: 8),
                    for (final item in specials)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: ThaliColors.primary,
                        value: (chosen[item] ?? 0) > 0,
                        title: Text(item.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        secondary: Text(item.priceLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                        onChanged: (v) => setModalState(() {
                          if (v == true) {
                            chosen[item] = 1;
                          } else {
                            chosen.remove(item);
                          }
                        }),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: ThaliColors.stroke),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: qty > 1 ? () => setModalState(() => qty--) : null,
                              icon: const Icon(Icons.remove_rounded, size: 18),
                            ),
                            Text('$qty', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                            IconButton(
                              onPressed: () => setModalState(() => qty++),
                              icon: const Icon(Icons.add_rounded, size: 18, color: ThaliColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MessActionButton(
                          label: unitTotal > 0 ? 'Add ${slot.name.toLowerCase()} ₹${unitTotal * qty}' : 'Add ${slot.name.toLowerCase()}',
                          onPressed: () {
                            appState.setMealSelection(CartMealSelection(
                              slotId: slot.id,
                              slotLabel: slot.name,
                              basePrice: basePrice,
                              quantity: qty,
                              addOns: chosen,
                              preferredWindow: slot.timeLabel,
                            ));
                            Navigator.pop(ctx);
                          },
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
    );
  }

  void _openWriteReviewSheet() {
    final appState = AppStateScope.of(context);
    final textCtrl = TextEditingController();
    int rating = 5;
    final selectedTags = <String>{};
    const allTags = ['Homestyle Food', 'Timely Delivery', 'Good Hygiene', 'Value for Money'];
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Write a Verified Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return IconButton(
                      onPressed: () => setModalState(() => rating = i + 1),
                      icon: Icon(
                        i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: ThaliColors.amber,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in allTags)
                      FilterChip(
                        label: Text(tag, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        selected: selectedTags.contains(tag),
                        selectedColor: ThaliColors.primarySoft,
                        checkmarkColor: ThaliColors.primary,
                        onSelected: (v) => setModalState(() {
                          if (v) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Share how the food, packaging & timing were...'),
                ),
                const SizedBox(height: 14),
                MessActionButton(
                  label: 'Submit Review',
                  loading: submitting,
                  onPressed: () async {
                    setModalState(() => submitting = true);
                    try {
                      await appState.repository.submitMessReview(
                        providerId: _provider.id,
                        customerId: appState.customerId,
                        customerName: appState.customerName.isEmpty ? 'Customer' : appState.customerName,
                        rating: rating,
                        reviewText: textCtrl.text,
                        tags: selectedTags.toList(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadReviews();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(friendlyCustomerError(e, action: 'submit review'))),
                        );
                      }
                    } finally {
                      if (ctx.mounted) setModalState(() => submitting = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final cartCount = appState.mealCartCount;

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 26),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(_provider.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
            onPressed: () => Navigator.push(context, messRoute(CustomerChatScreen(providerId: _provider.id, providerName: _provider.name))),
          ),
        ],
      ),
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: Container(
                  color: ThaliColors.card,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Column(
                    children: [
                      MessCoverVisual(
                        imageUrl: _provider.coverPath,
                        height: 155,
                        radius: 14,
                        closed: !_provider.isOpen,
                      ),
                      const SizedBox(height: 12),
                      Text(_provider.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                      const SizedBox(height: 3),
                      Text(
                        _provider.mealSlots.isEmpty ? 'Daily Mess' : _provider.mealSlots.map((s) => s.name).join(' · '),
                        style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _KpiTile(
                            icon: Icons.star_rounded,
                            iconColor: _provider.rating != null ? ThaliColors.amber : ThaliColors.muted,
                            value: _provider.rating != null ? '${_provider.rating!.toStringAsFixed(1)} (${_provider.totalReviews})' : 'New',
                            label: 'Rating',
                          ),
                          const SizedBox(width: 8),
                          _KpiTile(
                            icon: Icons.location_on_outlined,
                            value: _provider.distanceKm != null ? _provider.distanceLabel : _provider.area,
                            label: _provider.distanceKm != null ? 'Distance' : 'Area',
                          ),
                          const SizedBox(width: 8),
                          _KpiTile(
                            icon: Icons.sell_outlined,
                            value: _provider.startingMealPrice != null ? '₹${_provider.startingMealPrice}/meal' : '${_provider.plans.length} Plans',
                            label: 'Pricing',
                          ),
                          const SizedBox(width: 8),
                          _KpiTile(
                            icon: Icons.eco_outlined,
                            iconColor: ThaliColors.green,
                            value: _provider.dietarySummary,
                            label: 'Food Type',
                          ),
                        ],
                      ),
                      if (!_provider.isOpen) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141416),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF27272A)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 17, color: Colors.white),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Kitchen is closed today',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: ThaliColors.primary,
                    indicatorWeight: 2.5,
                    labelColor: ThaliColors.ink,
                    unselectedLabelColor: ThaliColors.muted,
                    labelStyle: const TextStyle(fontFamily: 'Urbanist', fontSize: 13.5, fontWeight: FontWeight.w700),
                    tabs: const [
                      Tab(text: 'Order'),
                      Tab(text: 'Menu'),
                      Tab(text: 'About'),
                      Tab(text: 'Review'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildOrderTab(appState),
                _buildMenuTab(),
                _buildAboutTab(),
                _buildReviewTab(),
              ],
            ),
          ),
          if (cartCount > 0 || _provider.plans.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: SafeArea(
                top: false,
                child: Builder(
                  builder: (_) {
                    final cartTotal = appState.mealCart.values.fold<int>(0, (s, e) => s + e.total);
                    final hasPaidSingleOrder = cartCount > 0 && cartTotal > 0;
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          messRoute(
                            CreateSubscriptionScreen(
                              provider: _provider,
                              forceSubscriptionMode: !hasPaidSingleOrder,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: ThaliColors.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [BoxShadow(color: Color(0x33E95F35), blurRadius: 16, offset: Offset(0, 6))],
                        ),
                        child: Row(
                          children: [
                            Text(
                              hasPaidSingleOrder
                                  ? '$cartCount Meal${cartCount == 1 ? '' : 's'} · ₹$cartTotal'
                                  : (cartCount > 0 ? '$cartCount Slot${cartCount == 1 ? '' : 's'} Selected' : 'Monthly & Weekly Plans'),
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const Spacer(),
                            Text(
                              hasPaidSingleOrder ? 'Order Now' : 'Subscribe',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _refreshLiveProvider(),
      _loadReviews(),
    ]);
  }

  Widget _buildOrderTab(appState) {
    if (_provider.mealSlots.isEmpty) {
      return RefreshIndicator(
        color: ThaliColors.primary,
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 40),
            Center(child: Text('No meal slots configured by this kitchen yet.', style: TextStyle(color: ThaliColors.muted))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: ThaliColors.primary,
      onRefresh: _refreshAll,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 92),
        itemCount: _provider.mealSlots.length,
        itemBuilder: (_, i) {
          final slot = _provider.mealSlots[i];
          final expanded = _expandedSlots.contains(slot.id);
          final cartItem = appState.mealCart[slot.id];
          final hasExtras = slot.items.any((x) => x.kind != FoodItemKind.included);
          final priceDisplay = (slot.startingPrice != null && slot.startingPrice! > 0) ? slot.startingPrice : null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CardSurface(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() {
                      if (expanded) {
                        _expandedSlots.remove(slot.id);
                      } else {
                        _expandedSlots.add(slot.id);
                      }
                    }),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(slot.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                                  if (!slot.enabled) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(color: ThaliColors.subtle, borderRadius: BorderRadius.circular(6)),
                                      child: const Text('Closed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThaliColors.muted)),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${_provider.supportsDelivery ? 'Delivers' : 'Pickup'} between ${slot.timeLabel}',
                                style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: ThaliColors.ink),
                      ],
                    ),
                  ),
                if (expanded) ...[
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                VegIndicator(isVeg: !_provider.dietaryTypes.contains('non_vegetarian')),
                                const SizedBox(width: 6),
                                Text(slot.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(slot.menuSummary, style: const TextStyle(fontSize: 12.5, color: ThaliColors.body)),
                            const SizedBox(height: 6),
                            Text(
                              priceDisplay != null ? '₹$priceDisplay/meal' : 'Included in Plans',
                              style: TextStyle(
                                fontSize: priceDisplay != null ? 14 : 12,
                                fontWeight: FontWeight.w800,
                                color: priceDisplay != null ? ThaliColors.ink : ThaliColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        children: [
                          if (cartItem == null)
                            InkWell(
                              onTap: () {
                                if (hasExtras) {
                                  _openCustomizeSheet(slot);
                                } else {
                                  appState.setMealSelection(CartMealSelection(
                                    slotId: slot.id,
                                    slotLabel: slot.name,
                                    basePrice: priceDisplay ?? 0,
                                    quantity: 1,
                                    addOns: const {},
                                    preferredWindow: slot.timeLabel,
                                  ));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(color: ThaliColors.primary, borderRadius: BorderRadius.circular(10)),
                                child: const Text('Add +', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: ThaliColors.primarySoft,
                                border: Border.all(color: ThaliColors.primary),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => appState.adjustMealQuantity(slot.id, -1),
                                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove_rounded, size: 16, color: ThaliColors.primary)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text('${cartItem.quantity}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ThaliColors.primary)),
                                  ),
                                  InkWell(
                                    onTap: () => appState.adjustMealQuantity(slot.id, 1),
                                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add_rounded, size: 16, color: ThaliColors.primary)),
                                  ),
                                ],
                              ),
                            ),
                          if (hasExtras)
                            GestureDetector(
                              onTap: () => _openCustomizeSheet(slot),
                              child: const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text('Customisable', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: ThaliColors.primary)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildMenuTab() {
    return RefreshIndicator(
      color: ThaliColors.primary,
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 92),
      children: [
        SizedBox(
          height: 54,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = _days[i];
              final sel = d == _selectedDay;
              return InkWell(
                onTap: () {
                  setState(() => _selectedDay = d);
                  _refreshLiveProvider();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? ThaliColors.primary : ThaliColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? ThaliColors.primary : ThaliColors.stroke),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    d == 'Daily' ? 'All Days' : d.substring(0, 3),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : ThaliColors.ink),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text("Today's Menu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
        const SizedBox(height: 10),
        if (_provider.mealSlots.isEmpty)
          const Text('Menu not published yet.', style: TextStyle(color: ThaliColors.muted))
        else
          for (final slot in _provider.mealSlots)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CardSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slot.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                    const SizedBox(height: 2),
                    Text('Served between ${slot.timeLabel}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ThaliColors.primary)),
                    const SizedBox(height: 8),
                    if (slot.items.where((x) => x.kind == FoodItemKind.included).isEmpty)
                      Text(slot.menuSummary, style: const TextStyle(fontSize: 13, color: ThaliColors.body))
                    else
                      for (final it in slot.items.where((x) => x.kind == FoodItemKind.included))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, size: 5, color: ThaliColors.primary),
                              const SizedBox(width: 8),
                              Text(it.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThaliColors.body)),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
      ],
      ),
    );
  }

  Widget _buildAboutTab() {
    return RefreshIndicator(
      color: ThaliColors.primary,
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 92),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.1,
            children: [
              _CapPill(icon: Icons.restaurant_outlined, label: _provider.supportsPickup ? 'Dine-in Available' : 'No Dine-in'),
              _CapPill(icon: Icons.shopping_bag_outlined, label: _provider.allowsTakeaway ? 'Takeaway Available' : 'No Takeaway'),
              _CapPill(icon: Icons.delivery_dining_outlined, label: _provider.supportsDelivery ? 'Self Delivery' : 'Counter Pickup Only'),
              _CapPill(icon: Icons.calendar_month_outlined, label: _provider.allowsMonthlyPlans ? 'Monthly Plans' : 'Daily Plans'),
            ],
          ),
          const SizedBox(height: 12),
          CardSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Timings', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                const SizedBox(height: 8),
                for (final s in _provider.mealSlots)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.name, style: const TextStyle(fontSize: 13, color: ThaliColors.body)),
                        Text(
                          s.enabled ? s.timeLabel : 'Closed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: s.enabled ? ThaliColors.ink : ThaliColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        if (_provider.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          CardSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('From Mess', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                const SizedBox(height: 6),
                Text(_provider.description, style: const TextStyle(fontSize: 13, height: 1.45, color: ThaliColors.body)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        CardSurface(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Location', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                    const SizedBox(height: 4),
                    Text(_provider.address ?? _provider.area, style: const TextStyle(fontSize: 13, color: ThaliColors.body)),
                  ],
                ),
              ),
              const Icon(Icons.location_on_outlined, color: ThaliColors.primary),
            ],
          ),
        ),
        if (_provider.publicPhone != null && _provider.publicPhone!.isNotEmpty) ...[
          const SizedBox(height: 10),
          CardSurface(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Contact Mess', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                      const SizedBox(height: 4),
                      Text(_provider.publicPhone!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThaliColors.body)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone_outlined, color: ThaliColors.primary),
                  onPressed: () => launchUrl(Uri.parse('tel:${_provider.publicPhone}')),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: const [
            ThaliLogoMark(size: 26, withWordmark: true),
            SizedBox(width: 10),
            Expanded(child: Text('Menu details updated directly by kitchen partner', style: TextStyle(fontSize: 11.5, color: ThaliColors.muted))),
          ],
        ),
      ],
      ),
    );
  }

  Widget _buildReviewTab() {
    if (_loadingReviews) {
      return RefreshIndicator(
        color: ThaliColors.primary,
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [ThaliListSkeleton(itemCount: 3, cardHeight: 112)],
        ),
      );
    }
    final rev = _reviews;
    final total = rev?.totalReviews ?? 0;

    return RefreshIndicator(
      color: ThaliColors.primary,
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 92),
      children: [
        CardSurface(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (int star = 5; star >= 1; star--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('$star', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: total > 0 ? (rev!.breakdown[star] ?? 0) / total : 0,
                                  minHeight: 6,
                                  backgroundColor: ThaliColors.subtle,
                                  color: ThaliColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Column(
                children: [
                  Text(
                    rev?.averageRating != null ? rev!.averageRating!.toStringAsFixed(1) : 'New',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                  ),
                  Text('$total Reviews', style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        MessActionButton(
          label: 'Write a Verified Review',
          icon: Icons.rate_review_outlined,
          secondary: true,
          height: 44,
          onPressed: _openWriteReviewSheet,
        ),
        if ((rev?.popularTags ?? []).isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Popular tags', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in rev!.popularTags)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: ThaliColors.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: ThaliColors.stroke)),
                  child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThaliColors.ink)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (total == 0)
          const CardSurface(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('No verified customer reviews yet. Be the first to review.', style: TextStyle(color: ThaliColors.muted))),
          )
        else
          for (final r in rev!.reviews)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CardSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: ThaliColors.primarySoft,
                          child: Text((r['customer_name']?.toString() ?? 'C')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: ThaliColors.primary)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(r['customer_name']?.toString() ?? 'Customer', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        ),
                        RatingBadge(rating: (r['rating'] as num?)?.toDouble(), compact: true),
                      ],
                    ),
                    if ((r['review_text']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(r['review_text'].toString(), style: const TextStyle(fontSize: 13, color: ThaliColors.body)),
                    ],
                    if ((r['partner_reply']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: ThaliColors.subtle, borderRadius: BorderRadius.circular(8)),
                        child: Text('Kitchen reply: ${r['partner_reply']}', style: const TextStyle(fontSize: 12, color: ThaliColors.ink)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.icon, required this.value, required this.label, this.iconColor});
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(color: ThaliColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: ThaliColors.stroke)),
        child: Column(
          children: [
            Icon(icon, size: 16, color: iconColor ?? ThaliColors.ink),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: ThaliColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _CapPill extends StatelessWidget {
  const _CapPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: ThaliColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: ThaliColors.stroke)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ThaliColors.ink),
          const SizedBox(width: 7),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThaliColors.ink))),
        ],
      ),
    );
  }
}

class _SliverTabDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabDelegate(this.tabBar);
  final TabBar tabBar;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: ThaliColors.card, child: tabBar);
  @override
  bool shouldRebuild(_SliverTabDelegate old) => false;
}
