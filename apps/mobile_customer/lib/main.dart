import 'package:flutter/material.dart';

void main() => runApp(const ThaliCustomerApp());

class ThaliCustomerApp extends StatelessWidget {
  const ThaliCustomerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Thali',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE28A24)), useMaterial3: true),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.restaurant, size: 48),
              const SizedBox(height: 20),
              Text('Thali', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text('Customer sign-in and meal passes will be available after the secure Thali backend is configured.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('No sample provider, subscription, balance, or payment is shown.', textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    ),
  );
}
