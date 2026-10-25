import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tiffin_provider/main.dart';

void main() {
  testWidgets('provider app does not expose demo sign-in or business data', (tester) async {
    await tester.pumpWidget(const ThaliProviderApp());
    expect(find.text('Provider sign-in, onboarding, menus, and QR operations require the secure backend and verified provider accounts.'), findsOneWidget);
    expect(find.text('No demo account or business data is available.'), findsOneWidget);
  });
}
