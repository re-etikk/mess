import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/animations/thali_animations.dart';
import '../../core/theme/mess_theme.dart';
import '../../mess_app.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

/// Full-screen promo & onboarding advertisement screen for first-time installed users.
/// Adheres strictly to UI/UX Pro Max design intelligence:
/// - Hero value propositions with comfortable spacing and WCAG AA contrast
/// - Top "Skip" action to jump straight to Login / Register
/// - Interactive carousel with smooth transitions
/// - Bottom primary CTA "Get Started / Register" and secondary "Sign In"
class AdOnboardingScreen extends StatefulWidget {
  const AdOnboardingScreen({super.key});

  @override
  State<AdOnboardingScreen> createState() => _AdOnboardingScreenState();
}

class _AdOnboardingScreenState extends State<AdOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'tag': 'ZERO DELIVERY SURGES',
      'title': 'Dine-In Mess Subscriptions',
      'subtitle':
          'Eat fresh, piping-hot homestyle food directly at top campus and local messes. No cold deliveries, zero packaging fees, and authentic taste.',
      'icon': Icons.restaurant_rounded,
      'badgeColor': Color(0xFFFFEDD5),
      'badgeText': Color(0xFFC2410C),
      'cardBg': Color(0xFFFFF7ED),
      'iconColor': MessColors.orange,
    },
    {
      'tag': '1-TAP SMART PASS',
      'title': 'Scan Daily Counter QR',
      'subtitle':
          'Never lose paper meal cards again. Walk into your mess, scan today\'s official cryptographic counter QR code, and enjoy your meal instantly.',
      'icon': Icons.qr_code_scanner_rounded,
      'badgeColor': Color(0xFFDCFCE7),
      'badgeText': Color(0xFF15803D),
      'cardBg': Color(0xFFF0FDF4),
      'iconColor': Color(0xFF16A34A),
    },
    {
      'tag': 'MAXIMUM SAVINGS',
      'title': 'Save Up to ₹3,000 Monthly',
      'subtitle':
          'Flexible monthly, 15-day, and meal-count plans starting at just ₹65/thali. Pause whenever you go home or skip meals without losing credits.',
      'icon': Icons.savings_rounded,
      'badgeColor': Color(0xFFFEF3C7),
      'badgeText': Color(0xFFB45309),
      'cardBg': Color(0xFFFFFBEB),
      'iconColor': Color(0xFFD97706),
    },
  ];

  Future<void> _completeOnboarding({bool toRegister = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('thali_has_seen_onboarding', true);
    } catch (_) {}

    if (!mounted) return;
    if (toRegister) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const RegisterScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const MessRootGate(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MessColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Brand + Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MessColors.orange.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.dinner_dining_rounded,
                          color: MessColors.orangeDark,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'THALI',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: MessColors.navy,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _completeOnboarding(),
                    icon: const Text(
                      'Skip',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: MessColors.muted,
                      ),
                    ),
                    label: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: MessColors.muted,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: MessColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Carousel Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Visual Hero Card with Pulse Effect
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 280),
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: slide['cardBg'] as Color,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: MessColors.border,
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A111820),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PulseRings(
                                  size: 160,
                                  color: slide['iconColor'] as Color,
                                  ringCount: 3,
                                ),
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (slide['iconColor'] as Color).withOpacity(0.24),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    slide['icon'] as IconData,
                                    color: slide['iconColor'] as Color,
                                    size: 46,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Promotional Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: slide['badgeColor'] as Color,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            slide['tag'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: slide['badgeText'] as Color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title
                        Text(
                          slide['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: MessColors.navy,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Subtitle
                        Text(
                          slide['subtitle'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: MessColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Pagination Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? MessColors.orange
                        : MessColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Bottom CTAs
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => _completeOnboarding(toRegister: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: MessColors.orange,
                        foregroundColor: MessColors.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get Started / Register',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => _completeOnboarding(toRegister: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MessColors.navy,
                        side: const BorderSide(color: MessColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Already have an account? Sign In',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
