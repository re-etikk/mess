import 'package:flutter/material.dart';

import '../../core/models/mess_models.dart';
import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final sub = state.activeSubscription;
        final history = state.history;

        int breakfastCount = 0;
        int lunchCount = 0;
        int dinnerCount = 0;
        for (final item in history) {
          final slot = item.slotName.toUpperCase();
          if (slot.contains('BREAKFAST')) {
            breakfastCount++;
          } else if (slot.contains('LUNCH')) {
            lunchCount++;
          } else if (slot.contains('DINNER')) {
            dinnerCount++;
          }
        }

        return Scaffold(
          backgroundColor: ThaliColors.scaffold,
          appBar: AppBar(title: const Text('Meal History')),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              if (sub != null && sub.isValidToday) ...[
                CardSurface(
                  color: ThaliColors.ink,
                  borderColor: ThaliColors.ink,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ACTIVE PASS SUMMARY',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            '${sub.daysRemaining}d left',
                            style: const TextStyle(color: ThaliColors.greenBorder, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sub.providerName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub.planName,
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _chip('Breakfast', breakfastCount),
                          const SizedBox(width: 8),
                          _chip('Lunch', lunchCount),
                          const SizedBox(width: 8),
                          _chip('Dinner', dinnerCount),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SectionHeader(title: 'Recent Check-Ins'),
              const SizedBox(height: 8),
              if (history.isEmpty)
                const CardSurface(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 36, color: ThaliColors.muted),
                      SizedBox(height: 8),
                      Text(
                        'No meal redemptions yet',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Scan the kitchen counter QR when collecting or dining in to build your meal log.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: ThaliColors.muted),
                      ),
                    ],
                  ),
                )
              else
                ...history.map((MealRedemption r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CardSurface(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            FoodGlyph(name: r.slotName, size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r.slotName} · ${r.providerName}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ThaliColors.ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${formatDate(r.redeemedAt)} at ${formatTime(r.redeemedAt)}',
                                    style: const TextStyle(fontSize: 12, color: ThaliColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            MealStatusBadge(status: 'redeemed'),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, int count) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text('$count', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
      );
}
