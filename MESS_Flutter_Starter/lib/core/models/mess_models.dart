import 'package:flutter/foundation.dart';

enum SubscriptionType { fixedPeriod, mealTracker, dailyMeal }

enum MealState { redeemed, available, upcoming, ended, unavailable }

enum FoodItemKind { included, addOn, substitution }

@immutable
class MealSlot {
  const MealSlot({
    required this.id,
    required this.name,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.menuSummary,
    required this.items,
    this.enabled = true,
  });

  final String id;
  final String name;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String menuSummary;
  final List<MenuItem> items;
  final bool enabled;

  String get timeLabel => '${_time(startHour, startMinute)} – ${_time(endHour, endMinute)}';

  bool contains(DateTime time) {
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    final now = time.hour * 60 + time.minute;
    return now >= start && now <= end;
  }

  MealState stateAt(DateTime now, {required bool redeemed}) {
    if (!enabled) return MealState.unavailable;
    if (redeemed) return MealState.redeemed;
    final current = now.hour * 60 + now.minute;
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    if (current < start) return MealState.upcoming;
    if (current <= end) return MealState.available;
    return MealState.ended;
  }

  static String _time(int hour, int minute) {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final shownHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$shownHour:${minute.toString().padLeft(2, '0')} $suffix';
  }
}

@immutable
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.price,
    this.portion,
    this.available = true,
    this.maxQuantity = 5,
    this.note,
  });

  final String id;
  final String name;
  final FoodItemKind kind;
  final int price;
  final String? portion;
  final bool available;
  final int maxQuantity;
  final String? note;

  String get priceLabel => kind == FoodItemKind.included ? 'Included' : '₹$price';
}

@immutable
class MessProvider {
  const MessProvider({
    required this.id,
    required this.name,
    required this.area,
    required this.distanceMeters,
    required this.description,
    required this.mealSlots,
    required this.plans,
    required this.isOpen,
    this.menuUpdatedAt,
    this.address,
  });

  final String id;
  final String name;
  final String area;
  final int distanceMeters;
  final String description;
  final List<MealSlot> mealSlots;
  final List<MealPlan> plans;
  final bool isOpen;
  final DateTime? menuUpdatedAt;
  final String? address;

  String get distanceLabel => distanceMeters < 1000
      ? '$distanceMeters m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}

@immutable
class MealPlan {
  const MealPlan({
    required this.id,
    required this.providerId,
    required this.name,
    required this.type,
    required this.durationDays,
    this.durationMonths,
    required this.price,
    required this.slotIds,
    this.includedMeals,
    this.description = '',
    this.discountPercent = 0,
    this.maxRedemptionsPerSlotPerDay = 1,
    this.isAvailable = true,
  });

  final String id;
  final String providerId;
  final String name;
  final SubscriptionType type;
  final int durationDays;
  /// Calendar-month duration when applicable; used to preserve same-day expiry (e.g. 25th to 25th).
  final int? durationMonths;
  final int price;
  final List<String> slotIds;
  final int? includedMeals;
  final String description;
  final int discountPercent;
  final int maxRedemptionsPerSlotPerDay;
  final bool isAvailable;

  String get durationLabel {
    if (durationMonths == 1) return '1 month';
    if (durationMonths != null) return '$durationMonths months';
    return '$durationDays days';
  }

  DateTime expiryFrom(DateTime start) {
    if (durationMonths == null) return start.add(Duration(days: durationDays));
    final monthIndex = start.month - 1 + durationMonths!;
    final year = start.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
    final day = start.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : start.day;
    return DateTime(year, month, day, start.hour, start.minute, start.second, start.millisecond, start.microsecond);
  }

  String get typeLabel => switch (type) {
        SubscriptionType.fixedPeriod => 'Fixed-period',
        SubscriptionType.mealTracker => 'Meal tracker',
        SubscriptionType.dailyMeal => 'Daily meal',
      };
}

@immutable
class ActiveSubscription {
  const ActiveSubscription({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.planName,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.slotIds,
    required this.totalMeals,
    required this.mealsUsed,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String planName;
  final SubscriptionType type;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> slotIds;
  final int? totalMeals;
  final int mealsUsed;

  int? get mealsRemaining => totalMeals == null ? null : (totalMeals! - mealsUsed).clamp(0, totalMeals!).toInt();
  bool get hasMealsRemaining => type != SubscriptionType.mealTracker || (mealsRemaining ?? 0) > 0;
  bool get isValidToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }
}

@immutable
class MealRedemption {
  const MealRedemption({
    required this.id,
    required this.providerName,
    required this.slotName,
    required this.redeemedAt,
    required this.status,
    this.planType,
  });

  final String id;
  final String providerName;
  final String slotName;
  final DateTime redeemedAt;
  final String status;
  final SubscriptionType? planType;
}

@immutable
class DailyMealEntitlement {
  const DailyMealEntitlement({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.slotId,
    required this.date,
    required this.paidAmount,
    required this.isPaid,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String slotId;
  final DateTime date;
  final int paidAmount;
  final bool isPaid;

  bool isForToday(DateTime now) => date.year == now.year && date.month == now.month && date.day == now.day;
}

@immutable
class CartAddOn {
  const CartAddOn({required this.item, required this.quantity});
  final MenuItem item;
  final int quantity;
  int get total => item.price * quantity;
}
