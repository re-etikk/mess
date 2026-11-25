import 'package:flutter/material.dart';

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
  static const _slots = ['breakfast', 'lunch', 'dinner'];

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
      if (mounted) showPartnerNotice(context, '$e', isError: true);
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
      if (mounted) showPartnerNotice(context, '$e', isError: true);
    }
  }

  Future<void> _addItemSheet() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '30');
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
                      if (mounted) showPartnerNotice(context, '$e', isError: true);
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
    final included = ((slotMap?['items_included'] as List?) ?? const []).map((e) => e.toString()).toList();
    final extras = ((slotMap?['items_extra'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                style: TextStyle(
                                  fontSize: 13,
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
                          SectionHeader(title: 'Main Thali Dishes (${included.length})', actionLabel: '+ Add', onAction: _addItemSheet),
                          const SizedBox(height: 8),
                          if (included.isEmpty)
                            const CardSurface(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No dishes listed in this slot yet. Tap Add Dish to publish live items to customers.',
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
                                'Add paid extras (Extra Roti, Curd, Paneer, Gulab Jamun) for customer customization.',
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
}
