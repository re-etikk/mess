import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/animations/thali_animations.dart';
import '../../core/theme/mess_theme.dart';
import '../../mess_app.dart';
import '../onboarding/ad_onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      bool hasSeenOnboarding = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        hasSeenOnboarding = prefs.getBool('thali_has_seen_onboarding') ?? false;
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => hasSeenOnboarding
              ? const MessRootGate()
              : const AdOnboardingScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MessColors.cream,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const InfinityTrail(
                size: 64,
                color: MessColors.orange,
                strokeWidth: 3.5,
              ),
              const SizedBox(height: 24),
              const TextShimmer(
                text: 'THALI',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                  color: MessColors.navy,
                ),
                shimmerColor: MessColors.orange,
              ),
              const SizedBox(height: 6),
              const Text(
                'YOUR MEALS · YOUR CHOICE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: MessColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
