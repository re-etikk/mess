import 'package:flutter/material.dart';

void main() => runApp(const DeliveryUnavailableApp());

class DeliveryUnavailableApp extends StatelessWidget {
  const DeliveryUnavailableApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Thali',
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.restaurant, size: 48),
              const SizedBox(height: 20),
              Text('Delivery is not offered', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text('The current Thali product is for customers visiting food providers. Delivery partner workflows are out of scope.', textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    ),
  );
}
