import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() => runApp(const MessProviderApp());

const Color ink = Color(0xFF142433);
const Color orange = Color(0xFFF59A16);
const Color cream = Color(0xFFFAF6EE);
const Color card = Color(0xFFFFFDF8);
const Color muted = Color(0xFF68737D);
const Color line = Color(0xFFE8E1D6);
const Color green = Color(0xFF218653);

class MessProviderApp extends StatefulWidget {
  const MessProviderApp({super.key});

  @override
  State<MessProviderApp> createState() => _MessProviderAppState();
}

class _MessProviderAppState extends State<MessProviderApp> {
  bool signedIn = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MESS Provider',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(seedColor: orange, primary: orange, surface: card),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink, height: 1.12),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
          titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
          bodyLarge: TextStyle(fontSize: 15, color: ink, height: 1.4),
          bodyMedium: TextStyle(fontSize: 13, color: muted, height: 1.4),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: orange, width: 1.5)),
          hintStyle: const TextStyle(color: Color(0xFF9AA1A8), fontSize: 13),
        ),
        cardTheme: CardThemeData(
          color: card,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: line)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: !signedIn
          ? ProviderLoginScreen(
              onDemoLogin: () => setState(() => signedIn = true),
              onRegister: () { appNavigatorKey.currentState?.push<void>(MaterialPageRoute<void>(
                builder: (_) => ProviderOnboardingScreen(onComplete: () => setState(() { signedIn = true; })),
              )); },
            )
          : ProviderShell(onSignOut: () => setState(() { signedIn = false; })),
    );
  }
}

