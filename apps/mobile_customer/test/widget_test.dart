import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mess_customer_app/core/models/mess_models.dart';
import 'package:mess_customer_app/core/repositories/http_mess_repository.dart';
import 'package:mess_customer_app/core/state/app_state.dart';
import 'package:mess_customer_app/core/theme/thali_theme.dart';
import 'package:mess_customer_app/core/widgets/app_state_scope.dart';
import 'package:mess_customer_app/core/widgets/mess_widgets.dart';
import 'package:mess_customer_app/mess_app.dart';

class _StubRepository extends HttpMessRepository {
  @override
  Future<List<MessProvider>> getProviders({
    double? lat,
    double? lng,
    String? slot,
    double? minRating,
    bool openNow = false,
    bool deliveryOnly = false,
    String? sort,
    String? dietary,
  }) async =>
      const [];

  @override
  Future<List<MessProvider>> searchProviders({
    String query = '',
    double? lat,
    double? lng,
    String? dietary,
  }) async =>
      const [];

  @override
  Future<Map<String, dynamic>> fetchSubscriptions({required String customerId}) async => {
        'active_subscriptions': const [],
        'past_subscriptions': const [],
        'subscriptions': const [],
      };

  @override
  Future<Map<String, dynamic>> fetchCustomerMeals({required String customerId, required String dateStr}) async => {
        'has_active_subscription': false,
        'week_days': const [],
        'meals': const [],
      };
}

void main() {
  testWidgets('Thali Customer App boots through Splash into LoginScreen', (tester) async {
    final appState = AppState(repository: _StubRepository());
    await tester.pumpWidget(MessApp(appState: appState));
    expect(find.byType(MessApp), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pumpAndSettle();
    expect(find.byType(MessRootGate), findsOneWidget);
  });

  testWidgets('HomeShell renders Behance 3-tab capsule navigation when signed in', (tester) async {
    final appState = AppState(repository: _StubRepository());
    appState.signIn(
      emailOrPhone: 'riya@example.com',
      name: 'Riya',
      userId: 'user-1',
      locality: 'Indiranagar',
      city: 'Bengaluru',
    );

    await tester.pumpWidget(MessApp(appState: appState));
    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('My meals'), findsOneWidget);
    expect(find.text('Subscriptions'), findsOneWidget);
  });

  testWidgets('MealStatusBadge renders all 6 Behance meal statuses', (tester) async {
    const statuses = [
      ('scheduled', 'Scheduled'),
      ('preparing', 'Preparing your meal'),
      ('out_for_delivery', 'Out for delivery'),
      ('ready_at_counter', 'Ready at counter'),
      ('delivered', 'Delivered'),
      ('skipped', 'Meal skipped'),
      ('cancelled_by_kitchen', 'Meal cancelled by kitchen'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThaliTheme.light,
        home: AppStateScope(
          notifier: AppState(repository: _StubRepository()),
          child: Scaffold(
            body: Column(
              children: statuses.map((s) => MealStatusBadge(status: s.$1)).toList(),
            ),
          ),
        ),
      ),
    );
    for (final s in statuses) {
      expect(find.text(s.$2), findsOneWidget);
    }
  });
}
