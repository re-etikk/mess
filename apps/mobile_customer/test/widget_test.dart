import 'package:flutter_test/flutter_test.dart';
import 'package:mess_customer_app/mess_app.dart';
import 'package:mess_customer_app/core/state/app_state.dart';
import 'package:mess_customer_app/core/widgets/app_state_scope.dart';

void main() {
  testWidgets('MESS Customer App smoke test', (tester) async {
    await tester.pumpWidget(AppStateScope(notifier: AppState(), child: const MessApp()));
    expect(find.byType(MessApp), findsOneWidget);
  });
}
