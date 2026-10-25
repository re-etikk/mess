import '../models/mess_models.dart';

abstract interface class MessRepository {
  Future<List<MessProvider>> getProviders();
  Future<MessProvider?> getProvider(String providerId);
  Future<MealRedemption> redeemMeal({required String qrPayload, required String customerId});
  Future<ActiveSubscription> purchasePlan({required MealPlan plan, required String customerId});
  Future<DailyMealEntitlement> purchaseDailyMeal({required MealPlan plan, required String slotId, required String customerId});
}

class RepositoryException implements Exception {
  const RepositoryException(this.message, {this.code = 'unknown'});
  final String message;
  final String code;
  @override
  String toString() => message;
}
