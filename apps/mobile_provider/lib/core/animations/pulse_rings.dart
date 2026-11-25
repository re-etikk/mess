import 'dart:math' as math;
import 'package:flutter/material.dart';

class PulseRings extends StatefulWidget {
  const PulseRings({
    super.key,
    this.size = 64.0,
    this.color = const Color(0xFFFF6B1A),
    this.ringCount = 3,
    this.duration = const Duration(milliseconds: 1800),
    this.strokeWidth = 2.0,
  });

  final double size;
  final Color color;
  final int ringCount;
  final Duration duration;
  final double strokeWidth;

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings> with SingleTickerProviderStateMixin {
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
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.color.withOpacity(0.5), width: widget.strokeWidth),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _PulseRingsPainter(
              progress: _controller.value,
              color: widget.color,
              ringCount: widget.ringCount,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _PulseRingsPainter extends CustomPainter {
  _PulseRingsPainter({
    required this.progress,
    required this.color,
    required this.ringCount,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final int ringCount;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;
    if (maxRadius <= 0) return;

    for (int i = 0; i < ringCount; i++) {
      final ringProgress = (progress + (i / ringCount)) % 1.0;
      final radius = ringProgress * maxRadius;
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulseRingsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
