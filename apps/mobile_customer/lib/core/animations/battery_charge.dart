import 'package:flutter/material.dart';

class BatteryCharge extends StatefulWidget {
  const BatteryCharge({
    super.key,
    this.size = 38.0,
    this.chargePercent = 0.75,
    this.color = const Color(0xFFFF6B1A),
    this.isCharging = true,
    this.duration = const Duration(milliseconds: 1400),
  });

  final double size;
  final double chargePercent;
  final Color color;
  final bool isCharging;
  final Duration duration;

  @override
  State<BatteryCharge> createState() => _BatteryChargeState();
}

class _BatteryChargeState extends State<BatteryCharge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.size;
    final height = widget.size * 0.52;

    return SizedBox(
      width: width,
      height: height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final pulse = widget.isCharging && !MediaQuery.of(context).disableAnimations
              ? 0.75 + (_controller.value * 0.25)
              : 1.0;

          return CustomPaint(
            painter: _BatteryPainter(
              chargePercent: widget.chargePercent,
              color: widget.color.withOpacity(pulse),
            ),
          );
        },
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter({required this.chargePercent, required this.color});
  final double chargePercent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= 0 || size.height <= 0) return;
    final bodyWidth = size.width * 0.88;
    final terminalWidth = size.width * 0.10;
    final stroke = size.height * 0.1;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bodyWidth, size.height),
      Radius.circular(size.height * 0.2),
    );

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawRRect(bodyRect, borderPaint);

    final terminalRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyWidth + 1.5, size.height * 0.3, terminalWidth, size.height * 0.4),
      Radius.circular(size.height * 0.1),
    );
    final terminalPaint = Paint()..color = color;
    canvas.drawRRect(terminalRect, terminalPaint);

    final innerWidth = (bodyWidth - (stroke * 2) - 4) * chargePercent.clamp(0.0, 1.0);
    if (innerWidth > 0) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(stroke + 2, stroke + 2, innerWidth, size.height - (stroke * 2) - 4),
        Radius.circular(size.height * 0.12),
      );
      final fillPaint = Paint()..color = color;
      canvas.drawRRect(fillRect, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) =>
      oldDelegate.chargePercent != chargePercent || oldDelegate.color != color;
}
