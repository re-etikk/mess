import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/mess_models.dart';
import '../theme/mess_theme.dart';

class MessLogo extends StatelessWidget {
  const MessLogo({super.key, this.compact = false, this.light = false});
  final bool compact;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final ink = light ? Colors.white : MessColors.navy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: compact ? 35 : 43,
          height: compact ? 35 : 43,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(bottom: 2, child: Container(width: compact ? 31 : 39, height: 4, decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(2)))),
              Positioned(bottom: 6, child: Icon(Icons.room_service_rounded, size: compact ? 29 : 35, color: MessColors.orange)),
              Positioned(top: 0, right: 4, child: Icon(Icons.local_fire_department_rounded, size: compact ? 16 : 19, color: MessColors.orangeDark)),
              Positioned(top: 2, left: 3, child: Icon(Icons.eco_rounded, size: compact ? 10 : 12, color: const Color(0xFF47834A))),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text('MESS', style: TextStyle(fontSize: compact ? 21 : 25, fontWeight: FontWeight.w900, letterSpacing: -1.2, color: ink)),
      ],
    );
  }
}

class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.onTap, required this.child, this.borderRadius, this.enabled = true});
  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.enabled && widget.onTap != null
          ? () { HapticFeedback.selectionClick(); widget.onTap!(); }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 115),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class MessActionButton extends StatelessWidget {
  const MessActionButton({super.key, required this.label, required this.onPressed, this.icon, this.secondary = false, this.loading = false, this.height = 50});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = secondary ? Colors.white : MessColors.orange;
    final fg = secondary ? MessColors.navy : MessColors.navy;
    return PressScale(
      onTap: loading ? null : onPressed,
      enabled: onPressed != null && !loading,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(13),
          border: secondary ? Border.all(color: MessColors.border) : null,
          boxShadow: secondary ? null : const [BoxShadow(color: Color(0x1AE18A13), blurRadius: 12, offset: Offset(0, 5))],
        ),
        child: loading
            ? SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
            : Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 9)],
                Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: fg)),
              ]),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.actionLabel, this.onAction, this.subtitle});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)]])),
          if (actionLabel != null) PressScale(onTap: onAction, child: Padding(padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(actionLabel!, style: const TextStyle(color: MessColors.orangeDark, fontWeight: FontWeight.w700, fontSize: 13)), const SizedBox(width: 3), const Icon(Icons.arrow_forward_ios_rounded, color: MessColors.orangeDark, size: 13)]))),
        ],
      );
}

class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.label, required this.color, this.background});
  final String label;
  final Color color;
  final Color? background;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: background ?? color.withOpacity(.10), borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 64, height: 64, decoration: const BoxDecoration(color: Color(0xFFFFEBCB), shape: BoxShape.circle), child: Icon(icon, size: 29, color: MessColors.orangeDark)),
          const SizedBox(height: 15),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MessColors.muted)),
          if (actionLabel != null) ...[const SizedBox(height: 18), SizedBox(width: 220, child: MessActionButton(label: actionLabel!, onPressed: onAction))],
        ]),
      );
}

class FoodGlyph extends StatelessWidget {
  const FoodGlyph({super.key, required this.name, this.size = 48, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    IconData icon;
    final lower = name.toLowerCase();
    if (lower.contains('paneer') || lower.contains('sabzi') || lower.contains('curry')) {
      icon = Icons.ramen_dining_rounded;
    } else if (lower.contains('rice') || lower.contains('dal')) {
      icon = Icons.rice_bowl_rounded;
    } else if (lower.contains('roti') || lower.contains('paratha')) {
      icon = Icons.breakfast_dining_rounded;
    } else if (lower.contains('tea')) {
      icon = Icons.emoji_food_beverage_rounded;
    } else {
      icon = Icons.restaurant_rounded;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: const Color(0xFFFFE8BF), borderRadius: BorderRadius.circular(size * .22)),
      child: Icon(icon, size: size * .52, color: color ?? MessColors.orangeDark),
    );
  }
}

class PriceText extends StatelessWidget {
  const PriceText({super.key, required this.amount, this.suffix});
  final int amount;
  final String? suffix;
  @override
  Widget build(BuildContext context) => RichText(text: TextSpan(style: const TextStyle(color: MessColors.navy, fontWeight: FontWeight.w800, fontSize: 18), children: [TextSpan(text: '₹$amount'), if (suffix != null) TextSpan(text: ' $suffix', style: const TextStyle(fontSize: 12, color: MessColors.muted, fontWeight: FontWeight.w500))]));
}

class CardSurface extends StatelessWidget {
  const CardSurface({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.color = Colors.white, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  final Color? borderColor;
  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        enabled: onTap != null,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor ?? MessColors.border.withOpacity(.7)), boxShadow: const [BoxShadow(color: Color(0x080D1722), blurRadius: 14, offset: Offset(0, 5))]),
          child: child,
        ),
      );
}

Route<T> messRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: curved, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.035, 0), end: Offset.zero).animate(curved), child: child));
      },
    );

String formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:${date.minute.toString().padLeft(2, '0')} $suffix';
}

String rupee(int amount) => '₹${amount.toString()}';
