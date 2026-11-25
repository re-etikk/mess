import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/thali_theme.dart';
import '../../core/widgets/mess_widgets.dart';
import '../../mess_app.dart';

class AdOnboardingScreen extends StatefulWidget {
  const AdOnboardingScreen({super.key});

  @override
  State<AdOnboardingScreen> createState() => _AdOnboardingScreenState();
}

class _AdOnboardingScreenState extends State<AdOnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _slides = [
    (
      svg: 'assets/images/ui/illus_onboard_1.svg',
      title: 'Find Home-style Meals',
      body: 'Browse trusted mess services near you, compare meals and prices, then choose the one that fits your daily routine.',
    ),
    (
      svg: 'assets/images/ui/illus_onboard_2.svg',
      title: 'Your Schedule. Your Meals.',
      body: 'Choose breakfast, lunch, dinner delivery time and repeat days. Pause or resume your subscription whenever you need.',
    ),
    (
      svg: 'assets/images/ui/illus_onboard_3.svg',
      title: 'Fresh Meals. Every Day.',
      body: 'Enjoy fresh home-style meals delivered on time, so you can focus on work, study, and everything else.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('thali_has_seen_onboarding', true);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(messRoute(const MessRootGate()));
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      backgroundColor: ThaliColors.card,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (v) => setState(() => _index = v),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 310,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF8F5),
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(s.svg, width: 250, height: 195),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            Text(
                              s.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: ThaliColors.ink,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.body,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: ThaliColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _index == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _index == i ? ThaliColors.primary : ThaliColors.stroke,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Column(
                children: [
                  MessActionButton(
                    label: isLast ? 'Get Started' : 'Continue',
                    onPressed: () {
                      if (isLast) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: isLast
                        ? const SizedBox.shrink()
                        : TextButton(
                            onPressed: _finish,
                            child: const Text(
                              'Skip',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ThaliColors.muted),
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
