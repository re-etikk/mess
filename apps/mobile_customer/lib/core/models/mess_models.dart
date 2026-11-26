import 'package:flutter/foundation.dart';

enum SubscriptionType { fixedPeriod, mealTracker, dailyMeal }

enum MealState { redeemed, available, upcoming, ended, unavailable }

enum FoodItemKind { included, addOn, special, substitution }

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
    this.startingPrice,
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
  final int? startingPrice;

  String get timeLabel => '${_time(startHour, startMinute)} - ${_time(endHour, endMinute)}';

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
class CartMealSelection {
  const CartMealSelection({
    required this.slotId,
    required this.slotLabel,
    required this.basePrice,
    required this.quantity,
    required this.addOns,
    this.preferredWindow = '',
  });

  final String slotId;
  final String slotLabel;
  final int basePrice;
  final int quantity;
  final Map<MenuItem, int> addOns;
  final String preferredWindow;

  int get addOnsTotal => addOns.entries.fold(0, (s, e) => s + e.key.price * e.value);
  int get unitPrice => basePrice + addOnsTotal;
  int get total => unitPrice * quantity;
  bool get isCustomized => addOns.values.any((q) => q > 0);
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
    this.city = '',
    this.address,
    this.publicPhone,
    this.coverPath,
    this.logoPath,
    this.rating,
    this.totalReviews = 0,
    this.subscriberCount = 0,
    this.distanceKm,
    this.startingMealPrice,
    this.supportsPickup = true,
    this.supportsDelivery = false,
    this.allowsTakeaway = true,
    this.allowsMonthlyPlans = true,
    this.dietaryTypes = const [],
    this.disposableFeeInr = 5,
    this.maxSkipsPerWeek = 2,
  });

  final String id;
  final String name;
  final String area;
  final String city;
  final int distanceMeters;
  final double? distanceKm;
  final String description;
  final List<MealSlot> mealSlots;
  final List<MealPlan> plans;
  final bool isOpen;
  final String? address;
  final String? publicPhone;
  final String? coverPath;
  final String? logoPath;
  final double? rating;
  final int totalReviews;
  final int subscriberCount;
  final int? startingMealPrice;
  final bool supportsPickup;
  final bool supportsDelivery;
  final bool allowsTakeaway;
  final bool allowsMonthlyPlans;
  final List<String> dietaryTypes;
  final int disposableFeeInr;
  final int maxSkipsPerWeek;

  String get distanceLabel {
    if (distanceKm == null) return area;
    if (distanceKm! < 1.0) return '${(distanceKm! * 1000).round()} meters';
    return '${distanceKm!.toStringAsFixed(1)} km away';
  }

  String get ratingBadgeText => rating != null ? rating!.toStringAsFixed(1) : 'New';

  String get dietarySummary {
    if (dietaryTypes.isEmpty) return 'Daily Menu';
    final hasVeg = dietaryTypes.any((t) => t == 'vegetarian' || t == 'vegan' || t == 'jain');
    final hasNonVeg = dietaryTypes.contains('non_vegetarian');
    if (hasVeg && hasNonVeg) return 'Veg & Non Veg';
    if (hasNonVeg) return 'Non Veg';
    return 'Pure Veg';
  }
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
    if (durationDays == 7) return '7 days';
    return '$durationDays days';
  }

  DateTime expiryFrom(DateTime start) {
    if (durationMonths == null) return start.add(Duration(days: durationDays));
    final monthIndex = start.month - 1 + durationMonths!;
    final year = start.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
    final day = start.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : start.day;
    return DateTime(year, month, day, start.hour, start.minute, start.second);
  }
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
    this.status = 'active',
    this.priceInr = 0,
    this.paymentMode = 'cashfree_online',
    this.providerLocality = '',
    this.providerPhone = '',
    this.repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    this.skipAllowance = 2,
    this.skipsUsed = 0,
    this.autoRenewal = false,
    this.reminderDaysBefore = 2,
    this.whatsappUpdates = false,
    this.pauseStartDate,
    this.pauseEndDate,
    this.packagingPreference = 'reusable_tiffin',
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
  final String status;
  final int priceInr;
  final String paymentMode;
  final String providerLocality;
  final String providerPhone;
  final List<int> repeatDays;
  final int skipAllowance;
  final int skipsUsed;
  final bool autoRenewal;
  final int reminderDaysBefore;
  final bool whatsappUpdates;
  final DateTime? pauseStartDate;
  final DateTime? pauseEndDate;
  final String packagingPreference;

  int? get mealsRemaining => totalMeals == null ? null : (totalMeals! - mealsUsed).clamp(0, totalMeals!).toInt();
  bool get hasMealsRemaining => type != SubscriptionType.mealTracker || (mealsRemaining ?? 0) > 0;
  bool get isPaused => status == 'paused';
  int get daysRemaining => endDate.difference(DateTime.now()).inDays.clamp(0, 3650);
  int get totalDays => endDate.difference(startDate).inDays.clamp(1, 3650);
  bool get isValidToday {
    if (status == 'cancelled' || status == 'expired') return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }
}

