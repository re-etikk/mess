import 'dart:math' as math;
import 'package:flutter/material.dart';

class TypingDots extends StatefulWidget {
  const TypingDots({
    super.key,
    this.size = 32.0,
    this.dotColor = const Color(0xFFFF6B1A),
    this.bubbleColor,
    this.duration = const Duration(milliseconds: 1200),
  });

  final double size;
  final Color dotColor;
  final Color? bubbleColor;
  final Duration duration;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
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
    final bg = widget.bubbleColor ?? const Color(0xFFFBF6EE);
    final dotSize = widget.size * 0.18;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: widget.size * 0.35, vertical: widget.size * 0.22),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(widget.size * 0.4),
        border: Border.all(color: const Color(0xFFE9E0D5)),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_controller.value - (i * 0.18)) % 1.0;
              final bounce = math.sin(t * math.pi).clamp(0.0, 1.0);
              return Container(
                width: dotSize,
                height: dotSize,
                margin: EdgeInsets.symmetric(horizontal: dotSize * 0.3),
                transform: Matrix4.translationValues(0, -bounce * (dotSize * 0.8), 0),
                decoration: BoxDecoration(
                  color: widget.dotColor.withOpacity(0.4 + (bounce * 0.6)),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
