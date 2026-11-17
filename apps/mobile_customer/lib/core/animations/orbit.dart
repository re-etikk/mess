import 'dart:math' as math;
import 'package:flutter/material.dart';

class Orbit extends StatefulWidget {
  const Orbit({
    super.key,
    this.size = 40.0,
    this.color = const Color(0xFFFF6B1A),
    this.dotRadius = 3.5,
    this.duration = const Duration(milliseconds: 1600),
  });

  final double size;
  final Color color;
  final double dotRadius;
  final Duration duration;

  @override
  State<Orbit> createState() => _OrbitState();
}

class _OrbitState extends State<Orbit> with SingleTickerProviderStateMixin {
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
        child: Center(
          child: Container(
            width: widget.dotRadius * 2.5,
            height: widget.dotRadius * 2.5,
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          ),
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
            painter: _OrbitPainter(
              progress: _controller.value,
              color: widget.color,
              dotRadius: widget.dotRadius,
            ),
          );
        },
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.progress,
    required this.color,
    required this.dotRadius,
  });

  final double progress;
  final Color color;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbitRadius = (math.min(size.width, size.height) / 2) - dotRadius - 2;

    final centerPaint = Paint()..color = color.withOpacity(0.9);
    canvas.drawCircle(center, dotRadius * 1.5, centerPaint);

    final pathPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, orbitRadius, pathPaint);

    final angle = progress * 2 * math.pi;
    final sat1 = Offset(
      center.dx + (orbitRadius * math.cos(angle)),
      center.dy + (orbitRadius * math.sin(angle)),
    );
    final satPaint1 = Paint()..color = color;
    canvas.drawCircle(sat1, dotRadius, satPaint1);

    final sat2 = Offset(
      center.dx + (orbitRadius * math.cos(angle + math.pi)),
      center.dy + (orbitRadius * math.sin(angle + math.pi)),
    );
    final satPaint2 = Paint()..color = color.withOpacity(0.5);
    canvas.drawCircle(sat2, dotRadius * 0.75, satPaint2);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
