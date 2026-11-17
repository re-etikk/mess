import 'package:flutter/material.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/animations/thali_animations.dart';

class AnimationGalleryScreen extends StatefulWidget {
  const AnimationGalleryScreen({super.key});

  @override
  State<AnimationGalleryScreen> createState() => _AnimationGalleryScreenState();
}

class _AnimationGalleryScreenState extends State<AnimationGalleryScreen> {
  Color _selectedColor = MessColors.orange;
  String _selectedCategory = 'All';

  final List<Color> _palette = const [
    Color(0xFFFF6B1A), // Thali Orange
    Color(0xFF182435), // Navy
    Color(0xFF36A653), // Green Success
    Color(0xFFE85B5B), // Red Error
    Color(0xFF687382), // Slate Muted
  ];

  final List<String> _categories = const ['All', 'Loaders', 'Progress', 'Delight'];

  List<_AnimSpec> _getItems() => [
    _AnimSpec(
      name: 'Spinner Arc',
      category: 'Loaders',
      description: 'Used for initial app boot, provider sync & QR initialization.',
      builder: (color) => SpinnerArc(color: color, size: 38),
    ),
    _AnimSpec(
      name: 'Bouncing Dots',
      category: 'Loaders',
      description: 'Used for search queries and secondary loading states.',
      builder: (color) => BouncingDots(color: color, size: 32),
    ),
    _AnimSpec(
      name: 'Pulse Rings',
      category: 'Delight',
      description: 'Concentric radar pulses around QR counter card and scanner frame.',
      builder: (color) => PulseRings(color: color, size: 48),
    ),
    _AnimSpec(
      name: 'Indeterminate Bar',
      category: 'Loaders',
      description: 'Sleek sliding gradient bar for background network sync.',
      builder: (color) => SizedBox(width: 90, child: IndeterminateBar(color: color, height: 5)),
    ),
    _AnimSpec(
      name: 'Skeleton Shimmer',
      category: 'Loaders',
      description: 'High-contrast placeholder shimmer for mess cards and food items.',
      builder: (color) => SizedBox(
        width: 95,
        height: 38,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonShimmer(width: 80, height: 10, baseColor: color.withOpacity(0.18), highlightColor: Colors.white),
            const SizedBox(height: 6),
            SkeletonShimmer(width: 50, height: 8, baseColor: color.withOpacity(0.18), highlightColor: Colors.white),
          ],
        ),
      ),
    ),
    _AnimSpec(
      name: 'Orbit',
      category: 'Delight',
      description: 'Satellite particle orbiting central hub for AI assistant thinking.',
      builder: (color) => Orbit(color: color, size: 42),
    ),
    _AnimSpec(
      name: 'Equalizer Bars',
      category: 'Delight',
      description: 'Live audio frequency visualization bars for voice commands.',
      builder: (color) => EqualizerBars(color: color, size: 36),
    ),
    _AnimSpec(
      name: 'Square Morph',
      category: 'Delight',
      description: 'Smooth morphing shape transition between circle and square.',
      builder: (color) => SquareMorph(color: color, size: 34),
    ),
    _AnimSpec(
      name: 'Liquid Fill',
      category: 'Progress',
      description: 'Dynamic undulating liquid level representing real meals remaining.',
      builder: (color) => LiquidFill(color: color, size: 46, fillPercent: 0.65, centerText: '13'),
    ),
    _AnimSpec(
      name: 'Dot Grid Wave',
      category: 'Delight',
      description: 'Matrix of dots pulsating with radial wave for onboarding.',
      builder: (color) => DotGridWave(color: color, size: 44),
    ),
    _AnimSpec(
      name: 'Infinity Trail',
      category: 'Loaders',
      description: 'Lemniscate figure-8 luminous trail for splash branding.',
      builder: (color) => InfinityTrail(color: color, size: 48),
    ),
    _AnimSpec(
      name: 'Flipping Square',
      category: 'Delight',
      description: '3D perspective card flip celebrating verified meal check-in.',
      builder: (color) => FlippingSquare(color: color, size: 34),
    ),
    _AnimSpec(
      name: 'Gradient Ring',
      category: 'Progress',
      description: 'Rotating angular sweep gradient for active subscription cards.',
      builder: (color) => GradientRing(size: 42, colors: [color, color.withOpacity(0.2), color]),
    ),
    _AnimSpec(
      name: 'Typing Dots',
      category: 'Loaders',
      description: 'Subtle undulating chat indicator for mess owner support responses.',
      builder: (color) => TypingDots(dotColor: color, size: 28),
    ),
    _AnimSpec(
      name: 'Spoke Spinner',
      category: 'Loaders',
      description: 'Radial discrete spokes activity indicator.',
      builder: (color) => SpokeSpinner(color: color, size: 34),
    ),
    _AnimSpec(
      name: 'Percent Bar',
      category: 'Progress',
      description: 'Animated progress bar showing genuine subscription expiry progress.',
      builder: (color) => SizedBox(width: 85, child: PercentBar(percent: 0.72, color: color, height: 6)),
    ),
    _AnimSpec(
      name: 'Chasing Square',
      category: 'Loaders',
      description: 'Perimeter running square for QR cryptographic token validation.',
      builder: (color) => ChasingSquare(color: color, size: 38),
    ),
    _AnimSpec(
      name: 'Text Shimmer',
      category: 'Delight',
      description: 'Luminous light streak passing across banner & badge text.',
      builder: (color) => TextShimmer(text: 'THALI PASS', shimmerColor: color, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
    ),
    _AnimSpec(
      name: 'Battery Charge',
      category: 'Progress',
      description: 'Charging battery icon with pulsating fill level.',
      builder: (color) => BatteryCharge(color: color, size: 36, chargePercent: 0.8),
    ),
    _AnimSpec(
      name: 'Bouncing Ball',
      category: 'Delight',
      description: 'Physics-based ball bounce with ground shadow for meal redemption.',
      builder: (color) => BouncingBall(color: color, size: 38),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final allItems = _getItems();
    final items = _selectedCategory == 'All'
        ? allItems
        : allItems.where((e) => e.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: MessColors.cream,
      appBar: AppBar(
        title: const Text('xTools Component Gallery', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filter & Color Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: MessColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Theme Tint', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: MessColors.muted)),
                    Row(
                      children: _palette.map((c) {
                        final isSel = c == _selectedColor;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = c),
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? MessColors.ink : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSel = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSel,
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                          selectedColor: MessColors.orangeSoft,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                            color: isSel ? MessColors.orangeDark : MessColors.ink,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
                  onTap: () => _showDetailSheet(context, item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MessColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Center(
                            child: item.builder(_selectedColor),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: MessColors.ink,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context, _AnimSpec item) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: MessColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 90,
              child: Center(child: item.builder(_selectedColor)),
            ),
            const SizedBox(height: 14),
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: MessColors.ink)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: MessColors.orangeSoft, borderRadius: BorderRadius.circular(8)),
              child: Text(item.category.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: MessColors.orangeDark)),
            ),
            const SizedBox(height: 12),
            Text(item.description, textAlign: TextAlign.center, style: const TextStyle(color: MessColors.muted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: MessColors.orange,
                foregroundColor: MessColors.ink,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close Preview', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimSpec {
  _AnimSpec({
    required this.name,
    required this.category,
    required this.description,
    required this.builder,
  });

  final String name;
  final String category;
  final String description;
  final Widget Function(Color color) builder;
}
