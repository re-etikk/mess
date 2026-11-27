import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mess_customer_app/core/models/mess_models.dart';
import 'package:mess_customer_app/core/repositories/http_mess_repository.dart';
import 'package:mess_customer_app/core/state/app_state.dart';
import 'package:mess_customer_app/core/theme/thali_theme.dart';
import 'package:mess_customer_app/core/widgets/app_state_scope.dart';
import 'package:mess_customer_app/core/widgets/mess_widgets.dart';
import 'package:mess_customer_app/features/auth/register_screen.dart';
import 'package:mess_customer_app/features/checkout/create_subscription_screen.dart';
import 'package:mess_customer_app/mess_app.dart';

class _StubRepository extends HttpMessRepository {
  _StubRepository({this.providers = const []});

  final List<MessProvider> providers;
  String? lastCityRequested;

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
    String? city,
  }) async {
    lastCityRequested = city;
    return openNow ? providers.where((p) => p.isOpen).toList() : providers;
  }

  @override
  Future<Map<String, dynamic>> fetchAppConfig() async => {
        'hero_headline': 'Fresh home thalis curated daily',
        'hero_subheadline': 'Zero platform fees on every subscription.',
        'maintenance_mode': false,
        'platform_fee_paise': 0,
        'default_delivery_fee_paise': 0,
      };

  @override
  Future<List<Map<String, dynamic>>> fetchAnnouncements({String audience = 'customer'}) async => [
        {
          'id': 'ann-1',
          'title': 'Welcome Offer',
          'body': 'Use code FIRSTTHALI for 15% off.',
          'promo_code': 'FIRSTTHALI',
        }
      ];

  @override
  Future<List<Map<String, dynamic>>> fetchAvailablePromos({String? providerId, String orderContext = 'plan'}) async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchSupportTickets() async => const [];

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

  @override
  Future<List<Map<String, dynamic>>> fetchNotifications({required String customerId}) async => const [];

  @override
  Future<void> markNotificationsRead({String? notificationId, String? customerId}) async {}
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
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Snacks'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
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

  testWidgets('HomeScreen renders closed kitchens cleanly and Open now filter hides them', (tester) async {
    final providers = [
      const MessProvider(
        id: 'p-open',
        name: 'Sunny Thali House',
        area: 'Sector 62',
        city: 'Noida',
        distanceMeters: 450,
        description: 'Fresh home food',
        mealSlots: [],
        plans: [],
        isOpen: true,
      ),
      const MessProvider(
        id: 'p-closed',
        name: 'Night Off Kitchen',
        area: 'Sector 63',
        city: 'Noida',
        distanceMeters: 900,
        description: 'Off today',
        mealSlots: [],
        plans: [],
        isOpen: false,
      ),
    ];

    final appState = AppState(repository: _StubRepository(providers: providers));
    appState.signIn(
      emailOrPhone: 'riya@example.com',
      name: 'Riya',
      userId: 'user-1',
      locality: 'Sector 62',
      city: 'Noida',
    );

    await tester.pumpWidget(MessApp(appState: appState));
    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pumpAndSettle();

    expect(find.text('Sunny Thali House'), findsAtLeastNWidgets(1));
    expect(find.text('Night Off Kitchen'), findsAtLeastNWidgets(1));
    expect(find.text('Closed today'), findsAtLeastNWidgets(1));

    await tester.scrollUntilVisible(
      find.text('CLOSED TODAY'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CLOSED TODAY'), findsAtLeastNWidgets(1));

    await tester.scrollUntilVisible(
      find.text('Open now'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Open now').first);
    await tester.pumpAndSettle();

    expect(find.text('Sunny Thali House'), findsAtLeastNWidgets(1));
    expect(find.text('Night Off Kitchen'), findsNothing);
    expect(find.text('CLOSED TODAY'), findsNothing);
    expect(find.text('Closed today'), findsNothing);
  });

  testWidgets('CreateSubscriptionScreen defaults to Single Meal Order (exact ₹30) and hides Monthly plans/days unless requested', (tester) async {
    final provider = MessProvider(
      id: 'p-1',
      name: 'Ritik Mess',
      area: 'Sector 62',
      distanceMeters: 400,
      description: 'Home meals',
      mealSlots: const [
        MealSlot(
          id: 'breakfast',
          name: 'Breakfast',
          startHour: 7,
          startMinute: 30,
          endHour: 10,
          endMinute: 0,
          menuSummary: 'Aloo Paratha',
          items: [],
          startingPrice: 30,
        ),
      ],
      plans: const [
        MealPlan(id: 'plan-1', providerId: 'p-1', name: 'Monthly', type: SubscriptionType.fixedPeriod, durationDays: 30, price: 1800, slotIds: ['breakfast', 'lunch', 'dinner']),
      ],
      isOpen: true,
    );

    final appState = AppState(repository: _StubRepository(providers: [provider]));
    appState.setMealSelection(const CartMealSelection(
      slotId: 'breakfast',
      slotLabel: 'Breakfast',
      basePrice: 30,
      quantity: 1,
      addOns: {},
      preferredWindow: '07:30 AM - 10:00 AM',
    ));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThaliTheme.light,
        home: AppStateScope(
          notifier: appState,
          child: CreateSubscriptionScreen(provider: provider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order Meal'), findsOneWidget);
    expect(find.text('₹30'), findsAtLeastNWidgets(2));
    expect(find.text('Review Order'), findsOneWidget);
    expect(find.text('Choose Your Plan'), findsNothing);
    expect(find.text('Delivery / Dining Days'), findsNothing);

    await tester.tap(find.text('View Plans'));
    await tester.pumpAndSettle();

    expect(find.text('Create Subscription'), findsOneWidget);
    expect(find.text('Choose Your Plan'), findsOneWidget);
    expect(find.text('Delivery / Dining Days'), findsOneWidget);
  });

  test('AppState isolates notifications per customer across signOut and new signIn', () async {
    SharedPreferences.setMockInitialValues({
      'thali_customer_saved_notifications_v2':
          '[{"id":"legacy-1","title":"Legacy Payment","message":"Paid ₹2","timestamp":"2026-11-26T00:00:00.000Z"}]',
    });

    final appState = AppState(repository: _StubRepository());
    await appState.initSession();
    expect(appState.notifications, isEmpty);

    appState.signIn(
      emailOrPhone: 'user1@example.com',
      name: 'User One',
      phone: '9876543210',
      userId: 'cust-111',
      token: 'tok-111',
      locality: 'Sector 62',
      city: 'Noida',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    appState.addNotification(title: 'Online Payment Successful', message: 'Paid ₹2');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(appState.notifications.length, 1);

    await appState.signOut();
    expect(appState.notifications, isEmpty);

    appState.signIn(
      emailOrPhone: 'user2@example.com',
      name: 'User Two',
      phone: '9123456780',
      userId: 'cust-222',
      token: 'tok-222',
      locality: 'Indiranagar',
      city: 'Bengaluru',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(appState.notifications, isEmpty);

    await appState.signOut();
    appState.signIn(
      emailOrPhone: 'user1@example.com',
      name: 'User One',
      phone: '9876543210',
      userId: 'cust-111',
      token: 'tok-111',
      locality: 'Sector 62',
      city: 'Noida',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(appState.notifications.map((n) => n.title), contains('Online Payment Successful'));
  });

  testWidgets('RegisterScreen requires a mandatory 10-digit mobile number', (tester) async {
    final appState = AppState(repository: _StubRepository());
    await tester.pumpWidget(
      MaterialApp(
        theme: ThaliTheme.light,
        home: AppStateScope(
          notifier: appState,
          child: const RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mobile Number (optional)'), findsNothing);
    expect(find.text('Mobile Number'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Riya Sharma');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'riya@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile Number'), '12345');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Password123');

    final createBtn = find.byType(MessActionButton);
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);
  });

  testWidgets('HomeScreen displays remote hero copy, announcement strip & Featured badge', (tester) async {
    final repo = _StubRepository(providers: const [
      MessProvider(
        id: 'prov-feat-1',
        name: 'Featured Home Kitchen',
        area: 'Sector 62',
        city: 'Noida',
        distanceMeters: 500,
        description: 'Pure veg thalis',
        mealSlots: [],
        plans: [],
        isOpen: true,
        isFeatured: true,
      ),
    ]);
    final appState = AppState(repository: repo);
    appState.signIn(
      emailOrPhone: 'riya@example.com',
      name: 'Riya',
      userId: 'user-feat',
      locality: 'Sector 62',
      city: 'Noida',
    );

    await tester.pumpWidget(MessApp(appState: appState));
    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pumpAndSettle();

    expect(find.text('Fresh home thalis curated daily'), findsOneWidget);
    expect(find.text('Welcome Offer'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Featured'), findsOneWidget);
    expect(repo.lastCityRequested, equals('Noida'));
  });
}
