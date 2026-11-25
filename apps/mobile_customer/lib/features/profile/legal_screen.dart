import 'package:flutter/material.dart';

import '../../core/theme/thali_theme.dart';
import '../../core/widgets/mess_widgets.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, this.isPrivacy = false});
  final bool isPrivacy;

  @override
  Widget build(BuildContext context) {
    final title = isPrivacy ? 'Privacy Policy' : 'Terms of Service';
    final items = isPrivacy
        ? const [
            (
              '1. Information We Collect',
              'Thali collects your name, verified email or mobile number, delivery locality, food preference, and meal subscription or attendance activity needed to coordinate daily meals with your chosen mess kitchen.'
            ),
            (
              '2. Kitchen Coordination & Data Sharing',
              'Delivery addresses, instructions, meal skips, and active plan dates are shared solely with the specific kitchen you subscribe to so meals can be prepared and verified.'
            ),
            (
              '3. Payments & Security',
              'Online payments are processed via encrypted Cashfree checkout. Counter cash subscriptions are reconciled directly with the kitchen owner.'
            ),
            (
              '4. Account Deletion',
              'You can permanently delete your account and associated personal profile data from Account & Profile -> Delete Account & Data.'
            ),
          ]
        : const [
            (
              '1. Meal Subscriptions & Redemptions',
              'Each active pass entitles the subscriber to meals across selected breakfast, lunch, and dinner windows subject to the plan duration, weekday schedule, and weekly skip allowance.'
            ),
            (
              '2. Pause, Skip & Reschedule Cutoffs',
              'Meal skips and delivery reschedules must be requested before the kitchen preparation cutoff displayed in Your Meals.'
            ),
            (
              '3. Counter Check-In',
              'Dine-in and counter pickup meals require scanning the kitchen\'s daily counter QR code inside active meal hours.'
            ),
            (
              '4. Support & Disputes',
              'Questions regarding meal quality, skipped credits, or counter cash approvals may be raised directly in Customer Support inside Account & Profile.'
            ),
          ];

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          CardSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThaliColors.ink),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Last updated: November 2026',
                  style: TextStyle(fontSize: 12, color: ThaliColors.muted),
                ),
                const SizedBox(height: 16),
                ...items.map((pair) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pair.$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink)),
                          const SizedBox(height: 4),
                          Text(pair.$2, style: const TextStyle(fontSize: 13, color: ThaliColors.body, height: 1.45)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
