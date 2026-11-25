import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/models/mess_models.dart';
import '../../core/repositories/mess_repository.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../checkout/create_subscription_screen.dart';
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
      } else if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
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
    final providerName = provider?.name ?? 'Kitchen Counter';
    final subscription = state.activeSubscription;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThaliColors.stroke,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThaliColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: ThaliColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Confirm Meal Check-in',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17.5, color: ThaliColors.ink),
                        ),
                        Text(
                          'Redeem today\'s meal attendance at the counter',
                          style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CardSurface(
                color: ThaliColors.scaffold,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            providerName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: ThaliColors.ink),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ThaliColors.greenSoft,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: ThaliColors.greenBorder),
                          ),
                          child: const Text(
                            'COUNTER QR',
                            style: TextStyle(color: ThaliColors.greenDark, fontWeight: FontWeight.w700, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    if (subscription != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Pass: ${subscription.planName}${subscription.mealsRemaining != null ? ' (${subscription.mealsRemaining} meals left)' : ''}',
                        style: const TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MessActionButton(
                      label: 'Cancel',
                      secondary: true,
                      height: 48,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: MessActionButton(
                      label: 'Confirm Check-in',
                      height: 48,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) {
      if (!mounted) return;
      setState(() => _processing = false);
      await _controller.start();
      return;
    }

    try {
      final redemption = await state.redeemMealQr(payload);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: ThaliColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.check_circle_rounded, color: ThaliColors.green, size: 48),
          title: const Text(
            'Meal Verified & Redeemed',
            style: TextStyle(fontWeight: FontWeight.w800, color: ThaliColors.ink),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${redemption.slotName} at ${redemption.providerName}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: ThaliColors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                redemption.status,
                style: const TextStyle(color: ThaliColors.muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            MessActionButton(
              label: 'Done',
              height: 46,
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on RepositoryException catch (error) {
      if (!mounted) return;
      if (error.code == 'no_entitlement') {
        await _showSubscriptionRequiredModal(context, provider, error.message);
      } else if (error.code == 'duplicate_redemption') {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: ThaliColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(Icons.info_outline_rounded, color: ThaliColors.amber, size: 44),
            title: const Text('Already Redeemed', style: TextStyle(fontWeight: FontWeight.w800)),
            content: Text(error.message, textAlign: TextAlign.center),
            actions: [
              MessActionButton(
                label: 'Understood',
                height: 44,
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: ThaliColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(Icons.error_outline_rounded, color: ThaliColors.red, size: 42),
            title: const Text('Could Not Redeem Meal', style: TextStyle(fontWeight: FontWeight.w800)),
            content: Text(error.message, textAlign: TextAlign.center),
            actions: [
              MessActionButton(
                label: 'Try Again',
                height: 44,
                onPressed: () => Navigator.pop(dialogContext),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not verify this QR code. Please scan again.')),
      );
    }
  }

  Future<void> _enterTokenManually() async {
    final ctrl = TextEditingController();
    final token = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
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
            const Text(
              'Enter Kitchen QR Token',
              style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Paste or type the daily counter code shown by the mess staff.',
              style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'Counter QR payload or token'),
            ),
            const SizedBox(height: 14),
            MessActionButton(
              label: 'Verify Token',
              onPressed: () {
                final val = ctrl.text.trim();
                if (val.isNotEmpty) Navigator.pop(ctx, val);
              },
            ),
          ],
        ),
      ),
    );
    if (token != null && token.isNotEmpty && mounted) {
      await _handlePayload(token);
    }
  }

  Future<void> _showSubscriptionRequiredModal(BuildContext context, MessProvider? provider, String message) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThaliColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: ThaliColors.primarySoft,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(Icons.lock_outline_rounded, color: ThaliColors.primary, size: 28),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No Active Subscription',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ThaliColors.ink),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: ThaliColors.muted, height: 1.45),
              ),
              const SizedBox(height: 20),
              MessActionButton(
                label: 'View Plans & Subscribe',
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.pop(context);
                  if (provider != null) {
                    Navigator.push(context, messRoute(CreateSubscriptionScreen(provider: provider)));
                  } else {
                    Navigator.push(context, messRoute(const PlansScreen()));
                  }
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cancel', style: TextStyle(color: ThaliColors.muted)),
              ),
            ],
          ),
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
      backgroundColor: ThaliColors.ink,
      appBar: AppBar(
        backgroundColor: ThaliColors.ink,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
        title: const Text('Scan Counter QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Align the kitchen counter QR inside the orange frame to check in for your meal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFD4D4D8), fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: (capture) {
                        final barcode = capture.barcodes
                            .where((b) => b.rawValue != null && b.rawValue!.isNotEmpty)
                            .firstOrNull;
                        if (barcode?.rawValue != null) {
                          _handlePayload(barcode!.rawValue!);
                        }
                      },
                    ),
                    IgnorePointer(child: CustomPaint(painter: _ScanOverlayPainter())),
                    if (_processing)
                      Container(
                        color: Colors.black54,
                        child: const ThaliLoadingView(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
            child: Column(
              children: [
                TextButton.icon(
                  onPressed: _enterTokenManually,
                  icon: const Icon(Icons.keyboard_outlined, color: Colors.white, size: 18),
                  label: const Text(
                    'Enter counter code manually',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_outlined, color: Color(0xFFA1A1AA), size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Verified counter attendance · Valid for today\'s active slot',
                      style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.42);
    final frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.72,
      height: size.width * 0.72,
    );
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dim);

    final cornerPaint = Paint()
      ..color = ThaliColors.primary
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
    for (final pts in lines) {
      final p = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(p, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
