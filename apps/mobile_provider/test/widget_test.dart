import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tiffin_provider/main.dart';

void main() {
  testWidgets('provider app renders login screen and branding', (tester) async {
    await tester.pumpWidget(const MessProviderApp());
    expect(find.text('Kitchen Partner Login'), findsOneWidget);
    expect(find.text('Register your mess / tiffin service'), findsOneWidget);
  });
}
