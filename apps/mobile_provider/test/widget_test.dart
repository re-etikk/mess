import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_tiffin_provider/core/theme/thali_partner_theme.dart';
import 'package:smart_tiffin_provider/core/widgets/partner_widgets.dart';
import 'package:smart_tiffin_provider/features/partner_auth_screens.dart';
import 'package:smart_tiffin_provider/main.dart';

void main() {
  testWidgets('Thali Partner App boots cleanly from Splash into PartnerLoginScreen', (tester) async {
    await tester.pumpWidget(const MessProviderApp(hasSeenAd: true));
    expect(find.text('Thali Partner'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(find.byType(ProviderLoginScreen), findsOneWidget);
    expect(find.text('Kitchen Partner Portal'), findsOneWidget);
    expect(find.text('Register Kitchen'), findsOneWidget);
  });

  testWidgets('Partner MealStatusBadge renders all live queue states', (tester) async {
    const states = [
      ('scheduled', 'Scheduled'),
      ('preparing', 'Preparing'),
      ('out_for_delivery', 'Out for delivery'),
      ('ready_at_counter', 'Ready at counter'),
      ('delivered', 'Delivered'),
      ('skipped', 'Skipped'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThaliPartnerTheme.light,
        home: Scaffold(
          body: Column(
            children: states.map((s) => MealStatusBadge(status: s.$1)).toList(),
          ),
        ),
      ),
    );
    for (final s in states) {
      expect(find.text(s.$2), findsOneWidget);
    }
  });
}
