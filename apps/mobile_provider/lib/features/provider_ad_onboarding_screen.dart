import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/animations/thali_animations.dart';

/// Full-screen promo & onboarding advertisement screen for first-time installed kitchen partners.
/// Designed for high conversion, clear value proposition, and instant action:
/// - Slide 1: Digital Counter QR Code & Paperless Attendance
/// - Slide 2: Direct Student-to-Kitchen UPI & 0% Commissions
/// - Slide 3: Live Menu, Timings & Plan Management
/// - Top "Skip" action to jump straight to Sign In / Register
/// - Bottom CTAs: "Register Kitchen / Partner" (Primary) and "Already a Partner? Sign In" (Secondary)
class ProviderAdOnboardingScreen extends StatefulWidget {
  const ProviderAdOnboardingScreen({
    super.key,
    required this.onSignIn,
    required this.onRegister,
  });

  final VoidCallback onSignIn;
  final VoidCallback onRegister;

  @override
  State<ProviderAdOnboardingScreen> createState() => _ProviderAdOnboardingScreenState();
}

class _ProviderAdOnboardingScreenState extends State<ProviderAdOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const Color ink = Color(0xFF182435);
  static const Color orange = Color(0xFFFF6B1A);
  static const Color orangeSoft = Color(0xFFFFF0E5);
  static const Color cream = Color(0xFFFBF6EE);
  static const Color muted = Color(0xFF687382);
  static const Color line = Color(0xFFE9E0D5);

  final List<Map<String, dynamic>> _slides = [
    {
      'tag': 'SMART COUNTER QR',
      'title': 'Zero Paper Registers, 100% Verified',
      'subtitle':
          'Replace manual khata registers and physical meal tokens. Display today\'s cryptographically signed counter QR code — students scan and verify their meal in 1 second.',
      'icon': Icons.qr_code_scanner_rounded,
      'badgeColor': Color(0xFFFFEDD5),
      'badgeText': Color(0xFFC2410C),
      'cardBg': Color(0xFFFFF7ED),
      'iconColor': orange,
    },
    {
      'tag': 'DIRECT SETTLEMENTS',
      'title': 'Instant UPI, 0% Commissions',
      'subtitle':
          'Student subscription fees go directly to your registered UPI handle or QR code. Track real-time transactions, student approvals, and daily cash/UPI settlement statements.',
      'icon': Icons.account_balance_wallet_rounded,
      'badgeColor': Color(0xFFDCFCE7),
      'badgeText': Color(0xFF15803D),
      'cardBg': Color(0xFFF0FDF4),
      'iconColor': Color(0xFF16A34A),
    },
    {
      'tag': 'FULL CONTROL',
      'title': 'Live Menu & Kitchen Management',
      'subtitle':
          'Update breakfast, lunch, snacks, and dinner menus instantly. Create custom monthly and meal-count plans, set slot timings, and toggle kitchen open/closed anytime.',
      'icon': Icons.storefront_rounded,
      'badgeColor': Color(0xFFFEF3C7),
      'badgeText': Color(0xFFB45309),
      'cardBg': Color(0xFFFFFBEB),
      'iconColor': Color(0xFFD97706),
    },
  ];

  Future<void> _handleSkipOrSignIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('thali_partner_has_seen_ad_onboarding', true);
    } catch (_) {}
    widget.onSignIn();
  }

  Future<void> _handleRegister() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('thali_partner_has_seen_ad_onboarding', true);
    } catch (_) {}
    widget.onRegister();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Partner Brand + Skip Button
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
                          color: orangeSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'THALI',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: ink,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'KITCHEN PARTNER HUB',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _handleSkipOrSignIn,
                    icon: const Text(
                      'Skip',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: muted,
                      ),
                    ),
                    label: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: muted,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: line),
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
                          constraints: const BoxConstraints(maxHeight: 270),
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: slide['cardBg'] as Color,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: line,
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A182435),
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
                        const SizedBox(height: 24),

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
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: ink,
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
                            color: muted,
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
                    color: _currentPage == i ? orange : line,
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
                      onPressed: _handleRegister,
                      style: FilledButton.styleFrom(
                        backgroundColor: orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Register Kitchen / Partner',
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
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _handleSkipOrSignIn,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        side: const BorderSide(color: line, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Already a Partner? Sign In',
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
