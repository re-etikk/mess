import 'package:flutter/material.dart';

import '../../core/models/mess_models.dart';
import 'create_subscription_screen.dart';

/// Legacy compatibility shim redirecting to the 2-stage Behance subscription flow.
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, required this.provider, this.plan});
  final MessProvider provider;
  final MealPlan? plan;

  @override
  Widget build(BuildContext context) => CreateSubscriptionScreen(provider: provider);
}
