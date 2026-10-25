class MenuItemModel {
  final String id;
  final String name;
  final String category;
  final bool isAvailable;
  final String dietType; // 'veg', 'non_veg', 'jain'

  MenuItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.isAvailable,
    required this.dietType,
  });

  MenuItemModel copyWith({bool? isAvailable}) {
    return MenuItemModel(
      id: id,
      name: name,
      category: category,
      isAvailable: isAvailable ?? this.isAvailable,
      dietType: dietType,
    );
  }
}

class RosterBookingModel {
  final String id;
  final String customerName;
  final String customerPhone;
  final String slotName;
  final String bookingDate;
  final String fulfillmentType; // 'pickup', 'delivery'
  String status; // 'confirmed', 'redeemed', 'out_for_delivery', 'delivered'
  final String? notes;

  RosterBookingModel({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.slotName,
    required this.bookingDate,
    required this.fulfillmentType,
    required this.status,
    this.notes,
  });
}

class ProviderPlanModel {
  final String id;
  final String name;
  final String planType; // 'fixed_period', 'meal_based', 'daily_pay_as_you_eat'
  final double priceInr;
  final int durationDays;
  final int? totalMeals;
  final int activeSubscribers;
  final bool isActive;

  ProviderPlanModel({
    required this.id,
    required this.name,
    required this.planType,
    required this.priceInr,
    required this.durationDays,
    this.totalMeals,
    required this.activeSubscribers,
    required this.isActive,
  });
}

class RedemptionResponseModel {
  final bool success;
  final String? customerName;
  final String? mealSlot;
  final int? remainingMeals;
  final String? redeemedAt;
  final String? errorCode;
  final String message;

  RedemptionResponseModel({
    required this.success,
    this.customerName,
    this.mealSlot,
    this.remainingMeals,
    this.redeemedAt,
    this.errorCode,
    required this.message,
  });
}