void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class ProviderLoginScreen extends StatefulWidget {
  const ProviderLoginScreen({super.key, required this.onDemoLogin, required this.onRegister});
  final VoidCallback onDemoLogin;
  final VoidCallback onRegister;
  @override
  State<ProviderLoginScreen> createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 14),
                Container(height: 100, alignment: Alignment.center, child: Image.asset('assets/branding/mess_logo_reference.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const BrandMark())),
                const SizedBox(height: 22),
                Text('Welcome back', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                const Text('Manage your mess, menu and daily meal service.', style: TextStyle(color: muted, fontSize: 15)),
                const SizedBox(height: 28),
                const FieldLabel('Email or phone number'),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'owner@example.com', prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 16),
                const FieldLabel('Password'),
                TextField(controller: password, obscureText: obscure, decoration: InputDecoration(hintText: 'Enter password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => showNotice(context, 'Password reset must be connected to the configured authentication provider.'), child: const Text('Forgot password?'))),
                const SizedBox(height: 6),
                PrimaryButton(label: 'Sign in', onPressed: () {
                  if (email.text.trim().isEmpty || password.text.isEmpty) { showNotice(context, 'Enter email/phone and password.'); return; }
                  showNotice(context, 'Preview mode: connect real authentication before launch.');
                  widget.onDemoLogin();
                }),
                const SizedBox(height: 17),
                const DividerWithLabel(label: 'OR'),
                const SizedBox(height: 17),
                OutlinedButton.icon(
                  onPressed: () => showNotice(context, 'Google sign-in UI is ready. Connect OAuth credentials to enable real sign-in.'),
                  icon: const GoogleMark(), label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(foregroundColor: ink, backgroundColor: Colors.white, minimumSize: const Size.fromHeight(52), side: const BorderSide(color: line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 22),
                Center(child: Wrap(alignment: WrapAlignment.center, children: [const Text('New to MESS? ', style: TextStyle(color: muted)), TextButton(onPressed: widget.onRegister, child: const Text('Register your business'))])),
                const SizedBox(height: 12),
                const DemoBanner(text: 'Preview build. Authentication and business records are not connected to a live backend.'),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;
  @override
  State<ProviderOnboardingScreen> createState() => _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  int step = 0;
  String businessType = 'Mess';
  String planModel = 'Both';
  final businessName = TextEditingController();
  final ownerName = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController(text: 'Noida');
  final fssai = TextEditingController();
  final selectedSlots = <String>{'Lunch', 'Dinner'};
  final selectedDurations = <String>{'15 days', '1 month', '3 months', '6 months', '12 months'};
  final priceControllers = <String, TextEditingController>{
    '15 days': TextEditingController(text: '1500'), '1 month': TextEditingController(text: '2800'),
    '3 months': TextEditingController(text: '7800'), '6 months': TextEditingController(text: '14400'), '12 months': TextEditingController(text: '26400'),
  };
  bool dailyMeal = true;
  bool acceptTerms = false;

  @override
  void dispose() {
    businessName.dispose(); ownerName.dispose(); phone.dispose(); address.dispose(); city.dispose(); fssai.dispose();
    for (final value in priceControllers.values) { value.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: cream, title: const Text('Register your business', style: TextStyle(color: ink, fontWeight: FontWeight.w800)), leading: IconButton(onPressed: () => step == 0 ? Navigator.pop(context) : setState(() => step--), icon: const Icon(Icons.arrow_back, color: ink))),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: List.generate(5, (i) => Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 220), height: 5, margin: EdgeInsets.only(right: i == 4 ? 0 : 6), decoration: BoxDecoration(color: i <= step ? orange : line, borderRadius: BorderRadius.circular(2)))))),
          const SizedBox(height: 14), Text('Step ${step + 1} of 5', style: const TextStyle(color: muted, fontWeight: FontWeight.w700)), const SizedBox(height: 3),
          Text(['Business details', 'Location & timings', 'Meal slots', 'Plans & pricing', 'Menu & review'][step], style: Theme.of(context).textTheme.headlineMedium),
        ])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 18), child: _buildStepContent(context))),
        Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 18), decoration: const BoxDecoration(color: cream, border: Border(top: BorderSide(color: line))), child: Row(children: [
          if (step > 0) Expanded(child: OutlinedButton(onPressed: () => setState(() => step--), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), side: const BorderSide(color: line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Back'))),
          if (step > 0) const SizedBox(width: 10),
          Expanded(flex: 2, child: PrimaryButton(label: step == 4 ? 'Save and preview dashboard' : 'Continue', onPressed: () {
            if (step == 0 && businessName.text.trim().isEmpty) { showNotice(context, 'Enter your business name.'); return; }
            if (step == 1 && address.text.trim().isEmpty) { showNotice(context, 'Add your business address.'); return; }
            if (step == 2 && selectedSlots.isEmpty) { showNotice(context, 'Select at least one meal slot.'); return; }
            if (step == 3 && selectedDurations.isEmpty) { showNotice(context, 'Select at least one plan duration.'); return; }
            if (step == 4 && !acceptTerms) { showNotice(context, 'Review and accept the provider terms to continue.'); return; }
            if (step < 4) { setState(() => step++); } else { showNotice(context, 'Preview profile created. Complete verification and backend setup before publishing.'); widget.onComplete(); Navigator.pop(context); }
          })),
        ])),
      ])),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionIntro(title: 'What kind of food business do you run?', subtitle: 'Choose the closest match. You can add more services later.'),
          ...['Mess', 'Hotel / Restaurant', 'Home tiffin service', 'Hostel / College canteen'].map((type) => SelectableTile(title: type, subtitle: {'Mess':'Daily meals for students and residents','Hotel / Restaurant':'Dine-in food service','Home tiffin service':'Home-cooked meals and tiffins','Hostel / College canteen':'Campus food operations'}[type]!, icon: {'Mess':Icons.storefront_outlined,'Hotel / Restaurant':Icons.restaurant_outlined,'Home tiffin service':Icons.ramen_dining_outlined,'Hostel / College canteen':Icons.school_outlined}[type]!, selected: businessType == type, onTap: () => setState(() => businessType = type))),
          const SizedBox(height: 16), const FieldLabel('Business / mess name'), TextField(controller: businessName, decoration: const InputDecoration(hintText: 'e.g. Radhe Mess', prefixIcon: Icon(Icons.storefront_outlined))),
          const SizedBox(height: 14), const FieldLabel('Owner / primary contact'), TextField(controller: ownerName, decoration: const InputDecoration(hintText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 14), const FieldLabel('Business phone'), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '+91', prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 14), const FieldLabel('Food business registration (optional during draft)'), TextField(controller: fssai, decoration: const InputDecoration(hintText: 'FSSAI number / verification reference', prefixIcon: Icon(Icons.verified_user_outlined))),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionIntro(title: 'Where is your business?', subtitle: 'Customers use this to find your mess and confirm the correct location.'),
          const FieldLabel('Full address'), TextField(controller: address, maxLines: 2, decoration: const InputDecoration(hintText: 'Shop, street, landmark, building', prefixIcon: Icon(Icons.location_on_outlined))),
          const SizedBox(height: 14), const FieldLabel('City / area'), TextField(controller: city, decoration: const InputDecoration(prefixIcon: Icon(Icons.map_outlined))),
          const SizedBox(height: 16), Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.pin_drop_outlined, size: 32, color: orange), const SizedBox(height: 8), const Text('Map pin and coordinates', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 4), const Text('Connect a location picker to store verified latitude and longitude. Manual address entry stays available if permission is denied.', style: TextStyle(color: muted, height: 1.4)), const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => showNotice(context, 'Map picker is a backend integration task. Manual address is available for this preview.'), icon: const Icon(Icons.map_outlined), label: const Text('Choose map location'))]))),
          const SizedBox(height: 16), const SectionIntro(title: 'Opening days', subtitle: 'Default schedule for this preview'), Wrap(spacing: 8, runSpacing: 8, children: ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((day) => FilterChip(label: Text(day), selected: day != 'Sun', onSelected: (_) => showNotice(context, 'Opening-day editor will be persisted with the backend configuration.'))).toList()),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionIntro(title: 'Set your serving times', subtitle: 'Only selected meal slots will be shown to customers.'),
          ...[
            ('Breakfast','07:00 AM','09:30 AM',Icons.wb_sunny_outlined),('Lunch','12:00 PM','02:30 PM',Icons.wb_sunny),('Evening snacks','04:30 PM','06:00 PM',Icons.local_cafe_outlined),('Dinner','07:00 PM','09:30 PM',Icons.nightlight_outlined),
          ].map((slot) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [Row(children: [Icon(slot.$4, color: selectedSlots.contains(slot.$1) ? orange : muted), const SizedBox(width: 10), Expanded(child: Text(slot.$1, style: const TextStyle(fontWeight: FontWeight.w800, color: ink))), Switch(value: selectedSlots.contains(slot.$1), activeTrackColor: orange, activeThumbColor: orange, onChanged: (value) => setState(() { value ? selectedSlots.add(slot.$1) : selectedSlots.remove(slot.$1); }))]), if (selectedSlots.contains(slot.$1)) Row(children: [Expanded(child: _TimeBox(label: 'Starts', value: slot.$2)), const SizedBox(width: 8), Expanded(child: _TimeBox(label: 'Ends', value: slot.$3))])])))),
          const SizedBox(height: 12), OutlinedButton.icon(onPressed: () => showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Custom meal slot'), content: const Text('Custom slot editor will be saved with the configured backend. You can add “Brunch”, “Tea” or a provider-specific slot.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))])), icon: const Icon(Icons.add), label: const Text('Add custom slot')),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionIntro(title: 'Choose how you sell meals', subtitle: 'Enable one or both subscription models. Daily meals are configured separately.'),
          ...['Fixed-period', 'Meal tracker', 'Both'].map((model) => SelectableTile(title: model, subtitle: {'Fixed-period':'Access for a set duration. Record attendance without reducing meal credits.','Meal tracker':'Sell a defined credit balance. Deduct one credit after confirmed redemption.','Both':'Offer customers a choice between both subscription models.'}[model]!, icon: {'Fixed-period':Icons.calendar_month_outlined,'Meal tracker':Icons.track_changes_outlined,'Both':Icons.layers_outlined}[model]!, selected: planModel == model, onTap: () => setState(() => planModel = model))),
          SwitchListTile(contentPadding: EdgeInsets.zero, activeTrackColor: orange, activeThumbColor: orange, value: dailyMeal, onChanged: (value) => setState(() => dailyMeal = value), title: const Text('Allow one-time daily meals', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), subtitle: const Text('Sell a single eligible meal without a subscription. Payment verification is required before redemption.')),
          const SizedBox(height: 10), const SectionIntro(title: 'Durations and price drafts', subtitle: 'These are editable examples, not market recommendations. Review every price before publishing.'),
          ...priceControllers.keys.map((duration) => CheckboxListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 8), value: selectedDurations.contains(duration), activeColor: orange, onChanged: (value) => setState(() { value == true ? selectedDurations.add(duration) : selectedDurations.remove(duration); }), title: Text(duration, style: const TextStyle(fontWeight: FontWeight.w700, color: ink)), secondary: SizedBox(width: 110, child: TextField(controller: priceControllers[duration], keyboardType: TextInputType.number, textAlign: TextAlign.right, decoration: const InputDecoration(prefixText: '₹ ', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)))))),
          const DemoBanner(text: 'Price, duration, eligible slots, included quantities, validity and discounts must be validated on the server before a plan can be published.'),
        ]);
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionIntro(title: 'Set your default menu rules', subtitle: 'You can change the menu every day and override portions or add-ons per meal slot.'),
          const Text('Included in regular thali', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: ['Dal','Rice (1 serving)','Roti (4)','Sabzi','Salad'].map((item) => Chip(label: Text(item), backgroundColor: const Color(0xFFFFEFD5), side: BorderSide.none)).toList()),
          const SizedBox(height: 20), const Text('Optional extras', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 8),
          const PriceRow(title: 'Paneer special', price: '₹30 / serving'), const PriceRow(title: 'Extra roti', price: '₹5 / piece'), const PriceRow(title: 'Extra rice', price: '₹10 / serving'),
          const SizedBox(height: 14), OutlinedButton.icon(onPressed: () => showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Menu item editor'), content: const Text('The full version supports item categories, included quantities, plan-specific inclusion, add-on pricing, stock, sold-out state, dietary labels and price snapshots.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))])), icon: const Icon(Icons.add), label: const Text('Add or edit menu item')),
          const SizedBox(height: 20), const Text('Review', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 8),
          ReviewLine(label: 'Business type', value: businessType), ReviewLine(label: 'Business', value: businessName.text.isEmpty ? 'Not set' : businessName.text), ReviewLine(label: 'Location', value: address.text.isEmpty ? 'Not set' : '${address.text}, ${city.text}'), ReviewLine(label: 'Meal slots', value: selectedSlots.isEmpty ? 'None' : selectedSlots.join(', ')), ReviewLine(label: 'Plan model', value: planModel), ReviewLine(label: 'Daily meals', value: dailyMeal ? 'Enabled' : 'Disabled'),
          const SizedBox(height: 12), CheckboxListTile(contentPadding: EdgeInsets.zero, activeColor: orange, value: acceptTerms, onChanged: (value) => setState(() => acceptTerms = value ?? false), title: const Text('I have reviewed the provider terms and pricing rules.', style: TextStyle(color: ink, fontSize: 13))),
          const DemoBanner(text: 'Submitting this preview does not verify your business. Real publication must wait for backend validation, required document review and provider agreement.'),
        ]);
    }
  }
}

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key, this.onSignOut});
  final VoidCallback? onSignOut;
  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int selectedTab = 0;
  String? detail;
  String businessName = 'Radhe Mess';

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ProviderOverview(onNavigate: (index) => setState(() { selectedTab = index; detail = null; }), onOpenDetail: (value) => setState(() => detail = value)),
      MenuManagementScreen(),
      PlansManagementScreen(),
      const DailyQrScreen(),
      MoreManagementScreen(onSelect: (value) => setState(() => detail = value), onSignOut: widget.onSignOut),
    ];
    Widget content;
    if (detail != null) {
      content = MoreDetailScreen(kind: detail!, onBack: () => setState(() => detail = null));
    } else {
      content = pages[selectedTab];
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cream, surfaceTintColor: cream,
        title: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFFFE5B7), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.restaurant, color: ink, size: 20)), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('MESS Provider', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16)), Text('DEMO WORKSPACE', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w800))]))]),
        actions: [IconButton(tooltip: 'Notifications', onPressed: () => setState(() => detail = 'Notifications'), icon: const Icon(Icons.notifications_none, color: ink)), const SizedBox(width: 4)],
      ),
      body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), switchInCurve: Curves.easeOut, switchOutCurve: Curves.easeIn, child: KeyedSubtree(key: ValueKey('${selectedTab}_${detail ?? 'root'}'), child: content))),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() { selectedTab = index; detail = null; }),
        backgroundColor: card, indicatorColor: const Color(0xFFFFE6B8), elevation: 4,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Menu'),
          NavigationDestination(icon: Icon(Icons.sell_outlined), selectedIcon: Icon(Icons.sell), label: 'Plans'),
          NavigationDestination(icon: Icon(Icons.qr_code_2_outlined), selectedIcon: Icon(Icons.qr_code_2), label: 'Daily QR'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class ProviderOverview extends StatelessWidget {
  const ProviderOverview({super.key, required this.onNavigate, required this.onOpenDetail});
  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
      const DemoBanner(text: 'Preview workspace. Live business records and metrics will appear after the provider repository is connected.'),
      const SizedBox(height: 18),
      Text('Good morning, owner', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 5), const Text('Here is your service overview for today.', style: TextStyle(color: muted)),
      const SizedBox(height: 18),
      Row(children: [Expanded(child: MetricCard(title: 'Today’s meals', value: '—', note: 'Connect redemption data', icon: Icons.restaurant, tint: const Color(0xFFFFE8C5))), const SizedBox(width: 10), Expanded(child: MetricCard(title: 'Gross sales', value: '—', note: 'Ledger not connected', icon: Icons.currency_rupee, tint: const Color(0xFFDDF2E6)))]),
      const SizedBox(height: 10), Row(children: [Expanded(child: MetricCard(title: 'Active plans', value: '—', note: 'Connect subscriptions', icon: Icons.calendar_month, tint: const Color(0xFFE4EDF9))), const SizedBox(width: 10), Expanded(child: MetricCard(title: 'Needs attention', value: '—', note: 'Live queue not connected', icon: Icons.flag_outlined, tint: const Color(0xFFFFE5E0)))]),
      const SizedBox(height: 22),
      SectionHeader(title: 'Today’s service', actionLabel: 'Manage menu', onAction: () => onNavigate(1)),
      const SizedBox(height: 10),
      const SlotStatusTile(name: 'Breakfast', time: '7:00 – 9:30 AM', status: 'Closed', count: 'Redemption data not connected', icon: Icons.wb_sunny_outlined, statusColor: muted),
      const SlotStatusTile(name: 'Lunch', time: '12:00 – 2:30 PM', status: 'Configured', count: 'Awaiting backend data', icon: Icons.wb_sunny, statusColor: orange),
      const SlotStatusTile(name: 'Dinner', time: '7:00 – 9:30 PM', status: 'Upcoming', count: 'Schedule only · no count yet', icon: Icons.nightlight_outlined, statusColor: orange),
      const SizedBox(height: 22),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.qr_code_2, size: 28, color: orange), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Daily counter QR', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), Text('One provider QR for today’s service date', style: TextStyle(fontSize: 12, color: muted))])), TextButton(onPressed: () => onNavigate(3), child: const Text('Open'))]),
        const SizedBox(height: 5), const Text('The production QR must be issued and signed by the backend. The QR screen in this package is a non-redeemable preview.', style: TextStyle(color: muted, height: 1.4, fontSize: 12)),
      ]))),
      const SizedBox(height: 22),
      SectionHeader(title: 'Quick actions'), const SizedBox(height: 10),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55, children: [
        QuickAction(icon: Icons.edit_calendar_outlined, title: 'Update menu', onTap: () => onNavigate(1)),
        QuickAction(icon: Icons.sell_outlined, title: 'Plan pricing', onTap: () => onNavigate(2)),
        QuickAction(icon: Icons.local_offer_outlined, title: 'Create offer', onTap: () => onOpenDetail('Offers')),
        QuickAction(icon: Icons.groups_outlined, title: 'Subscribers', onTap: () => onOpenDetail('Subscribers')),
      ]),
      const SizedBox(height: 22), SectionHeader(title: 'Recent activity', actionLabel: 'View all', onAction: () => onOpenDetail('Attendance')),
      const SizedBox(height: 8),
      const ActivityRow(title: 'Lunch redemption recorded', detail: 'Demo student · 12:24 PM', status: 'Success', success: true),
      const ActivityRow(title: 'New subscription order', detail: 'Tracker plan · 12:18 PM', status: 'Demo', success: false),
      const ActivityRow(title: 'Paneer special marked available', detail: 'Lunch menu · 11:40 AM', status: 'Updated', success: false),
    ]);
  }
}

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});
  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  String slot = 'Lunch';
  final items = <MenuItemDraft>[
    MenuItemDraft('Dal', 'Included', '1 serving', 0, true), MenuItemDraft('Rice', 'Included', '1 serving', 0, true), MenuItemDraft('Roti', 'Included', '4 pieces', 0, true), MenuItemDraft('Mixed sabzi', 'Included', '1 serving', 0, true), MenuItemDraft('Paneer special', 'Paid extra', '1 serving', 30, true, paid: true), MenuItemDraft('Extra roti', 'Paid extra', 'per piece', 5, true, paid: true),
  ];
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
      Text('Menu & portions', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 5), const Text('Configure what each plan includes and what costs extra.', style: TextStyle(color: muted)), const SizedBox(height: 17),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'Breakfast', label: Text('Breakfast')), ButtonSegment(value: 'Lunch', label: Text('Lunch')), ButtonSegment(value: 'Dinner', label: Text('Dinner'))], selected: {slot}, onSelectionChanged: (v) => setState(() => slot = v.first), style: const ButtonStyle(visualDensity: VisualDensity.compact)),
      const SizedBox(height: 18), Row(children: [Expanded(child: Text('$slot menu', style: Theme.of(context).textTheme.titleLarge)), TextButton.icon(onPressed: () => showNotice(context, 'Menu calendar editor should be connected to daily_menus.'), icon: const Icon(Icons.calendar_month_outlined), label: const Text('Date'))]),
      const SizedBox(height: 8),
      ...items.where((item) => item.enabled).map((item) => Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFFFEFD5), borderRadius: BorderRadius.circular(12)), child: Icon(item.paid ? Icons.add_shopping_cart_outlined : Icons.restaurant, color: ink)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)), Text('${item.rule} · ${item.portion}', style: const TextStyle(color: muted, fontSize: 12))])), if (item.price > 0) Text('₹${item.price}', style: const TextStyle(color: ink, fontWeight: FontWeight.w800)), IconButton(onPressed: () => _editItem(item), tooltip: 'Edit item', icon: const Icon(Icons.edit_outlined, size: 19))])))),
      const SizedBox(height: 10), OutlinedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Add menu item'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: line))),
      const SizedBox(height: 18), Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Rules to review before publishing', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 8), const RuleBullet('Included quantity must be explicit, e.g. 4 rotis.'), const RuleBullet('Paid extras must be separate line items.'), const RuleBullet('Sold-out extras must not be purchasable.'), const RuleBullet('Plan-specific inclusions must be checked by backend.'), const SizedBox(height: 8), PrimaryButton(label: 'Preview customer menu', onPressed: () => showNotice(context, 'Preview displays current local draft. Save it to the backend before publication.'))]))),
    ]);
  }
  void _addItem() => _itemDialog();
  void _editItem(MenuItemDraft item) => _itemDialog(existing: item);
  Future<void> _itemDialog({MenuItemDraft? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final portion = TextEditingController(text: existing?.portion ?? '1 serving');
    final price = TextEditingController(text: existing == null ? '0' : '${existing.price}');
    bool paid = existing?.paid ?? false;
    final result = await showDialog<MenuItemDraft>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(existing == null ? 'Add menu item' : 'Edit menu item'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')), const SizedBox(height: 10), TextField(controller: portion, decoration: const InputDecoration(labelText: 'Portion / unit')), const SizedBox(height: 10), SwitchListTile(contentPadding: EdgeInsets.zero, value: paid, onChanged: (value) => setDialogState(() => paid = value), title: const Text('Charge as extra')), TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (₹)'))])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { if (name.text.trim().isEmpty) return; Navigator.pop(dialogContext, MenuItemDraft(name.text.trim(), paid ? 'Paid extra' : 'Included', portion.text.trim(), int.tryParse(price.text) ?? 0, true, paid: paid)); }, child: const Text('Save draft'))],
    )));
    final saved = result;
    if (saved != null && mounted) setState(() { if (existing != null) { final i = items.indexOf(existing); if (i >= 0) items[i] = saved; } else { items.add(saved); } });
    name.dispose(); portion.dispose(); price.dispose();
  }
}

