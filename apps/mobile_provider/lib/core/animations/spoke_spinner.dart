import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpokeSpinner extends StatefulWidget {
  const SpokeSpinner({
    super.key,
    this.size = 32.0,
    this.color = const Color(0xFFFF6B1A),
    this.spokeCount = 8,
    this.duration = const Duration(milliseconds: 900),
  });

  final double size;
  final Color color;
  final int spokeCount;
  final Duration duration;

  @override
  State<SpokeSpinner> createState() => _SpokeSpinnerState();
}

class _SpokeSpinnerState extends State<SpokeSpinner> with SingleTickerProviderStateMixin {
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
        child: CircularProgressIndicator(strokeWidth: 2.5, color: widget.color),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _SpokeSpinnerPainter(
              progress: _controller.value,
              color: widget.color,
              spokeCount: widget.spokeCount,
            ),
          );
        },
      ),
    );
  }
}

class _SpokeSpinnerPainter extends CustomPainter {
  _SpokeSpinnerPainter({
    required this.progress,
    required this.color,
    required this.spokeCount,
  });

  final double progress;
  final Color color;
  final int spokeCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final minRadius = maxRadius * 0.52;
    final spokeThickness = size.width * 0.085;

    final activeIndex = (progress * spokeCount).floor() % spokeCount;

    for (int i = 0; i < spokeCount; i++) {
      final angle = (i * 2 * math.pi) / spokeCount;
      final diff = (i - activeIndex + spokeCount) % spokeCount;
      final opacity = 0.2 + (0.8 * (1.0 - (diff / spokeCount)));

      final paint = Paint()
        ..color = color.withOpacity(opacity.clamp(0.15, 1.0))
        ..strokeWidth = spokeThickness
        ..strokeCap = StrokeCap.round;

      final start = Offset(center.dx + (minRadius * math.cos(angle)), center.dy + (minRadius * math.sin(angle)));
      final end = Offset(center.dx + (maxRadius * math.cos(angle)), center.dy + (maxRadius * math.sin(angle)));

      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpokeSpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
