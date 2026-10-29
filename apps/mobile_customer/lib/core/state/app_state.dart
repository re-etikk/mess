import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mess_models.dart';
import '../repositories/http_mess_repository.dart';
import '../repositories/mess_repository.dart';

class AppState extends ChangeNotifier {
  AppState({MessRepository? repository}) : repository = repository ?? HttpMessRepository();

  final MessRepository repository;
  static const String _sessionKey = 'thali_customer_saved_session';

  bool isSignedIn = false;
  String customerId = '';
  String customerName = 'Student';
  String customerEmail = '';
  String location = 'Sector 62, Noida';
  String selectedProviderId = '';
  ActiveSubscription? _activeSubscription;
  DailyMealEntitlement? _dailyMeal;
  final Set<String> _redeemedSlots = <String>{};
  final List<MealRedemption> _history = <MealRedemption>[];
  final Map<String, int> _pendingAddOns = <String, int>{};
  int currentTab = 0;
  List<MessProvider> _cachedProviders = [];

  Future<void> initSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_sessionKey);
      if (str != null && str.isNotEmpty) {
        final data = jsonDecode(str) as Map<String, dynamic>;
        customerId = data['customerId']?.toString() ?? '';
        customerName = data['customerName']?.toString() ?? 'Student';
        customerEmail = data['customerEmail']?.toString() ?? '';
        location = data['location']?.toString() ?? 'Sector 62, Noida';
        isSignedIn = data['isSignedIn'] == true;
        if (data['selectedProviderId'] != null) {
          selectedProviderId = data['selectedProviderId'].toString();
        }
        if (data['activeSubscription'] != null) {
          final s = data['activeSubscription'] as Map<String, dynamic>;
          final typeStr = s['type']?.toString() ?? 'mealTracker';
          final subType = SubscriptionType.values.firstWhere(
            (t) => t.name == typeStr,
            orElse: () => SubscriptionType.mealTracker,
          );
          _activeSubscription = ActiveSubscription(
            id: s['id']?.toString() ?? '',
            providerId: s['providerId']?.toString() ?? '',
            providerName: s['providerName']?.toString() ?? '',
            planName: s['planName']?.toString() ?? '',
            type: subType,
            startDate: DateTime.tryParse(s['startDate']?.toString() ?? '') ?? DateTime.now(),
            endDate: DateTime.tryParse(s['endDate']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 30)),
            slotIds: (s['slotIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['lunch', 'dinner'],
            totalMeals: s['totalMeals'] as int?,
            mealsUsed: (s['mealsUsed'] as int?) ?? 0,
          );
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sub = _activeSubscription;
      await prefs.setString(_sessionKey, jsonEncode({
        'customerId': customerId,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'location': location,
        'isSignedIn': isSignedIn,
        'selectedProviderId': selectedProviderId,
        'activeSubscription': sub == null ? null : {
          'id': sub.id,
          'providerId': sub.providerId,
          'providerName': sub.providerName,
          'planName': sub.planName,
          'type': sub.type.name,
          'startDate': sub.startDate.toIso8601String(),
          'endDate': sub.endDate.toIso8601String(),
          'slotIds': sub.slotIds,
          'totalMeals': sub.totalMeals,
          'mealsUsed': sub.mealsUsed,
        },
      }));
    } catch (_) {}
  }

  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }

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

  Future<List<MessProvider>> getProviders() async {
    final providers = await repository.getProviders();
    _cachedProviders = providers;
    if (_cachedProviders.isNotEmpty && (selectedProviderId.isEmpty || !_cachedProviders.any((p) => p.id == selectedProviderId))) {
      selectedProviderId = _cachedProviders.first.id;
    }
    return providers;
  }

  Future<List<MessProvider>> searchProviders(String query) async {
    final providers = await repository.searchProviders(query: query);
    _cachedProviders = providers;
    return providers;
  }

  Future<MessProvider?> getProvider(String id) async {
    final provider = await repository.getProvider(id);
    if (provider != null && !_cachedProviders.any((p) => p.id == provider.id)) {
      _cachedProviders.add(provider);
    }
    return provider;
  }

  void signIn({required String emailOrPhone, required String name, String? userId}) {
    customerEmail = emailOrPhone.contains('@') ? emailOrPhone.trim() : '$emailOrPhone@student.local';
    customerName = name.trim().isEmpty ? _nameFromEmail(customerEmail) : name.trim();
    if (userId != null && userId.isNotEmpty) {
      customerId = userId;
    }
    isSignedIn = true;
    notifyListeners();
    _persistSession();
  }

  void signOut() {
    isSignedIn = false;
    _activeSubscription = null;
    _dailyMeal = null;
    _redeemedSlots.clear();
    _pendingAddOns.clear();
    currentTab = 0;
    notifyListeners();
    _clearPersistedSession();
  }

  void updateLocation(String value) {
    location = value;
    notifyListeners();
  }

  void selectTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  void setSelectedProvider(String providerId) {
    selectedProviderId = providerId;
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

  void clearAddOns() {
    _pendingAddOns.clear();
    notifyListeners();
  }

  Future<ActiveSubscription> purchasePlan(MealPlan plan) async {
    if (plan.type == SubscriptionType.dailyMeal) {
      throw const RepositoryException('Use purchaseDailyMeal for a daily meal pass.', code: 'wrong_plan_type');
    }
    final subscription = await repository.purchasePlan(plan: plan, customerId: customerId);
    _activeSubscription = subscription;
    _dailyMeal = null;
    selectedProviderId = plan.providerId;
    clearAddOns();
    notifyListeners();
    _persistSession();
    return subscription;
  }

  Future<ActiveSubscription> purchasePlanDemo(MealPlan plan) => purchasePlan(plan);

  Future<DailyMealEntitlement> purchaseDailyMeal(MealPlan plan, String slotId) async {
    if (plan.type != SubscriptionType.dailyMeal) {
      throw const RepositoryException('This plan is not a daily meal.', code: 'wrong_plan_type');
    }
    final entitlement = await repository.purchaseDailyMeal(plan: plan, slotId: slotId, customerId: customerId);
    _dailyMeal = entitlement;
    selectedProviderId = plan.providerId;
    clearAddOns();
    notifyListeners();
    return entitlement;
  }

  Future<DailyMealEntitlement> purchaseDailyMealDemo(MealPlan plan, String slotId) => purchaseDailyMeal(plan, slotId);

  Future<MealRedemption> redeemMealQr(String payload) async {
    final trimmed = payload.trim();
    String providerId = selectedProviderId;
    String slotName = 'Lunch';

    if (trimmed.startsWith('MESS_QR|') || trimmed.startsWith('MESS_DEMO|')) {
      final parts = trimmed.split('|');
      if (parts.length >= 2) providerId = parts[1];
      if (parts.length >= 4 && parts[3] != 'ALL') slotName = parts[3];
    }

    final today = _dateKey(DateTime.now());
    final entitlementKey = '$providerId|$today|${slotName.toLowerCase()}';
    if (_redeemedSlots.contains(entitlementKey)) {
      throw RepositoryException('Meal already redeemed for $slotName today.', code: 'duplicate_redemption');
    }

    // Call backend API /api/scan to verify QR token & customer entitlement
    final redemption = await repository.redeemMeal(qrPayload: payload, customerId: customerId);

    _redeemedSlots.add(entitlementKey);
    _history.insert(0, redemption);

    // If tracker plan, decrement locally to keep UI in sync
    final sub = _activeSubscription;
    if (sub != null && sub.type == SubscriptionType.mealTracker && sub.mealsRemaining != null) {
      _activeSubscription = ActiveSubscription(
        id: sub.id,
        providerId: sub.providerId,
        providerName: sub.providerName,
        planName: sub.planName,
        type: sub.type,
        startDate: sub.startDate,
        endDate: sub.endDate,
        slotIds: sub.slotIds,
        totalMeals: sub.totalMeals,
        mealsUsed: sub.mealsUsed + 1,
      );
    }
    if (_dailyMeal != null) _dailyMeal = null;

    notifyListeners();
    _persistSession();
    return redemption;
  }

  Future<MealRedemption> redeemDemoQr(String payload) => redeemMealQr(payload);

  void recordAddOnPayment({required String providerName, required List<CartAddOn> addOns}) {
    if (addOns.isEmpty) return;
    final now = DateTime.now();
    _history.insert(
      0,
      MealRedemption(
        id: 'addon-${now.microsecondsSinceEpoch}',
        providerName: providerName,
        slotName: 'Food extras',
        redeemedAt: now,
        status: 'Paid successfully',
      ),
    );
    _pendingAddOns.clear();
    notifyListeners();
  }

  void recordDemoAddOnPayment({required String providerName, required List<CartAddOn> addOns}) => recordAddOnPayment(providerName: providerName, addOns: addOns);

  bool isSlotRedeemed(String providerId, String slotId, DateTime date) => _redeemedSlots.contains('$providerId|${_dateKey(date)}|${slotId.toLowerCase()}');

  static String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _nameFromEmail(String email) {
    final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (local.isEmpty) return 'Student';
    return local.split(' ').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
  }
}
