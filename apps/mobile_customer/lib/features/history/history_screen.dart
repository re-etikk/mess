import 'package:flutter/material.dart';

import '../../core/models/mess_models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../plans/plans_screen.dart';

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

        // Calculate slot counts
        int lunchCount = 0;
        int dinnerCount = 0;
        int breakfastCount = 0;
        for (final item in history) {
          final slot = item.slotName.toUpperCase();
          if (slot.contains('LUNCH')) {
            lunchCount++;
          } else if (slot.contains('DINNER')) {
            dinnerCount++;
          } else if (slot.contains('BREAKFAST')) {
            breakfastCount++;
          }
        }

        final now = DateTime.now();
        int? daysRemaining;
        bool isExpiringSoon = false;
        if (sub != null) {
          final diff = sub.endDate.difference(now).inDays;
          daysRemaining = diff >= 0 ? diff : 0;
          if (daysRemaining <= 3) isExpiringSoon = true;
        }

        return Scaffold(
          backgroundColor: MessColors.cream,
          appBar: AppBar(
            backgroundColor: MessColors.cream,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text('Meal Tracker & History'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            children: [
              // Active Plan & Tracker Card
              if (sub != null && sub.isValidToday) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MessColors.navy,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C3E50),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('ACTIVE PLAN TRACKER', style: TextStyle(color: Color(0xFFBDC8D0), fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                          ),
                          if (isExpiringSoon)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFE67E22), borderRadius: BorderRadius.circular(6)),
                              child: const Text('RENEW SOON', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(sub.providerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(sub.planName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 16),
                      if (sub.type == SubscriptionType.mealTracker && sub.mealsRemaining != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${sub.mealsRemaining} meals remaining', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                            Text('Deducts 1 per valid scan', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (sub.mealsRemaining! / 60.0).clamp(0.0, 1.0),
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(MessColors.orange),
                            minHeight: 8,
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: MessColors.orange, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '$daysRemaining days remaining · Valid until ${formatDate(sub.endDate)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                      if (isExpiringSoon) ...[
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: () => Navigator.push(context, messRoute(const PlansScreen())),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: MessColors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Renew Plan Now', textAlign: TextAlign.center, style: TextStyle(color: MessColors.ink, fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MessColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFFFE8C5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.no_meals_outlined, color: MessColors.orange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('No Active Meal Pass', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: MessColors.ink)),
                            const SizedBox(height: 2),
                            const Text('Subscribe to any mess to track your daily attendance here.', style: TextStyle(fontSize: 12, color: MessColors.muted)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(context, messRoute(const PlansScreen())),
                        child: const Text('Browse', style: TextStyle(fontWeight: FontWeight.w800, color: MessColors.orangeDark)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Consumption Metrics Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: MessColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Breakfast', style: TextStyle(color: MessColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('$breakfastCount', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: MessColors.ink)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: MessColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lunch', style: TextStyle(color: MessColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('$lunchCount', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: MessColors.green)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: MessColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dinner', style: TextStyle(color: MessColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('$dinnerCount', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: MessColors.orangeDark)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: MessColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total', style: TextStyle(color: MessColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('${history.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: MessColors.navy)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              Text('Verified Attendance Log', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),

              if (history.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No meal scans yet',
                      message: 'Scan the mess counter QR when you eat to record your attendance with exact timestamps.',
                    ),
                  ),
                )
              else
                ...history.map((item) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: MessColors.border)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, color: MessColors.green, size: 22),
                      ),
                      title: Text(
                        '${item.slotName} at ${item.providerName}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: MessColors.ink),
                      ),
                      subtitle: Text(
                        '${formatDate(item.redeemedAt)} · ${formatTime(item.redeemedAt)}',
                        style: const TextStyle(fontSize: 12, color: MessColors.muted),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: MessColors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('VERIFIED', style: TextStyle(color: MessColors.green, fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
