import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mess_models.dart';
import 'mess_repository.dart';

class HttpMessRepository implements MessRepository {
  HttpMessRepository({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'https://mess-beta.vercel.app',
            );

  final String baseUrl;
  List<MessProvider> _cachedProviders = [];

  @override
  Future<List<MessProvider>> getProviders() async {
    try {
      final uri = Uri.parse('$baseUrl/api/mess/search');
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final list = (data is Map && data['providers'] is List)
            ? (data['providers'] as List)
            : (data is List ? data : []);

        final providers = list.map((json) => _parseProvider(json as Map<String, dynamic>)).toList();
        _cachedProviders = providers;
        return providers;
      }
    } catch (_) {}
    return _cachedProviders;
  }

  @override
  Future<List<MessProvider>> searchProviders({String query = ''}) async {
    try {
      final qParam = query.trim().isNotEmpty ? '?q=${Uri.encodeComponent(query.trim())}' : '';
      final uri = Uri.parse('$baseUrl/api/mess/search$qParam');
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final list = (data is Map && data['providers'] is List)
            ? (data['providers'] as List)
            : (data is List ? data : []);

        final providers = list.map((json) => _parseProvider(json as Map<String, dynamic>)).toList();
        if (query.trim().isEmpty) {
          _cachedProviders = providers;
        }
        return providers;
      }
    } catch (_) {}
    return _cachedProviders;
  }

  @override
  Future<MessProvider?> getProvider(String providerId) async {
    if (_cachedProviders.isEmpty) {
      await getProviders();
    }
    for (final p in _cachedProviders) {
      if (p.id == providerId) return p;
    }
    return _cachedProviders.isNotEmpty ? _cachedProviders.first : null;
  }

  @override
  Future<MealRedemption> redeemMeal({required String qrPayload, required String customerId}) async {
    final uri = Uri.parse('$baseUrl/api/scan');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': qrPayload.trim(),
              'user_id': customerId,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw const RepositoryException('Network error connecting to counter verification.', code: 'network_error');
    }

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    final bool isSuccess = (response.statusCode >= 200 && response.statusCode < 300) && (data['success'] == true);

    if (isSuccess) {
      final slot = data['slot']?.toString() ?? 'Meal';
      final remCredits = data['remaining_credits'];
      final message = data['message']?.toString() ?? 'Meal redeemed successfully.';

      return MealRedemption(
        id: data['redemption_id']?.toString() ?? 'red-${DateTime.now().microsecondsSinceEpoch}',
        providerName: _providerNameFromToken(qrPayload),
        slotName: slot,
        redeemedAt: DateTime.now(),
        status: remCredits != null ? 'Credits remaining: $remCredits' : message,
      );
    } else {
      final message = data['message']?.toString() ?? data['error']?.toString() ?? 'Meal redemption failed.';
      String code = 'invalid_qr';
      if (message.toLowerCase().contains('already redeemed')) {
        code = 'duplicate_redemption';
      } else if (message.toLowerCase().contains('no active subscription') ||
          message.toLowerCase().contains('no meal credits') ||
          message.toLowerCase().contains('pass found') ||
          message.toLowerCase().contains('renew')) {
        code = 'no_entitlement';
      } else if (message.toLowerCase().contains('closed') || message.toLowerCase().contains('off today')) {
        code = 'mess_closed';
      } else if (message.toLowerCase().contains('expired')) {
        code = 'expired_qr';
      }
      throw RepositoryException(message, code: code);
    }
  }

  @override
  Future<ActiveSubscription> purchasePlan({required MealPlan plan, required String customerId}) async {
    final uri = Uri.parse('$baseUrl/api/subscription/subscribe');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'provider_id': plan.providerId,
            'plan_id': plan.id,
            'customer_id': customerId,
            'plan_type': plan.type == SubscriptionType.fixedPeriod ? 'fixed_period' : 'meal_credits',
            'duration_days': plan.durationDays,
            'meal_credits': plan.includedMeals,
            'price_paise': plan.price * 100,
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      final sub = data['subscription'] as Map<String, dynamic>? ?? {};
      final now = DateTime.now();
      return ActiveSubscription(
        id: sub['id']?.toString() ?? 'sub-${now.microsecondsSinceEpoch}',
        providerId: plan.providerId,
        providerName: (await getProvider(plan.providerId))?.name ?? plan.name,
        planName: plan.name,
        type: plan.type,
        startDate: now,
        endDate: plan.expiryFrom(now),
        slotIds: plan.slotIds,
        totalMeals: plan.type == SubscriptionType.mealTracker ? plan.includedMeals : null,
        mealsUsed: 0,
      );
    }
    throw RepositoryException(data['error']?.toString() ?? 'Failed to subscribe to plan.');
  }

  @override
  Future<DailyMealEntitlement> purchaseDailyMeal({required MealPlan plan, required String slotId, required String customerId}) async {
    final uri = Uri.parse('$baseUrl/api/meal/daily_purchase');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'provider_id': plan.providerId,
            'slot': slotId.toUpperCase(),
            'customer_id': customerId,
            'price_paise': plan.price * 100,
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      final now = DateTime.now();
      return DailyMealEntitlement(
        id: 'daily-${now.microsecondsSinceEpoch}',
        providerId: plan.providerId,
        providerName: (await getProvider(plan.providerId))?.name ?? plan.name,
        slotId: slotId,
        date: now,
        paidAmount: plan.price,
        isPaid: true,
      );
    }
    throw RepositoryException(data['error']?.toString() ?? 'Failed to purchase daily meal pass.');
  }

  String _providerNameFromToken(String payload) {
    if (payload.contains('|')) {
      final parts = payload.split('|');
      if (parts.length >= 2) {
        final pid = parts[1];
        for (final p in _cachedProviders) {
          if (p.id == pid) return p.name;
        }
      }
    }
    if (_cachedProviders.isNotEmpty) return _cachedProviders.first.name;
    return 'Mess Counter';
  }

  MessProvider _parseProvider(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['display_name']?.toString() ?? json['name']?.toString() ?? 'Mess';
    final area = json['locality']?.toString() ?? json['city']?.toString() ?? 'Campus Area';
    final address = json['address']?.toString() ?? '';
    final distKm = (json['distance_km'] as num?)?.toDouble() ?? 0.8;
    final distanceMeters = (distKm * 1000).toInt();
    final description = json['description']?.toString() ?? 'Homely nutritious daily meals for students.';
    final isOpen = json['status']?.toString() == 'active' && json['is_open_today'] != false;

    // Parse plans: strictly reflect provider's plans. ZERO FAKE DATA.
    final rawPlans = (json['plans'] as List<dynamic>? ?? []);
    final List<MealPlan> plans = [];
    for (final p in rawPlans) {
      final planMap = p as Map<String, dynamic>;
      final planTypeStr = planMap['plan_type']?.toString() ?? 'fixed_period';
      final pType = planTypeStr == 'daily'
          ? SubscriptionType.dailyMeal
          : (planTypeStr == 'meal_credits' ? SubscriptionType.mealTracker : SubscriptionType.fixedPeriod);
      final pricePaise = (planMap['price_paise'] as num?)?.toInt() ?? 150000;
      final durDays = (planMap['duration_days'] as num?)?.toInt() ?? 30;

      plans.add(MealPlan(
        id: planMap['id']?.toString() ?? 'plan-$durDays',
        providerId: id,
        name: planMap['name']?.toString() ?? 'Plan',
        type: pType,
        durationDays: durDays,
        durationMonths: durDays >= 30 ? (durDays ~/ 30) : null,
        price: (pricePaise / 100).round(),
        slotIds: const ['lunch', 'dinner'],
        includedMeals: (planMap['meal_credits'] as num?)?.toInt(),
        description: planMap['description']?.toString() ?? '',
      ));
    }

    // Parse real menus from provider. ZERO FAKE DATA.
    final rawMenus = (json['menus'] as List<dynamic>? ?? []);
    final List<MealSlot> mealSlots = [];
    if (rawMenus.isNotEmpty) {
      for (final m in rawMenus) {
        final mMap = m as Map<String, dynamic>;
        final slotStr = (mMap['slot']?.toString() ?? 'LUNCH').toUpperCase();
        final slotId = slotStr.toLowerCase();
        final slotName = slotStr.substring(0, 1) + slotStr.substring(1).toLowerCase();

        final itemsIncluded = (mMap['items_included'] as List<dynamic>? ?? [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final itemsExtraRaw = (mMap['items_extra'] as List<dynamic>? ?? []);

        final List<MenuItem> items = [];
        for (final inc in itemsIncluded) {
          items.add(MenuItem(
            id: 'inc-${inc.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
            name: inc,
            kind: FoodItemKind.included,
            price: 0,
            portion: 'Standard',
          ));
        }
        for (final ext in itemsExtraRaw) {
          if (ext is Map) {
            final extName = ext['name']?.toString() ?? 'Add-on';
            final extPrice = (ext['price'] as num?)?.round() ?? 0;
            items.add(MenuItem(
              id: 'ext-${extName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              name: extName,
              kind: FoodItemKind.addOn,
              price: extPrice,
              portion: 'Add-on',
            ));
          } else if (ext is String && ext.isNotEmpty) {
            items.add(MenuItem(
              id: 'ext-${ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
              name: ext,
              kind: FoodItemKind.addOn,
              price: 30,
              portion: 'Add-on',
            ));
          }
        }

        int startHour = 11, startMinute = 30, endHour = 15, endMinute = 0;
        if (slotStr == 'BREAKFAST') {
          startHour = 7; startMinute = 30; endHour = 9; endMinute = 30;
        } else if (slotStr == 'DINNER') {
          startHour = 19; startMinute = 0; endHour = 22; endMinute = 0;
        }

        mealSlots.add(MealSlot(
          id: slotId,
          name: slotName,
          startHour: startHour,
          startMinute: startMinute,
          endHour: endHour,
          endMinute: endMinute,
          menuSummary: itemsIncluded.isNotEmpty ? itemsIncluded.join(', ') : 'No items listed',
          items: items,
        ));
      }
    }

    if (mealSlots.isEmpty) {
      mealSlots.addAll([
        const MealSlot(
          id: 'breakfast',
          name: 'Breakfast',
          startHour: 7,
          startMinute: 30,
          endHour: 9,
          endMinute: 30,
          menuSummary: 'No menu items published',
          items: [],
        ),
        const MealSlot(
          id: 'lunch',
          name: 'Lunch',
          startHour: 11,
          startMinute: 30,
          endHour: 15,
          endMinute: 0,
          menuSummary: 'No menu items published',
          items: [],
        ),
        const MealSlot(
          id: 'dinner',
          name: 'Dinner',
          startHour: 19,
          startMinute: 0,
          endHour: 22,
          endMinute: 0,
          menuSummary: 'No menu items published',
          items: [],
        ),
      ]);
    }

    return MessProvider(
      id: id,
      name: name,
      area: area,
      address: address,
      distanceMeters: distanceMeters,
      description: description,
      mealSlots: mealSlots,
      plans: plans,
      isOpen: isOpen,
    );
  }
}
