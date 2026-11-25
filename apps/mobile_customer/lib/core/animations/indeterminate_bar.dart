import 'package:flutter/material.dart';

class IndeterminateBar extends StatefulWidget {
  const IndeterminateBar({
    super.key,
    this.width,
    this.height = 4.0,
    this.color = const Color(0xFFFF6B1A),
    this.backgroundColor,
    this.borderRadius = 4.0,
    this.duration = const Duration(milliseconds: 1400),
  });

  final double? width;
  final double height;
  final Color color;
  final Color? backgroundColor;
  final double borderRadius;
  final Duration duration;

  @override
  State<IndeterminateBar> createState() => _IndeterminateBarState();
}

class _IndeterminateBarState extends State<IndeterminateBar> with SingleTickerProviderStateMixin {
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
    final bg = widget.backgroundColor ?? widget.color.withOpacity(0.18);
    final r = BorderRadius.circular(widget.borderRadius);

    if (MediaQuery.of(context).disableAnimations) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: widget.color, borderRadius: r),
      );
    }

    return ClipRRect(
      borderRadius: r,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: bg,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return FractionallySizedBox(
              alignment: Alignment(-1.5 + (_controller.value * 3.0), 0),
              widthFactor: 0.35,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: r,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
