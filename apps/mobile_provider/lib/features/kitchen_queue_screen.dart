import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

class KitchenQueueScreen extends StatefulWidget {
  const KitchenQueueScreen({
    super.key,
    required this.session,
    this.initialSlot = 'LUNCH',
  });

  final ProviderSession session;
  final String initialSlot;

  @override
  State<KitchenQueueScreen> createState() => _KitchenQueueScreenState();
}

class _KitchenQueueScreenState extends State<KitchenQueueScreen> {
  late String _slot;
  DateTime _date = DateTime.now();
  bool _loading = true;
  String? _error;
  KitchenQueueResponse? _data;
  List<Map<String, dynamic>> _riders = const [];

  static const _slots = ['BREAKFAST', 'LUNCH', 'DINNER'];

  @override
  void initState() {
    super.initState();
    _slot = _slots.contains(widget.initialSlot.toUpperCase()) ? widget.initialSlot.toUpperCase() : 'LUNCH';
    _load();
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ProviderApiService.fetchKitchenQueue(
        providerId: widget.session.providerId,
        date: _isoDate(_date),
        slot: _slot,
      );
      List<Map<String, dynamic>> riders = const [];
      try {
        riders = await ProviderApiService.fetchRiders(widget.session.providerId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _data = res;
        _riders = riders;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(KitchenQueueItem item, String nextStatus, {int? eta}) async {
    try {
      await ProviderApiService.updateKitchenQueueStatus(
        providerId: widget.session.providerId,
        subscriptionId: item.subscriptionId,
        customerId: item.customerId,
        serviceDate: item.serviceDate.isNotEmpty ? item.serviceDate : _isoDate(_date),
        slot: item.slot,
        status: nextStatus,
        etaMinutes: eta,
      );
      if (!mounted) return;
      showPartnerNotice(context, 'Updated ${item.customerName} -> ${nextStatus.replaceAll('_', ' ')}');
      await _load();
    } catch (e) {
      if (mounted) {
        showPartnerNotice(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  Future<void> _assignRiderAndDispatch(KitchenQueueItem item, Map<String, dynamic> rider) async {
    try {
      await ProviderApiService.assignRider(
        providerId: widget.session.providerId,
        riderId: rider['id'].toString(),
        subscriptionId: item.subscriptionId,
        customerId: item.customerId,
        slot: item.slot,
        serviceDate: item.serviceDate.isNotEmpty ? item.serviceDate : _isoDate(_date),
      );
      await ProviderApiService.updateKitchenQueueStatus(
        providerId: widget.session.providerId,
        subscriptionId: item.subscriptionId,
        customerId: item.customerId,
        serviceDate: item.serviceDate.isNotEmpty ? item.serviceDate : _isoDate(_date),
        slot: item.slot,
        status: 'out_for_delivery',
        etaMinutes: 20,
      );
      if (!mounted) return;
      showPartnerNotice(context, 'Assigned ${rider['name']} to ${item.customerName}');
      await _load();
    } catch (e) {
      if (mounted) {
        showPartnerNotice(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  Future<void> _pickDispatchOption(KitchenQueueItem item) async {
    final isDeliveryOrder = item.fulfillmentMode == 'delivery' || (_data?.supportsDelivery == true && item.fulfillmentMode != 'pickup');
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
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
                Text(
                  'Update ${item.customerName}',
                  style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 14),
                if (!isDeliveryOrder) ...[
                  PartnerActionButton(
                    label: 'Ready at Counter (Pickup / Dine-in)',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateStatus(item, 'ready_at_counter');
                    },
                  ),
                  const SizedBox(height: 10),
                  PartnerActionButton(
                    label: 'Picked Up / Completed',
                    color: ThaliColors.green,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateStatus(item, 'delivered');
                    },
                  ),
                ] else ...[
                  PartnerActionButton(
                    label: 'Out for Delivery (~20 mins)',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateStatus(item, 'out_for_delivery', eta: 20);
                    },
                  ),
                  if (_riders.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Or Assign Delivery Staff:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThaliColors.muted),
                    ),
                    const SizedBox(height: 6),
                    for (final r in _riders) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PartnerActionButton(
                          label: 'Assign to ${r['name']} (${r['phone']})',
                          secondary: true,
                          height: 40,
                          onPressed: () {
                            Navigator.pop(ctx);
                            _assignRiderAndDispatch(item, r);
                          },
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 6),
                  PartnerActionButton(
                    label: 'Ready at Counter Instead',
                    secondary: true,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateStatus(item, 'ready_at_counter');
                    },
                  ),
                  const SizedBox(height: 10),
                  PartnerActionButton(
                    label: 'Mark Delivered / Completed',
                    color: ThaliColors.green,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateStatus(item, 'delivered');
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

  Future<void> _callCustomer(String phone) async {
    if (phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:${phone.trim()}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final q = _data;
    final items = q?.items ?? const <KitchenQueueItem>[];

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(
        title: const Text('Live Kitchen Queue'),
        actions: [
          IconButton(
            tooltip: 'Select date',
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now().subtract(const Duration(days: 7)),
                lastDate: DateTime.now().add(const Duration(days: 14)),
              );
              if (d != null && mounted) {
                setState(() => _date = d);
                _load();
              }
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: ThaliColors.card,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  children: _slots.map((s) {
                    final active = _slot == s;
                    final label = s[0] + s.substring(1).toLowerCase();
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: PressScale(
                          onTap: () {
                            setState(() => _slot = s);
                            _load();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: active ? ThaliColors.primary : ThaliColors.subtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: active ? ThaliColors.primary : ThaliColors.stroke),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : ThaliColors.body,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (q != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statPill('Total', q.total, ThaliColors.subtle, ThaliColors.ink),
                      const SizedBox(width: 6),
                      _statPill('Prep', q.preparing, ThaliColors.amberSoft, ThaliColors.amberDark),
                      const SizedBox(width: 6),
                      _statPill('Out/Ready', q.outCount, ThaliColors.greenSoft, ThaliColors.greenDark),
                      const SizedBox(width: 6),
                      _statPill('Done', q.delivered, const Color(0xFFDCFCE7), const Color(0xFF166534)),
                      const SizedBox(width: 6),
                      _statPill('Skip', q.skipped, ThaliColors.subtle, ThaliColors.muted),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              color: ThaliColors.primary,
              onRefresh: _load,
              child: _loading
                  ? const PartnerSkeletonList(itemCount: 3, cardHeight: 116)
                  : _error != null
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
                                  const Icon(Icons.cloud_off_rounded, size: 36, color: ThaliColors.muted),
                                  const SizedBox(height: 10),
                                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: ThaliColors.red, fontSize: 13.5)),
                                  const SizedBox(height: 14),
                                  PartnerActionButton(label: 'Retry', height: 42, onPressed: _load),
                                ],
                              ),
                            ),
                          ],
                        )
                      : items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              padding: const EdgeInsets.all(24),
                              children: [
                                CardSurface(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.restaurant_outlined, size: 44, color: ThaliColors.muted),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No meals scheduled for ${formatPartnerDate(_date)} (${_slot.toLowerCase()})',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Active subscribers scheduled for this day appear here automatically.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _buildQueueCard(items[i]),
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, int val, Color bg, Color fg) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              Text('$val', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: fg)),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      );

  Widget _buildQueueCard(KitchenQueueItem item) {
    final st = item.status.toLowerCase();
    final isFinal = st == 'delivered' || st == 'skipped' || st == 'cancelled_by_kitchen';

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
                    Text(
                      item.customerName,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.planName}${item.timeWindow.isNotEmpty ? ' · ${item.timeWindow}' : ''}',
                      style: const TextStyle(fontSize: 12, color: ThaliColors.muted),
                    ),
                  ],
                ),
              ),
              MealStatusBadge(status: item.status),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _tag(
                item.fulfillmentMode == 'delivery' ? 'Self Delivery' : 'Counter Pickup',
                item.fulfillmentMode == 'delivery' ? Icons.delivery_dining_rounded : Icons.storefront_outlined,
              ),
              _tag(
                item.packagingPreference == 'disposable' ? 'Disposable Container' : 'Reusable Tiffin',
                Icons.inventory_2_outlined,
              ),
              if (item.riderName.isNotEmpty)
                _tag('Rider: ${item.riderName}', Icons.person_pin_circle_outlined),
              if (item.customerPhone.isNotEmpty)
                GestureDetector(
                  onTap: () => _callCustomer(item.customerPhone),
                  child: _tag(item.customerPhone, Icons.call_outlined),
                ),
            ],
          ),
          if (item.riderName.isNotEmpty || item.etaMinutes != null || (item.riderLat != null && item.riderLng != null)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (item.riderName.isNotEmpty)
                  _tag('Rider: ${item.riderName}', Icons.delivery_dining_outlined),
                if (item.etaMinutes != null)
                  _tag('ETA ${item.etaMinutes} min', Icons.schedule_rounded),
                if (item.riderLat != null && item.riderLng != null)
                  _tag('GPS Active', Icons.my_location_rounded),
              ],
            ),
          ],
          if (item.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Address: ${item.deliveryAddress}',
              style: const TextStyle(fontSize: 12, color: ThaliColors.body),
            ),
          ],
          if (item.addons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Add-ons: ${item.addons.map((a) => a is Map ? '${a['name'] ?? ''} x${a['qty'] ?? a['quantity'] ?? 1}' : a.toString()).join(', ')}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThaliColors.primaryDark),
            ),
          ],
          if (item.instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThaliColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Note: ${item.instructions}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThaliColors.primaryDark),
              ),
            ),
          ],
          if (!isFinal) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (st == 'scheduled')
                  Expanded(
                    child: PartnerActionButton(
                      label: 'Start Preparing',
                      height: 40,
                      onPressed: () => _updateStatus(item, 'preparing'),
                    ),
                  )
                else if (st == 'preparing')
                  Expanded(
                    child: PartnerActionButton(
                      label: 'Dispatch / Ready',
                      height: 40,
                      onPressed: () => _pickDispatchOption(item),
                    ),
                  )
                else
                  Expanded(
                    child: PartnerActionButton(
                      label: 'Mark Delivered',
                      color: ThaliColors.green,
                      height: 40,
                      onPressed: () => _updateStatus(item, 'delivered'),
                    ),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    side: const BorderSide(color: ThaliColors.stroke),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _pickDispatchOption(item),
                  child: const Icon(Icons.more_horiz_rounded, color: ThaliColors.ink, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: ThaliColors.subtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ThaliColors.stroke),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.5, color: ThaliColors.body),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ThaliColors.body)),
          ],
        ),
      );
}
