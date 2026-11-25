import 'package:flutter/material.dart';

class BouncingBall extends StatefulWidget {
  const BouncingBall({
    super.key,
    this.size = 40.0,
    this.color = const Color(0xFFFF6B1A),
    this.duration = const Duration(milliseconds: 900),
  });

  final double size;
  final Color color;
  final Duration duration;

  @override
  State<BouncingBall> createState() => _BouncingBallState();
}

class _BouncingBallState extends State<BouncingBall> with SingleTickerProviderStateMixin {
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
        child: Center(
          child: Container(
            width: widget.size * 0.45,
            height: widget.size * 0.45,
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          ),
        ),
      );
    }

    final ballDiameter = widget.size * 0.38;
    final maxDrop = widget.size * 0.48;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final heightRatio = 4 * t * (1 - t);
          final yOffset = -heightRatio * maxDrop;
          final shadowScale = 0.4 + (0.6 * (1.0 - heightRatio));

          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Transform.scale(
                scaleX: shadowScale,
                scaleY: 0.5,
                child: Container(
                  width: ballDiameter * 0.85,
                  height: ballDiameter * 0.35,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.25 * shadowScale),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, yOffset - 4),
                child: Container(
                  width: ballDiameter,
                  height: ballDiameter,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
