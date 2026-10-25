import 'package:flutter/material.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(animation: state, builder: (context, _) => Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Meal history')),
      body: state.history.isEmpty
          ? const Center(child: EmptyState(icon: Icons.receipt_long_outlined, title: 'No meal activity yet', message: 'Your successful redemptions and add-on transactions will appear here.'))
          : ListView.separated(padding: const EdgeInsets.all(18), itemCount: state.history.length, separatorBuilder: (_, __) => const SizedBox(height: 9), itemBuilder: (context, index) {
              final item = state.history[index];
              return CardSurface(child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE7F5E9), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.check_circle_outline_rounded, color: MessColors.green)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.providerName, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 3), Text('${item.slotName} · ${formatDate(item.redeemedAt)} at ${formatTime(item.redeemedAt)}', style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 5), Text(item.status, style: const TextStyle(color: MessColors.green, fontSize: 11, fontWeight: FontWeight.w700))]))]));
            }),
    ));
  }
}
