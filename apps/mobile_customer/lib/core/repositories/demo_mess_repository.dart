import 'dart:convert';
import '../data/demo_data.dart';
import '../models/mess_models.dart';
import 'mess_repository.dart';

/// Adapter for mobile customer app meal redemption and plan operations.
class DemoMessRepository implements MessRepository {
  final Set<String> _redeemedKeys = <String>{};
  final List<MealRedemption> history = <MealRedemption>[];

  @override
  Future<List<MessProvider>> getProviders() async => List<MessProvider>.unmodifiable(DemoData.providers);

  @override
  Future<MessProvider?> getProvider(String providerId) async {
    for (final provider in DemoData.providers) {
      if (provider.id == providerId) return provider;
    }
    // Fallback to first provider if id matches prefix
    if (DemoData.providers.isNotEmpty) return DemoData.providers.first;
    return null;
  }

  @override
  Future<MealRedemption> redeemMeal({required String qrPayload, required String customerId}) async {
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    String providerId = 'radhe-mess';
    String qrDate = today;
    String slot = 'Lunch';

    final trimmed = qrPayload.trim();
    if (trimmed.startsWith('MESS_QR|') || trimmed.startsWith('MESS_DEMO|')) {
      final parts = trimmed.split('|');
      if (parts.length >= 3) {
        providerId = parts[1];
        qrDate = parts[2];
        if (parts.length >= 4 && parts[3] != 'ALL') {
          slot = parts[3];
        }
      }
    } else if (trimmed.contains('.')) {
      try {
        final b64 = trimmed.split('.').first;
        final normalized = base64Url.normalize(b64);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final json = jsonDecode(decoded);
        providerId = json['provider_id'] ?? json['pid'] ?? providerId;
        qrDate = json['date'] ?? today;
        slot = json['slot'] ?? slot;
      } catch (_) {}
    }

    if (qrDate != today) {
      throw const RepositoryException('This QR is not valid for today.', code: 'expired_qr');
    }

    final provider = await getProvider(providerId) ?? (DemoData.providers.isNotEmpty ? DemoData.providers.first : null);
    if (provider == null) throw const RepositoryException('This mess could not be found.', code: 'provider_not_found');

    final redemptionKey = '$customerId|$providerId|$today|$slot';
    if (_redeemedKeys.contains(redemptionKey)) {
      throw const RepositoryException('You have already redeemed this meal slot today.', code: 'duplicate_redemption');
    }
    _redeemedKeys.add(redemptionKey);

    final redemption = MealRedemption(
      id: 'red-${DateTime.now().microsecondsSinceEpoch}',
      providerName: provider.name,
      slotName: slot,
      redeemedAt: now,
      status: 'Redeemed successfully',
    );
    history.insert(0, redemption);
    return redemption;
  }

  @override
  Future<ActiveSubscription> purchasePlan({required MealPlan plan, required String customerId}) async {
    final now = DateTime.now();
    return ActiveSubscription(
      id: 'sub-${now.microsecondsSinceEpoch}',
      providerId: plan.providerId,
      providerName: (await getProvider(plan.providerId))?.name ?? 'Selected Mess',
      planName: plan.name,
      type: plan.type,
      startDate: now,
      endDate: plan.expiryFrom(now),
      slotIds: plan.slotIds,
      totalMeals: plan.type == SubscriptionType.mealTracker ? plan.includedMeals : null,
      mealsUsed: 0,
    );
  }

  @override
  Future<DailyMealEntitlement> purchaseDailyMeal({required MealPlan plan, required String slotId, required String customerId}) async {
    final now = DateTime.now();
    return DailyMealEntitlement(
      id: 'daily-${now.microsecondsSinceEpoch}',
      providerId: plan.providerId,
      providerName: (await getProvider(plan.providerId))?.name ?? 'Selected Mess',
      slotId: slotId,
      date: DateTime(now.year, now.month, now.day),
      paidAmount: plan.price,
      isPaid: true,
    );
  }
}
