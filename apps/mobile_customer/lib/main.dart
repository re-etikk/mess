import 'package:flutter/material.dart';

import 'mess_app.dart';
import 'core/state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.initSession();
  runApp(MessApp(appState: appState));
}
