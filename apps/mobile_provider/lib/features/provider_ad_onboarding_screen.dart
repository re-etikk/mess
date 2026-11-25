import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';

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
  int _index = 0;

  static const _slides = [
    (
      'LIVE KITCHEN QUEUE',
      'Prep, Dispatch & Counter Check-In',
      'See every subscriber meal for Breakfast, Lunch, and Dinner in real time, update cooking status, and read delivery instructions in one view.',
      'assets/images/ui/illus_onboard_1.svg',
      Icons.kitchen_outlined,
    ),
    (
      'ONLINE & COUNTER CASH',
      'Cashfree Online + Cash Approvals',
      'Accept instant online subscriptions settled via Cashfree, or review and activate counter cash members in one tap.',
      'assets/images/ui/illus_onboard_2.svg',
      Icons.payments_outlined,
    ),
    (
      'DAILY COUNTER QR',
      'Instant Verified Meal Attendance',
      'Display your kitchen\'s cryptographic counter QR code. Diners scan to check in, eliminating paper registers and token disputes.',
      'assets/images/ui/illus_onboard_3.svg',
      Icons.qr_code_2_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markSeenAndGo(VoidCallback action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('thali_partner_has_seen_ad_onboarding', true);
    } catch (_) {}
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThaliColors.card,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 8),
              child: Row(
                children: [
                  const ThaliLogoMark(size: 34, withWordmark: true, subtitle: 'Partner'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _markSeenAndGo(widget.onSignIn),
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ThaliColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 240,
                          height: 220,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: ThaliColors.primarySoft,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: SvgPicture.asset(
                            s.$4,
                            placeholderBuilder: (_) => Icon(s.$5, size: 84, color: ThaliColors.primary),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ThaliColors.primarySoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            s.$1,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: ThaliColors.primaryDark,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: ThaliColors.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: ThaliColors.body,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = _index == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? ThaliColors.primary : ThaliColors.stroke,
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Column(
                children: [
                  PartnerActionButton(
                    label: _index < _slides.length - 1 ? 'Next' : 'Register Your Kitchen',
                    onPressed: () {
                      if (_index < _slides.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      } else {
                        _markSeenAndGo(widget.onRegister);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  PartnerActionButton(
                    label: 'Already a Partner? Sign In',
                    secondary: true,
                    onPressed: () => _markSeenAndGo(widget.onSignIn),
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
