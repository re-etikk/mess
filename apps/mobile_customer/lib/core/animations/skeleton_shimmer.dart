import 'package:flutter/material.dart';

class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer> with SingleTickerProviderStateMixin {
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
    final base = widget.baseColor ?? const Color(0xFFE9E0D5).withOpacity(0.7);
    final highlight = widget.highlightColor ?? const Color(0xFFFFFFFF).withOpacity(0.9);

    if (MediaQuery.of(context).disableAnimations) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: widget.borderRadius),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.8 + (_controller.value * 3.6), -0.3),
              end: Alignment(-0.2 + (_controller.value * 3.6), 0.3),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
