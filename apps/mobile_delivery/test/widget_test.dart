import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tiffin_delivery/main.dart';

void main() {
  testWidgets('delivery app states that delivery is outside current scope', (tester) async {
    await tester.pumpWidget(const DeliveryUnavailableApp());
    expect(find.text('Delivery is not offered'), findsOneWidget);
    expect(find.text('The current Thali product is for customers visiting food providers. Delivery partner workflows are out of scope.'), findsOneWidget);
  });
}
