import 'package:flutter/widgets.dart';
import '../state/app_state.dart';

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState notifier, required super.child}) : super(notifier: notifier);

  static AppState of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<AppStateScope>()
        : context.getInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing above this context.');
    return scope!.notifier!;
  }
}
