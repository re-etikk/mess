import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mess_models.dart';
import 'mess_repository.dart';

class HttpMessRepository implements MessRepository {
  HttpMessRepository({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'https://www.thali.store',
            );

  final String baseUrl;
  String authToken = '';
  List<MessProvider> _cachedProviders = [];

  Map<String, String> _authHeaders({bool json = false, bool noCache = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (noCache) 'Cache-Control': 'no-cache, no-store',
      if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
    };
  }

  Map<String, dynamic> _safeJsonMap(http.Response response, {required String action}) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException catch (e) {
      throw RepositoryException(
        friendlyCustomerError(e, statusCode: response.statusCode, body: response.body, action: action),
        code: response.statusCode == 404 ? 'not_deployed' : 'invalid_response',
      );
    }
    throw RepositoryException(
      friendlyCustomerError('Unexpected payload', statusCode: response.statusCode, body: response.body, action: action),
      code: 'invalid_response',
    );
  }

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
  }) async {
    final qp = <String, String>{};
    if (lat != null && lng != null) {
      qp['lat'] = lat.toString();
      qp['lng'] = lng.toString();
    }
    if (slot != null && slot.isNotEmpty) qp['slot'] = slot;
    if (minRating != null && minRating > 0) qp['min_rating'] = minRating.toString();
    if (openNow) qp['open_now'] = 'true';
    if (deliveryOnly) qp['delivery_only'] = 'true';
    if (sort != null && sort.isNotEmpty) qp['sort'] = sort;
    if (dietary != null && dietary.isNotEmpty && dietary != 'all') qp['dietary'] = dietary;

    final uri = Uri.parse('$baseUrl/api/mess/search').replace(queryParameters: qp.isEmpty ? null : qp);
    http.Response response;
    try {
      response = await http
          .get(uri, headers: {'Cache-Control': 'no-cache, no-store'})
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw RepositoryException(friendlyCustomerError(e, action: 'load kitchens'), code: 'network_error');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      final list = (data is Map && data['providers'] is List) ? (data['providers'] as List) : (data is List ? data : []);
      final providers = list.map((json) => _parseProvider(json as Map<String, dynamic>)).toList();
      if (qp.isEmpty) _cachedProviders = providers;
      return providers;
    }
    String? msg;
    try {
      final errBody = jsonDecode(response.body);
      if (errBody is Map) msg = errBody['error']?.toString();
    } catch (_) {}
    throw RepositoryException(
      msg ?? friendlyCustomerError('HTTP ${response.statusCode}', statusCode: response.statusCode, body: response.body, action: 'load kitchens'),
      code: 'search_failed',
    );
  }

  @override
  Future<List<MessProvider>> searchProviders({
    String query = '',
    double? lat,
    double? lng,
    String? dietary,
  }) async {
    final qp = <String, String>{};
    if (query.trim().isNotEmpty) qp['q'] = query.trim();
    if (lat != null && lng != null) {
      qp['lat'] = lat.toString();
      qp['lng'] = lng.toString();
    }
    if (dietary != null && dietary.isNotEmpty) qp['dietary'] = dietary;

    final uri = Uri.parse('$baseUrl/api/mess/search').replace(queryParameters: qp.isEmpty ? null : qp);
    http.Response response;
    try {
      response = await http
          .get(uri, headers: {'Cache-Control': 'no-cache, no-store'})
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw RepositoryException(friendlyCustomerError(e, action: 'search kitchens'), code: 'network_error');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      final list = (data is Map && data['providers'] is List) ? (data['providers'] as List) : (data is List ? data : []);
      final providers = list.map((json) => _parseProvider(json as Map<String, dynamic>)).toList();
      if (query.trim().isEmpty) _cachedProviders = providers;
      return providers;
    }
    throw RepositoryException(
      friendlyCustomerError('HTTP ${response.statusCode}', statusCode: response.statusCode, body: response.body, action: 'search kitchens'),
      code: 'search_failed',
    );
  }

  @override
  Future<MessProvider?> getProvider(String providerId) async {
    if (_cachedProviders.isEmpty) {
      try {
        await getProviders();
      } catch (_) {}
    }
    for (final p in _cachedProviders) {
      if (p.id == providerId) return p;
    }
    return null;
  }

  @override
  Future<MessProvider?> fetchLiveProvider(String providerId, {String? day}) async {
    try {
      final dayParam = day != null && day.isNotEmpty ? '?day=${Uri.encodeComponent(day)}' : '';
      final menuUri = Uri.parse('$baseUrl/api/mess/$providerId/menu$dayParam');
      final plansUri = Uri.parse('$baseUrl/api/provider/plans?provider_id=$providerId');
      final results = await Future.wait([
        http.get(menuUri, headers: {'Cache-Control': 'no-cache, no-store'}).timeout(const Duration(seconds: 10)),
        http.get(plansUri, headers: {'Cache-Control': 'no-cache, no-store'}).timeout(const Duration(seconds: 10)),
      ]);

      final base = await getProvider(providerId);
      if (base == null) return null;

      List<MealPlan> updatedPlans = List.from(base.plans);
      if (results[1].statusCode == 200) {
        final plansData = jsonDecode(results[1].body);
        if (plansData is Map && plansData['plans'] is List) {
          final parsed = <MealPlan>[];
          for (final p in plansData['plans'] as List) {
            final pMap = p as Map<String, dynamic>;
            final planTypeStr = pMap['plan_type']?.toString() ?? 'fixed_period';
            final pType = planTypeStr == 'daily'
                ? SubscriptionType.dailyMeal
                : (planTypeStr == 'meal_credits' ? SubscriptionType.mealTracker : SubscriptionType.fixedPeriod);
            final pricePaise = (pMap['price_paise'] as num?)?.toInt() ?? 0;
            final durDays = (pMap['duration_days'] as num?)?.toInt() ?? 30;
            parsed.add(MealPlan(
              id: pMap['id']?.toString() ?? '',
              providerId: providerId,
              name: pMap['name']?.toString() ?? 'Plan',
              type: pType,
              durationDays: durDays,
              durationMonths: durDays >= 30 ? (durDays ~/ 30) : null,
              price: (pricePaise / 100).round(),
              slotIds: const ['breakfast', 'lunch', 'dinner'],
              includedMeals: (pMap['meal_credits'] as num?)?.toInt(),
              description: pMap['description']?.toString() ?? '',
            ));
          }
          if (parsed.isNotEmpty) updatedPlans = parsed;
        }
      }

      List<MealSlot> updatedSlots = List.from(base.mealSlots);
      String? updatedCover = base.coverPath;
      String updatedDesc = base.description;
      bool updatedPickup = base.supportsPickup;
      bool updatedDelivery = base.supportsDelivery;
      bool updatedTakeaway = base.allowsTakeaway;

      if (results[0].statusCode == 200) {
        final menuData = jsonDecode(results[0].body);
        if (menuData is Map) {
          final provMeta = menuData['provider'];
          if (provMeta is Map) {
            final c = provMeta['cover_path']?.toString();
            if (c != null && c.isNotEmpty) updatedCover = c;
            final d = provMeta['description']?.toString();
            if (d != null && d.isNotEmpty) updatedDesc = d;
            if (provMeta.containsKey('supports_pickup')) updatedPickup = provMeta['supports_pickup'] != false;
            if (provMeta.containsKey('supports_delivery')) updatedDelivery = provMeta['supports_delivery'] == true;
            if (provMeta.containsKey('allows_takeaway')) updatedTakeaway = provMeta['allows_takeaway'] != false;
          }
          if (menuData['menus'] is List) {
            final rawMenus = menuData['menus'] as List;
            final rawTimings = menuData['timings'] is Map
                ? Map<String, dynamic>.from(menuData['timings'] as Map)
                : null;
            final parsedSlots = _parseMenus(rawMenus, rawTimings);
            if (parsedSlots.isNotEmpty) updatedSlots = parsedSlots;
          }
        }
      }

      final freshProvider = MessProvider(
        id: base.id,
        name: base.name,
        area: base.area,
        city: base.city,
        distanceMeters: base.distanceMeters,
        distanceKm: base.distanceKm,
        description: updatedDesc,
        mealSlots: updatedSlots,
        plans: updatedPlans,
        isOpen: base.isOpen,
        address: base.address,
        publicPhone: base.publicPhone,
        coverPath: updatedCover,
        rating: base.rating,
        totalReviews: base.totalReviews,
        subscriberCount: base.subscriberCount,
        startingMealPrice: base.startingMealPrice,
        supportsPickup: updatedPickup,
        supportsDelivery: updatedDelivery,
        allowsTakeaway: updatedTakeaway,
        allowsMonthlyPlans: base.allowsMonthlyPlans,
        dietaryTypes: base.dietaryTypes,
        disposableFeeInr: base.disposableFeeInr,
        maxSkipsPerWeek: base.maxSkipsPerWeek,
      );
      final idx = _cachedProviders.indexWhere((p) => p.id == providerId);
      if (idx >= 0) _cachedProviders[idx] = freshProvider;
      return freshProvider;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MealRedemption> redeemMeal({required String qrPayload, required String customerId}) async {
    final uri = Uri.parse('$baseUrl/api/scan');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _authHeaders(json: true),
            body: jsonEncode({'token': qrPayload.trim(), 'user_id': customerId}),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const RepositoryException('Network error connecting to counter verification.', code: 'network_error');
    }

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      final slot = data['slot']?.toString() ?? 'Meal';
      final remCredits = data['remaining_credits'];
      return MealRedemption(
        id: data['redemption_id']?.toString() ?? 'red-${DateTime.now().microsecondsSinceEpoch}',
        providerName: _providerNameFromToken(qrPayload),
        slotName: slot,
        redeemedAt: DateTime.now(),
        status: remCredits != null ? 'Credits remaining: $remCredits' : (data['message']?.toString() ?? 'Meal redeemed'),
      );
    }

    final message = data['message']?.toString() ?? data['error']?.toString() ?? 'Meal redemption failed.';
    final codeRaw = (data['code']?.toString() ?? '').toLowerCase();
    String code = 'invalid_qr';
    if (codeRaw == 'already_redeemed' || message.toLowerCase().contains('already redeemed')) {
      code = 'duplicate_redemption';
    } else if (codeRaw == 'no_active_subscription' ||
        codeRaw == 'plan_unavailable' ||
        codeRaw == 'daily_limit_reached' ||
        message.toLowerCase().contains('no active subscription')) {
      code = 'no_entitlement';
    } else if (codeRaw == 'mess_closed' || message.toLowerCase().contains('closed')) {
      code = 'mess_closed';
    } else if (codeRaw == 'qr_expired' || message.toLowerCase().contains('expired')) {
      code = 'expired_qr';
    }
    throw RepositoryException(message, code: code);
  }

  @override
  Future<ActiveSubscription> purchasePlan({
    required MealPlan plan,
    required String customerId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String paymentMode = 'counter_cash',
    Map<String, dynamic>? selectedSlots,
    List<int>? repeatDays,
    String packagingPreference = 'reusable_tiffin',
    String? deliveryInstructions,
    String fulfillmentMode = 'pickup',
    String? deliveryAddress,
    String? promoCode,
    int discountPaise = 0,
    DateTime? startsAt,
  }) async {
    final uri = Uri.parse('$baseUrl/api/subscription/subscribe');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _authHeaders(json: true),
            body: jsonEncode({
              'provider_id': plan.providerId,
              'plan_id': plan.id,
              'customer_id': customerId,
              if (customerName != null) 'customer_name': customerName,
              if (customerEmail != null) 'customer_email': customerEmail,
              if (customerPhone != null) 'customer_phone': customerPhone,
              'plan_type': plan.type == SubscriptionType.fixedPeriod ? 'fixed_period' : 'meal_credits',
              'duration_days': plan.durationDays,
              'meal_credits': plan.includedMeals,
              'price_paise': plan.price * 100,
              'payment_mode': paymentMode,
              if (selectedSlots != null) 'selected_slots': selectedSlots,
              if (repeatDays != null) 'repeat_days': repeatDays,
              'packaging_preference': packagingPreference,
              if (deliveryInstructions != null && deliveryInstructions.isNotEmpty) 'delivery_instructions': deliveryInstructions,
              'fulfillment_mode': fulfillmentMode,
              if (deliveryAddress != null && deliveryAddress.isNotEmpty) 'delivery_address': deliveryAddress,
              if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
              'discount_paise': discountPaise,
              if (startsAt != null) 'starts_at': startsAt.toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw RepositoryException(friendlyCustomerError(e, action: 'submit subscription'), code: 'network_error');
    }

    final data = _safeJsonMap(response, action: 'submit subscription');
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      final sub = data['subscription'] as Map<String, dynamic>? ?? {};
      final start = startsAt ?? DateTime.now();
      return ActiveSubscription(
        id: sub['id']?.toString() ?? '',
        providerId: plan.providerId,
        providerName: (await getProvider(plan.providerId))?.name ?? plan.name,
        planName: plan.name,
        type: plan.type,
        startDate: start,
        endDate: plan.expiryFrom(start),
        slotIds: plan.slotIds,
        totalMeals: plan.type == SubscriptionType.mealTracker ? plan.includedMeals : null,
        mealsUsed: 0,
        status: sub['status']?.toString() ?? 'pending_payment',
        priceInr: (sub['price_inr'] as num?)?.toInt() ?? plan.price,
        paymentMode: paymentMode,
        repeatDays: repeatDays ?? const [1, 2, 3, 4, 5, 6, 7],
        packagingPreference: packagingPreference,
      );
    }
    throw RepositoryException(
      data['error']?.toString() ??
          friendlyCustomerError('HTTP ${response.statusCode}', statusCode: response.statusCode, action: 'submit subscription'),
      code: 'subscribe_failed',
    );
  }

  @override
  Future<DailyMealEntitlement> purchaseDailyMeal({
    required MealPlan plan,
    required String slotId,
    required String customerId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/meal/daily_purchase');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _authHeaders(json: true),
            body: jsonEncode({
              'provider_id': plan.providerId,
              'slot': slotId.toUpperCase(),
              'customer_id': customerId,
              'price_paise': plan.price * 100,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw RepositoryException(friendlyCustomerError(e, action: 'purchase meal'), code: 'network_error');
    }

    final data = _safeJsonMap(response, action: 'purchase meal');
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return DailyMealEntitlement(
        id: data['entitlement_id']?.toString() ?? 'daily-${DateTime.now().microsecondsSinceEpoch}',
        providerId: plan.providerId,
        providerName: (await getProvider(plan.providerId))?.name ?? plan.name,
        slotId: slotId,
        date: DateTime.now(),
        paidAmount: plan.price,
        isPaid: true,
      );
    }
    throw RepositoryException(data['error']?.toString() ?? 'Unable to purchase daily meal.', code: 'daily_purchase_failed');
  }

  @override
  Future<Map<String, dynamic>> createCashfreeOrder({
    required String purpose,
    required String providerId,
    required String customerId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    MealPlan? plan,
    String? subscriptionId,
    ActiveSubscription? currentSub,
    String? slotId,
    int addOnsPaise = 0,
    int discountPaise = 0,
    String? promoCode,
    Map<String, dynamic>? selectedSlots,
    List<int>? repeatDays,
    String packagingPreference = 'reusable_tiffin',
    String? deliveryInstructions,
    String fulfillmentMode = 'pickup',
    String? deliveryAddress,
    DateTime? startsAt,
  }) async {
    final uri = Uri.parse('$baseUrl/api/payments/cashfree/create-order');
    final response = await http
        .post(
          uri,
          headers: _authHeaders(json: true),
          body: jsonEncode({
            'purpose': purpose,
            'provider_id': providerId,
            'customer_id': customerId,
            if (customerName != null && customerName.isNotEmpty) 'customer_name': customerName,
            if (customerEmail != null && customerEmail.isNotEmpty) 'customer_email': customerEmail,
            if (customerPhone != null && customerPhone.isNotEmpty) 'customer_phone': customerPhone,
            if (plan != null) ...{
              'plan_id': plan.id,
              'target_plan_id': plan.id,
              'plan_name': plan.name,
              'plan_type': plan.type == SubscriptionType.mealTracker
                  ? 'meal_credits'
                  : (plan.type == SubscriptionType.dailyMeal ? 'daily' : 'fixed_period'),
              'duration_days': plan.durationDays,
              'meal_credits': plan.includedMeals,
              'price_paise': plan.price * 100,
              'target_plan_price_paise': plan.price * 100,
            },
            if (subscriptionId != null && subscriptionId.isNotEmpty) 'subscription_id': subscriptionId,
            if (currentSub != null)
              'current_subscription': {
                'providerId': currentSub.providerId,
                'planName': currentSub.planName,
                'type': currentSub.type == SubscriptionType.mealTracker ? 'meal_credits' : 'fixed_period',
                'startDate': currentSub.startDate.toIso8601String(),
                'endDate': currentSub.endDate.toIso8601String(),
                'mealsRemaining': currentSub.mealsRemaining,
                'totalMeals': currentSub.totalMeals,
                'price': currentSub.priceInr,
              },
            if (slotId != null && slotId.isNotEmpty) 'slot': slotId.toUpperCase(),
            if (addOnsPaise > 0) 'add_ons_paise': addOnsPaise,
            if (discountPaise > 0) 'discount_paise': discountPaise,
            if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
            if (selectedSlots != null) 'selected_slots': selectedSlots,
            if (repeatDays != null) 'repeat_days': repeatDays,
            'packaging_preference': packagingPreference,
            if (deliveryInstructions != null && deliveryInstructions.isNotEmpty) 'delivery_instructions': deliveryInstructions,
            'fulfillment_mode': fulfillmentMode,
            if (deliveryAddress != null && deliveryAddress.isNotEmpty) 'delivery_address': deliveryAddress,
            if (startsAt != null) 'starts_at': startsAt.toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw RepositoryException(
      data['error']?.toString() ?? 'Unable to initialize Cashfree payment.',
      code: data['code']?.toString() ?? 'cashfree_order_failed',
    );
  }

  @override
  Future<Map<String, dynamic>> verifyCashfreePayment({required String orderId}) async {
    final uri = Uri.parse('$baseUrl/api/payments/cashfree/verify');
    final response = await http
        .post(
          uri,
          headers: _authHeaders(json: true),
          body: jsonEncode({'order_id': orderId}),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw RepositoryException(
      data['error']?.toString() ?? 'Payment verification failed.',
      code: data['code']?.toString() ?? 'cashfree_verify_failed',
    );
  }

  @override
  Future<Map<String, dynamic>> getUpgradeQuote({
    required String subscriptionId,
    required String targetPlanId,
    ActiveSubscription? currentSub,
    MealPlan? targetPlan,
  }) async {
    final uri = Uri.parse('$baseUrl/api/subscription/upgrade-quote');
    final response = await http
        .post(
          uri,
          headers: _authHeaders(json: true),
          body: jsonEncode({
            'subscription_id': subscriptionId,
            'target_plan_id': targetPlanId,
            if (currentSub != null) ...{
              'provider_id': currentSub.providerId,
              'current_plan_name': currentSub.planName,
              'current_plan_type': currentSub.type == SubscriptionType.mealTracker ? 'meal_credits' : 'fixed_period',
              'start_date': currentSub.startDate.toIso8601String(),
              'end_date': currentSub.endDate.toIso8601String(),
              'duration_days': currentSub.totalDays,
              'remaining_credits': currentSub.mealsRemaining,
              'initial_credits': currentSub.totalMeals,
              'price': currentSub.priceInr,
            },
            if (targetPlan != null) ...{
              'target_plan_name': targetPlan.name,
              'target_plan_price': targetPlan.price,
              'target_plan_price_paise': targetPlan.price * 100,
              'target_plan_type': targetPlan.type == SubscriptionType.mealTracker ? 'meal_credits' : 'fixed_period',
              'target_duration_days': targetPlan.durationDays,
              'target_meal_credits': targetPlan.includedMeals,
            },
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data['quote'] as Map<String, dynamic>? ?? {};
    }
    throw RepositoryException(data['error']?.toString() ?? 'Could not calculate upgrade quote.', code: 'quote_failed');
  }

  @override
  Future<Map<String, dynamic>> requestPlanUpgrade({
    required String subscriptionId,
    required String targetPlanId,
    String paymentMode = 'counter_cash',
    ActiveSubscription? currentSub,
    MealPlan? targetPlan,
  }) async {
    final uri = Uri.parse('$baseUrl/api/subscription/upgrade');
    final response = await http
        .post(
          uri,
          headers: _authHeaders(json: true),
          body: jsonEncode({
            'subscription_id': subscriptionId,
            'target_plan_id': targetPlanId,
            'payment_mode': paymentMode,
            if (currentSub != null) ...{
              'provider_id': currentSub.providerId,
              'current_plan_name': currentSub.planName,
            },
            if (targetPlan != null) ...{
              'target_plan_name': targetPlan.name,
              'target_plan_price': targetPlan.price,
              'target_duration_days': targetPlan.durationDays,
            },
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw RepositoryException(data['error']?.toString() ?? 'Plan upgrade request failed.', code: 'upgrade_failed');
  }

  @override
  Future<Map<String, dynamic>> validatePromo({
    required String code,
    required int orderAmountPaise,
    String? providerId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/promos/validate');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code': code.trim(),
            'order_amount_paise': orderAmountPaise,
            if (providerId != null) 'provider_id': providerId,
          }),
        )
        .timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['isValid'] == true) {
      return data;
    }
    throw RepositoryException(data['message']?.toString() ?? 'Invalid promo code.', code: 'promo_invalid');
  }

  @override
  Future<ReviewSummaryData> fetchMessReviews(String providerId) async {
    final uri = Uri.parse('$baseUrl/api/mess/reviews?provider_id=$providerId');
    final response = await http.get(uri, headers: {'Cache-Control': 'no-cache, no-store'}).timeout(const Duration(seconds: 10));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawBk = data['breakdown'] as Map<String, dynamic>? ?? {};
      final bk = <int, int>{
        5: (rawBk['5'] as num?)?.toInt() ?? 0,
        4: (rawBk['4'] as num?)?.toInt() ?? 0,
        3: (rawBk['3'] as num?)?.toInt() ?? 0,
        2: (rawBk['2'] as num?)?.toInt() ?? 0,
        1: (rawBk['1'] as num?)?.toInt() ?? 0,
      };
      final rawTags = (data['popular_tags'] as List<dynamic>? ?? [])
          .map((e) => e is Map ? e['tag']?.toString() ?? '' : e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
      final imgs = (data['images'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
      final reviews = (data['reviews'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      return ReviewSummaryData(
        averageRating: (data['average_rating'] as num?)?.toDouble(),
        totalReviews: (data['total_reviews'] as num?)?.toInt() ?? reviews.length,
        breakdown: bk,
        images: imgs,
        popularTags: rawTags,
        reviews: reviews,
      );
    }
    return const ReviewSummaryData(
      averageRating: null,
      totalReviews: 0,
      breakdown: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      images: [],
      popularTags: [],
      reviews: [],
    );
  }

  @override
  Future<void> submitMessReview({
    required String providerId,
    required String customerId,
    required String customerName,
    required int rating,
    required String reviewText,
    List<String> tags = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/api/mess/reviews');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _authHeaders(json: true),
            body: jsonEncode({
              'provider_id': providerId,
              'customer_id': customerId,
              'customer_name': customerName,
              'rating': rating,
              'review_text': reviewText.trim(),
              'tags': tags,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw RepositoryException(friendlyCustomerError(e, action: 'save review'), code: 'network_error');
    }
    final data = _safeJsonMap(response, action: 'save review');
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw RepositoryException(data['error']?.toString() ?? 'Could not save review.', code: 'review_failed');
    }
  }

  @override
  Future<Map<String, dynamic>> fetchCustomerMeals({
    required String customerId,
    required String dateStr,
  }) async {
    final uri = Uri.parse('$baseUrl/api/customer/meals?customer_id=$customerId&date=$dateStr');
    http.Response response;
    try {
      response = await http.get(uri, headers: _authHeaders(noCache: true)).timeout(const Duration(seconds: 12));
    } catch (e) {
      throw RepositoryException(friendlyCustomerError(e, action: 'load daily meals'), code: 'network_error');
    }
    final data = _safeJsonMap(response, action: 'load daily meals');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw RepositoryException(
      data['error']?.toString() ??
          friendlyCustomerError('HTTP ${response.statusCode}', statusCode: response.statusCode, action: 'load daily meals'),
      code: 'meals_fetch_failed',
    );
  }

  @override
  Future<Map<String, dynamic>> postMealAction({
    required String action,
    required String subscriptionId,
    required String customerId,
    required String providerId,
    required String serviceDate,
    required String slot,
    String? customTimeSlot,
    String? instructions,
    String? reason,
  }) async {
    final uri = Uri.parse('$baseUrl/api/customer/meals');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _authHeaders(json: true),
            body: jsonEncode({
              'action': action,
              'subscription_id': subscriptionId,
              'customer_id': customerId,
              'provider_id': providerId,
              'service_date': serviceDate,
              'slot': slot.toUpperCase(),
              if (customTimeSlot != null) 'custom_time_slot': customTimeSlot,
              if (instructions != null) 'instructions': instructions,
              if (reason != null) 'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw RepositoryException(friendlyCustomerError(e, action: 'update meal'), code: 'network_error');
    }
    final data = _safeJsonMap(response, action: 'update meal');
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw RepositoryException(data['error']?.toString() ?? 'Could not update meal.', code: 'meal_action_failed');
  }

  @override
  Future<Map<String, dynamic>> fetchSubscriptions({required String customerId}) async {
    final uri = Uri.parse('$baseUrl/api/subscription/manage?customer_id=$customerId');
    http.Response response;
    try {
      response = await http.get(uri, headers: _authHeaders(noCache: true)).timeout(const Duration(seconds: 12));
    } catch (e) {
      throw RepositoryException(friendlyCustomerError(e, action: 'load subscriptions'), code: 'network_error');
    }
    final data = _safeJsonMap(response, action: 'load subscriptions');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw RepositoryException(
      data['error']?.toString() ??
          friendlyCustomerError('HTTP ${response.statusCode}', statusCode: response.statusCode, action: 'load subscriptions'),
      code: 'subs_fetch_failed',
    );
  }

  @override
  Future<Map<String, dynamic>> manageSubscription({
    required String action,
    required String subscriptionId,
    required String customerId,
    String? pauseStartDate,
    String? pauseEndDate,
    String? reason,
    List<int>? repeatDays,
    bool? autoRenewal,
    int? reminderDaysBefore,
    bool? whatsappUpdates,
  }) async {
    final uri = Uri.parse('$baseUrl/api/subscription/manage');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: _authHeaders(json: true),
            body: jsonEncode({
              'action': action,
              'subscription_id': subscriptionId,
              'customer_id': customerId,
              if (pauseStartDate != null) 'pause_start_date': pauseStartDate,
              if (pauseEndDate != null) 'pause_end_date': pauseEndDate,
              if (reason != null) 'reason': reason,
              if (repeatDays != null) 'repeat_days': repeatDays,
              if (autoRenewal != null) 'auto_renewal': autoRenewal,
              if (reminderDaysBefore != null) 'reminder_days_before': reminderDaysBefore,
              if (whatsappUpdates != null) 'whatsapp_updates': whatsappUpdates,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw RepositoryException(friendlyCustomerError(e, action: 'update subscription'), code: 'network_error');
    }
    final data = _safeJsonMap(response, action: 'update subscription');
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw RepositoryException(data['error']?.toString() ?? 'Could not update subscription.', code: 'sub_manage_failed');
  }

  @override
  Future<Map<String, dynamic>> saveProfile({
    required String userId,
    String? displayName,
    String? foodPreference,
    String? email,
    String? phone,
    String? address,
    String? locality,
    String? city,
    double? latitude,
    double? longitude,
    bool? onboardingCompleted,
  }) async {
    final uri = Uri.parse('$baseUrl/api/user/profile');
    final response = await http
        .post(
          uri,
          headers: _authHeaders(json: true),
          body: jsonEncode({
            'user_id': userId,
            if (displayName != null) 'display_name': displayName,
            if (foodPreference != null) 'food_preference': foodPreference,
            if (email != null) 'email': email,
            if (phone != null) 'phone': phone,
            if (address != null) 'address': address,
            if (locality != null) 'locality': locality,
            if (city != null) 'city': city,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (onboardingCompleted != null) 'onboarding_completed': onboardingCompleted,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
      return data;
    }
    throw RepositoryException(data['error']?.toString() ?? 'Could not save profile.', code: 'profile_save_failed');
  }

  @override
  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    final uri = Uri.parse('$baseUrl/api/location/autocomplete?input=${Uri.encodeComponent(query)}');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['predictions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$baseUrl/api/location/autocomplete?lat=$lat&lng=$lng');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['address'] as Map<String, dynamic>? ?? {};
    }
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAddresses(String customerId) async {
    final uri = Uri.parse('$baseUrl/api/user/addresses?customer_id=$customerId');
    final response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['addresses'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  @override
  Future<void> saveAddress(Map<String, dynamic> address) async {
    final uri = Uri.parse('$baseUrl/api/user/addresses');
    final response = await http
        .post(uri, headers: _authHeaders(json: true), body: jsonEncode(address))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const RepositoryException('Unable to save address.', code: 'address_save_failed');
    }
  }

  @override
  Future<void> deleteAddress(String id, String customerId) async {
    final uri = Uri.parse('$baseUrl/api/user/addresses?id=$id&customer_id=$customerId');
    await http.delete(uri, headers: _authHeaders()).timeout(const Duration(seconds: 10));
  }

  String _providerNameFromToken(String payload) {
    if (payload.contains('|')) {
      final parts = payload.split('|');
      if (parts.length >= 2) {
        for (final p in _cachedProviders) {
          if (p.id == parts[1]) return p.name;
        }
      }
    }
    return 'Mess Counter';
  }

  static (int, int) _parseTimeString(String raw) {
    if (raw.isEmpty) return (0, 0);
    final upper = raw.trim().toUpperCase();
    final isPm = upper.contains('PM');
    final isAm = upper.contains('AM');
    final cleaned = upper.replaceAll('AM', '').replaceAll('PM', '').trim();
    final parts = cleaned.split(':');
    if (parts.length < 2) return (0, 0);
    int hour = int.tryParse(parts[0].trim()) ?? 0;
    final minute = int.tryParse(parts[1].trim()) ?? 0;
    if (isPm && hour != 12) hour += 12;
    if (isAm && hour == 12) hour = 0;
    return (hour.clamp(0, 23), minute.clamp(0, 59));
  }

  static (int, int, int, int) _defaultTiming(String slotStr) {
    if (slotStr == 'BREAKFAST') return (7, 30, 9, 30);
    if (slotStr == 'DINNER') return (19, 30, 21, 30);
    return (12, 0, 14, 0);
  }

  List<MealSlot> _parseMenus(List<dynamic> rawMenus, Map<String, dynamic>? rawTimings) {
    final List<MealSlot> mealSlots = [];
    for (final m in rawMenus) {
      final mMap = m as Map<String, dynamic>;
      final slotStr = (mMap['slot']?.toString() ?? 'LUNCH').toUpperCase();
      final slotId = slotStr.toLowerCase();
      final slotName = slotStr.substring(0, 1) + slotStr.substring(1).toLowerCase();

      final itemsIncluded = (mMap['items_included'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final itemsExtraRaw = mMap['items_extra'] as List<dynamic>? ?? [];
      final fullItems = mMap['items'] as List<dynamic>? ?? [];

      final List<MenuItem> items = [];
      int? slotStartingPrice;
      for (final it in fullItems) {
        if (it is Map && it['is_add_on'] != true) {
          final p = ((it['price_paise'] as num?)?.toInt() ?? 0) ~/ 100;
          if (p > 0 && (slotStartingPrice == null || p < slotStartingPrice)) slotStartingPrice = p;
        }
      }

      for (final inc in itemsIncluded) {
        items.add(MenuItem(
          id: 'inc-$slotId-${inc.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: inc,
          kind: FoodItemKind.included,
          price: 0,
          portion: 'Standard',
        ));
      }
      for (final ext in itemsExtraRaw) {
        if (ext is Map) {
          final extName = ext['name']?.toString() ?? 'Add-on';
          final extPrice = (ext['price'] as num?)?.round() ?? (((ext['price_paise'] as num?)?.toInt() ?? 0) ~/ 100);
          final kindStr = ext['kind']?.toString() ?? 'addon';
          items.add(MenuItem(
            id: ext['id']?.toString() ?? 'ext-$slotId-${extName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
            name: extName,
            kind: kindStr == 'special' ? FoodItemKind.special : FoodItemKind.addOn,
            price: extPrice,
            portion: kindStr == 'special' ? 'Special' : 'Add-on',
          ));
        }
      }

      int startHour, startMinute, endHour, endMinute;
      bool slotEnabled = (mMap['active'] as bool?) ?? true;
      final timingObj = (rawTimings != null && rawTimings[slotId] is Map)
          ? rawTimings[slotId] as Map<String, dynamic>
          : null;
      if (timingObj != null && timingObj.containsKey('enabled')) {
        slotEnabled = timingObj['enabled'] as bool? ?? slotEnabled;
      }

      final startsAt = mMap['starts_at_local']?.toString() ?? '';
      final endsAt = mMap['ends_at_local']?.toString() ?? '';
      if (startsAt.isNotEmpty && endsAt.isNotEmpty) {
        final s = _parseTimeString(startsAt);
        final e = _parseTimeString(endsAt);
        startHour = s.$1;
        startMinute = s.$2;
        endHour = e.$1;
        endMinute = e.$2;
      } else if (timingObj != null) {
        final s = _parseTimeString(timingObj['start']?.toString() ?? '');
        final e = _parseTimeString(timingObj['end']?.toString() ?? '');
        startHour = s.$1;
        startMinute = s.$2;
        endHour = e.$1;
        endMinute = e.$2;
      } else {
        (startHour, startMinute, endHour, endMinute) = _defaultTiming(slotStr);
      }

      mealSlots.add(MealSlot(
        id: slotId,
        name: slotName,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        menuSummary: itemsIncluded.isNotEmpty ? itemsIncluded.join(' · ') : 'Menu updating soon',
        items: items,
        enabled: slotEnabled,
        startingPrice: slotStartingPrice,
      ));
    }
    return mealSlots;
  }

  MessProvider _parseProvider(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['display_name']?.toString() ?? json['name']?.toString() ?? '';
    final area = json['locality']?.toString() ?? json['city']?.toString() ?? '';
    final city = json['city']?.toString() ?? '';
    final address = [json['address_line1'], json['locality'], json['city']].where((v) => v != null && v.toString().isNotEmpty).join(', ');
    final distKm = (json['distance_km'] as num?)?.toDouble();
    final distanceMeters = distKm != null ? (distKm * 1000).round() : 0;
    final description = json['description']?.toString() ?? '';
    final isOpen = json['status']?.toString() == 'active' && json['is_open_today'] != false;

    final rawPlans = json['plans'] as List<dynamic>? ?? [];
    final plans = rawPlans.map((p) {
      final m = p as Map<String, dynamic>;
      final planTypeStr = m['plan_type']?.toString() ?? 'fixed_period';
      final pType = planTypeStr == 'daily'
          ? SubscriptionType.dailyMeal
          : (planTypeStr == 'meal_credits' ? SubscriptionType.mealTracker : SubscriptionType.fixedPeriod);
      final pricePaise = (m['price_paise'] as num?)?.toInt() ?? 0;
      final durDays = (m['duration_days'] as num?)?.toInt() ?? 30;
      return MealPlan(
        id: m['id']?.toString() ?? '',
        providerId: id,
        name: m['name']?.toString() ?? 'Plan',
        type: pType,
        durationDays: durDays,
        durationMonths: durDays >= 30 ? (durDays ~/ 30) : null,
        price: (pricePaise / 100).round(),
        slotIds: const ['breakfast', 'lunch', 'dinner'],
        includedMeals: (m['meal_credits'] as num?)?.toInt(),
        description: m['description']?.toString() ?? '',
      );
    }).toList();

    final rawMenus = json['menus'] as List<dynamic>? ?? [];
    final rawTimings = json['timings'] as Map<String, dynamic>?;
    final mealSlots = _parseMenus(rawMenus, rawTimings);

    return MessProvider(
      id: id,
      name: name,
      area: area,
      city: city,
      address: address.isNotEmpty ? address : null,
      publicPhone: json['public_phone']?.toString(),
      coverPath: json['cover_path']?.toString(),
      distanceMeters: distanceMeters,
      distanceKm: distKm,
      description: description,
      mealSlots: mealSlots,
      plans: plans,
      isOpen: isOpen,
      rating: (json['rating'] as num?)?.toDouble(),
      totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
      subscriberCount: (json['subscriber_count'] as num?)?.toInt() ?? 0,
      startingMealPrice: (json['starting_meal_price'] as num?)?.toInt(),
      supportsPickup: json['supports_pickup'] != false,
      supportsDelivery: json['supports_delivery'] == true,
      allowsTakeaway: json['allows_takeaway'] != false,
      allowsMonthlyPlans: json['allows_monthly_plans'] != false,
      dietaryTypes: (json['dietary_types'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      disposableFeeInr: ((json['disposable_fee_paise'] as num?)?.toInt() ?? 500) ~/ 100,
      maxSkipsPerWeek: (json['max_skips_per_week'] as num?)?.toInt() ?? 2,
    );
  }

  @override
  Future<Map<String, dynamic>> recommendPlans({
    required String providerId,
    required int weeklyDays,
    required int weeklySkips,
    int mealsPerDay = 2,
  }) async {
    final uri = Uri.parse('$baseUrl/api/ai/plan-recommender');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'provider_id': providerId,
            'weekly_days': weeklyDays,
            'weekly_skips': weeklySkips,
            'meals_per_day': mealsPerDay,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final map = _safeJsonMap(resp, action: 'compare plans');
    if (resp.statusCode >= 400 || map['success'] == false) {
      throw RepositoryException(
        map['error']?.toString() ?? 'Unable to compute plan savings right now.',
      );
    }
    return map;
  }

  @override
  Future<Map<String, dynamic>> smartSearchParse(String query) async {
    final uri = Uri.parse('$baseUrl/api/ai/smart-search');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'query': query}),
        )
        .timeout(const Duration(seconds: 12));
    final map = _safeJsonMap(resp, action: 'parse smart search');
    if (resp.statusCode >= 400 || map['success'] == false) {
      throw RepositoryException(
        map['error']?.toString() ?? 'Smart search unavailable.',
      );
    }
    return map;
  }
}