class PlansManagementScreen extends StatefulWidget {
  const PlansManagementScreen({super.key});
  @override
  State<PlansManagementScreen> createState() => _PlansManagementScreenState();
}

class _PlansManagementScreenState extends State<PlansManagementScreen> {
  bool fixed = true, tracker = true, daily = true;
  final offers = <String>['WELCOME5 · 5% on first plan'];
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
      Text('Plans & pricing', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 5), const Text('Choose the models customers can buy. Prices below are demo drafts.', style: TextStyle(color: muted)), const SizedBox(height: 17),
      SwitchListTile(value: fixed, onChanged: (v) => setState(() => fixed = v), activeTrackColor: orange, activeThumbColor: orange, contentPadding: const EdgeInsets.symmetric(horizontal: 12), tileColor: card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)), title: const Text('Fixed-period plan', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), subtitle: const Text('Record visits; do not deduct meal credits.'), secondary: const Icon(Icons.calendar_month_outlined, color: orange)),
      const SizedBox(height: 10), SwitchListTile(value: tracker, onChanged: (v) => setState(() => tracker = v), activeTrackColor: orange, activeThumbColor: orange, contentPadding: const EdgeInsets.symmetric(horizontal: 12), tileColor: card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)), title: const Text('Meal-tracker plan', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), subtitle: const Text('Deduct one credit after verified redemption.'), secondary: const Icon(Icons.track_changes_outlined, color: orange)),
      const SizedBox(height: 10), SwitchListTile(value: daily, onChanged: (v) => setState(() => daily = v), activeTrackColor: orange, activeThumbColor: orange, contentPadding: const EdgeInsets.symmetric(horizontal: 12), tileColor: card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)), title: const Text('Daily pay-as-you-eat', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), subtitle: const Text('Sell a single meal after verified payment.'), secondary: const Icon(Icons.receipt_long_outlined, color: orange)),
      const SizedBox(height: 20), const SectionHeader(title: 'Duration pricing'), const SizedBox(height: 9),
      const PlanPriceCard(duration: '15 days', price: '₹1,500', perMeal: 'Set meal slots and portions'), const SizedBox(height: 9), const PlanPriceCard(duration: '1 month', price: '₹2,800', perMeal: 'Monthly reference price'), const SizedBox(height: 9), const PlanPriceCard(duration: '3 months', price: '₹7,800', perMeal: 'Optional long-term discount'), const SizedBox(height: 9), const PlanPriceCard(duration: '6 months', price: '₹14,400', perMeal: 'Optional long-term discount'), const SizedBox(height: 9), const PlanPriceCard(duration: '12 months', price: '₹26,400', perMeal: 'Optional long-term discount'),
      const SizedBox(height: 20), SectionHeader(title: 'Offers & discounts', actionLabel: 'Create offer', onAction: _createOffer), const SizedBox(height: 8),
      ...offers.map((offer) => Card(child: ListTile(leading: const Icon(Icons.local_offer_outlined, color: orange), title: Text(offer, style: const TextStyle(fontWeight: FontWeight.w700, color: ink)), subtitle: const Text('Draft offer · not published', style: TextStyle(color: muted)), trailing: IconButton(onPressed: () => setState(() => offers.remove(offer)), icon: const Icon(Icons.delete_outline))))),
      const SizedBox(height: 12), const DemoBanner(text: 'Offer engine should validate date range, minimum spend, eligible plans, per-customer limits and stacking rules on the backend. Never show unapproved discounts as live.'),
    ]);
  }
  Future<void> _createOffer() async {
    final code = TextEditingController(); final discount = TextEditingController(text: '5');
    final result = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Create offer draft'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: code, decoration: const InputDecoration(labelText: 'Offer code')), const SizedBox(height: 10), TextField(controller: discount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount (%)'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { if (code.text.trim().isNotEmpty) Navigator.pop(dialogContext, '${code.text.trim().toUpperCase()} · ${discount.text}% draft discount'); }, child: const Text('Save draft'))]));
    if (result != null && mounted) setState(() => offers.add(result)); code.dispose(); discount.dispose();
  }
}

