import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../animations/thali_animations.dart';
import '../theme/thali_partner_theme.dart';

/// Cleaned Thali logo mark (NO "MESS" sub-label).
class ThaliLogoMark extends StatelessWidget {
  const ThaliLogoMark({
    super.key,
    this.size = 38,
    this.withWordmark = false,
    this.whiteContainer = false,
    this.textColor,
    this.subtitle = 'Partner',
  });

  final double size;
  final bool withWordmark;
  final bool whiteContainer;
  final Color? textColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.storefront_rounded,
        size: size * 0.8,
        color: ThaliColors.primary,
      ),
    );

    final badge = whiteContainer
        ? Container(
            width: size + 18,
            height: size + 18,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            alignment: Alignment.center,
            child: mark,
          )
        : mark;

    if (!withWordmark) return badge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Thali',
                  style: TextStyle(
                    fontSize: size * 0.62,
                    fontWeight: FontWeight.w800,
                    color: textColor ?? ThaliColors.ink,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (textColor == Colors.white)
                          ? Colors.white.withValues(alpha: 0.2)
                          : ThaliColors.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: (textColor == Colors.white) ? Colors.white : ThaliColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final Widget child;
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
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class PartnerActionButton extends StatelessWidget {
  const PartnerActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.loading = false,
    this.height = 48,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool loading;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final bg = secondary
        ? ThaliColors.card
        : (disabled ? ThaliColors.subtle : (color ?? ThaliColors.primary));
    final fg = secondary
        ? (disabled ? ThaliColors.hint : (color ?? ThaliColors.primary))
        : (disabled ? ThaliColors.hint : Colors.white);

    return PressScale(
      onTap: disabled ? null : onPressed,
      enabled: !disabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: secondary
              ? Border.all(color: disabled ? ThaliColors.stroke : (color ?? ThaliColors.primary))
              : null,
        ),
        alignment: Alignment.center,
        child: loading
            ? SpinnerArc(size: 20, color: fg)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: fg,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class CardSurface extends StatelessWidget {
  const CardSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color = ThaliColors.card,
    this.borderColor,
    this.radius = 14,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? ThaliColors.stroke),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return PressScale(onTap: onTap, child: box);
  }
}

class MealStatusBadge extends StatelessWidget {
  const MealStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final st = status.toLowerCase();
    late Color fg, bg, bd;
    late IconData ic;
    late String label;

    switch (st) {
      case 'preparing':
        fg = ThaliColors.amberDark;
        bg = ThaliColors.amberSoft;
        bd = ThaliColors.amberBorder;
        ic = Icons.local_fire_department_outlined;
        label = 'Preparing';
        break;
      case 'out_for_delivery':
        fg = ThaliColors.greenDark;
        bg = ThaliColors.greenSoft;
        bd = ThaliColors.greenBorder;
        ic = Icons.delivery_dining_outlined;
        label = 'Out for delivery';
        break;
      case 'ready_at_counter':
        fg = ThaliColors.greenDark;
        bg = ThaliColors.greenSoft;
        bd = ThaliColors.greenBorder;
        ic = Icons.storefront_outlined;
        label = 'Ready at counter';
        break;
      case 'delivered':
      case 'redeemed':
        fg = const Color(0xFF166534);
        bg = const Color(0xFFDCFCE7);
        bd = ThaliColors.greenBorder;
        ic = Icons.check_circle_outline_rounded;
        label = 'Delivered';
        break;
      case 'skipped':
        fg = ThaliColors.body;
        bg = ThaliColors.subtle;
        bd = ThaliColors.stroke;
        ic = Icons.redo_rounded;
        label = 'Skipped';
        break;
      case 'cancelled_by_kitchen':
        fg = ThaliColors.red;
        bg = ThaliColors.redSoft;
        bd = ThaliColors.redBorder;
        ic = Icons.cancel_outlined;
        label = 'Cancelled';
        break;
      default:
        fg = ThaliColors.blue;
        bg = ThaliColors.blueSoft;
        bd = ThaliColors.blueBorder;
        ic = Icons.schedule_rounded;
        label = 'Scheduled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 12.5, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, this.rating});
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final hasRating = rating != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: hasRating ? ThaliColors.green : ThaliColors.subtle,
        borderRadius: BorderRadius.circular(6),
        border: hasRating ? null : Border.all(color: ThaliColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasRating) ...[
            const Icon(Icons.star_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 2.5),
          ],
          Text(
            hasRating ? rating!.toStringAsFixed(1) : 'New',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: hasRating ? Colors.white : ThaliColors.body,
            ),
          ),
        ],
      ),
    );
  }
}

class SlotIconTile extends StatelessWidget {
  const SlotIconTile({super.key, required this.slot, this.size = 36});
  final String slot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = slot.toLowerCase();
    final asset = s.contains('breakfast')
        ? 'assets/images/ui/icon_breakfast.svg'
        : s.contains('dinner')
            ? 'assets/images/ui/icon_dinner.svg'
            : 'assets/images/ui/icon_lunch.svg';
    final bg = s.contains('breakfast')
        ? ThaliColors.breakfastTile
        : s.contains('dinner')
            ? ThaliColors.dinnerTile
            : ThaliColors.lunchTile;

    return Container(
      width: size + 8,
      height: size + 8,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
      child: SvgPicture.asset(
        asset,
        width: size,
        height: size,
        placeholderBuilder: (_) => Icon(Icons.restaurant_menu_rounded, size: size * 0.65, color: ThaliColors.primary),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: ThaliColors.ink),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThaliColors.primary),
              ),
            ),
        ],
      );
}

Route<T> partnerRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 170),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

void showPartnerNotice(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? ThaliColors.red : ThaliColors.ink,
    ),
  );
}

String rupee(num amount) => '₹${amount is int ? amount : amount.round()}';

String formatPartnerDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Branded shimmer cards for Partner list/queue/dashboard loading states.
class PartnerSkeletonList extends StatelessWidget {
  const PartnerSkeletonList({super.key, this.itemCount = 3, this.cardHeight = 112});

  final int itemCount;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => SkeletonShimmer(
        height: cardHeight,
        width: double.infinity,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

/// Branded centered arc spinner for Partner overlays and detail loads.
class PartnerLoadingView extends StatelessWidget {
  const PartnerLoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SpinnerArc(size: 36, color: ThaliColors.primary),
          if (label != null && label!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              label!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ThaliColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
