import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/thali_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../meals/my_meals_screen.dart';
import '../plans/plans_screen.dart';
import 'home_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _tabs = [
    (label: 'Explore', icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded),
    (label: 'My meals', icon: Icons.room_service_outlined, activeIcon: Icons.room_service_rounded),
    (label: 'Subscriptions', icon: Icons.credit_score_outlined, activeIcon: Icons.credit_score_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final idx = appState.currentTab.clamp(0, 2);

    const pages = <Widget>[
      HomeScreen(),
      MyMealsScreen(),
      PlansScreen(),
    ];

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      body: Stack(
        children: [
          IndexedStack(index: idx, children: pages),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: ThaliColors.card,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: ThaliColors.stroke),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1E18181B), blurRadius: 20, offset: Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final tab = _tabs[i];
                    final selected = idx == i;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          appState.selectTab(i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                          decoration: BoxDecoration(
                            color: selected ? ThaliColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                selected ? tab.activeIcon : tab.icon,
                                size: 20,
                                color: selected ? Colors.white : ThaliColors.muted,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tab.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : ThaliColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