class DailyQrScreen extends StatelessWidget {
  const DailyQrScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final date = DateTime.now();
    final dateText = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
      Text('Today’s QR', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 5), const Text('Display this at the counter so eligible customers can scan it.', style: TextStyle(color: muted)), const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        Row(children: [const Icon(Icons.storefront_outlined, color: orange), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Radhe Mess', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), Text('Provider demo workspace', style: TextStyle(color: muted, fontSize: 12))])), const StatusTag(text: 'DEMO', color: orange)]),
        const SizedBox(height: 18), Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: const Border.fromBorderSide(BorderSide(color: line))), child: QrImageView(data: 'MESS_DEMO_PROVIDER_QR|NOT_VALID|$dateText', version: QrVersions.auto, size: 210, backgroundColor: Colors.white)),
        const SizedBox(height: 12), Text('Service date: $dateText', style: const TextStyle(color: ink, fontWeight: FontWeight.w800)), const SizedBox(height: 4), const Text('Demo QR only. Not valid for live redemption.', style: TextStyle(color: Color(0xFFB44736), fontWeight: FontWeight.w700)),
        const SizedBox(height: 16), const Divider(), const SizedBox(height: 8), const Row(children: [Icon(Icons.shield_outlined, color: green), SizedBox(width: 8), Expanded(child: Text('Production QR must be issued by the backend, bound to provider and service date, and validated on every scan.', style: TextStyle(color: muted, fontSize: 12, height: 1.4)))]),
        const SizedBox(height: 14), PrimaryButton(label: 'Refresh demo preview', onPressed: () => showNotice(context, 'Demo QR refreshed visually. Connect the server-issued daily QR API before releasing this feature.')),
      ]))),
      const SizedBox(height: 12), const SectionHeader(title: 'Today’s redemption overview'), const SizedBox(height: 8),
      const SlotStatusTile(name: 'Breakfast', time: '7:00 – 9:30 AM', status: 'Closed', count: 'Live attendance not connected', icon: Icons.wb_sunny_outlined, statusColor: muted),
      const SlotStatusTile(name: 'Lunch', time: '12:00 – 2:30 PM', status: 'Configured', count: 'Awaiting backend data', icon: Icons.wb_sunny, statusColor: orange),
      const SlotStatusTile(name: 'Dinner', time: '7:00 – 9:30 PM', status: 'Upcoming', count: 'Scheduled slot · no count yet', icon: Icons.nightlight_outlined, statusColor: orange),
    ]);
  }
}

