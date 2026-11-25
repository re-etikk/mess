import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mess_models.dart';
import '../models/app_notification.dart';
import '../repositories/http_mess_repository.dart';
import '../repositories/mess_repository.dart';
import '../services/cashfree_payment_service.dart';
import '../services/customer_auth_service.dart';

class AppState extends ChangeNotifier {
  AppState({MessRepository? repository}) : repository = repository ?? HttpMessRepository();

  final MessRepository repository;
  static const String _sessionKey = 'thali_customer_saved_session';
  static const String _notificationsKey = 'thali_customer_saved_notifications_v2';
  static const String _recentSearchKey = 'thali_customer_recent_searches';

  bool isSignedIn = false;
  bool needsProfileSetup = false;
  String customerId = '';
  String customerName = '';
  String customerEmail = '';
  String customerPhone = '';
  String customerAvatar = '';
  String foodPreference = 'veg'; // veg | non_veg
  String authToken = '';
  String refreshToken = '';

  String location = '';
  String selectedCity = '';
  double? userLat;
  double? userLng;

  String selectedProviderId = '';
  int currentTab = 0;

  ActiveSubscription? _activeSubscription;
  List<ActiveSubscription> activeSubscriptions = [];
  List<ActiveSubscription> pastSubscriptions = [];
  DailyMealEntitlement? _dailyMeal;
  final Set<String> _redeemedSlots = <String>{};
  final List<MealRedemption> _history = <MealRedemption>[];
  List<MessProvider> _cachedProviders = [];
  List<String> recentSearches = [];

  // Create-Subscription Cart: slotId ('breakfast' | 'lunch' | 'dinner') -> CartMealSelection
  final Map<String, CartMealSelection> _mealCart = <String, CartMealSelection>{};
  final Map<String, int> _pendingAddOns = <String, int>{};

  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  Map<String, CartMealSelection> get mealCart => Map.unmodifiable(_mealCart);
  int get mealCartCount => _mealCart.values.fold(0, (s, item) => s + item.quantity);
  int get mealCartPerDayTotal => _mealCart.values.fold(0, (s, item) => s + item.total);

  ActiveSubscription? get activeSubscription => _activeSubscription;
  DailyMealEntitlement? get dailyMeal => _dailyMeal;
  List<MealRedemption> get history => List.unmodifiable(_history);
  Map<String, int> get pendingAddOns => Map.unmodifiable(_pendingAddOns);
  bool get hasActiveSubscription => _activeSubscription != null && _activeSubscription!.isValidToday && _activeSubscription!.hasMealsRemaining;
  bool get hasAnyMealAccess => hasActiveSubscription || (_dailyMeal?.isPaid == true && _dailyMeal!.isForToday(DateTime.now()));
  bool get canOpenScanner => true;

  MessProvider? get activeProvider {
    final activeId = _activeSubscription?.isValidToday == true ? _activeSubscription!.providerId : null;
    final dailyId = _dailyMeal != null && _dailyMeal!.isForToday(DateTime.now()) ? _dailyMeal!.providerId : null;
    final id = activeId ?? dailyId ?? selectedProviderId;
    return _cachedProviders.where((item) => item.id == id).firstOrNull;
  }

