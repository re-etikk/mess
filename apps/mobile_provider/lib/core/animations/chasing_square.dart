import 'package:flutter/material.dart';

class ChasingSquare extends StatefulWidget {
  const ChasingSquare({
    super.key,
    this.size = 40.0,
    this.color = const Color(0xFFFF6B1A),
    this.strokeWidth = 2.5,
    this.duration = const Duration(milliseconds: 1600),
  });

  final double size;
  final Color color;
  final double strokeWidth;
  final Duration duration;

  @override
  State<ChasingSquare> createState() => _ChasingSquareState();
}

class _ChasingSquareState extends State<ChasingSquare> with SingleTickerProviderStateMixin {
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
          border: Border.all(color: widget.color, width: widget.strokeWidth),
          borderRadius: BorderRadius.circular(6),
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
            painter: _ChasingSquarePainter(
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

class _ChasingSquarePainter extends CustomPainter {
  _ChasingSquarePainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= strokeWidth * 2 || size.height <= strokeWidth * 2) return;
    final rect = (Offset.zero & size).deflate(strokeWidth);
    final borderPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.6;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), borderPaint);

    final perimeter = 4 * rect.width;
    final currentDist = progress * perimeter;
    final side = rect.width;

    double x = rect.left;
    double y = rect.top;

    if (currentDist < side) {
      x = rect.left + currentDist;
      y = rect.top;
    } else if (currentDist < side * 2) {
      x = rect.right;
      y = rect.top + (currentDist - side);
    } else if (currentDist < side * 3) {
      x = rect.right - (currentDist - (side * 2));
      y = rect.bottom;
    } else {
      x = rect.left;
      y = rect.bottom - (currentDist - (side * 3));
    }

    final squareSize = strokeWidth * 2.8;
    final chaserPaint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: squareSize, height: squareSize),
        const Radius.circular(2),
      ),
      chaserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChasingSquarePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
