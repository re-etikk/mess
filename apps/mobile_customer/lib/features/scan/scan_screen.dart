import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/data/demo_data.dart';
import '../../core/models/mess_models.dart';
import '../../core/repositories/mess_repository.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';

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
    _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode], detectionSpeed: DetectionSpeed.noDuplicates, torchEnabled: false);
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
    try {
      final redemption = await state.redeemDemoQr(payload);
      if (!mounted) return;
      await showDialog<void>(context: context, barrierDismissible: false, builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: MessColors.green, size: 44),
        title: const Text('Meal marked'),
        content: Text('${redemption.slotName} at ${redemption.providerName} has been recorded in the local demo.\n\nThe production app must use server-side QR signature verification and atomic meal redemption.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done'))],
      ));
      if (!mounted) return;
      Navigator.pop(context);
    } on RepositoryException catch (error) {
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded, color: MessColors.red, size: 40),
        title: const Text('Could not redeem meal'),
        content: Text(error.message),
        actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Try again'))],
      ));
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

  Future<void> _tryDemo() async {
    final state = AppStateScope.of(context);
    final provider = state.activeProvider ?? DemoData.providers.first;
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _handlePayload('MESS_DEMO|${provider.id}|$date|local-demo-only');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final provider = state.activeProvider ?? DemoData.providers.first;
    return Scaffold(
      backgroundColor: MessColors.navy,
      appBar: AppBar(backgroundColor: MessColors.navy, foregroundColor: Colors.white, leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded)), title: const Text('Scan mess QR', style: TextStyle(color: Colors.white)), actions: [IconButton(tooltip: _torch ? 'Turn torch off' : 'Turn torch on', onPressed: () async { await _controller.toggleTorch(); setState(() => _torch = !_torch); }, icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white))]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(22, 12, 22, 18), child: Column(children: [Text(provider.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)), const SizedBox(height: 5), const Text('Scan the daily QR displayed at the mess counter.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFD1DBE2), fontSize: 13))])),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Stack(fit: StackFit.expand, children: [
          MobileScanner(controller: _controller, onDetect: (capture) {
            final barcode = capture.barcodes.where((b) => b.rawValue != null && b.rawValue!.isNotEmpty).firstOrNull;
            if (barcode?.rawValue != null) _handlePayload(barcode!.rawValue!);
          }),
          IgnorePointer(child: CustomPaint(painter: _ScanOverlayPainter())),
          if (_processing) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: MessColors.orange))),
        ])))),
        Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 26), child: Column(children: [
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_outlined, color: Color(0xFFB8C5CF), size: 17), SizedBox(width: 7), Flexible(child: Text('Only scan the QR shown by your selected mess.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFB8C5CF), fontSize: 11.5)))]),
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: const Color(0xFF243442), borderRadius: BorderRadius.circular(11)), child: const Text('Local demo mode: the server is not connected. A scanned code is not production-verified.', style: TextStyle(color: Color(0xFFE0E6EB), fontSize: 11.5, height: 1.35), textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: TextButton.icon(onPressed: _processing ? null : _tryDemo, icon: const Icon(Icons.science_outlined, color: MessColors.orange), label: const Text('Try demo redemption', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        ])),
      ]),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = Colors.black.withOpacity(.36);
    final frame = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.width * .72, height: size.width * .72);
    final path = Path()..addRect(Offset.zero & size)..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(25)))..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dim);
    final cornerPaint = Paint()..color = MessColors.orange..strokeWidth = 5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const corner = 30.0;
    final r = frame;
    final lines = <List<Offset>>[
      [Offset(r.left, r.top + corner), Offset(r.left, r.top), Offset(r.left + corner, r.top)],
      [Offset(r.right - corner, r.top), Offset(r.right, r.top), Offset(r.right, r.top + corner)],
      [Offset(r.left, r.bottom - corner), Offset(r.left, r.bottom), Offset(r.left + corner, r.bottom)],
      [Offset(r.right - corner, r.bottom), Offset(r.right, r.bottom), Offset(r.right, r.bottom - corner)],
    ];
    for (final points in lines) { final p = Path()..moveTo(points.first.dx, points.first.dy)..lineTo(points[1].dx, points[1].dy)..lineTo(points.last.dx, points.last.dy); canvas.drawPath(p, cornerPaint); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension _FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
