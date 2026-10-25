import 'package:flutter/material.dart';

import 'core/theme/mess_theme.dart';
import 'core/state/app_state.dart';
import 'core/widgets/app_state_scope.dart';
import 'core/widgets/mess_widgets.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';

class MessApp extends StatelessWidget {
  const MessApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) => MaterialApp(
        title: 'MESS | Your Meals, Your Choice',
        debugShowCheckedModeBanner: false,
        theme: MessTheme.light(),
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: appState.isSignedIn ? const HomeShell(key: ValueKey('home-shell')) : const LoginScreen(key: ValueKey('login')),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == '/login') return messRoute(const LoginScreen());
          return null;
        },
      ),
    );
  }
}
