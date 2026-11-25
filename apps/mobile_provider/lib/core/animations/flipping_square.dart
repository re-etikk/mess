import 'dart:math' as math;
import 'package:flutter/material.dart';

class FlippingSquare extends StatefulWidget {
  const FlippingSquare({
    super.key,
    this.size = 36.0,
    this.color = const Color(0xFFFF6B1A),
    this.duration = const Duration(milliseconds: 1200),
  });

  final double size;
  final Color color;
  final Duration duration;

  @override
  State<FlippingSquare> createState() => _FlippingSquareState();
}

class _FlippingSquareState extends State<FlippingSquare> with SingleTickerProviderStateMixin {
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
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.size * 0.2),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final angleY = t * 2 * math.pi;

        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateY(angleY);

        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(widget.size * 0.2),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
