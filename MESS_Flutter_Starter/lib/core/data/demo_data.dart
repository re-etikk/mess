import '../models/mess_models.dart';

class DemoData {
  static final DateTime now = DateTime.now();

  static final List<MenuItem> standardLunch = <MenuItem>[
    const MenuItem(id: 'dal', name: 'Dal', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'rice', name: 'Rice', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'roti4', name: 'Roti (4)', kind: FoodItemKind.included, price: 0, portion: '4 pieces'),
    const MenuItem(id: 'sabzi', name: 'Seasonal sabzi', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'salad', name: 'Salad', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'paneer', name: 'Paneer special', kind: FoodItemKind.addOn, price: 30, portion: '1 serving', maxQuantity: 2),
    const MenuItem(id: 'extra_roti', name: 'Extra roti', kind: FoodItemKind.addOn, price: 5, portion: 'per piece', maxQuantity: 10),
    const MenuItem(id: 'extra_rice', name: 'Extra rice', kind: FoodItemKind.addOn, price: 10, portion: 'per serving', maxQuantity: 3),
  ];

  static final List<MenuItem> standardDinner = <MenuItem>[
    const MenuItem(id: 'dal_dinner', name: 'Dal', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'rice_dinner', name: 'Rice', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'roti_dinner', name: 'Roti (4)', kind: FoodItemKind.included, price: 0, portion: '4 pieces'),
    const MenuItem(id: 'sabzi_dinner', name: 'Seasonal sabzi', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'sweet', name: 'Sweet of the day', kind: FoodItemKind.addOn, price: 20, portion: '1 piece', maxQuantity: 3),
    const MenuItem(id: 'extra_roti_dinner', name: 'Extra roti', kind: FoodItemKind.addOn, price: 5, portion: 'per piece', maxQuantity: 10),
  ];

  static final List<MealPlan> radhePlans = <MealPlan>[
    MealPlan(id: 'radhe-daily-lunch', providerId: 'radhe-mess', name: 'Daily lunch', type: SubscriptionType.dailyMeal, durationDays: 1, price: 95, slotIds: const ['lunch'], description: 'One lunch entitlement for today. Optional extras are charged separately.'),
    MealPlan(id: 'radhe-daily-dinner', providerId: 'radhe-mess', name: 'Daily dinner', type: SubscriptionType.dailyMeal, durationDays: 1, price: 95, slotIds: const ['dinner'], description: 'One dinner entitlement for today. Optional extras are charged separately.'),
    MealPlan(id: 'radhe-fixed-15', providerId: 'radhe-mess', name: '15-day access', type: SubscriptionType.fixedPeriod, durationDays: 15, price: 650, slotIds: const ['lunch', 'dinner'], description: 'Access during the plan period. Meal credits are not deducted; daily slot limits apply.'),
    MealPlan(id: 'radhe-fixed-30', providerId: 'radhe-mess', name: 'Monthly access', type: SubscriptionType.fixedPeriod, durationDays: 30, durationMonths: 1, price: 1200, slotIds: const ['lunch', 'dinner'], description: 'Fixed-period access with configured daily meal limits.'),
    MealPlan(id: 'radhe-fixed-90', providerId: 'radhe-mess', name: '3-month access', type: SubscriptionType.fixedPeriod, durationDays: 90, durationMonths: 3, price: 3300, slotIds: const ['lunch', 'dinner'], discountPercent: 8, description: 'Longer access period with provider-defined daily limits.'),
    MealPlan(id: 'radhe-fixed-180', providerId: 'radhe-mess', name: '6-month access', type: SubscriptionType.fixedPeriod, durationDays: 180, durationMonths: 6, price: 6200, slotIds: const ['lunch', 'dinner'], discountPercent: 14, description: 'Longer access period with provider-defined daily limits.'),
    MealPlan(id: 'radhe-fixed-365', providerId: 'radhe-mess', name: '12-month access', type: SubscriptionType.fixedPeriod, durationDays: 365, durationMonths: 12, price: 11500, slotIds: const ['lunch', 'dinner'], discountPercent: 20, description: 'Longer access period with provider-defined daily limits.'),
    MealPlan(id: 'radhe-tracker-15', providerId: 'radhe-mess', name: '15-day meal tracker', type: SubscriptionType.mealTracker, durationDays: 15, price: 850, slotIds: const ['lunch', 'dinner'], includedMeals: 30, description: 'A credit is used only after a successful meal redemption.'),
    MealPlan(id: 'radhe-tracker-30', providerId: 'radhe-mess', name: '30-meal tracker', type: SubscriptionType.mealTracker, durationDays: 30, durationMonths: 1, price: 1600, slotIds: const ['lunch', 'dinner'], includedMeals: 30, description: '30 total meals, valid through the calendar-month expiry date. Whichever limit comes first ends the plan.'),
    MealPlan(id: 'radhe-tracker-90', providerId: 'radhe-mess', name: '3-month meal tracker', type: SubscriptionType.mealTracker, durationDays: 90, durationMonths: 3, price: 4500, slotIds: const ['lunch', 'dinner'], includedMeals: 90, discountPercent: 8, description: 'Meal credits and validity are both enforced.'),
    MealPlan(id: 'radhe-tracker-180', providerId: 'radhe-mess', name: '6-month meal tracker', type: SubscriptionType.mealTracker, durationDays: 180, durationMonths: 6, price: 8600, slotIds: const ['lunch', 'dinner'], includedMeals: 180, discountPercent: 14, description: 'Meal credits and validity are both enforced.'),
    MealPlan(id: 'radhe-tracker-365', providerId: 'radhe-mess', name: '12-month meal tracker', type: SubscriptionType.mealTracker, durationDays: 365, durationMonths: 12, price: 16600, slotIds: const ['lunch', 'dinner'], includedMeals: 365, discountPercent: 20, description: 'Meal credits and validity are both enforced.'),
  ];

