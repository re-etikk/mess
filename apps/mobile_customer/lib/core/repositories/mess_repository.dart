import '../models/mess_models.dart';

abstract interface class MessRepository {
  Future<List<MessProvider>> getProviders();
  Future<List<MessProvider>> searchProviders({String query = ''});
  Future<MessProvider?> getProvider(String providerId);
  Future<MealRedemption> redeemMeal({required String qrPayload, required String customerId});
  Future<ActiveSubscription> purchasePlan({
    required MealPlan plan,
    required String customerId,
    String paymentMode = 'counter_cash',
    String? receiptUrl,
    String? utrReference,
  });
  Future<DailyMealEntitlement> purchaseDailyMeal({required MealPlan plan, required String slotId, required String customerId});
  Future<Map<String, dynamic>> fetchPaymentSettings(String providerId);
  Future<Map<String, dynamic>> getUpgradeQuote({required String subscriptionId, required String targetPlanId});
  Future<Map<String, dynamic>> requestPlanUpgrade({
    required String subscriptionId,
    required String targetPlanId,
    String paymentMode = 'counter_cash',
    String? receiptUrl,
    String? utrReference,
  });
}

class RepositoryException implements Exception {
  const RepositoryException(this.message, {this.code = 'unknown'});
  final String message;
  final String code;
  @override
  String toString() => message;
}
