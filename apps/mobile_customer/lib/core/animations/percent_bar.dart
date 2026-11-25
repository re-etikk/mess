import 'package:flutter/material.dart';

class PercentBar extends StatelessWidget {
  const PercentBar({
    super.key,
    required this.percent,
    this.width,
    this.height = 7.0,
    this.color = const Color(0xFFFF6B1A),
    this.backgroundColor,
    this.borderRadius = 6.0,
    this.showLabel = false,
  });

  final double percent;
  final double? width;
  final double height;
  final Color color;
  final Color? backgroundColor;
  final double borderRadius;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 1.0);
    final bg = backgroundColor ?? color.withOpacity(0.15);
    final r = BorderRadius.circular(borderRadius);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
              Text(
                '${(clamped * 100).toInt()}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 5),
        ],
        ClipRRect(
          borderRadius: r,
          child: Container(
            width: width ?? double.infinity,
            height: height,
            color: bg,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: clamped),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: r,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
