import '../models/mess_models.dart';

abstract interface class MessRepository {
  Future<List<MessProvider>> getProviders({
    double? lat,
    double? lng,
    String? slot,
    double? minRating,
    bool openNow = false,
    bool deliveryOnly = false,
    String? sort,
    String? dietary,
  });

  Future<List<MessProvider>> searchProviders({
    String query = '',
    double? lat,
    double? lng,
    String? dietary,
  });

  Future<MessProvider?> getProvider(String providerId);
  Future<MessProvider?> fetchLiveProvider(String providerId, {String? day});

  Future<MealRedemption> redeemMeal({required String qrPayload, required String customerId});

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
    String fulfillmentMode = 'pickup',
    String? deliveryAddress,
    String? deliveryInstructions,
    String? promoCode,
    int discountPaise = 0,
    DateTime? startsAt,
  });

  Future<DailyMealEntitlement> purchaseDailyMeal({
    required MealPlan plan,
    required String slotId,
    required String customerId,
  });

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
    String fulfillmentMode = 'pickup',
    String? deliveryAddress,
    String? deliveryInstructions,
    DateTime? startsAt,
  });

  Future<Map<String, dynamic>> verifyCashfreePayment({required String orderId});

  Future<Map<String, dynamic>> getUpgradeQuote({
    required String subscriptionId,
    required String targetPlanId,
    ActiveSubscription? currentSub,
    MealPlan? targetPlan,
  });

  Future<Map<String, dynamic>> requestPlanUpgrade({
    required String subscriptionId,
    required String targetPlanId,
    String paymentMode = 'counter_cash',
    ActiveSubscription? currentSub,
    MealPlan? targetPlan,
  });

  // New real API methods for Behance 1:1 flows
  Future<Map<String, dynamic>> validatePromo({
    required String code,
    required int orderAmountPaise,
    String? providerId,
  });

  Future<ReviewSummaryData> fetchMessReviews(String providerId);
  Future<void> submitMessReview({
    required String providerId,
    required String customerId,
    required String customerName,
    required int rating,
    required String reviewText,
    List<String> tags = const [],
  });

  Future<Map<String, dynamic>> fetchCustomerMeals({
    required String customerId,
    required String dateStr,
  });

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
  });

  Future<Map<String, dynamic>> fetchSubscriptions({required String customerId});

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
  });

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
  });

  Future<List<Map<String, dynamic>>> searchLocations(String query);
  Future<Map<String, dynamic>> reverseGeocode(double lat, double lng);
  Future<List<Map<String, dynamic>>> fetchAddresses(String customerId);
  Future<void> saveAddress(Map<String, dynamic> address);
  Future<void> deleteAddress(String id, String customerId);

  Future<Map<String, dynamic>> recommendPlans({
    required String providerId,
    required int weeklyDays,
    required int weeklySkips,
    int mealsPerDay = 2,
  });

  Future<Map<String, dynamic>> smartSearchParse(String query);
}

class RepositoryException implements Exception {
  const RepositoryException(this.message, {this.code = 'unknown'});
  final String message;
  final String code;
  @override
  String toString() => message;
}

/// Converts raw transport/HTTP/SQL failures into clear, user-friendly English.
String friendlyCustomerError(
  Object error, {
  int? statusCode,
  String? body,
  String action = 'complete request',
}) {
  final raw = error is RepositoryException ? error.message : error.toString();
  final cleaned = raw.replaceFirst('Exception: ', '').replaceFirst('RepositoryException: ', '').trim();
  final lower = cleaned.toLowerCase();

  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('clientexception')) {
    return 'No internet connection. Check your network and try again.';
  }
  if (lower.contains('timeoutexception') || lower.contains('timed out')) {
    return 'Request took too long. Please try again.';
  }

  final bodyTrim = (body ?? '').trimLeft().toLowerCase();
  final looksTechnical = statusCode == 404 ||
      lower.contains('formatexception') ||
      bodyTrim.startsWith('<!doctype') ||
      bodyTrim.startsWith('<html') ||
      lower.contains('permission denied') ||
      lower.contains('postgres') ||
      lower.contains('42501') ||
      lower.contains('42p01') ||
      lower.contains('pgrst') ||
      lower.contains('violates') ||
      lower.contains('relation ') ||
      lower.contains('column ') ||
      lower.contains('supabase') ||
      lower.contains('sql') ||
      lower.contains("type '") ||
      lower.contains('rangeerror') ||
      lower.contains('nosuchmethod') ||
      lower.contains('null check') ||
      lower.contains('http ');

  if (looksTechnical) {
    return 'Something went wrong while trying to $action. Please try again.';
  }
  if (statusCode == 401) {
    return 'Session expired. Please sign in again.';
  }
  if (statusCode == 403) {
    return 'Permission denied. Please sign in again.';
  }
  if (statusCode == 503 || (statusCode != null && statusCode >= 500)) {
    return 'Service is temporarily busy. Please try again.';
  }
  if (error is RepositoryException && cleaned.isNotEmpty) {
    return cleaned;
  }
  if (raw.startsWith('Exception: ') && cleaned.isNotEmpty) {
    return cleaned;
  }
  return 'Something went wrong. Please try again.';
}
