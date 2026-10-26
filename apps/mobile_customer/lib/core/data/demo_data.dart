import '../models/mess_models.dart';

class DemoData {
  static final DateTime now = DateTime.now();

  static final List<MenuItem> standardLunch = <MenuItem>[
    const MenuItem(id: 'dal', name: 'Dal Tadka', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'rice', name: 'Steamed Rice', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'roti4', name: 'Phulka Roti (4)', kind: FoodItemKind.included, price: 0, portion: '4 pieces'),
    const MenuItem(id: 'sabzi', name: 'Seasonal Sabzi', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'salad', name: 'Green Salad', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'paneer', name: 'Paneer Butter Masala', kind: FoodItemKind.addOn, price: 35, portion: '1 serving', maxQuantity: 2),
    const MenuItem(id: 'extra_roti', name: 'Extra Roti (Set of 2)', kind: FoodItemKind.addOn, price: 15, portion: '2 pieces', maxQuantity: 4),
  ];

  static final List<MenuItem> standardDinner = <MenuItem>[
    const MenuItem(id: 'dal_dinner', name: 'Mixed Dal Fry', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'rice_dinner', name: 'Jeera Rice', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'roti_dinner', name: 'Phulka Roti (4)', kind: FoodItemKind.included, price: 0, portion: '4 pieces'),
    const MenuItem(id: 'sabzi_dinner', name: 'Aloo Gobi Matar', kind: FoodItemKind.included, price: 0, portion: '1 serving'),
    const MenuItem(id: 'sweet', name: 'Gulab Jamun (2 pcs)', kind: FoodItemKind.addOn, price: 30, portion: '2 pieces', maxQuantity: 2),
  ];

  static final List<MealPlan> radhePlans = <MealPlan>[
    const MealPlan(id: 'radhe-daily-lunch', providerId: 'prov-radhe-001', name: 'Single Daily Meal Pass', type: SubscriptionType.dailyMeal, durationDays: 1, price: 95, slotIds: ['lunch', 'dinner'], description: 'One lunch or dinner entitlement for today.'),
    const MealPlan(id: 'radhe-fixed-15', providerId: 'prov-radhe-001', name: '15-Day Unlimited Access', type: SubscriptionType.fixedPeriod, durationDays: 15, price: 1500, slotIds: ['lunch', 'dinner'], description: 'Unlimited daily access for 15 days.'),
    const MealPlan(id: 'radhe-fixed-30', providerId: 'prov-radhe-001', name: 'Monthly Unlimited Access', type: SubscriptionType.fixedPeriod, durationDays: 30, durationMonths: 1, price: 2800, slotIds: ['lunch', 'dinner'], description: 'Fixed-period unlimited access for 30 days.'),
    const MealPlan(id: 'radhe-tracker-60', providerId: 'prov-radhe-001', name: '60-Meal Flexi Tracker', type: SubscriptionType.mealTracker, durationDays: 60, price: 4800, slotIds: ['lunch', 'dinner'], includedMeals: 60, description: 'Deducts 1 credit per verified meal redemption.'),
  ];

  static final List<MessProvider> providers = <MessProvider>[
    MessProvider(
      id: 'prov-radhe-001',
      name: 'Radhe Mess & Tiffin Services',
      area: 'Campus Area',
      address: 'Near Student Campus',
      distanceMeters: 200,
      description: 'Pure authentic homely vegetarian thalis and meals for students & professionals.',
      isOpen: true,
      mealSlots: <MealSlot>[
        const MealSlot(id: 'breakfast', name: 'Breakfast', startHour: 7, startMinute: 30, endHour: 9, endMinute: 30, menuSummary: 'Poha, Upma, Tea', items: [MenuItem(id: 'poha', name: 'Poha', kind: FoodItemKind.included, price: 0, portion: '1 serving'), MenuItem(id: 'tea', name: 'Masala Tea', kind: FoodItemKind.included, price: 0, portion: '1 cup')]),
        MealSlot(id: 'lunch', name: 'Lunch', startHour: 11, startMinute: 30, endHour: 15, endMinute: 0, menuSummary: 'Dal Tadka, Rice, 4 Phulka Rotis, Sabzi, Salad', items: standardLunch),
        MealSlot(id: 'dinner', name: 'Dinner', startHour: 19, startMinute: 0, endHour: 22, endMinute: 0, menuSummary: 'Mixed Dal, Jeera Rice, 4 Rotis, Sabzi', items: standardDinner),
      ],
      plans: radhePlans,
    ),
  ];
}
