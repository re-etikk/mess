import 'dart:math' as math;
import 'package:flutter/material.dart';

class GradientRing extends StatefulWidget {
  const GradientRing({
    super.key,
    this.size = 44.0,
    this.colors,
    this.strokeWidth = 3.5,
    this.duration = const Duration(milliseconds: 1400),
  });

  final double size;
  final List<Color>? colors;
  final double strokeWidth;
  final Duration duration;

  @override
  State<GradientRing> createState() => _GradientRingState();
}

class _GradientRingState extends State<GradientRing> with SingleTickerProviderStateMixin {
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
    final ringColors = widget.colors ?? [
      const Color(0xFFFF6B1A),
      const Color(0xFFFFF0E5),
      const Color(0xFFFF6B1A),
    ];

    if (MediaQuery.of(context).disableAnimations) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ringColors.first, width: widget.strokeWidth),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Transform.rotate(
            angle: _controller.value * 2 * math.pi,
            child: CustomPaint(
              painter: _GradientRingPainter(
                colors: ringColors,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  _GradientRingPainter({required this.colors, required this.strokeWidth});
  final List<Color> colors;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= 0 || size.height <= 0) return;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..shader = SweepGradient(colors: colors).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) => false;
}