class MoreManagementScreen extends StatelessWidget {
  const MoreManagementScreen({super.key, required this.onSelect, this.onSignOut});
  final ValueChanged<String> onSelect; final VoidCallback? onSignOut;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
    Text('Business tools', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 5), const Text('Manage customers, offers, settlement and business settings.', style: TextStyle(color: muted)), const SizedBox(height: 18),
    MoreMenuTile(icon: Icons.groups_outlined, title: 'Subscribers & customers', subtitle: 'Active plans and customer records', onTap: () => onSelect('Subscribers')),
    MoreMenuTile(icon: Icons.account_balance_wallet_outlined, title: 'Earnings & settlements', subtitle: 'Gross sales, fees, refunds and payouts', onTap: () => onSelect('Earnings')),
    MoreMenuTile(icon: Icons.local_offer_outlined, title: 'Offers and promotions', subtitle: 'Discount rules and published offers', onTap: () => onSelect('Offers')),
    MoreMenuTile(icon: Icons.fact_check_outlined, title: 'Meal attendance', subtitle: 'Filter redemption by date and meal slot', onTap: () => onSelect('Attendance')),
    MoreMenuTile(icon: Icons.star_outline, title: 'Reviews & feedback', subtitle: 'Only verified meal feedback, with moderation status', onTap: () => onSelect('Feedback')),
    MoreMenuTile(icon: Icons.insights_outlined, title: 'Business reports', subtitle: 'Slot trends, repeat customers and plan renewals', onTap: () => onSelect('Reports')),
    MoreMenuTile(icon: Icons.store_mall_directory_outlined, title: 'Business profile', subtitle: 'Type, location, hours and documents', onTap: () => onSelect('Business profile')),
    MoreMenuTile(icon: Icons.support_agent_outlined, title: 'Support & disputes', subtitle: 'Raise and track operational issues', onTap: () => onSelect('Support')),
    MoreMenuTile(icon: Icons.settings_outlined, title: 'Settings & team access', subtitle: 'Business preferences and staff roles', onTap: () => onSelect('Settings')),
    MoreMenuTile(icon: Icons.policy_outlined, title: 'Terms and privacy', subtitle: 'Provider agreement and data policy', onTap: () => onSelect('Policies')),
    const SizedBox(height: 18), OutlinedButton.icon(onPressed: onSignOut ?? () => showNotice(context, 'Connect sign-out to the live auth provider.'), icon: const Icon(Icons.logout), label: const Text('Sign out'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: const Color(0xFFB83B31), side: const BorderSide(color: Color(0xFFEBCBC6), width: 1))),
  ]);
}

