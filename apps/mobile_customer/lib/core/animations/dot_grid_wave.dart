import 'dart:math' as math;
import 'package:flutter/material.dart';

class DotGridWave extends StatefulWidget {
  const DotGridWave({
    super.key,
    this.size = 48.0,
    this.color = const Color(0xFFFF6B1A),
    this.gridSize = 3,
    this.duration = const Duration(milliseconds: 1500),
  });

  final double size;
  final Color color;
  final int gridSize;
  final Duration duration;

  @override
  State<DotGridWave> createState() => _DotGridWaveState();
}

class _DotGridWaveState extends State<DotGridWave> with SingleTickerProviderStateMixin {
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
    final dotDiameter = (widget.size / widget.gridSize) * 0.36;

    if (MediaQuery.of(context).disableAnimations) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(widget.gridSize, (r) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.gridSize, (c) => Container(
              width: dotDiameter,
              height: dotDiameter,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
            )),
          )),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.gridSize, (r) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(widget.gridSize, (c) {
                  final dist = math.sqrt(math.pow(r - 1, 2) + math.pow(c - 1, 2));
                  final progress = (_controller.value - (dist * 0.22)) % 1.0;
                  final scale = 0.5 + (0.5 * math.sin(progress * 2 * math.pi).abs());
                  return Container(
                    width: dotDiameter * scale,
                    height: dotDiameter * scale,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.3 + (scale * 0.7)),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            }),
          );
        },
      ),
    );
  }
}
