import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animations/thali_animations.dart';
import '../models/mess_models.dart';
import '../theme/thali_theme.dart';

/// Clean Thali logo mark (without any "MESS" wordmark below).
class ThaliLogoMark extends StatelessWidget {
  const ThaliLogoMark({
    super.key,
    this.size = 38,
    this.withWordmark = false,
    this.whiteContainer = false,
    this.textColor,
    this.subtitle,
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
        Icons.room_service_rounded,
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
            Text(
              'Thali',
              style: TextStyle(
                fontSize: size * 0.65,
                fontWeight: FontWeight.w800,
                color: textColor ?? ThaliColors.ink,
                letterSpacing: -0.6,
                height: 1.0,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: (textColor ?? ThaliColors.muted).withValues(alpha: 0.85),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Backward compatible alias pointing strictly to the cleaned ThaliLogoMark.
class MessLogo extends StatelessWidget {
  const MessLogo({super.key, this.compact = false, this.light = false});
  final bool compact;
  final bool light;

  @override
  Widget build(BuildContext context) => ThaliLogoMark(
        size: compact ? 28 : 38,
        withWordmark: true,
        textColor: light ? Colors.white : ThaliColors.ink,
      );
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

class MessActionButton extends StatelessWidget {
  const MessActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.loading = false,
    this.height = 50,
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
                      fontSize: 14.5,
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
    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? ThaliColors.stroke),
      ),
      child: child,
    );
    if (onTap == null) return container;
    return PressScale(onTap: onTap, child: container);
  }
}

/// Square Veg / Non-Veg dietary indicator per Behance component board.
class VegIndicator extends StatelessWidget {
  const VegIndicator({super.key, this.isVeg = true, this.size = 15});
  final bool isVeg;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = isVeg ? ThaliColors.green : ThaliColors.primaryPressed;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.5),
        border: Border.all(color: c, width: 1.5),
      ),
      alignment: Alignment.center,
      child: isVeg
          ? Container(
              width: size * 0.48,
              height: size * 0.48,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            )
          : Icon(Icons.change_history_rounded, size: size * 0.68, color: c),
    );
  }
}

/// Crisp green rating pill ("★ 4.3") or honest "New" pill when 0 reviews.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, this.rating, this.compact = false});
  final double? rating;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasRating = rating != null;
    final bg = hasRating ? ThaliColors.green : ThaliColors.subtle;
    final fg = hasRating ? Colors.white : ThaliColors.body;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2.5 : 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: hasRating ? null : Border.all(color: ThaliColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasRating) ...[
            Icon(Icons.star_rounded, size: compact ? 11 : 13, color: Colors.white),
            const SizedBox(width: 2.5),
          ],
          Text(
            hasRating ? rating!.toStringAsFixed(1) : 'New',
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// All 6 Meal Status Badges matching the Behance Component System.
class MealStatusBadge extends StatelessWidget {
  const MealStatusBadge({super.key, required this.status, this.fullWidth = false});
  final String status;
  final bool fullWidth;

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
        label = 'Preparing your meal';
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
        label = 'Meal skipped';
        break;
      case 'cancelled_by_kitchen':
        fg = ThaliColors.red;
        bg = ThaliColors.redSoft;
        bd = ThaliColors.redBorder;
        ic = Icons.cancel_outlined;
        label = 'Meal cancelled by kitchen';
        break;
      default:
        fg = ThaliColors.blue;
        bg = ThaliColors.blueSoft;
        bd = ThaliColors.blueBorder;
        ic = Icons.schedule_rounded;
        label = 'Scheduled';
    }

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ic, size: 13.5, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Real photo renderer when a cover URL exists, or warm culinary graphic backdrop when empty.
class MessCoverVisual extends StatelessWidget {
  const MessCoverVisual({
    super.key,
    this.imageUrl,
    this.height = 140,
    this.radius = 12,
    this.caption,
    this.closed = false,
  });

  final String? imageUrl;
  final double height;
  final double radius;
  final String? caption;
  final bool closed;

  static const List<double> _grayscaleMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = (imageUrl ?? '').trim();
    final isDataUri = trimmed.startsWith('data:image/');
    final hasHttpUrl = trimmed.startsWith('http');

    Widget mediaWidget;
    if (isDataUri) {
      try {
        final b64 = trimmed.split(',').last;
        mediaWidget = Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackArt(),
        );
      } catch (_) {
        mediaWidget = _fallbackArt();
      }
    } else if (hasHttpUrl) {
      mediaWidget = Image.network(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackArt(),
      );
    } else {
      mediaWidget = _fallbackArt();
    }

    if (closed) {
      mediaWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
        child: mediaWidget,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            mediaWidget,
            if (closed)
              Container(
                color: Colors.black.withValues(alpha: 0.52),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final compact = constraints.maxWidth < 145;
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 5),
                        decoration: BoxDecoration(
                          color: const Color(0xF009090B),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: compact ? 11 : 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              compact ? 'CLOSED' : 'CLOSED TODAY',
                              style: TextStyle(
                                fontSize: compact ? 9.5 : 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (caption != null && caption!.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC18181B)],
                    ),
                  ),
                  child: Text(
                    caption!,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackArt() {
    return Image.asset(
      'assets/images/ui/cover_default_kitchen.jpg',
      fit: BoxFit.cover,
      cacheWidth: 720,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C2D12), Color(0xFF27140A)],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class FoodGlyph extends StatelessWidget {
  const FoodGlyph({super.key, required this.name, this.size = 44, this.color});
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lower = name.toLowerCase();
    final IconData ic = lower.contains('breakfast') || lower.contains('poha') || lower.contains('idli')
        ? Icons.wb_twilight_rounded
        : lower.contains('dinner')
            ? Icons.nights_stay_outlined
            : Icons.wb_sunny_outlined;
    final bg = lower.contains('breakfast')
        ? ThaliColors.breakfastTile
        : lower.contains('dinner')
            ? ThaliColors.dinnerTile
            : ThaliColors.lunchTile;
    final fg = lower.contains('breakfast')
        ? ThaliColors.primary
        : lower.contains('dinner')
            ? const Color(0xFF2563EB)
            : ThaliColors.amber;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.24)),
      child: Icon(ic, size: size * 0.5, color: color ?? fg),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ThaliColors.ink),
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

Route<T> messRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 180),
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

String formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:${date.minute.toString().padLeft(2, '0')} $suffix';
}

String rupee(int amount) => '₹$amount';

/// Branded shimmer card placeholder for customer list/detail loading states.
class ThaliListSkeleton extends StatelessWidget {
  const ThaliListSkeleton({super.key, this.itemCount = 3, this.cardHeight = 148});

  final int itemCount;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SkeletonShimmer(
            height: cardHeight,
            width: double.infinity,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Branded Thali arc spinner loading state.
class ThaliLoadingView extends StatelessWidget {
  const ThaliLoadingView({super.key, this.label});

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