class MoreDetailScreen extends StatefulWidget {
  const MoreDetailScreen({super.key, required this.kind, required this.onBack});
  final String kind; final VoidCallback onBack;
  @override
  State<MoreDetailScreen> createState() => _MoreDetailScreenState();
}

class _MoreDetailScreenState extends State<MoreDetailScreen> {
  final TextEditingController search = TextEditingController();
  @override
  void dispose() { search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    switch (widget.kind) {
      case 'Earnings': return _detailScaffold(context, 'Earnings & settlements', [
        const DemoBanner(text: 'All amounts below are illustrative demo values, not actual earnings.'), const SizedBox(height: 12), Row(children: [Expanded(child: MetricCard(title: 'Gross sales', value: '—', note: 'Ledger not connected', icon: Icons.currency_rupee, tint: const Color(0xFFDDF2E6))), const SizedBox(width: 10), Expanded(child: MetricCard(title: 'Platform fee', value: '—', note: 'Agreement not connected', icon: Icons.percent, tint: const Color(0xFFFFE8C5)))]), const SizedBox(height: 10), const MetricCard(title: 'Estimated payable', value: '—', note: 'Settlement not connected', icon: Icons.account_balance_outlined, tint: Color(0xFFE4EDF9)), const SizedBox(height: 18), const SectionHeader(title: 'Recent ledger entries'), const SizedBox(height: 8), const ActivityRow(title: 'Subscription payment', detail: 'Demo ledger · today', status: 'Recorded', success: true), const ActivityRow(title: 'Refund adjustment', detail: 'Demo ledger · yesterday', status: 'Review', success: false), PrimaryButton(label: 'Export report', onPressed: () => showNotice(context, 'Export should be generated from authorized server-side financial records.')),
      ]);
      case 'Offers': return _detailScaffold(context, 'Offers & promotions', [const DemoBanner(text: 'Draft offers are not active until validated and published.'), const SizedBox(height: 12), const OfferInfoCard(code: 'WELCOME5', description: '5% off first eligible subscription', status: 'Draft'), const OfferInfoCard(code: 'LONGTERM', description: 'Long-term plan discount rule', status: 'Draft'), const SizedBox(height: 10), PrimaryButton(label: 'Create offer', onPressed: () => _newOffer(context))]);
      case 'Subscribers': return _detailScaffold(context, 'Subscribers & customers', [TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search customers or plan')), const SizedBox(height: 12), const DemoBanner(text: 'Customer rows below are demo examples. Only show real customers with authorized provider access.'), const SizedBox(height: 8), ...['Aarav S. · Tracker plan · 18 credits left','Neha K. · Fixed-period · Valid till 25 Nov','Kabir M. · Daily meal · Lunch'].where((s) => s.toLowerCase().contains(search.text.toLowerCase())).map((s) => Card(child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFFFE8C5), child: Icon(Icons.person_outline, color: ink)), title: Text(s, style: const TextStyle(color: ink, fontWeight: FontWeight.w700)), subtitle: const Text('Demo subscriber · masked identity'), trailing: const Icon(Icons.chevron_right)))),]);
      case 'Attendance': return _detailScaffold(context, 'Meal attendance', [const DemoBanner(text: 'Only verified, server-confirmed redemption records count as attendance.'), const SizedBox(height: 12), const SlotStatusTile(name: 'Breakfast', time: '7:00 – 9:30 AM', status: 'Closed', count: 'Live attendance not connected', icon: Icons.wb_sunny_outlined, statusColor: muted), const SlotStatusTile(name: 'Lunch', time: '12:00 – 2:30 PM', status: 'Configured', count: 'Awaiting backend data', icon: Icons.wb_sunny, statusColor: orange), const SlotStatusTile(name: 'Dinner', time: '7:00 – 9:30 PM', status: 'Upcoming', count: 'Scheduled slot · no count yet', icon: Icons.nightlight_outlined, statusColor: orange), OutlinedButton.icon(onPressed: () => showNotice(context, 'Connect date and slot filters to meal_redemptions.'), icon: const Icon(Icons.filter_list), label: const Text('Filter by date and slot'))]);
      case 'Support': return _detailScaffold(context, 'Support & disputes', [const Text('Need help with a payment, redemption or customer issue?', style: TextStyle(color: muted)), const SizedBox(height: 14), const FieldLabel('Issue type'), DropdownButtonFormField<String>(items: const [DropdownMenuItem(value: 'payment', child: Text('Payment / settlement')), DropdownMenuItem(value: 'redemption', child: Text('Meal redemption')), DropdownMenuItem(value: 'customer', child: Text('Customer dispute')), DropdownMenuItem(value: 'technical', child: Text('Technical issue'))], onChanged: (_) {}, decoration: const InputDecoration(hintText: 'Select issue')), const SizedBox(height: 12), const FieldLabel('Description'), const TextField(maxLines: 4, decoration: InputDecoration(hintText: 'Describe the issue and include a reference ID if available')), const SizedBox(height: 14), PrimaryButton(label: 'Create support ticket', onPressed: () => showNotice(context, 'Demo only. Connect to support_tickets API before release.'))]);
      case 'Settings': return _detailScaffold(context, 'Settings & team', [const DemoBanner(text: 'Role and permission changes must be enforced by the server, not only hidden in the UI.'), const SizedBox(height: 12), const SettingsRow(title: 'Business operating hours', subtitle: 'Edit opening days and closure schedule', icon: Icons.schedule), const SettingsRow(title: 'Team members', subtitle: 'Owner, manager, cashier and menu editor roles', icon: Icons.groups_outlined), const SettingsRow(title: 'Notifications', subtitle: 'Daily summary and operational alerts', icon: Icons.notifications_outlined), const SettingsRow(title: 'Payout account', subtitle: 'Managed by approved payment provider', icon: Icons.account_balance_outlined)]);
      case 'Notifications': return _detailScaffold(context, 'Notifications', [const ActivityRow(title: 'Lunch slot opened', detail: 'Demo notification · today', status: 'Info', success: false), const ActivityRow(title: 'Settlement needs review', detail: 'Demo notification · yesterday', status: 'Action', success: false)]);
      case 'Feedback': return _detailScaffold(context, 'Reviews & feedback', [const DemoBanner(text: 'Never display fabricated customer reviews. Only show feedback tied to verified meal redemptions, subject to the platform moderation policy.'), const SizedBox(height: 12), const Card(child: Padding(padding: EdgeInsets.all(18), child: Column(children: [Icon(Icons.rate_review_outlined, size: 34, color: muted), SizedBox(height: 10), Text('No verified feedback in this preview', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), SizedBox(height: 5), Text('Once customers submit feedback after a verified meal, it will appear here.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12, height: 1.4))])))]);
      case 'Reports': return _detailScaffold(context, 'Business reports', [const DemoBanner(text: 'Only compute reports from verified backend events. The prototype intentionally does not invent a trend chart.'), const SizedBox(height: 12), const SettingsRow(title: 'Meal slot report', subtitle: 'Breakfast, lunch, evening and dinner redemptions', icon: Icons.bar_chart_outlined), const SettingsRow(title: 'Plan performance', subtitle: 'Active subscriptions, renewals and expiries', icon: Icons.query_stats_outlined), const SettingsRow(title: 'Financial statement', subtitle: 'Gross, fees, refunds, payable and settled amounts', icon: Icons.account_balance_wallet_outlined)]);
      case 'Business profile': return _detailScaffold(context, 'Business profile', [const DemoBanner(text: 'Business profile values below are illustrative. Address changes and required-document changes should trigger server-side verification when applicable.'), const SizedBox(height: 12), const ReviewLine(label: 'Business name', value: 'Radhe Mess (demo)'), const ReviewLine(label: 'Business type', value: 'Student mess'), const ReviewLine(label: 'Address', value: 'Sector 62, Noida (demo)'), const ReviewLine(label: 'Verification', value: 'Not verified in this prototype'), const ReviewLine(label: 'Publication', value: 'Draft preview only'), PrimaryButton(label: 'Edit business profile', onPressed: () => showNotice(context, 'Connect this action to the saved provider profile editor; do not create a second business by default.'))]);
      default: return _detailScaffold(context, 'Terms & privacy', [const Text('Provider agreement and privacy documents need business-specific legal review before production publication.', style: TextStyle(color: muted, height: 1.5)), const SizedBox(height: 14), const SettingsRow(title: 'Provider terms', subtitle: 'Commission, settlement, cancellation and redemption rules', icon: Icons.description_outlined), const SettingsRow(title: 'Privacy policy', subtitle: 'Customer and provider data handling', icon: Icons.privacy_tip_outlined)]);
    }
  }
  Widget _detailScaffold(BuildContext context, String title, List<Widget> children) => ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [Row(children: [IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)), Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineMedium))]), const SizedBox(height: 8), ...children]);
  Future<void> _newOffer(BuildContext context) async { showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('New offer draft'), content: const Text('Configure code, discount type, eligible plans, start/end date, minimum order amount, usage limit and stacking rules in the live offer editor.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))])); }
}

// Reusable design-system components.
class BrandMark extends StatelessWidget { const BrandMark({super.key}); @override Widget build(BuildContext context) => const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.restaurant, color: orange, size: 42), SizedBox(width: 8), Text('MESS', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.6, color: ink))]); }
class FieldLabel extends StatelessWidget { const FieldLabel(this.label, {super.key}); final String label; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink))); }
class PrimaryButton extends StatelessWidget { const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon}); final String label; final VoidCallback onPressed; final IconData? icon; @override Widget build(BuildContext context) => SizedBox(height: 50, child: FilledButton.icon(onPressed: onPressed, icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18), label: Text(label), style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)))); }
class DividerWithLabel extends StatelessWidget { const DividerWithLabel({super.key, required this.label}); final String label; @override Widget build(BuildContext context) => Row(children: [const Expanded(child: Divider(color: line)), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(label, style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800))), const Expanded(child: Divider(color: line))]); }
class GoogleMark extends StatelessWidget { const GoogleMark({super.key}); @override Widget build(BuildContext context) => const Text('G', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4285F4), fontSize: 19)); }
class DemoBanner extends StatelessWidget { const DemoBanner({super.key, required this.text}); final String text; @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF0D8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0D7A9))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline, color: Color(0xFF976011), size: 18), const SizedBox(width: 9), Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF76521D), height: 1.4)))])); }
class SectionIntro extends StatelessWidget { const SectionIntro({super.key, required this.title, required this.subtitle}); final String title, subtitle; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: muted, height: 1.45))])); }
class SelectableTile extends StatelessWidget { const SelectableTile({super.key, required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap}); final String title, subtitle; final IconData icon; final bool selected; final VoidCallback onTap; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: selected ? const Color(0xFFFFF0D8) : card, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? orange : line, width: selected ? 1.4 : 1)), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: ink)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: muted, fontSize: 12, height: 1.3))])), const SizedBox(width: 8), Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? orange : muted)])))); }
class _TimeBox extends StatelessWidget { const _TimeBox({required this.label, required this.value}); final String label, value; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: const Border.fromBorderSide(BorderSide(color: line))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: muted, fontSize: 11)), const SizedBox(height: 3), Text(value, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12))])); }
class ReviewLine extends StatelessWidget { const ReviewLine({super.key, required this.label, required this.value}); final String label, value; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(label, style: const TextStyle(color: muted))), const SizedBox(width: 10), Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: ink, fontWeight: FontWeight.w700)))])); }
class PriceRow extends StatelessWidget { const PriceRow({super.key, required this.title, required this.price}); final String title, price; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(color: ink))), Text(price, style: const TextStyle(color: ink, fontWeight: FontWeight.w800))])); }
class RuleBullet extends StatelessWidget { const RuleBullet(this.text, {super.key}); final String text; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_outline, size: 17, color: green), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(color: muted, fontSize: 12, height: 1.35)))])); }
class MetricCard extends StatelessWidget { const MetricCard({super.key, required this.title, required this.value, required this.note, required this.icon, required this.tint}); final String title, value, note; final IconData icon; final Color tint; @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 19, color: ink)), const SizedBox(height: 12), Text(title, style: const TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 4), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 22))), const SizedBox(height: 4), Text(note, style: const TextStyle(color: muted, fontSize: 10))]))); }
class SectionHeader extends StatelessWidget { const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction}); final String title; final String? actionLabel; final VoidCallback? onAction; @override Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)), if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!))]); }
class SlotStatusTile extends StatelessWidget { const SlotStatusTile({super.key, required this.name, required this.time, required this.status, required this.count, required this.icon, required this.statusColor}); final String name, time, status, count; final IconData icon; final Color statusColor; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFFFF0D8), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: ink)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)), Text('$time · $count', style: const TextStyle(color: muted, fontSize: 11))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 12)), const SizedBox(height: 4), const Icon(Icons.chevron_right, color: muted, size: 18)])])))); }
class QuickAction extends StatelessWidget { const QuickAction({super.key, required this.icon, required this.title, required this.onTap}); final IconData icon; final String title; final VoidCallback onTap; @override Widget build(BuildContext context) => Material(color: card, borderRadius: BorderRadius.circular(14), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: line)), padding: const EdgeInsets.all(13), child: Row(children: [Icon(icon, color: orange), const SizedBox(width: 9), Expanded(child: Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12))), const Icon(Icons.arrow_forward_ios, size: 12, color: muted)])))); }
class ActivityRow extends StatelessWidget { const ActivityRow({super.key, required this.title, required this.detail, required this.status, required this.success}); final String title, detail, status; final bool success; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2), leading: Icon(success ? Icons.check_circle_outline : Icons.receipt_long_outlined, color: success ? green : orange), title: Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 13)), subtitle: Text(detail, style: const TextStyle(color: muted, fontSize: 11)), trailing: StatusTag(text: status, color: success ? green : orange)))); }
class StatusTag extends StatelessWidget { const StatusTag({super.key, required this.text, required this.color}); final String text; final Color color; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)), child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10))); }
class PlanPriceCard extends StatelessWidget { const PlanPriceCard({super.key, required this.duration, required this.price, required this.perMeal}); final String duration, price, perMeal; @override Widget build(BuildContext context) => Card(child: ListTile(leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFFFE8C5), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.calendar_month_outlined, color: ink)), title: Text(duration, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)), subtitle: Text(perMeal, style: const TextStyle(color: muted, fontSize: 12)), trailing: Text(price, style: const TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 14)))); }
class OfferInfoCard extends StatelessWidget { const OfferInfoCard({super.key, required this.code, required this.description, required this.status}); final String code, description, status; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(leading: const Icon(Icons.local_offer_outlined, color: orange), title: Text(code, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)), subtitle: Text(description, style: const TextStyle(color: muted, fontSize: 12)), trailing: StatusTag(text: status, color: muted)))); }
class MoreMenuTile extends StatelessWidget { const MoreMenuTile({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap}); final IconData icon; final String title, subtitle; final VoidCallback onTap; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(onTap: onTap, leading: Icon(icon, color: orange, size: 24), title: Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 14)), subtitle: Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)), trailing: const Icon(Icons.chevron_right, color: muted)))); }
class SettingsRow extends StatelessWidget { const SettingsRow({super.key, required this.title, required this.subtitle, required this.icon}); final String title, subtitle; final IconData icon; @override Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon, color: orange), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)), subtitle: Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)), trailing: const Icon(Icons.chevron_right, color: muted))); }
class MenuItemDraft { MenuItemDraft(this.name, this.rule, this.portion, this.price, this.enabled, {this.paid = false}); final String name, rule, portion; final int price; final bool enabled, paid; }
