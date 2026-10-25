import 'package:flutter_test/flutter_test.dart';
import 'package:mess_customer_app/core/models/mess_models.dart';

void main() {
  group('MealSlot status', () {
    const slot = MealSlot(
      id: 'lunch',
      name: 'Lunch',
      startHour: 12,
      startMinute: 0,
      endHour: 14,
      endMinute: 30,
      menuSummary: 'Test menu',
      items: <MenuItem>[],
    );

    test('is upcoming before its serving window', () {
      expect(slot.stateAt(DateTime(2026, 10, 25, 11, 59), redeemed: false), MealState.upcoming);
    });

    test('is available during its serving window', () {
      expect(slot.stateAt(DateTime(2026, 10, 25, 12, 30), redeemed: false), MealState.available);
    });

    test('is redeemed when a prior successful redemption exists', () {
      expect(slot.stateAt(DateTime(2026, 10, 25, 12, 30), redeemed: true), MealState.redeemed);
    });

    test('ends after configured serving window', () {
      expect(slot.stateAt(DateTime(2026, 10, 25, 14, 31), redeemed: false), MealState.ended);
    });
  });

  group('Plan expiry', () {
    test('monthly plan keeps same calendar day', () {
      const plan = MealPlan(
        id: 'monthly', providerId: 'radhe', name: 'Monthly',
        type: SubscriptionType.fixedPeriod, durationDays: 30, durationMonths: 1,
        price: 1200, slotIds: <String>['lunch'],
      );
      expect(plan.expiryFrom(DateTime(2026, 10, 25, 10)), DateTime(2026, 11, 25, 10));
    });

    test('monthly plan clamps a day that does not exist in the target month', () {
      const plan = MealPlan(
        id: 'monthly', providerId: 'radhe', name: 'Monthly',
        type: SubscriptionType.fixedPeriod, durationDays: 30, durationMonths: 1,
        price: 1200, slotIds: <String>['lunch'],
      );
      expect(plan.expiryFrom(DateTime(2026, 1, 31, 10)), DateTime(2026, 2, 28, 10));
    });
  });
}
