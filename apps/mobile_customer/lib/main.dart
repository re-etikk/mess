import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mess_app.dart';
import 'core/state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  try {
    await appState.initSession();
  } catch (_) {}

  bool hasSeenOnboarding = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    hasSeenOnboarding = prefs.getBool('thali_has_seen_onboarding') ?? false;
  } catch (_) {}

  runApp(MessApp(appState: appState, hasSeenOnboarding: hasSeenOnboarding));
}
