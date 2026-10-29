import 'package:flutter/material.dart';

import 'mess_app.dart';
import 'core/state/app_state.dart';
import 'core/widgets/app_state_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.initSession();
  runApp(AppStateScope(notifier: appState, child: const MessApp()));
}
