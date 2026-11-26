import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

class DeliveryStaffScreen extends StatefulWidget {
  const DeliveryStaffScreen({super.key, required this.session});
  final ProviderSession session;

  @override
  State<DeliveryStaffScreen> createState() => _DeliveryStaffScreenState();
}

class _DeliveryStaffScreenState extends State<DeliveryStaffScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _riders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ProviderApiService.fetchRiders(widget.session.providerId);
      if (mounted) setState(() => _riders = list);
    } catch (e) {
      if (mounted) setState(() => _error = ProviderApiService.friendlyError(e, action: 'load staff'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addRiderSheet() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
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
              const Text('Add Delivery Staff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
              const SizedBox(height: 4),
              const Text(
                'Your rider uses the mobile web link (no separate APK needed).',
                style: TextStyle(fontSize: 12, color: ThaliColors.muted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Staff Name (e.g. Suresh)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(labelText: '10-digit Mobile Number', counterText: ''),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: '4-digit PIN (optional - auto generated)', counterText: ''),
              ),
              const SizedBox(height: 16),
              PartnerActionButton(
                label: 'Save & Generate Rider Link',
                loading: saving,
                onPressed: () async {
                  final n = nameCtrl.text.trim();
                  final p = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                  if (n.isEmpty || p.length != 10) {
                    showPartnerNotice(context, 'Enter valid name and 10-digit phone number.', isError: true);
                    return;
                  }
                  setSheetState(() => saving = true);
                  try {
                    await ProviderApiService.saveRider(
                      providerId: widget.session.providerId,
                      name: n,
                      phone: p,
                      pinCode: pinCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      showPartnerNotice(context, 'Delivery staff added! Share their WhatsApp link now.');
                      _load();
                    }
                  } catch (e) {
                    setSheetState(() => saving = false);
                    if (mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'add staff'), isError: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _remove(Map<String, dynamic> rider) async {
    try {
      await ProviderApiService.removeRider(
        providerId: widget.session.providerId,
        riderId: rider['id'].toString(),
      );
      if (mounted) {
        showPartnerNotice(context, 'Removed ${rider['name']}');
        _load();
      }
    } catch (e) {
      if (mounted) showPartnerNotice(context, ProviderApiService.friendlyError(e, action: 'remove staff'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(
        title: const Text('My Delivery Staff'),
        actions: [
          TextButton.icon(
            onPressed: _addRiderSheet,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: ThaliColors.primary),
            label: const Text('Add Staff', style: TextStyle(color: ThaliColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: ThaliColors.primary,
        onRefresh: _load,
        child: _loading
            ? const PartnerSkeletonList(itemCount: 3, cardHeight: 112)
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 24),
                      CardSurface(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: ThaliColors.red)),
                            const SizedBox(height: 12),
                            PartnerActionButton(label: 'Retry', height: 42, onPressed: _load),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Share link (thali.store/rider/portal) & 4-digit PIN with your riders.',
                          style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                        ),
                      ),
                      if (_riders.isEmpty)
                        CardSurface(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(Icons.delivery_dining_rounded, size: 36, color: ThaliColors.muted),
                              const SizedBox(height: 10),
                              const Text(
                                'No delivery staff added yet.',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add your rider with their phone number to share their instant web login link.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                              ),
                              const SizedBox(height: 14),
                              PartnerActionButton(label: 'Add First Delivery Staff', height: 42, onPressed: _addRiderSheet),
                            ],
                          ),
                        )
                      else
                        ..._riders.map((r) {
                          final name = r['name']?.toString() ?? 'Rider';
                          final phone = r['phone']?.toString() ?? '';
                          final pin = r['pin_code']?.toString() ?? '----';
                          final waUrl = r['whatsapp_url']?.toString() ?? '';
                          final portalUrl = r['rider_url']?.toString() ?? 'https://www.thali.store/rider/portal?phone=$phone';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CardSurface(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: ThaliColors.primarySoft,
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'R',
                                          style: const TextStyle(fontWeight: FontWeight.w800, color: ThaliColors.primaryDark),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                                            Text(phone, style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: ThaliColors.subtle,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: ThaliColors.stroke),
                                        ),
                                        child: Text(
                                          'PIN: $pin',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: PartnerActionButton(
                                          label: 'Share Invite',
                                          height: 38,
                                          icon: Icons.share_outlined,
                                          onPressed: () {
                                            if (waUrl.isNotEmpty) {
                                              launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: '$portalUrl (Phone: $phone, PIN: $pin)'));
                                          showPartnerNotice(context, 'Rider login link & PIN copied.');
                                        },
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 38),
                                          side: const BorderSide(color: ThaliColors.stroke),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Icon(Icons.copy_rounded, size: 17, color: ThaliColors.ink),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        onPressed: () => _remove(r),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: ThaliColors.red),
                                        tooltip: 'Remove rider',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}