  Future<void> initSession() async {
    await _loadNotifications();
    try {
      final prefs = await SharedPreferences.getInstance();
      recentSearches = prefs.getStringList(_recentSearchKey) ?? [];
      final str = prefs.getString(_sessionKey);
      if (str != null && str.isNotEmpty) {
        final data = jsonDecode(str) as Map<String, dynamic>;
        customerId = data['customerId']?.toString() ?? '';
        customerName = data['customerName']?.toString() ?? '';
        customerEmail = data['customerEmail']?.toString() ?? '';
        customerPhone = data['customerPhone']?.toString() ?? '';
        customerAvatar = data['customerAvatar']?.toString() ?? '';
        foodPreference = data['foodPreference']?.toString() ?? 'veg';
        location = data['location']?.toString() ?? '';
        selectedCity = data['selectedCity']?.toString() ?? '';
        userLat = (data['userLat'] as num?)?.toDouble();
        userLng = (data['userLng'] as num?)?.toDouble();
        needsProfileSetup = data['needsProfileSetup'] == true;
        authToken = data['authToken']?.toString() ?? '';
        refreshToken = data['refreshToken']?.toString() ?? '';
        isSignedIn = data['isSignedIn'] == true && customerId.isNotEmpty && authToken.isNotEmpty;

        if (isSignedIn && refreshToken.isNotEmpty) {
          try {
            final refreshed = await CustomerAuthService.refreshSession(
              refreshToken: refreshToken,
              fallbackUserId: customerId,
              fallbackEmail: customerEmail,
              fallbackName: customerName,
            );
            customerId = refreshed.userId;
            customerEmail = refreshed.email;
            if (refreshed.name.isNotEmpty) customerName = refreshed.name;
            authToken = refreshed.token;
            refreshToken = refreshed.refreshToken;
          } catch (_) {}
        }

        if (data['selectedProviderId'] != null) {
          selectedProviderId = data['selectedProviderId'].toString();
        }
        notifyListeners();
        if (isSignedIn) {
          await _persistSession();
          refreshSubscriptionsFromServer();
        }
      }
    } catch (_) {}
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sessionKey,
        jsonEncode({
          'customerId': customerId,
          'customerName': customerName,
          'customerEmail': customerEmail,
          'customerPhone': customerPhone,
          'customerAvatar': customerAvatar,
          'foodPreference': foodPreference,
          'location': location,
          'selectedCity': selectedCity,
          'userLat': userLat,
          'userLng': userLng,
          'needsProfileSetup': needsProfileSetup,
          'isSignedIn': isSignedIn,
          'authToken': authToken,
          'refreshToken': refreshToken,
          'selectedProviderId': selectedProviderId,
        }),
      );
    } catch (_) {}
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_notificationsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _notifications.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) _notifications.add(AppNotification.fromJson(item));
        }
      }
    } catch (_) {}
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _notifications.take(50).map((n) => n.toJson()).toList();
      await prefs.setString(_notificationsKey, jsonEncode(list));
    } catch (_) {}
  }

  void addNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.general,
    String? actionRoute,
  }) {
    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        message: message,
        timestamp: DateTime.now(),
        type: type,
        isRead: false,
        actionRoute: actionRoute,
      ),
    );
    if (_notifications.length > 50) _notifications.removeLast();
    _saveNotifications();
    notifyListeners();
  }

  void markNotificationRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _saveNotifications();
      notifyListeners();
    }
  }

  void markAllNotificationsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _saveNotifications();
    notifyListeners();
  }

  Future<void> recordRecentSearch(String q) async {
    final clean = q.trim();
    if (clean.isEmpty) return;
    recentSearches.removeWhere((x) => x.toLowerCase() == clean.toLowerCase());
    recentSearches.insert(0, clean);
    if (recentSearches.length > 8) recentSearches = recentSearches.take(8).toList();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchKey, recentSearches);
    } catch (_) {}
  }

  Future<void> clearRecentSearches() async {
    recentSearches.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchKey);
    } catch (_) {}
  }

  Future<List<MessProvider>> getProviders({
    String? slot,
    double? minRating,
    bool openNow = false,
    bool deliveryOnly = false,
    String? sort,
    String? dietary,
  }) async {
    final providers = await repository.getProviders(
      lat: userLat,
      lng: userLng,
      slot: slot,
      minRating: minRating,
      openNow: openNow,
      deliveryOnly: deliveryOnly,
      sort: sort,
      dietary: dietary,
    );
    _cachedProviders = providers;
    if (_cachedProviders.isNotEmpty && (selectedProviderId.isEmpty || !_cachedProviders.any((p) => p.id == selectedProviderId))) {
      selectedProviderId = _cachedProviders.first.id;
    }
    notifyListeners();
    return providers;
  }

  Future<List<MessProvider>> searchProviders(String query, {String? dietary}) async {
    return repository.searchProviders(query: query, lat: userLat, lng: userLng, dietary: dietary);
  }

  Future<MessProvider?> getProvider(String id) => repository.getProvider(id);

  void signIn({
    required String emailOrPhone,
    required String name,
    String? userId,
    String? token,
    String? refreshToken,
    bool needsSetup = false,
    String? foodPref,
    String? locality,
    String? city,
  }) {
    if (emailOrPhone.contains('@')) {
      customerEmail = emailOrPhone.trim();
    } else if (emailOrPhone.trim().isNotEmpty) {
      customerPhone = emailOrPhone.trim();
    }
    if (name.trim().isNotEmpty) customerName = name.trim();
    if (token != null && token.isNotEmpty) authToken = token;
    if (refreshToken != null) this.refreshToken = refreshToken;
    if (userId != null && userId.isNotEmpty) customerId = userId;
    if (foodPref != null && foodPref.isNotEmpty) foodPreference = foodPref;
    if (locality != null && locality.isNotEmpty) location = locality;
    if (city != null && city.isNotEmpty) selectedCity = city;
    needsProfileSetup = needsSetup || customerName.trim().isEmpty || location.trim().isEmpty;
    isSignedIn = true;
    notifyListeners();
    _persistSession();
    refreshSubscriptionsFromServer();
  }

  Future<void> completeProfileAndLocation({
    required String name,
    required String foodPref,
    required String locality,
    required String city,
    String? address,
    double? lat,
    double? lng,
  }) async {
    customerName = name.trim();
    foodPreference = foodPref;
    location = locality.trim();
    selectedCity = city.trim();
    userLat = lat;
    userLng = lng;
    needsProfileSetup = false;
    notifyListeners();
    await _persistSession();

    if (customerId.isNotEmpty) {
      await repository.saveProfile(
        userId: customerId,
        displayName: customerName,
        foodPreference: foodPreference,
        address: address ?? locality,
        locality: locality,
        city: city,
        latitude: lat,
        longitude: lng,
        onboardingCompleted: true,
      );
    }
  }

  Future<void> updateProfile({String? name, String? email, String? phone, String? foodPref, String? avatar}) async {
    if (name != null && name.trim().isNotEmpty) customerName = name.trim();
    if (email != null && email.trim().isNotEmpty) customerEmail = email.trim();
    if (phone != null) customerPhone = phone.trim();
    if (foodPref != null) foodPreference = foodPref;
    if (avatar != null) customerAvatar = avatar;
    notifyListeners();
    await _persistSession();
    if (customerId.isNotEmpty) {
      try {
        await repository.saveProfile(
          userId: customerId,
          displayName: customerName,
          email: customerEmail,
          phone: customerPhone,
          foodPreference: foodPreference,
        );
      } catch (_) {}
    }
  }

  Future<void> deleteAccount() async {
    try {
      const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://www.thali.store');
      await http.post(
        Uri.parse('$baseUrl/api/account/delete'),
        headers: {
          'Content-Type': 'application/json',
          if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'user_id': customerId, 'confirmation': 'DELETE'}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
    await signOut();
  }

  Future<void> signOut() async {
    isSignedIn = false;
    needsProfileSetup = false;
    authToken = '';
    refreshToken = '';
    customerId = '';
    customerName = '';
    customerEmail = '';
    customerPhone = '';
    _activeSubscription = null;
    activeSubscriptions = [];
    pastSubscriptions = [];
    _dailyMeal = null;
    _redeemedSlots.clear();
    _mealCart.clear();
    _pendingAddOns.clear();
    currentTab = 0;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }

  void updateLocation(String locality, {String city = '', double? lat, double? lng}) {
    location = locality.trim();
    if (city.isNotEmpty) selectedCity = city.trim();
    if (lat != null) userLat = lat;
    if (lng != null) userLng = lng;
    notifyListeners();
    _persistSession();
  }

  void selectTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  void setSelectedProvider(String providerId) {
    if (selectedProviderId != providerId) {
      selectedProviderId = providerId;
      _mealCart.clear();
    }
    notifyListeners();
  }

  void setMealSelection(CartMealSelection selection) {
    if (selection.quantity <= 0) {
      _mealCart.remove(selection.slotId);
    } else {
      _mealCart[selection.slotId] = selection;
    }
    notifyListeners();
  }

  void adjustMealQuantity(String slotId, int delta) {
    final current = _mealCart[slotId];
    if (current == null) return;
    final nextQty = (current.quantity + delta).clamp(0, 10);
    if (nextQty == 0) {
      _mealCart.remove(slotId);
    } else {
      _mealCart[slotId] = CartMealSelection(
        slotId: current.slotId,
        slotLabel: current.slotLabel,
        basePrice: current.basePrice,
        quantity: nextQty,
        addOns: current.addOns,
        preferredWindow: current.preferredWindow,
      );
    }
    notifyListeners();
  }

  void clearMealCart() {
    _mealCart.clear();
    _pendingAddOns.clear();
    notifyListeners();
  }

  void adjustAddOn(String itemId, int delta, {int maxQuantity = 5}) {
    final newQuantity = ((_pendingAddOns[itemId] ?? 0) + delta).clamp(0, maxQuantity).toInt();
    if (newQuantity == 0) {
      _pendingAddOns.remove(itemId);
    } else {
      _pendingAddOns[itemId] = newQuantity;
    }
    notifyListeners();
  }

  Future<void> refreshSubscriptionsFromServer() async {
    if (customerId.isEmpty) return;
    try {
      final data = await repository.fetchSubscriptions(customerId: customerId);
      final rawActive = data['active_subscriptions'] as List<dynamic>? ?? [];
      final rawPast = data['past_subscriptions'] as List<dynamic>? ?? [];
      activeSubscriptions = rawActive.map((e) => _parseRichSubscription(e as Map<String, dynamic>)).toList();
      pastSubscriptions = rawPast.map((e) => _parseRichSubscription(e as Map<String, dynamic>)).toList();
      _activeSubscription = activeSubscriptions.isNotEmpty ? activeSubscriptions.first : null;
      notifyListeners();
    } catch (_) {}
  }

  ActiveSubscription _parseRichSubscription(Map<String, dynamic> m) {
    final pTypeStr = m['plan_type_snapshot']?.toString() ?? m['plan_type']?.toString() ?? 'fixed_period';
    final subType = pTypeStr == 'meal_credits' ? SubscriptionType.mealTracker : SubscriptionType.fixedPeriod;
    final initMeals = (m['initial_meal_credits'] as num?)?.toInt();
    final remMeals = (m['remaining_meal_credits'] as num?)?.toInt();
    return ActiveSubscription(
      id: m['id']?.toString() ?? '',
      providerId: m['provider_id']?.toString() ?? '',
      providerName: m['provider_name']?.toString() ?? 'Mess Partner',
      planName: m['plan_name_snapshot']?.toString() ?? m['plan_name']?.toString() ?? 'Meal Plan',
      type: subType,
      startDate: DateTime.tryParse(m['starts_at']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(m['expires_at']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 30)),
      slotIds: const ['breakfast', 'lunch', 'dinner'],
      totalMeals: initMeals,
      mealsUsed: initMeals != null && remMeals != null ? (initMeals - remMeals).clamp(0, initMeals) : 0,
      status: m['status']?.toString() ?? 'active',
      priceInr: (m['price_inr'] as num?)?.toInt() ?? (((m['price_paid_paise'] as num?)?.toInt() ?? 0) ~/ 100),
      paymentMode: m['payment_mode']?.toString() ?? 'cashfree_online',
      providerLocality: m['provider_locality']?.toString() ?? '',
      providerPhone: m['provider_phone']?.toString() ?? '',
      repeatDays: (m['repeat_days'] as List<dynamic>? ?? [1, 2, 3, 4, 5, 6, 7]).map((e) => (e as num).toInt()).toList(),
      skipAllowance: (m['skip_allowance'] as num?)?.toInt() ?? 2,
      skipsUsed: (m['skips_used'] as num?)?.toInt() ?? 0,
      autoRenewal: m['auto_renewal'] == true,
      reminderDaysBefore: (m['reminder_days_before'] as num?)?.toInt() ?? 2,
      whatsappUpdates: m['whatsapp_updates'] == true,
      pauseStartDate: DateTime.tryParse(m['pause_started_at']?.toString() ?? ''),
      pauseEndDate: DateTime.tryParse(m['pause_ends_at']?.toString() ?? ''),
      packagingPreference: m['packaging_preference']?.toString() ?? 'reusable_tiffin',
    );
  }

  Future<ActiveSubscription> purchaseCounterCashPlan({
    required MealPlan plan,
    Map<String, dynamic>? selectedSlots,
    List<int>? repeatDays,
    String packagingPreference = 'reusable_tiffin',
    String? deliveryInstructions,
    String? promoCode,
    int discountPaise = 0,
    DateTime? startsAt,
  }) async {
    final subscription = await repository.purchasePlan(
      plan: plan,
      customerId: customerId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      paymentMode: 'counter_cash',
      selectedSlots: selectedSlots,
      repeatDays: repeatDays,
      packagingPreference: packagingPreference,
      deliveryInstructions: deliveryInstructions,
      promoCode: promoCode,
      discountPaise: discountPaise,
      startsAt: startsAt,
    );
    _activeSubscription = subscription;
    selectedProviderId = plan.providerId;
    clearMealCart();
    addNotification(
      title: 'Counter Cash Order Submitted',
      message: 'Pay at ${subscription.providerName} counter so the partner activates your ${plan.name}.',
      type: NotificationType.subscription,
    );
    await refreshSubscriptionsFromServer();
    notifyListeners();
    await _persistSession();
    return subscription;
  }

  Future<Map<String, dynamic>> payWithCashfree({
    required String purpose,
    required MessProvider provider,
    MealPlan? plan,
    String? slotId,
    ActiveSubscription? currentSub,
    int addOnsPaise = 0,
    int discountPaise = 0,
    String? promoCode,
    Map<String, dynamic>? selectedSlots,
    List<int>? repeatDays,
    String packagingPreference = 'reusable_tiffin',
    String? deliveryInstructions,
    DateTime? startsAt,
  }) async {
    final order = await repository.createCashfreeOrder(
      purpose: purpose,
      providerId: provider.id,
      customerId: customerId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      plan: plan,
      subscriptionId: currentSub?.id,
      currentSub: currentSub,
      slotId: slotId,
      addOnsPaise: addOnsPaise,
      discountPaise: discountPaise,
      promoCode: promoCode,
      selectedSlots: selectedSlots,
      repeatDays: repeatDays,
      packagingPreference: packagingPreference,
      deliveryInstructions: deliveryInstructions,
      startsAt: startsAt,
    );

    final orderId = order['order_id']?.toString() ?? '';
    final paymentSessionId = order['payment_session_id']?.toString() ?? '';
    final environment = order['environment']?.toString() ?? 'sandbox';

    if (orderId.isEmpty || paymentSessionId.isEmpty) {
      throw const RepositoryException('Cashfree session ID was not returned by server.', code: 'invalid_cashfree_session');
    }

    final paidOrderId = await CashfreePaymentService.startCheckout(
      orderId: orderId,
      paymentSessionId: paymentSessionId,
      environment: environment,
    );

    final verified = await repository.verifyCashfreePayment(orderId: paidOrderId);
    final start = startsAt ?? DateTime.now();

    if (plan != null) {
      if (plan.type == SubscriptionType.dailyMeal) {
        _dailyMeal = DailyMealEntitlement(
          id: verified['order_id']?.toString() ?? orderId,
          providerId: provider.id,
          providerName: provider.name,
          slotId: slotId ?? 'lunch',
          date: start,
          paidAmount: plan.price,
          isPaid: true,
        );
      } else {
        final subMap = verified['subscription'] as Map<String, dynamic>?;
        _activeSubscription = ActiveSubscription(
          id: subMap?['id']?.toString() ?? order['subscription_id']?.toString() ?? '',
          providerId: provider.id,
          providerName: provider.name,
          planName: plan.name,
          type: plan.type,
          startDate: start,
          endDate: plan.expiryFrom(start),
          slotIds: plan.slotIds,
          totalMeals: plan.type == SubscriptionType.mealTracker ? plan.includedMeals : null,
          mealsUsed: 0,
          status: 'active',
          priceInr: (verified['amount_inr'] as num?)?.toInt() ?? plan.price,
          paymentMode: 'cashfree_online',
        );
      }
      selectedProviderId = provider.id;
    }

    clearMealCart();
    addNotification(
      title: 'Online Payment Successful',
      message: 'Paid ₹${verified['amount_inr'] ?? plan?.price ?? ''} via Cashfree for ${plan?.name ?? provider.name}. Pass activated.',
      type: purpose == 'plan_upgrade' ? NotificationType.upgrade : NotificationType.subscription,
    );
    await refreshSubscriptionsFromServer();
    notifyListeners();
    await _persistSession();
    return verified;
  }

  Future<MealRedemption> redeemMealQr(String payload) async {
    final trimmed = payload.trim();
    String providerId = selectedProviderId;
    String slotName = 'Lunch';
    if (trimmed.startsWith('MESS_QR|')) {
      final parts = trimmed.split('|');
      if (parts.length >= 2) providerId = parts[1];
      if (parts.length >= 4 && parts[3] != 'ALL') slotName = parts[3];
    }
    final today = _dateKey(DateTime.now());
    final entitlementKey = '$providerId|$today|${slotName.toLowerCase()}';
    if (_redeemedSlots.contains(entitlementKey)) {
      throw RepositoryException('Meal already redeemed for $slotName today.', code: 'duplicate_redemption');
    }
    final redemption = await repository.redeemMeal(qrPayload: payload, customerId: customerId);
    _redeemedSlots.add(entitlementKey);
    _history.insert(0, redemption);
    addNotification(
      title: 'Meal Redeemed',
      message: 'Checked in for $slotName at ${redemption.providerName}.',
      type: NotificationType.redemption,
    );
    await refreshSubscriptionsFromServer();
    notifyListeners();
    await _persistSession();
    return redemption;
  }

  bool isSlotRedeemed(String providerId, String slotId, DateTime date) =>
      _redeemedSlots.contains('$providerId|${_dateKey(date)}|${slotId.toLowerCase()}');

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
