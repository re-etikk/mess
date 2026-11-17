import 'dart:math' as math;
import 'package:flutter/material.dart';

class BouncingDots extends StatefulWidget {
  const BouncingDots({
    super.key,
    this.size = 32.0,
    this.color = const Color(0xFFFF6B1A),
    this.dotCount = 3,
    this.duration = const Duration(milliseconds: 900),
  });

  final double size;
  final Color color;
  final int dotCount;
  final Duration duration;

  @override
  State<BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<BouncingDots> with SingleTickerProviderStateMixin {
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
      final dotSize = widget.size / (widget.dotCount * 2);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.dotCount, (index) => Container(
          width: dotSize,
          height: dotSize,
          margin: EdgeInsets.symmetric(horizontal: dotSize / 3),
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        )),
      );
    }

    final dotSize = widget.size / (widget.dotCount * 1.8);
    final maxBounce = dotSize * 0.9;

    return SizedBox(
      height: widget.size * 0.7,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.dotCount, (i) {
              final offset = (i * 0.22);
              final progress = (_controller.value + offset) % 1.0;
              final bounce = math.sin(progress * math.pi);
              final y = -bounce * maxBounce;
              return Transform.translate(
                offset: Offset(0, y),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  margin: EdgeInsets.symmetric(horizontal: dotSize * 0.25),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.45 + (bounce * 0.55)),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
