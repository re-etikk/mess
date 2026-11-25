import 'dart:math' as math;
import 'package:flutter/material.dart';

class SquareMorph extends StatefulWidget {
  const SquareMorph({
    super.key,
    this.size = 36.0,
    this.color = const Color(0xFFFF6B1A),
    this.duration = const Duration(milliseconds: 1400),
  });

  final double size;
  final Color color;
  final Duration duration;

  @override
  State<SquareMorph> createState() => _SquareMorphState();
}

class _SquareMorphState extends State<SquareMorph> with SingleTickerProviderStateMixin {
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
    if (MediaQuery.of(context).disableAnimations) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.size * 0.25),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic).value;
        final radius = (widget.size * 0.15) + (t * (widget.size * 0.35));
        final rotation = t * (math.pi / 2);

        return Transform.rotate(
          angle: rotation,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        );
      },
    );
  }
}
