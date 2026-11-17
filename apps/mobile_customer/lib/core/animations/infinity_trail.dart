import 'dart:math' as math;
import 'package:flutter/material.dart';

class InfinityTrail extends StatefulWidget {
  const InfinityTrail({
    super.key,
    this.size = 52.0,
    this.color = const Color(0xFFFF6B1A),
    this.strokeWidth = 3.0,
    this.duration = const Duration(milliseconds: 2200),
  });

  final double size;
  final Color color;
  final double strokeWidth;
  final Duration duration;

  @override
  State<InfinityTrail> createState() => _InfinityTrailState();
}

class _InfinityTrailState extends State<InfinityTrail> with SingleTickerProviderStateMixin {
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
        height: widget.size * 0.55,
        child: CustomPaint(
          painter: _InfinityStaticPainter(
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size * 0.55,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _InfinityTrailPainter(
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

class _InfinityStaticPainter extends CustomPainter {
  _InfinityStaticPainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= 0 || size.height <= 0) return;
    final path = _buildLemniscatePath(size);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _InfinityStaticPainter oldDelegate) => false;
}

class _InfinityTrailPainter extends CustomPainter {
  _InfinityTrailPainter({
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
    final trackPath = _buildLemniscatePath(size);
    final trackPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.75
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(trackPath, trackPaint);

    final t = progress * 2 * math.pi;
    final a = (size.width * 0.44);
    final denom = 1 + math.pow(math.sin(t), 2);
    final x = (size.width / 2) + ((a * math.cos(t)) / denom);
    final y = (size.height / 2) + ((a * math.sin(t) * math.cos(t)) / denom);

    final glowPaint = Paint()..color = color.withOpacity(0.4);
    canvas.drawCircle(Offset(x, y), strokeWidth * 2.2, glowPaint);

    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(x, y), strokeWidth * 1.3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _InfinityTrailPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

Path _buildLemniscatePath(Size size) {
  final path = Path();
  if (size.width <= 0 || size.height <= 0) return path;
  final a = size.width * 0.44;
  final center = Offset(size.width / 2, size.height / 2);

  for (double t = 0; t <= 2 * math.pi; t += 0.05) {
    final denom = 1 + math.pow(math.sin(t), 2);
    final x = center.dx + ((a * math.cos(t)) / denom);
    final y = center.dy + ((a * math.sin(t) * math.cos(t)) / denom);
    if (t == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}
