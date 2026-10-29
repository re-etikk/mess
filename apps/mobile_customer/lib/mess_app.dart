import 'package:flutter/material.dart';

import 'core/theme/mess_theme.dart';
import 'core/theme/thali_theme.dart';
import 'core/state/app_state.dart';
import 'core/widgets/app_state_scope.dart';
import 'core/widgets/mess_widgets.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';

class MessApp extends StatelessWidget {
  const MessApp({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MESS | Your Meals, Your Choice',
      debugShowCheckedModeBanner: false,
      theme: ThaliTheme.light,
      builder: (context, child) => AppStateScope(
        notifier: appState,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _MessRootGate(),
      onGenerateRoute: (settings) {
        if (settings.name == '/login') return messRoute(const LoginScreen());
        return null;
      },
    );
  }
}

class _MessRootGate extends StatelessWidget {
  const _MessRootGate();

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return appState.isSignedIn
        ? const HomeShell(key: ValueKey('home-shell'))
        : const LoginScreen(key: ValueKey('login'));
  }
}
