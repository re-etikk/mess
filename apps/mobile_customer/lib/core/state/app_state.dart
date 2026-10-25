import 'package:flutter/foundation.dart';

import '../data/demo_data.dart';
import '../models/mess_models.dart';
import '../repositories/demo_mess_repository.dart';
import '../repositories/mess_repository.dart';

class AppState extends ChangeNotifier {
  AppState({MessRepository? repository}) : repository = repository ?? DemoMessRepository() {
    final now = DateTime.now();
    _activeSubscription = ActiveSubscription(
      id: 'demo-active-subscription',
      providerId: 'radhe-mess',
      providerName: 'Radhe Mess',
      planName: '30-meal tracker',
      type: SubscriptionType.mealTracker,
      startDate: now.subtract(const Duration(days: 12)),
      endDate: now.add(const Duration(days: 18)),
      slotIds: const ['lunch', 'dinner'],
      totalMeals: 30,
      mealsUsed: 12,
    );
  }

  final MessRepository repository;
  bool isSignedIn = false;
  bool isDemoMode = true;
  String customerId = 'demo-customer-001';
  String customerName = 'Student';
  String customerEmail = 'student@example.com';
  String location = 'IIT Hostel, Sector 62';
  String selectedProviderId = 'radhe-mess';
  ActiveSubscription? _activeSubscription;
  DailyMealEntitlement? _dailyMeal;
  final Set<String> _redeemedSlots = <String>{};
  final List<MealRedemption> _history = <MealRedemption>[];
  final Map<String, int> _pendingAddOns = <String, int>{};
  int currentTab = 0;

  ActiveSubscription? get activeSubscription => _activeSubscription;
  DailyMealEntitlement? get dailyMeal => _dailyMeal;
  List<MealRedemption> get history => List.unmodifiable(_history);
  Map<String, int> get pendingAddOns => Map.unmodifiable(_pendingAddOns);
  bool get hasActiveSubscription => _activeSubscription != null && _activeSubscription!.isValidToday && _activeSubscription!.hasMealsRemaining;
  bool get hasAnyMealAccess => hasActiveSubscription || (_dailyMeal?.isPaid == true && _dailyMeal!.isForToday(DateTime.now()));
  bool get canOpenScanner => hasAnyMealAccess;

  MessProvider? get activeProvider {
    final activeId = _activeSubscription?.isValidToday == true ? _activeSubscription!.providerId : null;
    final dailyId = _dailyMeal != null && _dailyMeal!.isForToday(DateTime.now()) ? _dailyMeal!.providerId : null;
    final id = activeId ?? dailyId ?? selectedProviderId;
    return DemoData.providers.where((item) => item.id == id).firstOrNull;
  }

  Future<List<MessProvider>> getProviders() => repository.getProviders();
  Future<MessProvider?> getProvider(String id) => repository.getProvider(id);

  void signInDemo({required String emailOrPhone, required String name}) {
    customerEmail = emailOrPhone.contains('@') ? emailOrPhone.trim() : '$emailOrPhone@demo.local';
    customerName = name.trim().isEmpty ? _nameFromEmail(customerEmail) : name.trim();
    isSignedIn = true;
    notifyListeners();
  }

  void signOut() {
    isSignedIn = false;
    currentTab = 0;
    notifyListeners();
  }

  void updateLocation(String value) {
    location = value;
    notifyListeners();
  }

  void selectTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  void previewNoSubscription() {
    _activeSubscription = null;
    _dailyMeal = null;
    _redeemedSlots.clear();
    _pendingAddOns.clear();
    notifyListeners();
  }