@immutable
class DailyMealItem {
  const DailyMealItem({
    required this.id,
    required this.subscriptionId,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    required this.providerLocality,
    required this.serviceDate,
    required this.slot,
    required this.slotLabel,
    required this.menuSummary,
    required this.timeWindow,
    required this.status,
    required this.fulfillmentMode,
    required this.instructions,
    this.etaMinutes,
    this.cutoffTime = '',
    this.providerLat,
    this.providerLng,
    this.supportsDelivery = false,
    this.riderName,
    this.riderPhone,
    this.riderLat,
    this.riderLng,
    this.riderUpdatedAt,
  });

  final String id;
  final String subscriptionId;
  final String providerId;
  final String providerName;
  final String providerPhone;
  final String providerLocality;
  final String serviceDate;
  final String slot;
  final String slotLabel;
  final String menuSummary;
  final String timeWindow;
  final String status; // scheduled | preparing | out_for_delivery | ready_at_counter | delivered | skipped | cancelled_by_kitchen
  final String fulfillmentMode;
  final String instructions;
  final int? etaMinutes;
  final String cutoffTime;
  final double? providerLat;
  final double? providerLng;
  final bool supportsDelivery;
  final String? riderName;
  final String? riderPhone;
  final double? riderLat;
  final double? riderLng;
  final String? riderUpdatedAt;

  factory DailyMealItem.fromJson(Map<String, dynamic> j) => DailyMealItem(
        id: j['id']?.toString() ?? '',
        subscriptionId: j['subscription_id']?.toString() ?? '',
        providerId: j['provider_id']?.toString() ?? '',
        providerName: j['provider_name']?.toString() ?? '',
        providerPhone: j['provider_phone']?.toString() ?? '',
        providerLocality: j['provider_locality']?.toString() ?? '',
        serviceDate: j['service_date']?.toString() ?? '',
        slot: j['slot']?.toString() ?? 'LUNCH',
        slotLabel: j['slot_label']?.toString() ?? 'Lunch',
        menuSummary: j['menu_summary']?.toString() ?? '',
        timeWindow: j['time_window']?.toString() ?? '',
        status: j['status']?.toString() ?? 'scheduled',
        fulfillmentMode: j['fulfillment_mode']?.toString() ?? 'delivery',
        instructions: j['instructions']?.toString() ?? '',
        etaMinutes: (j['eta_minutes'] as num?)?.toInt(),
        cutoffTime: j['cutoff_time']?.toString() ?? '',
        providerLat: (j['provider_lat'] as num?)?.toDouble(),
        providerLng: (j['provider_lng'] as num?)?.toDouble(),
        supportsDelivery: j['supports_delivery'] == true,
        riderName: j['rider_name']?.toString(),
        riderPhone: j['rider_phone']?.toString(),
        riderLat: (j['rider_lat'] as num?)?.toDouble(),
        riderLng: (j['rider_lng'] as num?)?.toDouble(),
        riderUpdatedAt: j['rider_updated_at']?.toString(),
      );
}

@immutable
class CustomerWeekDay {
  const CustomerWeekDay({
    required this.date,
    required this.dayLabel,
    required this.dayNumber,
    required this.isSelected,
    required this.indicator,
  });

  final String date;
  final String dayLabel;
  final int dayNumber;
  final bool isSelected;
  final String indicator; // completed | scheduled | skipped | break_day

  factory CustomerWeekDay.fromJson(Map<String, dynamic> j) => CustomerWeekDay(
        date: j['date']?.toString() ?? '',
        dayLabel: j['day_label']?.toString() ?? '',
        dayNumber: (j['day_number'] as num?)?.toInt() ?? 1,
        isSelected: j['is_selected'] == true,
        indicator: j['indicator']?.toString() ?? 'scheduled',
      );
}

@immutable
class ReviewSummaryData {
  const ReviewSummaryData({
    required this.averageRating,
    required this.totalReviews,
    required this.breakdown,
    required this.images,
    required this.popularTags,
    required this.reviews,
  });

  final double? averageRating;
  final int totalReviews;
  final Map<int, int> breakdown;
  final List<String> images;
  final List<String> popularTags;
  final List<Map<String, dynamic>> reviews;
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
