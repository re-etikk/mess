import 'package:flutter/material.dart';

class TextShimmer extends StatefulWidget {
  const TextShimmer({
    super.key,
    required this.text,
    this.style,
    this.baseColor = const Color(0xFF687382),
    this.shimmerColor = const Color(0xFFFF6B1A),
    this.duration = const Duration(milliseconds: 2000),
  });

  final String text;
  final TextStyle? style;
  final Color baseColor;
  final Color shimmerColor;
  final Duration duration;

  @override
  State<TextShimmer> createState() => _TextShimmerState();
}

class _TextShimmerState extends State<TextShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
    _colorAnim = ColorTween(
      begin: widget.baseColor,
      end: widget.shimmerColor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

    if (MediaQuery.of(context).disableAnimations) {
      return Text(widget.text, style: textStyle.copyWith(color: widget.baseColor));
    }

    return AnimatedBuilder(
      animation: _colorAnim,
      builder: (context, _) {
        return Text(
          widget.text,
          style: textStyle.copyWith(color: _colorAnim.value ?? widget.shimmerColor),
        );
      },
    );
  }
}
