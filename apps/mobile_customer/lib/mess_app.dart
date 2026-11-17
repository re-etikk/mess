import 'package:flutter/material.dart';

import 'core/theme/thali_theme.dart';
import 'core/state/app_state.dart';
import 'core/widgets/app_state_scope.dart';
import 'core/widgets/mess_widgets.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/ad_onboarding_screen.dart';

class MessApp extends StatelessWidget {
  const MessApp({super.key, required this.appState, this.hasSeenOnboarding = true});
  final AppState appState;
  final bool hasSeenOnboarding;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: appState,
      child: MaterialApp(
        title: 'MESS | Your Meals, Your Choice',
        debugShowCheckedModeBanner: false,
        theme: ThaliTheme.light,
        home: hasSeenOnboarding ? const MessRootGate() : const AdOnboardingScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == '/login') return messRoute(const LoginScreen());
          return null;
        },
      ),
    );
  }
}

class MessRootGate extends StatelessWidget {
  const MessRootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return appState.isSignedIn
        ? const HomeShell(key: ValueKey('home-shell'))
        : const LoginScreen(key: ValueKey('login'));
  }
}
