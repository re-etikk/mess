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
    final textStyle = widget.style ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

    if (MediaQuery.of(context).disableAnimations) {
      return Text(widget.text, style: textStyle.copyWith(color: widget.baseColor));
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.5 + (_controller.value * 3.0), 0),
              end: Alignment(-0.5 + (_controller.value * 3.0), 0),
              colors: [widget.baseColor, widget.shimmerColor, widget.baseColor],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: Text(widget.text, style: textStyle),
        );
      },
    );
  }
}