  void previewTrackerSubscription() {
    final now = DateTime.now();
    _activeSubscription = ActiveSubscription(
      id: 'demo-preview-tracker',
      providerId: 'radhe-mess',
      providerName: 'Radhe Mess',
      planName: '30-meal tracker',
      type: SubscriptionType.mealTracker,
      startDate: now.subtract(const Duration(days: 12)),
      endDate: now.add(const Duration(days: 18)),
      slotIds: const ['lunch', 'dinner'],
      totalMeals: 30,
      mealsUsed: 12,
    );
    _dailyMeal = null;
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

  Future<ActiveSubscription> purchasePlanDemo(MealPlan plan) async {
    if (plan.type == SubscriptionType.dailyMeal) {
      throw const RepositoryException('Use purchaseDailyMealDemo for a daily meal.', code: 'wrong_plan_type');
    }
    final subscription = await repository.purchasePlan(plan: plan, customerId: customerId);
    _activeSubscription = subscription;
    _dailyMeal = null;
    selectedProviderId = plan.providerId;
    clearAddOns();
    notifyListeners();
    return subscription;
  }

  Future<DailyMealEntitlement> purchaseDailyMealDemo(MealPlan plan, String slotId) async {
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

  Future<MealRedemption> redeemDemoQr(String payload) async {
    final parts = payload.split('|');
    if (parts.length < 3) {
      throw const RepositoryException('This QR code is not recognised.', code: 'invalid_qr');
    }
    final providerId = parts[1];
    final today = _dateKey(DateTime.now());
    if (parts.length < 4 || parts[0] != 'MESS_DEMO' || parts[2] != today) {
      throw const RepositoryException('This code is invalid or expired. Ask the mess staff for today’s QR.', code: 'expired_or_invalid_qr');
    }
    final provider = await repository.getProvider(providerId);
    if (provider == null) throw const RepositoryException('Mess not found.', code: 'provider_not_found');
    final now = DateTime.now();
    final slot = provider.mealSlots.where((item) => item.contains(now)).firstOrNull;
    if (slot == null) throw const RepositoryException('No meal is being served right now.', code: 'no_active_slot');

    final entitlementKey = '$providerId|$today|${slot.id}';
    if (_redeemedSlots.contains(entitlementKey)) {
      throw const RepositoryException('This meal has already been marked for today.', code: 'duplicate_meal');
    }

    final subscription = _activeSubscription;
    final validSubscription = subscription != null &&
        subscription.providerId == providerId &&
        subscription.isValidToday &&
        subscription.slotIds.contains(slot.id) &&
        subscription.hasMealsRemaining;
    final validDaily = _dailyMeal != null &&
        _dailyMeal!.providerId == providerId &&
        _dailyMeal!.slotId == slot.id &&
        _dailyMeal!.isPaid &&
        _dailyMeal!.isForToday(now);
    if (!validSubscription && !validDaily) {
      throw const RepositoryException('No eligible plan or paid daily meal was found for this mess and meal slot.', code: 'no_entitlement');
    }

    final redemption = await repository.redeemMeal(qrPayload: payload, customerId: customerId);
    _redeemedSlots.add(entitlementKey);
    _history.insert(0, redemption);
    if (validSubscription && subscription!.type == SubscriptionType.mealTracker) {
      _activeSubscription = ActiveSubscription(
        id: subscription.id,
        providerId: subscription.providerId,
        providerName: subscription.providerName,
        planName: subscription.planName,
        type: subscription.type,
        startDate: subscription.startDate,
        endDate: subscription.endDate,
        slotIds: subscription.slotIds,
        totalMeals: subscription.totalMeals,
        mealsUsed: subscription.mealsUsed + 1,
      );
    }
    if (validDaily) _dailyMeal = null;
    notifyListeners();
    return redemption;
  }

  void recordDemoAddOnPayment({required String providerName, required List<CartAddOn> addOns}) {
    if (addOns.isEmpty) return;
    final now = DateTime.now();
    _history.insert(0, MealRedemption(id: 'demo-addon-${now.microsecondsSinceEpoch}', providerName: providerName, slotName: 'Food extras', redeemedAt: now, status: 'Paid in local demo'));
    _pendingAddOns.clear();
    notifyListeners();
  }

  bool isSlotRedeemed(String providerId, String slotId, DateTime date) => _redeemedSlots.contains('$providerId|${_dateKey(date)}|$slotId');

  static String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String _nameFromEmail(String email) {
    final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (local.isEmpty) return 'Student';
    return local.split(' ').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