  static final List<MessProvider> providers = <MessProvider>[
    MessProvider(
      id: 'radhe-mess',
      name: 'Radhe Mess',
      area: 'IIT Hostel, Sector 62',
      address: 'Sector 62, Noida, Uttar Pradesh',
      distanceMeters: 200,
      description: 'Home-style meals with configurable portions and daily menu.',
      isOpen: true,
      mealSlots: <MealSlot>[
        MealSlot(id: 'breakfast', name: 'Breakfast', startHour: 7, startMinute: 0, endHour: 9, endMinute: 30, menuSummary: 'Poha, toast and tea', items: const [MenuItem(id: 'poha', name: 'Poha', kind: FoodItemKind.included, price: 0, portion: '1 serving'), MenuItem(id: 'tea', name: 'Tea', kind: FoodItemKind.included, price: 0, portion: '1 cup'), MenuItem(id: 'extra_tea', name: 'Extra tea', kind: FoodItemKind.addOn, price: 10, portion: 'per cup')]),
        MealSlot(id: 'lunch', name: 'Lunch', startHour: 12, startMinute: 0, endHour: 14, endMinute: 30, menuSummary: 'Dal, rice, 4 roti, sabzi and salad', items: standardLunch),
        MealSlot(id: 'dinner', name: 'Dinner', startHour: 19, startMinute: 0, endHour: 21, endMinute: 30, menuSummary: 'Dal, rice, 4 roti and sabzi', items: standardDinner),
      ],
      plans: radhePlans,
    ),
    MessProvider(
      id: 'shree-mess',
      name: 'Shree Mess',
      area: 'Hostel Sector 62',
      address: 'Sector 62, Noida, Uttar Pradesh',
      distanceMeters: 350,
      description: 'A simple vegetarian mess with daily meal slots.',
      isOpen: true,
      mealSlots: <MealSlot>[
        MealSlot(id: 'lunch', name: 'Lunch', startHour: 12, startMinute: 0, endHour: 14, endMinute: 30, menuSummary: 'Thali, rice, roti and sabzi', items: standardLunch),
        MealSlot(id: 'dinner', name: 'Dinner', startHour: 19, startMinute: 0, endHour: 21, endMinute: 30, menuSummary: 'Roti, dal and sabzi', items: standardDinner),
      ],
      plans: <MealPlan>[
        MealPlan(id: 'shree-daily', providerId: 'shree-mess', name: 'Daily lunch', type: SubscriptionType.dailyMeal, durationDays: 1, price: 90, slotIds: const ['lunch'], description: 'One lunch redemption for the selected date.'),
        MealPlan(id: 'shree-fixed-30', providerId: 'shree-mess', name: 'Monthly access', type: SubscriptionType.fixedPeriod, durationDays: 30, durationMonths: 1, price: 1250, slotIds: const ['lunch', 'dinner'], description: 'Fixed-period access with daily slot limits.'),
        MealPlan(id: 'shree-tracker-30', providerId: 'shree-mess', name: '30-meal tracker', type: SubscriptionType.mealTracker, durationDays: 30, durationMonths: 1, price: 1650, slotIds: const ['lunch', 'dinner'], includedMeals: 30, description: '30 meals, subject to a calendar-month validity window.'),
      ],
    ),
    MessProvider(
      id: 'friends-mess',
      name: 'Friends Mess',
      area: 'Knowledge Park',
      address: 'Knowledge Park, Greater Noida, Uttar Pradesh',
      distanceMeters: 850,
      description: 'Daily menu with standard and optional extra portions.',
      isOpen: true,
      mealSlots: <MealSlot>[
        MealSlot(id: 'breakfast', name: 'Breakfast', startHour: 7, startMinute: 0, endHour: 9, endMinute: 30, menuSummary: 'Paratha and curd', items: const [MenuItem(id: 'paratha', name: 'Paratha (2)', kind: FoodItemKind.included, price: 0), MenuItem(id: 'curd', name: 'Curd', kind: FoodItemKind.included, price: 0), MenuItem(id: 'extra_paratha', name: 'Extra paratha', kind: FoodItemKind.addOn, price: 12, portion: 'each')]),
        MealSlot(id: 'lunch', name: 'Lunch', startHour: 12, startMinute: 0, endHour: 14, endMinute: 30, menuSummary: 'Rice, roti, dal and seasonal sabzi', items: standardLunch),
        MealSlot(id: 'dinner', name: 'Dinner', startHour: 19, startMinute: 0, endHour: 21, endMinute: 30, menuSummary: 'Roti, rice, dal and seasonal sabzi', items: standardDinner),
      ],
      plans: <MealPlan>[
        MealPlan(id: 'friends-daily', providerId: 'friends-mess', name: 'Daily meal', type: SubscriptionType.dailyMeal, durationDays: 1, price: 100, slotIds: const ['lunch'], description: 'One meal for today.'),
        MealPlan(id: 'friends-tracker', providerId: 'friends-mess', name: '30-meal tracker', type: SubscriptionType.mealTracker, durationDays: 30, price: 1750, slotIds: const ['lunch', 'dinner'], includedMeals: 30, description: '30 meals within a 30-day validity window.'),
      ],
    ),
  ];
}
