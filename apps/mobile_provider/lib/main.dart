import 'package:flutter/material.dart';

void main() => runApp(const ThaliProviderApp());

class ThaliProviderApp extends StatelessWidget {
  const ThaliProviderApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Thali Provider',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE28A24)), useMaterial3: true),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.storefront, size: 48),
              const SizedBox(height: 20),
              Text('Thali Provider', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text('Provider sign-in, onboarding, menus, and QR operations require the secure backend and verified provider accounts.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text('No demo account or business data is available.', textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    ),
  );
}
