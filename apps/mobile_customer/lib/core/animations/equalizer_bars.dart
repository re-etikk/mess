import 'dart:math' as math;
import 'package:flutter/material.dart';

class EqualizerBars extends StatefulWidget {
  const EqualizerBars({
    super.key,
    this.size = 36.0,
    this.color = const Color(0xFFFF6B1A),
    this.barCount = 4,
    this.duration = const Duration(milliseconds: 1000),
  });

  final double size;
  final Color color;
  final int barCount;
  final Duration duration;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars> with SingleTickerProviderStateMixin {
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.barCount, (i) => Container(
            width: (widget.size / widget.barCount) * 0.5,
            height: widget.size * (0.3 + (i * 0.2)),
            decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(3)),
          )),
        ),
      );
    }

    final barWidth = (widget.size / widget.barCount) * 0.45;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (i) {
              final phase = (i * 0.7);
              final val = (math.sin((_controller.value * 2 * math.pi) + phase).abs() * 0.75) + 0.25;
              final barHeight = widget.size * val;
              return Container(
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(barWidth / 2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
