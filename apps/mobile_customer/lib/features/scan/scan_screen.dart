import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/models/mess_models.dart';
import '../../core/repositories/mess_repository.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../checkout/checkout_screen.dart';
import '../plans/plans_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _processing = false;
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
      torchEnabled: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_processing) {
      if (state == AppLifecycleState.resumed) {
        _controller.start();
      } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handlePayload(String payload) async {
    if (_processing) return;
    setState(() => _processing = true);
    await _controller.stop();
    if (!mounted) return;
    final state = AppStateScope.of(context);
    final provider = state.activeProvider;
    final providerName = provider?.name ?? 'Selected Mess';
    final subscription = state.activeSubscription;

    // Show dual confirmation prompt before finalizing meal check-in
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFFE8C5), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.qr_code_scanner, color: MessColors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Confirm Meal Check-in', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: MessColors.ink)),
                      Text('Verify meal attendance redemption at counter', style: TextStyle(fontSize: 12, color: MessColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MessColors.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MessColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(providerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: MessColors.ink)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: MessColors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: const Text('VERIFIED COUNTER', style: TextStyle(color: MessColors.green, fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subscription != null
                        ? 'Plan: ${subscription.planName} · ${subscription.mealsRemaining != null ? "${subscription.mealsRemaining} meals remaining" : "Unlimited Access"}'
                        : 'Single meal check-in / daily meal pass',
                    style: const TextStyle(fontSize: 12, color: MessColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: MessColors.border),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: MessColors.ink, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirm & Check-in'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MessColors.orange,
                      foregroundColor: MessColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      setState(() => _processing = false);
      _controller.start();
      return;
    }

    try {
      final redemption = await state.redeemMealQr(payload);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: MessColors.green, size: 48),
          title: const Text('Meal Verified & Redeemed!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${redemption.slotName} at ${redemption.providerName}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: MessColors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                redemption.status,
                style: const TextStyle(color: MessColors.muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(backgroundColor: MessColors.orange, foregroundColor: MessColors.ink),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on RepositoryException catch (error) {
      if (!mounted) return;

      if (error.code == 'no_entitlement') {
        // Show actionable modal for missing subscription
        await _showSubscriptionRequiredModal(context, provider, error.message);
      } else if (error.code == 'duplicate_redemption') {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: MessColors.orange, size: 44),
            title: const Text('Already Redeemed'),
            content: Text(error.message, textAlign: TextAlign.center),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.error_outline_rounded, color: MessColors.red, size: 40),
            title: const Text('Could Not Redeem Meal'),
            content: Text(error.message, textAlign: TextAlign.center),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
      }

      if (!mounted) return;
      setState(() => _processing = false);
      await _controller.start();
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      await _controller.start();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not process this QR. Please try again.')));
    }
  }

  Future<void> _showSubscriptionRequiredModal(BuildContext context, MessProvider? provider, String message) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0D8),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(Icons.lock_outline_rounded, color: MessColors.orange, size: 30),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Active Subscription',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: MessColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have an active plan or daily pass for this mess.\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF68737D), height: 1.45),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.pop(context); // close scanner
                Navigator.push(
                  context,
                  messRoute(PlansScreen(provider: provider)),
                );
              },
              icon: const Icon(Icons.star_outline, size: 18),
              label: const Text('View Plans & Subscribe', style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: MessColors.orange,
                foregroundColor: MessColors.ink,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                if (provider != null) {
                  final dailyPlan = provider.plans.where((p) => p.type == SubscriptionType.dailyMeal).firstOrNull ??
                      provider.plans.first;
                  Navigator.pop(context); // close scanner
                  Navigator.push(
                    context,
                    messRoute(CheckoutScreen(provider: provider, plan: dailyPlan)),
                  );
                }
              },
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('Buy Single Meal Pass (₹95)', style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: MessColors.orange),
                foregroundColor: MessColors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF68737D))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final provider = state.activeProvider;
    final title = provider != null ? provider.name : 'Counter QR';

    return Scaffold(
      backgroundColor: MessColors.navy,
      appBar: AppBar(
        backgroundColor: MessColors.navy,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Scan Mess QR', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: _torch ? 'Turn torch off' : 'Turn torch on',
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _torch = !_torch);
            },
            icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
          child: Column(children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 5),
            const Text('Scan the daily QR code displayed at the mess counter to redeem your meal.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFD1DBE2), fontSize: 13)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(fit: StackFit.expand, children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final barcode = capture.barcodes.where((b) => b.rawValue != null && b.rawValue!.isNotEmpty).firstOrNull;
                    if (barcode?.rawValue != null) _handlePayload(barcode!.rawValue!);
                  },
                ),
                IgnorePointer(child: CustomPaint(painter: _ScanOverlayPainter())),
                if (_processing)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator(color: MessColors.orange)),
                  ),
              ]),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFB8C5CF), size: 17),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Verified counter redemption · Token valid for today only.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB8C5CF), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = Colors.black.withOpacity(.36);
    final frame = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.width * .72, height: size.width * .72);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(25)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dim);
    final cornerPaint = Paint()
      ..color = MessColors.orange
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const corner = 30.0;
    final r = frame;
    final lines = <List<Offset>>[
      [Offset(r.left, r.top + corner), Offset(r.left, r.top), Offset(r.left + corner, r.top)],
      [Offset(r.right - corner, r.top), Offset(r.right, r.top), Offset(r.right, r.top + corner)],
      [Offset(r.left, r.bottom - corner), Offset(r.left, r.bottom), Offset(r.left + corner, r.bottom)],
      [Offset(r.right - corner, r.bottom), Offset(r.right, r.bottom), Offset(r.right, r.bottom - corner)],
    ];
    for (final points in lines) {
      final p = Path()
        ..moveTo(points.first.dx, points.first.dy)
        ..lineTo(points[1].dx, points[1].dy)
        ..lineTo(points.last.dx, points.last.dy);
      canvas.drawPath(p, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
