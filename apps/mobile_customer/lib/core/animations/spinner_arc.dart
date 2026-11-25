import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpinnerArc extends StatefulWidget {
  const SpinnerArc({
    super.key,
    this.size = 36.0,
    this.color = const Color(0xFFE95F35),
    this.strokeWidth = 3.5,
    this.duration = const Duration(milliseconds: 1000),
  });

  final double size;
  final Color color;
  final double strokeWidth;
  final Duration duration;

  @override
  State<SpinnerArc> createState() => _SpinnerArcState();
}

class _SpinnerArcState extends State<SpinnerArc> with SingleTickerProviderStateMixin {
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
    if (MediaQuery.of(context).disableAnimations) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(
          strokeWidth: widget.strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(widget.color),
          value: 0.75,
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _SpinnerArcPainter(
              progress: _controller.value,
              color: widget.color,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _SpinnerArcPainter extends CustomPainter {
  _SpinnerArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final startAngle = progress * 2 * math.pi;
    const sweepAngle = math.pi * 1.35;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinnerArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
