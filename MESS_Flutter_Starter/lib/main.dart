import 'package:flutter/material.dart';

import 'mess_app.dart';
import 'core/state/app_state.dart';
import 'core/widgets/app_state_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppStateScope(notifier: AppState(), child: const MessApp()));
}
