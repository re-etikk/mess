import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

class MenuManagementTab extends StatefulWidget {
  const MenuManagementTab({super.key, required this.session});
  final ProviderSession session;

  @override
  State<MenuManagementTab> createState() => _MenuManagementTabState();
}

class _MenuManagementTabState extends State<MenuManagementTab> {
  String _selectedDay = 'Daily';
  String _selectedSlot = 'lunch';
  bool _loading = true;
  List<Map<String, dynamic>> _menus = [];

  static const _days = ['Daily', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _slots = ['breakfast', 'lunch', 'snacks', 'dinner'];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() => _loading = true);
    try {
      final res = await ProviderApiService.fetchMenu(widget.session.providerId);
      final raw = (res['menus'] as List?) ?? (res['menu'] as List?) ?? const [];
      if (mounted) {
        setState(() {
          _menus = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _currentSlotMap() {
    for (final m in _menus) {
      final s = (m['slot']?.toString() ?? m['name']?.toString() ?? '').toLowerCase();
      if (s == _selectedSlot) return m;
    }
    return null;
  }

  Future<void> _toggleAvailability(String name, bool nextAvail) async {
    try {
      await ProviderApiService.toggleMenuAvailability(
        providerId: widget.session.providerId,
        name: name,
        isAvailable: nextAvail,
      );
      await _loadMenu();
    } catch (e) {
      if (mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'update dish'), isError: true);
    }
  }

  Future<void> _removeItem(String name) async {
    try {
      await ProviderApiService.removeMenuItem(
        providerId: widget.session.providerId,
        name: name,
        slot: _selectedSlot,
      );
      if (mounted) {
        showPartnerNotice(context, 'Removed $name');
        await _loadMenu();
      }
    } catch (e) {
      if (mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'remove dish'), isError: true);
    }
  }

  Future<void> _editSlotRateSheet() async {
    final slotMap = _currentSlotMap();
    final currentRate = (slotMap?['single_meal_price_inr'] as num?)?.toInt();
    final rateCtrl = TextEditingController(text: currentRate != null && currentRate > 0 ? '$currentRate' : '');
    final slotTitle = _selectedSlot[0].toUpperCase() + _selectedSlot.substring(1);
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
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
              Text('$slotTitle Single-Meal Rate', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
              const SizedBox(height: 6),
              const Text(
                'Set the per-plate price for walk-in / single orders. Enter 0 to allow subscription plans only.',
                style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Price per meal (INR)',
                  hintText: 'e.g. 50',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 16),
              PartnerActionButton(
                label: 'Save Meal Rate',
                loading: saving,
                onPressed: () async {
                  final parsed = int.tryParse(rateCtrl.text.trim()) ?? 0;
                  setSheetState(() => saving = true);
                  try {
                    await ProviderApiService.setSlotPrice(
                      providerId: widget.session.providerId,
                      slot: _selectedSlot,
                      priceInr: parsed > 0 ? parsed : 0,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      showPartnerNotice(
                        context,
                        parsed > 0 ? '$slotTitle single-meal rate set to ₹$parsed' : '$slotTitle single-meal rate cleared',
                      );
                      await _loadMenu();
                    }
                  } catch (e) {
                    setSheetState(() => saving = false);
                    if (mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'update meal rate'), isError: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editExtraItemSheet(Map<String, dynamic> extra) async {
    final nameCtrl = TextEditingController(text: extra['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: ((extra['price'] as num?)?.toInt() ?? 0).toString());
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              const Text('Edit Item Price', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
              const SizedBox(height: 14),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (INR)', prefixText: '₹ '),
              ),
              const SizedBox(height: 16),
              PartnerActionButton(
                label: 'Save Item',
                loading: saving,
                onPressed: () async {
                  final nextName = nameCtrl.text.trim();
                  final nextPrice = int.tryParse(priceCtrl.text.trim()) ?? 0;
                  if (nextName.isEmpty) return;
                  setSheetState(() => saving = true);
                  try {
                    await ProviderApiService.updateMenuItem(
                      providerId: widget.session.providerId,
                      itemId: extra['id']?.toString(),
                      name: nextName,
                      price: nextPrice,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      showPartnerNotice(context, 'Updated $nextName');
                      await _loadMenu();
                    }
                  } catch (e) {
                    setSheetState(() => saving = false);
                    if (mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'update item'), isError: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addItemSheet() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '20');
    String kind = 'included'; // included | addon | special
    String slot = _selectedSlot;
    String day = _selectedDay;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
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
                const Text('Add Dish or Customize Extra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Dish Name (e.g. Paneer Masala, Extra Roti)')),
                const SizedBox(height: 12),
                const Text('Category', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _kindChip('Included Thali', 'included', kind, (v) => setSheetState(() => kind = v)),
                    const SizedBox(width: 8),
                    _kindChip('Extra Add-on', 'addon', kind, (v) => setSheetState(() => kind = v)),
                    const SizedBox(width: 8),
                    _kindChip('Special', 'special', kind, (v) => setSheetState(() => kind = v)),
                  ],
                ),
                if (kind != 'included') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price (INR)', prefixText: '₹ '),
                  ),
                ],
                const SizedBox(height: 12),
                const Text('Meal Slot & Schedule Day', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: slot,
                        items: _slots
                            .map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setSheetState(() => slot = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: day,
                        items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (v) {
                          if (v != null) setSheetState(() => day = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                PartnerActionButton(
                  label: 'Add to Menu',
                  loading: saving,
                  onPressed: () async {
                    final dish = nameCtrl.text.trim();
                    if (dish.isEmpty) return;
                    setSheetState(() => saving = true);
                    try {
                      final p = int.tryParse(priceCtrl.text.trim()) ?? 0;
                      await ProviderApiService.addMenuItem(
                        providerId: widget.session.providerId,
                        name: dish,
                        slot: slot,
                        price: kind == 'included' ? 0 : p,
                        isExtra: kind == 'addon',
                        dayOfWeek: day,
                        itemKind: kind,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        showPartnerNotice(context, 'Added $dish to $slot');
                        await _loadMenu();
                      }
                    } catch (e) {
                      setSheetState(() => saving = false);
                      if (mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'add dish'), isError: true);
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

  Widget _kindChip(String label, String value, String current, ValueChanged<String> onTap) {
    final active = value == current;
    return Expanded(
      child: PressScale(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? ThaliColors.primarySoft : ThaliColors.subtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? ThaliColors.primary : ThaliColors.stroke),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: active ? ThaliColors.primaryDark : ThaliColors.body,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slotMap = _currentSlotMap();
    final rawItems = ((slotMap?['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final dayMatches = rawItems.where((it) {
      if (_selectedDay == 'Daily') return true;
      final dow = (it['day_of_week']?.toString() ?? 'Daily').trim();
      return dow.isEmpty || dow == 'Daily' || dow.toLowerCase() == _selectedDay.toLowerCase();
    }).toList();
    final included = rawItems.isNotEmpty
        ? dayMatches
            .where((it) => it['is_add_on'] != true && it['active'] != false)
            .map((it) => it['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
        : ((slotMap?['items_included'] as List?) ?? const []).map((e) => e.toString()).toList();
    final extras = rawItems.isNotEmpty
        ? dayMatches
            .where((it) => it['is_add_on'] == true && it['active'] != false)
            .map((it) => {
                  'id': it['id'],
                  'name': it['name']?.toString() ?? 'Extra',
                  'price_paise': it['price_paise'] ?? 0,
                  'price': (((it['price_paise'] as num?)?.toInt() ?? 0) / 100).round(),
                  'limit': it['max_quantity'] ?? 5,
                  'is_available': it['active'] != false,
                })
            .toList()
        : ((slotMap?['items_extra'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final unavailable = ((slotMap?['items_unavailable'] as List?) ?? const []).map((e) => e.toString().toLowerCase()).toSet();

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              color: ThaliColors.card,
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '7-Day Menu Builder',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _aiSnapMenuSheet,
                        icon: const Icon(Icons.document_scanner_outlined, size: 17, color: ThaliColors.ink),
                        label: const Text('Scan Menu', style: TextStyle(color: ThaliColors.ink, fontWeight: FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: _addItemSheet,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: ThaliColors.primary),
                        label: const Text('Add Dish', style: TextStyle(color: ThaliColors.primary, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _days.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final d = _days[i];
                        final active = _selectedDay == d;
                        return PressScale(
                          onTap: () => setState(() => _selectedDay = d),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: active ? ThaliColors.primary : ThaliColors.subtle,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              d == 'Daily' ? 'All Days' : d.substring(0, 3),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : ThaliColors.body,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _slots.map((s) {
                      final active = _selectedSlot == s;
                      final label = s[0].toUpperCase() + s.substring(1);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: PressScale(
                            onTap: () => setState(() => _selectedSlot = s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: active ? ThaliColors.primarySoft : ThaliColors.scaffold,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: active ? ThaliColors.primary : ThaliColors.stroke),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active ? ThaliColors.primaryDark : ThaliColors.body,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const PartnerSkeletonList(itemCount: 4, cardHeight: 74)
                  : RefreshIndicator(
                      color: ThaliColors.primary,
                      onRefresh: _loadMenu,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 118),
                        children: [
                          Builder(
                            builder: (_) {
                              final rate = (slotMap?['single_meal_price_inr'] as num?)?.toInt();
                              final hasRate = rate != null && rate > 0;
                              final slotTitle = _selectedSlot[0].toUpperCase() + _selectedSlot.substring(1);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: CardSurface(
                                  color: hasRate ? ThaliColors.primarySoft : ThaliColors.card,
                                  borderColor: hasRate ? ThaliColors.primary.withValues(alpha: 0.4) : null,
                                  onTap: _editSlotRateSheet,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: ThaliColors.card,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.sell_outlined, size: 18, color: ThaliColors.primary),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$slotTitle Single-Meal Rate',
                                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                                            ),
                                            Text(
                                              hasRate ? '₹$rate / plate · Pay-per-meal active' : 'Subscription plans only (tap to set rate)',
                                              style: const TextStyle(fontSize: 11.5, color: ThaliColors.body),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        hasRate ? '₹$rate' : 'Set ₹',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ThaliColors.primaryDark),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.edit_outlined, size: 16, color: ThaliColors.primaryDark),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          SectionHeader(title: 'Main Thali Dishes (${included.length})', actionLabel: '+ Add', onAction: _addItemSheet),
                          const SizedBox(height: 8),
                          if (included.isEmpty)
                            const CardSurface(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No dishes in this slot yet.',
                                style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                              ),
                            )
                          else
                            ...included.map((name) {
                              final avail = !unavailable.contains(name.toLowerCase());
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: CardSurface(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: ThaliColors.ink)),
                                            Text(avail ? 'Available' : 'Paused today', style: TextStyle(fontSize: 11.5, color: avail ? ThaliColors.greenDark : ThaliColors.amberDark)),
                                          ],
                                        ),
                                      ),
                                      Switch.adaptive(
                                        activeColor: ThaliColors.primary,
                                        value: avail,
                                        onChanged: (v) => _toggleAvailability(name, v),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 19, color: ThaliColors.muted),
                                        onPressed: () => _removeItem(name),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          const SizedBox(height: 18),
                          SectionHeader(title: 'Customize Add-Ons & Specials (${extras.length})', actionLabel: '+ Add', onAction: _addItemSheet),
                          const SizedBox(height: 8),
                          if (extras.isEmpty)
                            const CardSurface(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No add-ons or specials yet.',
                                style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                              ),
                            )
                          else
                            ...extras.map((ex) {
                              final name = ex['name']?.toString() ?? '';
                              final price = (ex['price'] as num?)?.toInt() ?? 0;
                              final avail = ex['is_available'] != false && !unavailable.contains(name.toLowerCase());
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: CardSurface(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: ThaliColors.ink)),
                                            Text('${rupee(price)} add-on', style: const TextStyle(fontSize: 12, color: ThaliColors.primaryDark, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: ThaliColors.primary),
                                        onPressed: () => _editExtraItemSheet(ex),
                                      ),
                                      Switch.adaptive(
                                        activeColor: ThaliColors.primary,
                                        value: avail,
                                        onChanged: (v) => _toggleAvailability(name, v),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 19, color: ThaliColors.muted),
                                        onPressed: () => _removeItem(name),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aiSnapMenuSheet() async {
    final textCtrl = TextEditingController();
    String? imageBase64;
    String? imageName;
    bool parsing = false;
    bool publishing = false;
    List<String> included = [];
    List<Map<String, dynamic>> extras = [];
    String dietaryGuess = 'veg';
    int? calories;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.document_scanner_outlined, size: 20, color: ThaliColors.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scan Menu (${_selectedSlot[0].toUpperCase()}${_selectedSlot.substring(1)} · $_selectedDay)',
                        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Paste your dishes list or pick a photo of your menu board.',
                  style: TextStyle(fontSize: 12, color: ThaliColors.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Dishes Text',
                    hintText: 'e.g. Rajma chawal, 4 roti, raita, extra gulab jamun 25',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: parsing || publishing
                            ? null
                            : () async {
                                final picked = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1280,
                                  imageQuality: 80,
                                );
                                if (picked == null) return;
                                final bytes = await picked.readAsBytes();
                                final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
                                setSheetState(() {
                                  imageBase64 = 'data:image/$ext;base64,${base64Encode(bytes)}';
                                  imageName = picked.name;
                                });
                              },
                        icon: const Icon(Icons.photo_camera_outlined, size: 17),
                        label: Text(
                          imageName == null ? 'Pick Menu Photo' : 'Photo: $imageName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: parsing || publishing
                            ? null
                            : () async {
                                setSheetState(() => parsing = true);
                                try {
                                  final res = await ProviderApiService.parseMenuAi(
                                    providerId: widget.session.providerId,
                                    slot: _selectedSlot,
                                    textInput: textCtrl.text,
                                    imageBase64: imageBase64,
                                  );
                                  setSheetState(() {
                                    included = ((res['included'] as List?) ?? const []).map((e) => e.toString()).toList();
                                    extras = ((res['extras'] as List?) ?? const [])
                                        .map((e) => Map<String, dynamic>.from(e as Map))
                                        .toList();
                                    dietaryGuess = res['dietary_guess']?.toString() ?? 'veg';
                                    calories = (res['estimated_calories'] as num?)?.toInt();
                                  });
                                } catch (e) {
                                  if (mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'parse menu'), isError: true);
                                } finally {
                                  setSheetState(() => parsing = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThaliColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(parsing ? 'Parsing...' : 'Extract', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                if (included.isNotEmpty || extras.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThaliColors.subtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ThaliColors.stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detected ${dietaryGuess.toUpperCase()}${calories != null ? ' · ~$calories kcal' : ''}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: ThaliColors.greenDark),
                        ),
                        if (included.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Included Items (tap to remove):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ThaliColors.muted)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: included
                                .map((item) => InputChip(
                                      label: Text(item, style: const TextStyle(fontSize: 12)),
                                      onDeleted: () => setSheetState(() => included.remove(item)),
                                    ))
                                .toList(),
                          ),
                        ],
                        if (extras.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Extras / Specials:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ThaliColors.muted)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: extras
                                .map((ex) => InputChip(
                                      label: Text('${ex['name']} (${rupee((ex['price'] as num?)?.toInt() ?? 0)})', style: const TextStyle(fontSize: 12)),
                                      onDeleted: () => setSheetState(() => extras.remove(ex)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  PartnerActionButton(
                    label: 'Publish ${included.length + extras.length} Item(s) to Menu',
                    loading: publishing,
                    onPressed: () async {
                      setSheetState(() => publishing = true);
                      try {
                        for (final dish in included) {
                          await ProviderApiService.addMenuItem(
                            providerId: widget.session.providerId,
                            name: dish,
                            slot: _selectedSlot,
                            price: 0,
                            isExtra: false,
                            dayOfWeek: _selectedDay,
                            itemKind: 'included',
                          );
                        }
                        for (final ex in extras) {
                          final kind = ex['kind']?.toString() == 'special' ? 'special' : 'addon';
                          await ProviderApiService.addMenuItem(
                            providerId: widget.session.providerId,
                            name: ex['name']?.toString() ?? 'Extra',
                            slot: _selectedSlot,
                            price: (ex['price'] as num?)?.toInt() ?? 25,
                            isExtra: kind == 'addon',
                            dayOfWeek: _selectedDay,
                            itemKind: kind,
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          showPartnerNotice(context, 'Published menu items to $_selectedSlot.');
                          await _loadMenu();
                        }
                      } catch (e) {
                        setSheetState(() => publishing = false);
                        if (mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'publish menu'), isError: true);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
