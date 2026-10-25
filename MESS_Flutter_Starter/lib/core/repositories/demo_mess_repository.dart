import '../data/demo_data.dart';
import '../models/mess_models.dart';
import 'mess_repository.dart';

/// Local-only adapter for UI and flow testing. Replace with a server-backed repository
/// before release. It intentionally cannot verify cryptographic QR signatures or payments.
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
    return null;
  }

  @override
  Future<MealRedemption> redeemMeal({required String qrPayload, required String customerId}) async {
    // Demo payload only: MESS_DEMO|providerId|YYYY-MM-DD|daily-public-demo-token
    final parts = qrPayload.split('|');
    if (parts.length != 4 || parts.first != 'MESS_DEMO') {
      throw const RepositoryException('This QR is not recognised by the demo. Production QR validation must happen on the backend.', code: 'invalid_qr');
    }
    final providerId = parts[1];
    final qrDate = parts[2];
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (qrDate != today) {
      throw const RepositoryException('This QR is not valid for today.', code: 'expired_qr');
    }
    final provider = await getProvider(providerId);
    if (provider == null) throw const RepositoryException('This mess could not be found.', code: 'provider_not_found');
    final currentSlot = provider.mealSlots.where((slot) => slot.contains(now)).firstOrNull;
    if (currentSlot == null) {
      throw const RepositoryException('There is no active meal slot right now. Check the mess timings.', code: 'no_active_slot');
    }
    final redemptionKey = '$customerId|$providerId|$today|${currentSlot.id}';
    if (_redeemedKeys.contains(redemptionKey)) {
      throw const RepositoryException('You have already redeemed this meal slot today.', code: 'duplicate_redemption');
    }
    _redeemedKeys.add(redemptionKey);
    final redemption = MealRedemption(
      id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
      providerName: provider.name,
      slotName: currentSlot.name,
      redeemedAt: now,
      status: 'Redeemed (demo)',
    );
    history.insert(0, redemption);
    return redemption;
  }

  @override
  Future<ActiveSubscription> purchasePlan({required MealPlan plan, required String customerId}) async {
    // This method models the post-payment state for local UI testing only.
    // A real integration must verify an authenticated payment webhook/server response first.
    final now = DateTime.now();
    return ActiveSubscription(
      id: 'demo-sub-${now.microsecondsSinceEpoch}',
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
      id: 'demo-daily-${now.microsecondsSinceEpoch}',
      providerId: plan.providerId,
      providerName: (await getProvider(plan.providerId))?.name ?? 'Selected Mess',
      slotId: slotId,
      date: DateTime(now.year, now.month, now.day),
      paidAmount: plan.price,
      isPaid: true, // Demo state only; never infer production payment from this value.
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
