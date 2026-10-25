import os

# Fix checkout_screen.dart
path_checkout = 'apps/mobile_customer/lib/features/checkout/checkout_screen.dart'
with open(path_checkout, 'r', encoding='utf-8') as f:
    code = f.read()
code = code.replace("import '../../core/state/app_state.dart';", "import '../../core/repositories/mess_repository.dart';")
with open(path_checkout, 'w', encoding='utf-8', newline='\n') as f:
    f.write(code)
print("Updated checkout_screen.dart")

# Fix scan_screen.dart
path_scan = 'apps/mobile_customer/lib/features/scan/scan_screen.dart'
with open(path_scan, 'r', encoding='utf-8') as f:
    code = f.read()
code = code.replace("import '../../core/state/app_state.dart';", "import '../../core/repositories/mess_repository.dart';")
with open(path_scan, 'w', encoding='utf-8', newline='\n') as f:
    f.write(code)
print("Updated scan_screen.dart")

# Fix widget_test.dart
path_test = 'apps/mobile_customer/test/widget_test.dart'
test_code = """import 'package:flutter_test/flutter_test.dart';
import 'package:mess_customer_app/mess_app.dart';
import 'package:mess_customer_app/core/state/app_state.dart';
import 'package:mess_customer_app/core/widgets/app_state_scope.dart';

void main() {
  testWidgets('MESS Customer App smoke test', (tester) async {
    await tester.pumpWidget(AppStateScope(notifier: AppState(), child: const MessApp()));
    expect(find.byType(MessApp), findsOneWidget);
  });
}
"""
with open(path_test, 'w', encoding='utf-8', newline='\n') as f:
    f.write(test_code)
print("Updated widget_test.dart")
