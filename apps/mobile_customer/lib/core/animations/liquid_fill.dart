import 'dart:math' as math;
import 'package:flutter/material.dart';

class LiquidFill extends StatefulWidget {
  const LiquidFill({
    super.key,
    this.size = 72.0,
    required this.fillPercent,
    this.color = const Color(0xFFFF6B1A),
    this.backgroundColor,
    this.centerText,
    this.duration = const Duration(milliseconds: 2000),
  });

  final double size;
  final double fillPercent;
  final Color color;
  final Color? backgroundColor;
  final String? centerText;
  final Duration duration;

  @override
  State<LiquidFill> createState() => _LiquidFillState();
}

class _LiquidFillState extends State<LiquidFill> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clampedFill = widget.fillPercent.clamp(0.0, 1.0);
    final bg = widget.backgroundColor ?? widget.color.withOpacity(0.12);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: widget.color.withOpacity(0.3), width: 2.0),
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!MediaQuery.of(context).disableAnimations)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _LiquidWavePainter(
                      wavePhase: _controller.value * 2 * math.pi,
                      fillPercent: clampedFill,
                      color: widget.color,
                    ),
                  );
                },
              )
            else
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: widget.size * clampedFill,
                  color: widget.color,
                ),
              ),
            if (widget.centerText != null)
              Text(
                widget.centerText!,
                style: TextStyle(
                  fontSize: widget.size * 0.22,
                  fontWeight: FontWeight.w800,
                  color: clampedFill > 0.5 ? Colors.white : widget.color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiquidWavePainter extends CustomPainter {
  _LiquidWavePainter({
    required this.wavePhase,
    required this.fillPercent,
    required this.color,
  });

  final double wavePhase;
  final double fillPercent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (fillPercent <= 0.0 || size.isEmpty || size.width <= 0 || size.height <= 0) return;

    final baseHeight = size.height * (1.0 - fillPercent);
    final waveAmplitude = size.height * 0.045 * (fillPercent < 0.95 && fillPercent > 0.05 ? 1.0 : 0.2);

    final path = Path()..moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 1.0) {
      final y = baseHeight + (math.sin((x / size.width * 2 * math.pi) + wavePhase) * waveAmplitude);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    final paint = Paint()
      ..color = color.withOpacity(0.88)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidWavePainter oldDelegate) =>
      oldDelegate.wavePhase != wavePhase || oldDelegate.fillPercent != fillPercent;
}
