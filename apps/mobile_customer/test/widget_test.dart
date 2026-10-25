import 'package:flutter_test/flutter_test.dart';
import 'package:mess_customer_app/main.dart';

void main() {
  testWidgets('customer app does not show sample records while backend is unavailable', (tester) async {
    await tester.pumpWidget(const ThaliCustomerApp());
    expect(find.text('Customer sign-in and meal passes will be available after the secure Thali backend is configured.'), findsOneWidget);
    expect(find.text('No sample provider, subscription, balance, or payment is shown.'), findsOneWidget);
  });
}
