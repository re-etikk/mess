import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

class DailyQrTab extends StatefulWidget {
  const DailyQrTab({super.key, required this.session});
  final ProviderSession session;

  @override
  State<DailyQrTab> createState() => _DailyQrTabState();
}

class _DailyQrTabState extends State<DailyQrTab> {
  String _slot = 'LUNCH';
  String _qrToken = '';
  bool _loading = true;
  List<Map<String, dynamic>> _todayRedemptions = [];

  static const _slots = ['BREAKFAST', 'LUNCH', 'DINNER'];

  @override
  void initState() {
    super.initState();
    final hour = DateTime.now().hour;
    _slot = hour < 11 ? 'BREAKFAST' : (hour < 16 ? 'LUNCH' : 'DINNER');
    _loadQr();
  }

  Future<void> _loadQr() async {
    setState(() => _loading = true);
    try {
      ProviderApiService.currentSession ??= widget.session;
      final token = await ProviderApiService.fetchDailyQrToken(
        widget.session.providerId,
        slot: _slot,
        token: widget.session.token,
      );
      final scans = await ProviderApiService.fetchAttendance(widget.session.providerId);
      if (mounted) {
        setState(() {
          _qrToken = token;
          _todayRedemptions = scans.take(8).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: ThaliColors.primary,
          onRefresh: _loadQr,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 118),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Counter QR',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                        ),
                        Text(
                          'Diners scan this code at counter to redeem their meal pass',
                          style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: _slots.map((s) {
                  final active = _slot == s;
                  final label = s[0] + s.substring(1).toLowerCase();
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: PressScale(
                        onTap: () {
                          setState(() => _slot = s);
                          _loadQr();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: active ? ThaliColors.primary : ThaliColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: active ? ThaliColors.primary : ThaliColors.stroke),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
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
              const SizedBox(height: 16),
              CardSurface(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  children: [
                    Text(
                      widget.session.businessName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatPartnerDate(DateTime.now())} · $_slot',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThaliColors.primary),
                    ),
                    const SizedBox(height: 18),
                    if (_loading)
                      const SizedBox(
                        height: 220,
                        child: PartnerLoadingView(label: 'Generating Counter QR...'),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ThaliColors.stroke),
                        ),
                        child: QrImageView(
                          data: _qrToken,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ThaliColors.ink),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ThaliColors.ink),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: PartnerActionButton(
                            label: 'Copy Token',
                            secondary: true,
                            height: 42,
                            icon: Icons.copy_rounded,
                            onPressed: _qrToken.isEmpty
                                ? null
                                : () {
                                    Clipboard.setData(ClipboardData(text: _qrToken));
                                    showPartnerNotice(context, 'Counter QR token copied.');
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PartnerActionButton(
                            label: 'Regenerate',
                            height: 42,
                            icon: Icons.qr_code_2_rounded,
                            onPressed: _loadQr,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionHeader(title: 'Recent Counter Check-Ins (${_todayRedemptions.length})'),
              const SizedBox(height: 8),
              if (_todayRedemptions.isEmpty)
                const CardSurface(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'No counter QR scans recorded today yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                  ),
                )
              else
                ..._todayRedemptions.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CardSurface(
                        padding: const EdgeInsets.all(13),
                        child: Row(
                          children: [
                            SlotIconTile(slot: r['slot']?.toString() ?? 'LUNCH', size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['customer_name']?.toString() ?? 'Subscriber',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                                  ),
                                  Text(
                                    r['slot']?.toString() ?? 'LUNCH',
                                    style: const TextStyle(fontSize: 11.5, color: ThaliColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            const MealStatusBadge(status: 'redeemed'),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
