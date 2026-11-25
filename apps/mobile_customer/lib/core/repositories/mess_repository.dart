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
}

class RepositoryException implements Exception {
  const RepositoryException(this.message, {this.code = 'unknown'});
  final String message;
  final String code;
  @override
  String toString() => message;
}

/// Converts raw transport/HTTP/HTML failures into clear, actionable human English.
String friendlyCustomerError(
  Object error, {
  int? statusCode,
  String? body,
  String action = 'load data',
}) {
  if (error is RepositoryException) return error.message;
  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('clientexception')) {
    return 'No internet connection or unable to reach Thali servers right now. Check Wi-Fi or mobile data and pull down to retry.';
  }
  if (lower.contains('timeoutexception') || lower.contains('timed out')) {
    return 'Server took too long to respond while trying to $action. Pull down to try again.';
  }

  final bodyTrim = (body ?? '').trimLeft().toLowerCase();
  if (statusCode == 404 ||
      lower.contains('formatexception') ||
      bodyTrim.startsWith('<!doctype') ||
      bodyTrim.startsWith('<html')) {
    if (statusCode == 404) {
      return 'This feature is not live on the web server yet (404). The latest server update needs to be deployed to thali.store.';
    }
    return 'Could not $action because the web server returned a webpage instead of app data. Make sure the latest backend update is deployed.';
  }
  if (statusCode == 401) {
    return 'Your session expired. Please sign in again to continue.';
  }
  if (statusCode == 403) {
    return 'You do not have permission to $action.';
  }
  if (statusCode == 503) {
    return 'Server database setup is incomplete (missing server credentials or SQL table migration).';
  }
  if (statusCode != null && statusCode >= 500) {
    return 'Thali server ran into an issue ($statusCode) while trying to $action. Please try again in a moment.';
  }
  if (raw.startsWith('Exception: ')) {
    return raw.substring(11);
  }
  return 'Unable to $action right now. Pull down to refresh.';
}
