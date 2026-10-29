import 'package:flutter/material.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/mess_theme.dart';
import '../../core/widgets/app_state_scope.dart';
import '../../core/widgets/mess_widgets.dart';
import '../plans/plans_screen.dart';
import '../profile/profile_screen.dart';
import '../scan/scan_screen.dart';
import '../search/search_screen.dart';
import 'home_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final tab = state.currentTab;
        final page = switch (tab) {
          0 => const HomeScreen(key: ValueKey('home')),
          1 => const SearchScreen(key: ValueKey('search')),
          3 => const PlansScreen(key: ValueKey('plans')),
          4 => const ProfileScreen(key: ValueKey('profile')),
          _ => const HomeScreen(key: ValueKey('home-fallback')),
        };
        return PopScope(
          canPop: tab == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (tab != 0) {
              state.selectTab(0);
            }
          },
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, .015), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(tab), child: page),
              ),
            ),
            bottomNavigationBar: _BottomNavigation(
              selectedIndex: tab,
              onSelected: (index) {
                if (index == 2) {
                  if (state.canOpenScanner) {
                    Navigator.of(context).push(messRoute(const ScanScreen()));
                  } else {
                    _showScannerGate(context, state);
                  }
                } else {
                  state.selectTab(index);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

Future<void> _showScannerGate(BuildContext context, AppState state) async {
  final provider = state.activeProvider;
  final choice = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.qr_code_scanner_rounded, size: 38, color: MessColors.orangeDark),
      title: const Text('Meal access required'),
      content: const Text('The scanner is available after you activate a plan or pay for today’s meal.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, 'daily'), child: const Text('Find a meal')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, 'plans'), child: const Text('View plans')),
      ],
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'plans') {
    Navigator.push(context, messRoute(PlansScreen(provider: provider)));
  } else {
    state.selectTab(1);
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.selectedIndex, required this.onSelected});
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: MessColors.white,
          border: Border(top: BorderSide(color: MessColors.border, width: 1.0)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: selectedIndex == 0,
                  onTap: () => onSelected(0),
                ),
                _NavItem(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  selected: selectedIndex == 1,
                  onTap: () => onSelected(1),
                ),
                Expanded(
                  child: Center(
                    child: PressScale(
                      onTap: () => onSelected(2),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: MessColors.orange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x38E94E12),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 28,
                          color: MessColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Plans',
                  selected: selectedIndex == 3,
                  onTap: () => onSelected(3),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  selected: selectedIndex == 4,
                  onTap: () => onSelected(4),
                ),
              ],
            ),
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: PressScale(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? MessColors.orange : MessColors.muted,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? MessColors.orange : MessColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
