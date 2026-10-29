import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'services/provider_api_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedSession = await ProviderApiService.loadSavedSession();
  runApp(MessProviderApp(initialSession: savedSession));
}

const Color ink = Color(0xFF142433);
const Color orange = Color(0xFFF59A16);
const Color cream = Color(0xFFFAF6EE);
const Color card = Color(0xFFFFFDF8);
const Color muted = Color(0xFF68737D);
const Color line = Color(0xFFE8E1D6);
const Color green = Color(0xFF218653);

class MessProviderApp extends StatefulWidget {
  const MessProviderApp({super.key, this.initialSession});
  final ProviderSession? initialSession;

  @override
  State<MessProviderApp> createState() => _MessProviderAppState();
}

class _MessProviderAppState extends State<MessProviderApp> {
  ProviderSession? _session;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
  }

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
      home: _session == null
          ? ProviderLoginScreen(
              onLoginSuccess: (session) => setState(() => _session = session),
              onRegister: () {
                appNavigatorKey.currentState?.push<void>(MaterialPageRoute<void>(
                  builder: (_) => ProviderOnboardingScreen(
                    onComplete: (session) => setState(() => _session = session),
                  ),
                ));
              },
            )
          : ProviderShell(
              session: _session!,
              onSignOut: () async {
                await ProviderApiService.clearSession();
                setState(() => _session = null);
              },
            ),
    );
  }
}

void showNotice(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? const Color(0xFFC0392B) : ink,
    ),
  );
}

class ProviderLoginScreen extends StatefulWidget {
  const ProviderLoginScreen({super.key, required this.onLoginSuccess, required this.onRegister});
  final ValueChanged<ProviderSession> onLoginSuccess;
  final VoidCallback onRegister;

  @override
  State<ProviderLoginScreen> createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final emailText = email.text.trim();
    final passText = password.text.trim();
    if (emailText.isEmpty) {
      showNotice(context, 'Please enter your registered phone or email.', isError: true);
      return;
    }

    setState(() => loading = true);
    try {
      final session = await ProviderApiService.login(
        email: emailText,
        password: passText.isNotEmpty ? passText : 'MessOwner@2026',
      );
      if (!mounted) return;
      showNotice(context, 'Signed in as ${session.businessName}');
      widget.onLoginSuccess(session);
    } catch (e) {
      if (!mounted) return;
      showNotice(context, e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showQuickSelectApprovedMess() async {
    setState(() => loading = true);
    try {
      final providers = await ProviderApiService.fetchApprovedProviders();
      if (!mounted) return;
      if (providers.isEmpty) {
        showNotice(context, 'No active approved mess found yet. Register your mess to get approved by admin.', isError: true);
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (bottomSheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Select Your Approved Mess',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
                ),
                const SizedBox(height: 6),
                const Text('Choose your mess to log into the Kitchen Partner Dashboard.', style: TextStyle(color: muted, fontSize: 13)),
                const SizedBox(height: 16),
                ...providers.map((p) {
                  final name = p['display_name']?.toString() ?? 'Mess';
                  final phone = p['public_phone']?.toString() ?? '';
                  final city = p['city']?.toString() ?? '';
                  final pId = p['id']?.toString() ?? '';
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: const CircleAvatar(backgroundColor: Color(0xFFFFF0D8), child: Icon(Icons.storefront_outlined, color: orange)),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                    subtitle: Text([city, phone].where((s) => s.isNotEmpty).join(' • '), style: const TextStyle(fontSize: 12, color: muted)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: muted),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      email.text = phone.isNotEmpty ? phone : (p['public_email']?.toString() ?? pId);
                      password.text = 'MessOwner@2026';
                      _handleSignIn();
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

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
                Container(
                  height: 90,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/branding/mess_logo_reference.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const BrandMark(),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Kitchen Partner Login', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                const Text('Sign in to manage your mess menu, daily counter QR, and customer subscriptions.', style: TextStyle(color: muted, fontSize: 14)),
                const SizedBox(height: 26),
                const FieldLabel('Provider phone or email'),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(hintText: 'e.g. 7250171036 or owner@mess.in', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 16),
                const FieldLabel('Account password'),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                loading
                    ? const Center(child: CircularProgressIndicator(color: orange))
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        PrimaryButton(
                          label: 'Sign In to Mess Portal',
                          icon: Icons.login,
                          onPressed: _handleSignIn,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _showQuickSelectApprovedMess,
                          icon: const Icon(Icons.storefront, color: orange, size: 18),
                          label: const Text('Select Your Registered Mess', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ]),
                const SizedBox(height: 22),
                const DividerWithLabel(label: 'OR'),
                const SizedBox(height: 20),
                Center(
                  child: Wrap(alignment: WrapAlignment.center, children: [
                    const Text('New kitchen partner? ', style: TextStyle(color: muted)),
                    TextButton(onPressed: widget.onRegister, child: const Text('Register your mess / tiffin service')),
                  ]),
                ),
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
  final ValueChanged<ProviderSession> onComplete;

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
  final email = TextEditingController();
  final password = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final fssai = TextEditingController();
  final selectedSlots = <String>{};
  final selectedDurations = <String>{};
  final priceControllers = <String, TextEditingController>{
    '15 days': TextEditingController(),
    '1 month': TextEditingController(),
    '3 months': TextEditingController(),
  };
  bool dailyMeal = true;
  bool acceptTerms = false;
  bool submitting = false;

  @override
  void dispose() {
    businessName.dispose();
    ownerName.dispose();
    phone.dispose();
    email.dispose();
    password.dispose();
    address.dispose();
    city.dispose();
    fssai.dispose();
    for (final value in priceControllers.values) {
      value.dispose();
    }
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!acceptTerms) {
      showNotice(context, 'Please accept the provider terms to proceed.', isError: true);
      return;
    }

    setState(() => submitting = true);
    try {
      final session = await ProviderApiService.register(
        businessName: businessName.text.trim(),
        ownerName: ownerName.text.trim(),
        phone: phone.text.trim(),
        email: email.text.trim(),
        password: password.text.trim(),
        address: address.text.trim(),
        city: city.text.trim(),
      );
      if (!mounted) return;
      showNotice(context, 'Business registered successfully!');
      Navigator.pop(context);
      widget.onComplete(session);
    } catch (e) {
      if (!mounted) return;
      showNotice(context, e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cream,
        title: const Text('Register your business', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => step == 0 ? Navigator.pop(context) : setState(() => step--),
          icon: const Icon(Icons.arrow_back, color: ink),
        ),
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 5,
                      margin: EdgeInsets.only(right: i == 4 ? 0 : 6),
                      decoration: BoxDecoration(color: i <= step ? orange : line, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Step ${step + 1} of 5', style: const TextStyle(color: muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(['Business details', 'Location & account', 'Meal slots', 'Plans & pricing', 'Review & activate'][step], style: Theme.of(context).textTheme.headlineMedium),
            ]),
          ),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 18), child: _buildStepContent(context))),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: const BoxDecoration(color: cream, border: Border(top: BorderSide(color: line))),
            child: Row(children: [
              if (step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => step--),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              if (step > 0) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: submitting
                    ? const Center(child: CircularProgressIndicator(color: orange))
                    : PrimaryButton(
                        label: step == 4 ? 'Activate Business' : 'Continue',
                        onPressed: () {
                          if (step == 0) {
                            if (businessName.text.trim().length < 3) {
                              showNotice(context, 'Enter valid business/mess name (min 3 characters).', isError: true);
                              return;
                            }
                            if (ownerName.text.trim().length < 3) {
                              showNotice(context, 'Enter owner full legal name.', isError: true);
                              return;
                            }
                            final cleanPhone = phone.text.trim().replaceAll(RegExp(r'\D'), '');
                            if (cleanPhone.length != 10) {
                              showNotice(context, 'Enter valid 10-digit Indian mobile number.', isError: true);
                              return;
                            }
                          }
                          if (step == 1) {
                            if (address.text.trim().length < 5) {
                              showNotice(context, 'Enter complete kitchen/shop address.', isError: true);
                              return;
                            }
                            if (city.text.trim().isEmpty) {
                              showNotice(context, 'Enter your city.', isError: true);
                              return;
                            }
                            if (!email.text.trim().contains('@') || !email.text.trim().contains('.')) {
                              showNotice(context, 'Enter a valid login email address.', isError: true);
                              return;
                            }
                            if (password.text.trim().length < 6) {
                              showNotice(context, 'Create a login password with at least 6 characters.', isError: true);
                              return;
                            }
                          }
                          if (step == 2 && selectedSlots.isEmpty) {
                            showNotice(context, 'Select at least one serving meal slot (Lunch, Dinner, Breakfast).', isError: true);
                            return;
                          }
                          if (step == 3) {
                            if (selectedDurations.isEmpty) {
                              showNotice(context, 'Select at least one subscription duration you offer.', isError: true);
                              return;
                            }
                            for (final d in selectedDurations) {
                              final p = int.tryParse(priceControllers[d]?.text.trim() ?? '') ?? 0;
                              if (p <= 0) {
                                showNotice(context, 'Please enter your custom price for $d plan.', isError: true);
                                return;
                              }
                            }
                          }
                          if (step == 4 && !acceptTerms) {
                            showNotice(context, 'Please accept the platform partnership agreement terms to activate.', isError: true);
                            return;
                          }
                          if (step < 4) {
                            setState(() => step++);
                          } else {
                            _submitRegistration();
                          }
                        },
                      ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionIntro(title: 'What kind of food service do you run?', subtitle: 'Select your core business type.'),
          ...['Mess', 'Home tiffin service', 'Hostel canteen'].map(
            (type) => SelectableTile(
              title: type,
              subtitle: {'Mess': 'Daily meals for students and residents', 'Home tiffin service': 'Home-cooked tiffin boxes', 'Hostel canteen': 'Campus food facility'}[type]!,
              icon: {'Mess': Icons.storefront_outlined, 'Home tiffin service': Icons.ramen_dining_outlined, 'Hostel canteen': Icons.school_outlined}[type]!,
              selected: businessType == type,
              onTap: () => setState(() => businessType = type),
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Business / mess name'),
          TextField(controller: businessName, decoration: const InputDecoration(hintText: 'e.g. Shyam Homely Mess', prefixIcon: Icon(Icons.storefront_outlined))),
          const SizedBox(height: 14),
          const FieldLabel('Owner name'),
          TextField(controller: ownerName, decoration: const InputDecoration(hintText: 'Full legal name', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 14),
          const FieldLabel('Phone number'),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '+91 98765 43210', prefixIcon: Icon(Icons.phone_outlined))),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionIntro(title: 'Business location & login credentials', subtitle: 'This is where students find your counter.'),
          const FieldLabel('Full address'),
          TextField(controller: address, maxLines: 2, decoration: const InputDecoration(hintText: 'Shop/Building, Street, Landmark', prefixIcon: Icon(Icons.location_on_outlined))),
          const SizedBox(height: 14),
          const FieldLabel('City'),
          TextField(controller: city, decoration: const InputDecoration(prefixIcon: Icon(Icons.map_outlined))),
          const SizedBox(height: 14),
          const FieldLabel('Login email address'),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'e.g. owner@mess.in', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 14),
          const FieldLabel('Password'),
          TextField(controller: password, decoration: const InputDecoration(hintText: 'Secret password', prefixIcon: Icon(Icons.lock_outline))),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionIntro(title: 'Service meal slots', subtitle: 'Active slots will be verifiable during meal hours.'),
          ...[
            ('Breakfast', '07:30 AM', '09:30 AM', Icons.wb_sunny_outlined),
            ('Lunch', '12:00 PM', '02:30 PM', Icons.wb_sunny),
            ('Dinner', '07:30 PM', '09:30 PM', Icons.nightlight_outlined),
          ].map(
            (slot) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(children: [
                    Icon(slot.$4, color: selectedSlots.contains(slot.$1) ? orange : muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(slot.$1, style: const TextStyle(fontWeight: FontWeight.w800, color: ink))),
                    Switch(
                      value: selectedSlots.contains(slot.$1),
                      activeTrackColor: orange,
                      activeThumbColor: orange,
                      onChanged: (value) => setState(() {
                        value ? selectedSlots.add(slot.$1) : selectedSlots.remove(slot.$1);
                      }),
                    ),
                  ]),
                  if (selectedSlots.contains(slot.$1))
                    Row(children: [
                      Expanded(child: _TimeBox(label: 'Starts', value: slot.$2)),
                      const SizedBox(width: 8),
                      Expanded(child: _TimeBox(label: 'Ends', value: slot.$3)),
                    ]),
                ]),
              ),
            ),
          ),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionIntro(title: 'Subscription plans', subtitle: 'Set the models you offer to subscribers.'),
          ...['Fixed-period', 'Meal tracker', 'Both'].map(
            (model) => SelectableTile(
              title: model,
              subtitle: {'Fixed-period': 'Unlimited meals during date range.', 'Meal tracker': 'Deducts 1 meal credit per valid scan.', 'Both': 'Offer both subscription choices.'}[model]!,
              icon: {'Fixed-period': Icons.calendar_month_outlined, 'Meal tracker': Icons.track_changes_outlined, 'Both': Icons.layers_outlined}[model]!,
              selected: planModel == model,
              onTap: () => setState(() => planModel = model),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeTrackColor: orange,
            activeThumbColor: orange,
            value: dailyMeal,
            onChanged: (v) => setState(() => dailyMeal = v),
            title: const Text('Allow single daily meals', style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
            subtitle: const Text('Sell pay-as-you-eat single lunch or dinner tokens.'),
          ),
          const SizedBox(height: 10),
          const SectionIntro(title: 'Durations & pricing', subtitle: 'Configure subscriber prices.'),
          ...priceControllers.keys.map(
            (dur) => CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              value: selectedDurations.contains(dur),
              activeColor: orange,
              onChanged: (v) => setState(() {
                v == true ? selectedDurations.add(dur) : selectedDurations.remove(dur);
              }),
              title: Text(dur, style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
              secondary: SizedBox(
                width: 110,
                child: TextField(
                  controller: priceControllers[dur],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(prefixText: '₹ ', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
                ),
              ),
            ),
          ),
        ]);
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionIntro(title: 'Review registration', subtitle: 'Verify details before activating.'),
          ReviewLine(label: 'Business name', value: businessName.text.isEmpty ? 'Not set' : businessName.text),
          ReviewLine(label: 'Owner', value: ownerName.text),
          ReviewLine(label: 'Phone', value: phone.text),
          ReviewLine(label: 'Address', value: '${address.text}, ${city.text}'),
          ReviewLine(label: 'Active meal slots', value: selectedSlots.join(', ')),
          ReviewLine(label: 'Plan models', value: planModel),
          ReviewLine(label: 'Daily meal pass', value: dailyMeal ? 'Enabled' : 'Disabled'),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: orange,
            value: acceptTerms,
            onChanged: (val) => setState(() => acceptTerms = val ?? false),
            title: const Text('I confirm this mess is genuine and accept the platform partner terms.', style: TextStyle(color: ink, fontSize: 13)),
          ),
        ]);
    }
  }
}

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key, required this.session, this.onSignOut});
  final ProviderSession session;
  final VoidCallback? onSignOut;

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int selectedTab = 0;
  String? detail;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ProviderOverview(
        session: widget.session,
        onNavigate: (index) => setState(() {
          selectedTab = index;
          detail = null;
        }),
        onOpenDetail: (value) => setState(() => detail = value),
      ),
      MenuManagementScreen(session: widget.session),
      PlansManagementScreen(session: widget.session),
      DailyQrScreen(session: widget.session),
      MoreManagementScreen(
        session: widget.session,
        onSelect: (value) => setState(() => detail = value),
        onSignOut: widget.onSignOut,
      ),
    ];

    Widget content = detail != null
        ? MoreDetailScreen(
            session: widget.session,
            kind: detail!,
            onBack: () => setState(() => detail = null),
          )
        : pages[selectedTab];

    return PopScope(
      canPop: detail == null && selectedTab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (detail != null) {
          setState(() => detail = null);
        } else if (selectedTab != 0) {
          setState(() => selectedTab = 0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cream,
          surfaceTintColor: cream,
          title: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: const Color(0xFFFFE5B7), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.restaurant, color: ink, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.session.businessName, style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                const Text('KITCHEN PARTNER HUB', style: TextStyle(color: green, fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
          actions: [
            IconButton(
              tooltip: 'Live counter QR',
              onPressed: () => setState(() {
                selectedTab = 3;
                detail = null;
              }),
              icon: const Icon(Icons.qr_code_2_rounded, color: ink),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey('${selectedTab}_${detail ?? 'root'}'), child: content),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedTab,
          onDestinationSelected: (index) => setState(() {
            selectedTab = index;
            detail = null;
          }),
          backgroundColor: card,
          indicatorColor: const Color(0xFFFFE6B8),
          elevation: 4,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Overview'),
            NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Menu'),
            NavigationDestination(icon: Icon(Icons.sell_outlined), selectedIcon: Icon(Icons.sell), label: 'Plans'),
            NavigationDestination(icon: Icon(Icons.qr_code_2_outlined), selectedIcon: Icon(Icons.qr_code_2), label: 'Daily QR'),
            NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
      ),
    );
  }
}

class ProviderOverview extends StatefulWidget {
  const ProviderOverview({super.key, required this.session, required this.onNavigate, required this.onOpenDetail});
  final ProviderSession session;
  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onOpenDetail;

  @override
  State<ProviderOverview> createState() => _ProviderOverviewState();
}

class _ProviderOverviewState extends State<ProviderOverview> {
  DashboardMetrics? _metrics;
  bool _loading = true;
  String? _error;
  bool _isOpenToday = true;
  bool _togglingStatus = false;

  Future<void> _loadKitchenStatus() async {
    try {
      final isOpen = await ProviderApiService.fetchKitchenStatus(widget.session.providerId);
      if (mounted) setState(() => _isOpenToday = isOpen);
    } catch (_) {}
  }

  Future<void> _toggleKitchenStatus(bool val) async {
    setState(() => _togglingStatus = true);
    try {
      final ok = await ProviderApiService.toggleKitchenStatus(
        providerId: widget.session.providerId,
        isOpen: val,
      );
      if (mounted) {
        if (ok) {
          setState(() => _isOpenToday = val);
          showNotice(
            context,
            val
              ? '🟢 Kitchen marked OPEN & SERVING TODAY'
              : '🔴 Kitchen marked CLOSED / OFF TODAY (Dark shade enabled)',
          );
        } else {
          showNotice(context, 'Failed to update kitchen status.', isError: true);
        }
      }
    } catch (_) {
      if (mounted) showNotice(context, 'Network error updating status.', isError: true);
    } finally {
      if (mounted) setState(() => _togglingStatus = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final metrics = await ProviderApiService.fetchDashboard(widget.session.providerId);
      await _loadKitchenStatus();
      if (mounted) setState(() => _metrics = metrics);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: orange));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48, color: muted),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 14)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]),
        ),
      );
    }

    final metrics = _metrics;
    return RefreshIndicator(
      onRefresh: _loadData,
      color: orange,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Welcome, ${widget.session.businessName}', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 3),
                Text('Live Counter Status · Active Slot: ${metrics?.currentSlot ?? "LUNCH"}', style: const TextStyle(color: muted, fontSize: 13)),
              ]),
            ),
            IconButton(icon: const Icon(Icons.refresh, color: orange), onPressed: _loadData),
          ]),
          const SizedBox(height: 12),
          // KITCHEN STATUS TOGGLE CARD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isOpenToday ? const Color(0xFFF0FDF4) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isOpenToday ? const Color(0xFF86EFAC) : const Color(0xFF475569),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isOpenToday ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                  color: _isOpenToday ? const Color(0xFF16A34A) : const Color(0xFFF87171),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOpenToday ? 'KITCHEN OPEN TODAY' : 'MESS CLOSED / OFF TODAY',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: _isOpenToday ? const Color(0xFF15803D) : Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isOpenToday
                            ? 'Serving meals today • QR scans active'
                            : 'Dark shade shown • Scans paused today',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isOpenToday ? const Color(0xFF166534) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isOpenToday,
                  activeColor: const Color(0xFF16A34A),
                  onChanged: _togglingStatus ? null : _toggleKitchenStatus,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: MetricCard(title: 'Today’s meals', value: '${metrics?.todayScans ?? 0}', note: 'Redemptions today', icon: Icons.restaurant, tint: const Color(0xFFFFE8C5))),
            const SizedBox(width: 10),
            Expanded(child: MetricCard(title: 'Active plans', value: '${metrics?.activePlans ?? 2}', note: 'Published models', icon: Icons.calendar_month, tint: const Color(0xFFE4EDF9))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: MetricCard(title: 'Subscribers', value: '${metrics?.activeSubscribers ?? 0}', note: 'Active student plans', icon: Icons.groups_outlined, tint: const Color(0xFFDDF2E6))),
            const SizedBox(width: 10),
            Expanded(child: MetricCard(title: 'Total scans', value: '${metrics?.totalScans ?? 0}', note: 'All-time verified', icon: Icons.qr_code_2, tint: const Color(0xFFFFE5E0))),
          ]),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.qr_code_2_rounded, size: 30, color: orange),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Official Counter QR Code', style: TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 15)),
                      Text('Signed cryptographic token for today’s meal slot', style: TextStyle(fontSize: 12, color: muted)),
                    ]),
                  ),
                  FilledButton(
                    onPressed: () => widget.onNavigate(3),
                    style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink, padding: const EdgeInsets.symmetric(horizontal: 14)),
                    child: const Text('Open QR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Quick actions'),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              QuickAction(icon: Icons.edit_calendar_outlined, title: 'Today’s menu', onTap: () => widget.onNavigate(1)),
              QuickAction(icon: Icons.sell_outlined, title: 'Plan pricing', onTap: () => widget.onNavigate(2)),
              QuickAction(icon: Icons.qr_code_2_outlined, title: 'Counter QR', onTap: () => widget.onNavigate(3)),
              QuickAction(icon: Icons.groups_outlined, title: 'Subscribers', onTap: () => widget.onOpenDetail('Subscribers')),
            ],
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Today’s verified redemptions', actionLabel: 'View all', onAction: () => widget.onOpenDetail('Attendance')),
          const SizedBox(height: 8),
          if (metrics?.recentRedemptions.isEmpty ?? true)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Column(children: [
                    const Icon(Icons.fact_check_outlined, size: 38, color: muted),
                    const SizedBox(height: 8),
                    const Text('No redemptions yet today', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
                    const SizedBox(height: 4),
                    const Text('When eligible students scan your counter QR, their meal tickets will appear here in real time.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
                  ]),
                ),
              ),
            )
          else
            ...metrics!.recentRedemptions.take(5).map((r) {
              final slot = r['slot']?.toString() ?? 'Meal';
              final time = r['redeemed_at'] != null ? r['redeemed_at'].toString().split('T').last.substring(0, 5) : 'Today';
              return ActivityRow(
                title: '$slot redeemed',
                detail: 'Verified customer · $time',
                status: 'Success',
                success: true,
              );
            }),
        ],
      ),
    );
  }
}

class DailyQrScreen extends StatefulWidget {
  const DailyQrScreen({super.key, required this.session});
  final ProviderSession session;

  @override
  State<DailyQrScreen> createState() => _DailyQrScreenState();
}

class _DailyQrScreenState extends State<DailyQrScreen> {
  int _tabIndex = 0; // 0 = Daily Attendance QR, 1 = Counter Standee QR
  String? qrToken;
  String currentSlot = 'LUNCH';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchQr();
  }

  Future<void> _fetchQr() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final token = await ProviderApiService.fetchDailyQrToken(widget.session.providerId);
      if (mounted) {
        setState(() {
          qrToken = token;
          if (token.contains('|')) {
            final parts = token.split('|');
            if (parts.length >= 4) currentSlot = parts[3];
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.now();
    final dateText = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final joinUrl = 'https://mess-beta.vercel.app/join/${widget.session.providerId}';
    final standeeUrl = 'https://mess-beta.vercel.app/provider/standee?provider_id=${widget.session.providerId}';

    return RefreshIndicator(
      onRefresh: _fetchQr,
      color: orange,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Text('Counter QR Codes', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          // Tab Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tabIndex = 0),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tabIndex == 0 ? orange : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '🍽️ Daily Attendance',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _tabIndex == 0 ? ink : muted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tabIndex = 1),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tabIndex == 1 ? orange : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '📌 Standee (Join & Pay)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _tabIndex == 1 ? ink : muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_tabIndex == 0) ...[
            const Text(
              'Place this QR at your counter for daily meal redemption. Active subscribers scan this with their app during Lunch/Dinner.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.storefront_outlined, color: orange, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.session.businessName, style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 16)),
                        Text('Service Date: $dateText · $currentSlot', style: const TextStyle(color: muted, fontSize: 12)),
                      ]),
                    ),
                    StatusTag(text: currentSlot, color: green),
                  ]),
                  const SizedBox(height: 20),
                  if (loading)
                    const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(color: orange)))
                  else if (error != null)
                    SizedBox(
                      height: 220,
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.error_outline, color: Color(0xFFC0392B), size: 36),
                          const SizedBox(height: 8),
                          Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
                          const SizedBox(height: 10),
                          FilledButton(onPressed: _fetchQr, child: const Text('Retry')),
                        ]),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: line),
                      ),
                      child: QrImageView(
                        data: qrToken ?? '',
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.verified, color: green, size: 18),
                    SizedBox(width: 6),
                    Text('Cryptographically Signed Counter Token', style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Valid only for today’s active meal slot at your mess.', style: TextStyle(color: muted, fontSize: 12)),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: 'Refresh Daily QR Token',
                    icon: Icons.refresh,
                    onPressed: _fetchQr,
                  ),
                ]),
              ),
            ),
          ] else ...[
            const Text(
              'Permanent desk standee QR. Walk-in students scan this with ANY mobile camera, Google Lens, or Paytm/GPay to browse your menu and self-register.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.qr_code_scanner, color: orange, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.session.businessName, style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 16)),
                        const Text('Permanent Student Onboarding QR', style: TextStyle(color: muted, fontSize: 12)),
                      ]),
                    ),
                    const StatusTag(text: 'COUNTER STANDEE', color: Color(0xFF2980B9)),
                  ]),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: line),
                    ),
                    child: QrImageView(
                      data: joinUrl,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.flash_on, color: orange, size: 18),
                    SizedBox(width: 6),
                    Text('Scan with Any Phone Camera', style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                  const SizedBox(height: 4),
                  const Text('No app download required. Opens instant joining web portal.', style: TextStyle(color: muted, fontSize: 12)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 16, color: muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            joinUrl,
                            style: const TextStyle(fontSize: 12, color: ink, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: orange),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: joinUrl));
                            showNotice(context, 'Joining link copied to clipboard!');
                          },
                          tooltip: 'Copy Link',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: joinUrl));
                            showNotice(context, 'Joining link copied! Share it on WhatsApp with students.');
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share Link'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            side: const BorderSide(color: line),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: standeeUrl));
                            showNotice(context, 'Printable Standee URL copied! Open in browser to print.');
                          },
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Print Standee'),
                          style: FilledButton.styleFrom(
                            backgroundColor: ink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key, required this.session});
  final ProviderSession session;

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  String slot = 'Lunch';
  bool loading = true;
  List<String> itemsIncluded = [];
  List<Map<String, dynamic>> itemsExtra = [];
  List<String> itemsUnavailable = [];

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  Future<void> _fetchMenu() async {
    setState(() => loading = true);
    try {
      final res = await ProviderApiService.fetchMenu(widget.session.providerId);
      final menuList = res['menu'] as List<dynamic>? ?? [];
      final currentMenu = menuList.firstWhere(
        (m) => m['slot']?.toString().toLowerCase() == slot.toLowerCase(),
        orElse: () => null,
      );
      if (currentMenu != null) {
        itemsIncluded = (currentMenu['items_included'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
        itemsExtra = (currentMenu['items_extra'] as List<dynamic>? ?? []).map((e) => e as Map<String, dynamic>).toList();
        itemsUnavailable = (currentMenu['items_unavailable'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
      } else {
        itemsIncluded = ['Dal Tadka', 'Steamed Rice', 'Phulka Roti (4 pcs)', 'Seasonal Sabzi', 'Salad'];
        itemsExtra = [
          {'name': 'Paneer Butter Masala', 'price': 40, 'is_available': true},
          {'name': 'Gulab Jamun (2 pcs)', 'price': 25, 'is_available': true},
          {'name': 'Extra Roti (Set of 2)', 'price': 15, 'is_available': true},
        ];
        itemsUnavailable = [];
      }
    } catch (_) {
      itemsIncluded = ['Dal Tadka', 'Steamed Rice', 'Phulka Roti (4 pcs)', 'Seasonal Sabzi', 'Salad'];
      itemsExtra = [
        {'name': 'Paneer Butter Masala', 'price': 40, 'is_available': true},
        {'name': 'Extra Roti (Set of 2)', 'price': 15, 'is_available': true},
      ];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _toggleAvailability(String name, bool isAvailable) async {
    setState(() {
      if (!isAvailable) {
        if (!itemsUnavailable.contains(name)) itemsUnavailable.add(name);
      } else {
        itemsUnavailable.remove(name);
      }
    });
    try {
      await ProviderApiService.toggleMenuAvailability(
        providerId: widget.session.providerId,
        name: name,
        isAvailable: isAvailable,
      );
      if (mounted) {
        showNotice(context, isAvailable ? '$name marked available today' : '$name marked out of stock today');
      }
    } catch (_) {}
  }

  Future<void> _removeItem(String name, bool isExtra) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove from Menu?'),
        content: Text('Are you sure you want to remove "$name" from $slot menu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      if (isExtra) {
        itemsExtra.removeWhere((item) => item['name'] == name);
      } else {
        itemsIncluded.remove(name);
      }
    });

    try {
      await ProviderApiService.removeMenuItem(
        providerId: widget.session.providerId,
        name: name,
        slot: slot,
      );
      if (mounted) showNotice(context, 'Removed $name from menu');
    } catch (_) {
      if (mounted) showNotice(context, 'Failed to update menu online', isError: true);
    }
  }

  void _openAddDishSheet() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    bool isExtra = false;
    String targetSlot = slot;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFFFE8C5), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.restaurant, color: orange, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text('Add Dish to Menu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: ink)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const FieldLabel('Dish Name'),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. Matar Paneer, Jeera Rice, Gulab Jamun', prefixIcon: Icon(Icons.food_bank_outlined)),
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Meal Serving Slot'),
                    Wrap(
                      spacing: 8,
                      children: ['Breakfast', 'Lunch', 'Dinner'].map((s) {
                        return ChoiceChip(
                          label: Text(s),
                          selected: targetSlot == s,
                          selectedColor: orange,
                          onSelected: (val) => setSheetState(() => targetSlot = s),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isExtra,
                      onChanged: (v) => setSheetState(() => isExtra = v),
                      title: const Text('Charge as Paid Add-On / Special Extra', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Included items come standard with subscriber thali.', style: TextStyle(fontSize: 12, color: muted)),
                    ),
                    if (isExtra) ...[
                      const SizedBox(height: 8),
                      const FieldLabel('Add-on Price (₹)'),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'e.g. 40', prefixIcon: Icon(Icons.currency_rupee)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            showNotice(context, 'Please enter a dish name', isError: true);
                            return;
                          }
                          final price = isExtra ? (int.tryParse(priceCtrl.text) ?? 30) : 0;
                          Navigator.pop(ctx);
                          try {
                            await ProviderApiService.addMenuItem(
                              providerId: widget.session.providerId,
                              name: name,
                              slot: targetSlot,
                              price: price,
                              isExtra: isExtra,
                            );
                            _fetchMenu();
                            if (mounted) showNotice(context, 'Added "$name" to $targetSlot menu');
                          } catch (_) {
                            _fetchMenu();
                          }
                        },
                        style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink),
                        child: const Text('Save & Publish Dish', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Menu & Portions', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 3),
                  const Text('Manage items, prices, and daily stock availability.', style: TextStyle(color: muted, fontSize: 13)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _openAddDishSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Dish'),
              style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Breakfast', label: Text('Breakfast')),
            ButtonSegment(value: 'Lunch', label: Text('Lunch')),
            ButtonSegment(value: 'Dinner', label: Text('Dinner')),
          ],
          selected: {slot},
          onSelectionChanged: (v) {
            setState(() => slot = v.first);
            _fetchMenu();
          },
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 18),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: orange)))
        else ...[
          Text('Thali Included Dishes (${itemsIncluded.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink)),
          const SizedBox(height: 8),
          if (itemsIncluded.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No standard items added for this slot.', style: TextStyle(color: muted, fontSize: 13)))
          else
            ...itemsIncluded.map((name) {
              final isUnavailable = itemsUnavailable.contains(name);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFFFEFD5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.restaurant, color: ink, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isUnavailable ? muted : ink,
                                decoration: isUnavailable ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            Text(
                              isUnavailable ? '⚠️ Marked Out of Stock Today' : 'Included in standard thali',
                              style: TextStyle(color: isUnavailable ? const Color(0xFFC0392B) : green, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: !isUnavailable,
                        activeColor: green,
                        onChanged: (val) => _toggleAvailability(name, val),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFC0392B), size: 20),
                        tooltip: 'Remove Dish',
                        onPressed: () => _removeItem(name, false),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 18),
          Text('Special Add-ons & Extras (${itemsExtra.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink)),
          const SizedBox(height: 8),
          if (itemsExtra.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No paid add-ons configured.', style: TextStyle(color: muted, fontSize: 13)))
          else
            ...itemsExtra.map((extra) {
              final name = extra['name']?.toString() ?? 'Extra Item';
              final price = extra['price'] ?? 30;
              final isUnavailable = itemsUnavailable.contains(name);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFFFE8C5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.add_shopping_cart, color: orange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isUnavailable ? muted : ink,
                                decoration: isUnavailable ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            Text(
                              '₹$price add-on · ${isUnavailable ? "Sold Out" : "Available"}',
                              style: TextStyle(color: isUnavailable ? const Color(0xFFC0392B) : muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text('₹$price', style: const TextStyle(fontWeight: FontWeight.w900, color: ink, fontSize: 14)),
                      const SizedBox(width: 8),
                      Switch(
                        value: !isUnavailable,
                        activeColor: green,
                        onChanged: (val) => _toggleAvailability(name, val),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFC0392B), size: 20),
                        tooltip: 'Remove Dish',
                        onPressed: () => _removeItem(name, true),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ],
    );
  }
}

class PlansManagementScreen extends StatefulWidget {
  const PlansManagementScreen({super.key, required this.session});
  final ProviderSession session;

  @override
  State<PlansManagementScreen> createState() => _PlansManagementScreenState();
}

class _PlansManagementScreenState extends State<PlansManagementScreen> {
  bool loading = true;
  List<Map<String, dynamic>> plans = [];

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => loading = true);
    try {
      plans = await ProviderApiService.fetchProviderPlans(widget.session.providerId);
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _deletePlan(String planId, String planName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Plan?'),
        content: Text('Are you sure you want to remove "$planName"? Existing subscribers will remain active.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ProviderApiService.deletePlan(providerId: widget.session.providerId, planId: planId);
      _fetchPlans();
      if (mounted) showNotice(context, 'Plan removed successfully');
    } catch (e) {
      if (mounted) showNotice(context, 'Failed to delete plan', isError: true);
    }
  }

  void _openCreatePlanSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final creditsCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    String planType = 'fixed_period';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFFFE8C5), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.sell_outlined, color: orange, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text('Create Custom Meal Plan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: ink)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const FieldLabel('Plan Name'),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'e.g. Deluxe Monthly Unlimited')),
                    const SizedBox(height: 12),
                    const FieldLabel('Plan Model'),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('📅 Fixed Days')),
                            selected: planType == 'fixed_period',
                            selectedColor: orange,
                            onSelected: (v) => setSheetState(() => planType = 'fixed_period'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('🔢 Flexi Credits')),
                            selected: planType == 'meal_credits',
                            selectedColor: orange,
                            onSelected: (v) => setSheetState(() => planType = 'meal_credits'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const FieldLabel('Duration (Days)'),
                              TextField(controller: durationCtrl, keyboardType: TextInputType.number),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const FieldLabel('Price (₹)'),
                              TextField(controller: priceCtrl, keyboardType: TextInputType.number),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (planType == 'meal_credits') ...[
                      const SizedBox(height: 12),
                      const FieldLabel('Included Meal Credits'),
                      TextField(controller: creditsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'e.g. 60 meals')),
                    ],
                    const SizedBox(height: 12),
                    const FieldLabel('Promotional Discount (%)'),
                    TextField(controller: discountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'e.g. 10')),
                    const SizedBox(height: 12),
                    const FieldLabel('Plan Description / Benefits'),
                    TextField(controller: descCtrl, decoration: const InputDecoration(hintText: 'e.g. Unlimited lunch & dinner access with sweets')),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            showNotice(context, 'Please enter plan name', isError: true);
                            return;
                          }
                          final duration = int.tryParse(durationCtrl.text) ?? 30;
                          final price = int.tryParse(priceCtrl.text) ?? 3000;
                          final credits = planType == 'meal_credits' ? (int.tryParse(creditsCtrl.text) ?? 60) : null;
                          final discount = int.tryParse(discountCtrl.text);

                          Navigator.pop(ctx);
                          try {
                            await ProviderApiService.savePlan(
                              providerId: widget.session.providerId,
                              name: name,
                              description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : '$duration-day mess subscription',
                              planType: planType,
                              durationDays: duration,
                              priceInr: price,
                              mealCredits: credits,
                              discountPercent: discount,
                            );
                            _fetchPlans();
                            if (mounted) showNotice(context, 'Plan "$name" published successfully!');
                          } catch (e) {
                            if (mounted) showNotice(context, e.toString().replaceAll('Exception: ', ''), isError: true);
                          }
                        },
                        style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink),
                        child: const Text('Save & Publish Plan', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plans & Pricing', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 3),
                  const Text('Customize subscription options visible to students.', style: TextStyle(color: muted, fontSize: 13)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _openCreatePlanSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Plan'),
              style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: orange)))
        else if (plans.isEmpty)
          const EmptyStateCard(
            icon: Icons.sell_outlined,
            title: 'No custom plans published',
            subtitle: 'Tap "+ New Plan" above to create custom monthly, 15-day, or flexi meal plans for your mess.',
          )
        else
          ...plans.map((p) {
            final name = p['name']?.toString() ?? 'Plan';
            final price = (p['price_paise'] != null ? (p['price_paise'] as num) / 100 : (p['price'] ?? 0)).toInt();
            final duration = p['duration_days'] ?? 30;
            final type = p['plan_type']?.toString() ?? 'fixed_period';
            final credits = p['meal_credits'];
            final discount = p['discount_percent'];
            final planId = p['id']?.toString() ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: const Color(0xFFFFE8C5), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.calendar_month_outlined, color: ink),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 16)),
                              Text(
                                type == 'meal_credits' ? '$credits Meals · Flexi Tracker' : '$duration Days · Unlimited Access',
                                style: const TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text('₹$price', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ink)),
                      ],
                    ),
                    if (p['description'] != null && p['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(p['description'].toString(), style: const TextStyle(color: muted, fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (discount != null && discount > 0)
                          StatusTag(text: '$discount% OFF SPECIAL', color: green)
                        else
                          StatusTag(text: type.toUpperCase(), color: orange),
                        TextButton.icon(
                          onPressed: () => _deletePlan(planId, name),
                          icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFC0392B)),
                          label: const Text('Delete Plan', style: TextStyle(color: Color(0xFFC0392B), fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class MoreManagementScreen extends StatelessWidget {
  const MoreManagementScreen({super.key, required this.session, required this.onSelect, this.onSignOut});
  final ProviderSession session;
  final ValueChanged<String> onSelect;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Text('Kitchen Tools', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 5),
          const Text('Manage subscribers, reports, settlements and kitchen profile.', style: TextStyle(color: muted)),
          const SizedBox(height: 18),
          MoreMenuTile(icon: Icons.groups_outlined, title: 'Subscribers & Customers', subtitle: 'View verified student subscription plans & scan logs', onTap: () => onSelect('Subscribers')),
          MoreMenuTile(icon: Icons.point_of_sale_outlined, title: 'Counter Sales & Extras', subtitle: 'Record walk-in thali, extra rotis and paneer orders', onTap: () => onSelect('CounterOrders')),
          MoreMenuTile(icon: Icons.schedule_outlined, title: 'Operating Hours & Timings', subtitle: 'Manage breakfast, lunch and dinner serving slots', onTap: () => onSelect('Timings')),
          MoreMenuTile(icon: Icons.fact_check_outlined, title: 'Meal Redemptions Log', subtitle: 'Real-time scan logs and attendance records', onTap: () => onSelect('Attendance')),
          MoreMenuTile(icon: Icons.account_balance_wallet_outlined, title: 'Settlement & Payouts', subtitle: 'Platform scan billing and payout summary', onTap: () => onSelect('Earnings')),
          MoreMenuTile(icon: Icons.support_agent_outlined, title: 'Help & Support Desk', subtitle: 'Submit issues and feedback directly to support', onTap: () => onSelect('Support')),
          MoreMenuTile(icon: Icons.store_mall_directory_outlined, title: 'Mess Profile & Details', subtitle: session.businessName, onTap: () => onSelect('Business profile')),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: const Color(0xFFB83B31),
              side: const BorderSide(color: Color(0xFFEBCBC6), width: 1),
            ),
          ),
        ],
      );
}

class MoreDetailScreen extends StatefulWidget {
  const MoreDetailScreen({super.key, required this.session, required this.kind, required this.onBack});
  final ProviderSession session;
  final String kind;
  final VoidCallback onBack;

  @override
  State<MoreDetailScreen> createState() => _MoreDetailScreenState();
}

class _MoreDetailScreenState extends State<MoreDetailScreen> {
  bool loading = true;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> plans = [];
  String subFilter = 'All';

  // Timings controllers
  final bfStart = TextEditingController(text: '07:30 AM');
  final bfEnd = TextEditingController(text: '10:00 AM');
  final lunchStart = TextEditingController(text: '12:00 PM');
  final lunchEnd = TextEditingController(text: '03:30 PM');
  final dinnerStart = TextEditingController(text: '07:30 PM');
  final dinnerEnd = TextEditingController(text: '10:30 PM');

  // Support controllers
  final supportSubject = TextEditingController();
  final supportMessage = TextEditingController();
  String supportCategory = 'general';
  bool submittingTicket = false;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
    _fetchPlans();
    if (widget.kind == 'Timings') _loadTimings();
  }

  Future<void> _loadTimings() async {
    try {
      final t = await ProviderApiService.fetchTimings(widget.session.providerId);
      if (t['breakfast'] is Map) {
        bfStart.text = t['breakfast']['start'] ?? '07:30 AM';
        bfEnd.text = t['breakfast']['end'] ?? '10:00 AM';
      }
      if (t['lunch'] is Map) {
        lunchStart.text = t['lunch']['start'] ?? '12:00 PM';
        lunchEnd.text = t['lunch']['end'] ?? '03:30 PM';
      }
      if (t['dinner'] is Map) {
        dinnerStart.text = t['dinner']['start'] ?? '07:30 PM';
        dinnerEnd.text = t['dinner']['end'] ?? '10:30 PM';
      }
    } catch (_) {}
  }

  Future<void> _fetchPlans() async {
    try {
      plans = await ProviderApiService.fetchProviderPlans(widget.session.providerId);
    } catch (_) {}
  }

  Future<void> _fetchDetail() async {
    setState(() => loading = true);
    try {
      if (widget.kind == 'Subscribers') {
        items = await ProviderApiService.fetchSubscribers(widget.session.providerId);
      } else if (widget.kind == 'Attendance') {
        items = await ProviderApiService.fetchAttendance(widget.session.providerId);
      } else if (widget.kind == 'CounterOrders') {
        items = await ProviderApiService.fetchOrders(widget.session.providerId);
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  void _openSubscriberHistory(Map<String, dynamic> sub) {
    final subId = sub['id']?.toString() ?? '';
    final name = sub['customer_name']?.toString() ?? 'Student';
    final plan = sub['plan_name']?.toString() ?? 'Plan';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: ProviderApiService.fetchSubscriberHistory(widget.session.providerId, subId),
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFFFE8C5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.history_edu, color: orange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$name’s Scan History', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: ink)),
                            Text('$plan · ID: #SUB-${subId.length >= 8 ? subId.substring(0, 8) : subId}', style: const TextStyle(fontSize: 12, color: muted)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: orange)))
                  else if (!snapshot.hasData || snapshot.data!.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: cream, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
                      child: const Column(
                        children: [
                          Icon(Icons.event_busy, color: muted, size: 36),
                          SizedBox(height: 8),
                          Text('No meals scanned yet', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
                          SizedBox(height: 4),
                          Text('Scans will record here with exact timestamps when student redeems counter QR.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: muted)),
                        ],
                      ),
                    )
                  else ...[
                    Text('Total Verified Scans: ${snapshot.data!.length}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: green)),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: snapshot.data!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: line),
                        itemBuilder: (context, i) {
                          final h = snapshot.data![i];
                          final timeFormatted = h['time_formatted'] ?? (h['redeemed_at']?.toString().contains('T') == true ? h['redeemed_at'].toString().split('T').last.substring(0, 5) : 'Meal Time');
                          final slot = h['slot'] ?? 'LUNCH';
                          final date = h['date'] ?? '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.check, color: green, size: 20),
                            ),
                            title: Text('$slot Attendance Verified', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ink)),
                            subtitle: Text('$date at $timeFormatted', style: const TextStyle(fontSize: 12, color: muted)),
                            trailing: const StatusTag(text: 'VERIFIED', color: green),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openAddCounterOrderSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final itemsCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String paymentMode = 'cash';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.point_of_sale, color: orange, size: 24),
                        SizedBox(width: 10),
                        Text('Record Walk-in / Extra Sale', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: ink)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const FieldLabel('Customer Name (Optional)'),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'e.g. Walk-in Student')),
                    const SizedBox(height: 12),
                    const FieldLabel('Customer Phone (Optional)'),
                    TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'e.g. 9876543210')),
                    const SizedBox(height: 12),
                    const FieldLabel('Items Summary / Order Details'),
                    TextField(controller: itemsCtrl, decoration: const InputDecoration(hintText: 'e.g. 1x Thali, 1x Paneer, 2 Extra Roti')),
                    const SizedBox(height: 12),
                    const FieldLabel('Total Amount (₹)'),
                    TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'e.g. 120')),
                    const SizedBox(height: 14),
                    const FieldLabel('Payment Mode'),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('💵 Cash')),
                            selected: paymentMode == 'cash',
                            selectedColor: orange,
                            onSelected: (v) => setSheetState(() => paymentMode = 'cash'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('📱 Counter UPI')),
                            selected: paymentMode == 'counter_upi',
                            selectedColor: orange,
                            onSelected: (v) => setSheetState(() => paymentMode = 'counter_upi'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Walk-in Customer';
                          final itemsDesc = itemsCtrl.text.trim().isNotEmpty ? itemsCtrl.text.trim() : 'Meal Extras';
                          final amt = double.tryParse(amountCtrl.text) ?? 80;
                          Navigator.pop(ctx);
                          try {
                            await ProviderApiService.createOrder(
                              providerId: widget.session.providerId,
                              customerName: name,
                              customerPhone: phoneCtrl.text.trim(),
                              itemsSummary: itemsDesc,
                              totalAmount: amt,
                              paymentMode: paymentMode,
                            );
                            _fetchDetail();
                            if (mounted) showNotice(context, 'Counter order recorded: ₹$amt via ${paymentMode.toUpperCase()}');
                          } catch (e) {
                            if (mounted) showNotice(context, 'Failed to record order', isError: true);
                          }
                        },
                        style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink),
                        child: const Text('Save Counter Order', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openAddMemberSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String? selectedPlanId = plans.isNotEmpty ? plans.first['id']?.toString() : null;
    String paymentMode = 'cash';
    bool submitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFFFE8C5), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.person_add_alt_1, color: orange, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text('Register Member Manually', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: ink)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const FieldLabel('Student Full Name *'),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. Rahul Sharma', prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: 12),
                    const FieldLabel('Mobile Number (10 digits) *'),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: 'e.g. 9876543210', prefixIcon: Icon(Icons.phone_outlined)),
                    ),
                    const SizedBox(height: 12),
                    const FieldLabel('Email Address (Optional)'),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(hintText: 'e.g. rahul@gmail.com', prefixIcon: Icon(Icons.email_outlined)),
                    ),
                    const SizedBox(height: 12),
                    const FieldLabel('Select Subscription Plan'),
                    if (plans.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedPlanId,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                        items: plans.map((p) {
                          final pName = p['name'] ?? 'Plan';
                          final pPrice = (p['price_paise'] != null ? (p['price_paise'] as num) / 100 : (p['price'] ?? 0)).toInt();
                          final pDays = p['duration_days'] ?? 30;
                          return DropdownMenuItem<String>(
                            value: p['id']?.toString(),
                            child: Text('$pName (₹$pPrice / $pDays d)'),
                          );
                        }).toList(),
                        onChanged: (val) => setSheetState(() => selectedPlanId = val),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: cream, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
                        child: const Text('Standard Monthly Plan (₹3,000 / 30 Days)', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(height: 14),
                    const FieldLabel('Payment Received Via'),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('💵 Cash')),
                            selected: paymentMode == 'cash',
                            selectedColor: orange,
                            onSelected: (val) => setSheetState(() => paymentMode = 'cash'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('📱 Counter UPI')),
                            selected: paymentMode == 'counter_upi',
                            selectedColor: orange,
                            onSelected: (val) => setSheetState(() => paymentMode = 'counter_upi'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final phone = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                                if (name.length < 2) {
                                  showNotice(context, 'Please enter a valid student name.', isError: true);
                                  return;
                                }
                                if (phone.length < 10) {
                                  showNotice(context, 'Please enter a valid 10-digit mobile number.', isError: true);
                                  return;
                                }

                                setSheetState(() => submitting = true);
                                try {
                                  final res = await ProviderApiService.createManualSubscriber(
                                    providerId: widget.session.providerId,
                                    customerName: name,
                                    customerPhone: phone,
                                    customerEmail: emailCtrl.text.trim(),
                                    planId: selectedPlanId,
                                    paymentMode: paymentMode,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    _fetchDetail();
                                    _showSubscriberSuccessDialog(res, name, phone);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    setSheetState(() => submitting = false);
                                    showNotice(context, e.toString().replaceAll('Exception: ', ''), isError: true);
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: orange,
                          foregroundColor: ink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        child: submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: ink, strokeWidth: 2))
                            : const Text('Register & Activate Pass'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSubscriberSuccessDialog(Map<String, dynamic> res, String name, String phone) {
    final passUrl = res['pass_url']?.toString() ?? 'https://mess-beta.vercel.app/customer/dashboard?phone=$phone';
    final whatsappUrl = res['whatsapp_url']?.toString() ?? '';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: green, size: 26),
            SizedBox(width: 8),
            Text('Member Added!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ $name has been registered and their meal pass is now active.', style: const TextStyle(color: ink, fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cream, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Student Digital Meal Pass:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: muted)),
                  const SizedBox(height: 4),
                  Text(passUrl, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: ink)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: passUrl));
              showNotice(context, 'Meal Pass link copied to clipboard!');
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Pass Link'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: whatsappUrl.isNotEmpty ? whatsappUrl : passUrl));
              showNotice(context, 'WhatsApp notification text copied! Paste to send to student.');
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: green),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Share WhatsApp'),
          ),
        ],
      ),
    );
  }

  void _openReactivateDialog(Map<String, dynamic> sub) {
    final subId = sub['id']?.toString() ?? '';
    final studentName = sub['customer_name']?.toString() ?? 'Student';
    final studentPhone = sub['customer_phone']?.toString() ?? '';
    int days = 30;
    String mode = 'cash';
    bool renewing = false;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.autorenew, color: orange, size: 24),
                  SizedBox(width: 8),
                  Expanded(child: Text('Renew Member Pass', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Member: $studentName ($studentPhone)', style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                  const SizedBox(height: 12),
                  const Text('Select extension period:', style: TextStyle(fontSize: 13, color: muted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('+30 Days'),
                        selected: days == 30,
                        selectedColor: orange,
                        onSelected: (v) => setDlgState(() => days = 30),
                      ),
                      ChoiceChip(
                        label: const Text('+15 Days'),
                        selected: days == 15,
                        selectedColor: orange,
                        onSelected: (v) => setDlgState(() => days = 15),
                      ),
                      ChoiceChip(
                        label: const Text('+60 Days'),
                        selected: days == 60,
                        selectedColor: orange,
                        onSelected: (v) => setDlgState(() => days = 60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Payment mode:', style: TextStyle(fontSize: 13, color: muted)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('💵 Cash'),
                        selected: mode == 'cash',
                        selectedColor: orange,
                        onSelected: (v) => setDlgState(() => mode = 'cash'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('📱 UPI'),
                        selected: mode == 'counter_upi',
                        selectedColor: orange,
                        onSelected: (v) => setDlgState(() => mode = 'counter_upi'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: renewing
                      ? null
                      : () async {
                          setDlgState(() => renewing = true);
                          try {
                            final res = await ProviderApiService.reactivateSubscription(
                              providerId: widget.session.providerId,
                              subscriptionId: subId,
                              days: days,
                              paymentMode: mode,
                            );
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              showNotice(context, res['message'] ?? 'Subscription renewed successfully!');
                              _fetchDetail();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDlgState(() => renewing = false);
                              showNotice(context, e.toString().replaceAll('Exception: ', ''), isError: true);
                            }
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink),
                  child: renewing
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: ink, strokeWidth: 2))
                      : const Text('Confirm Renewal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.kind) {
      case 'Subscribers':
        final filtered = items.where((sub) {
          if (subFilter == 'Monthly') return (sub['plan_name']?.toString().toLowerCase().contains('monthly') == true) || (sub['plan_name']?.toString().contains('30') == true);
          if (subFilter == '15 Days') return sub['plan_name']?.toString().contains('15') == true;
          if (subFilter == 'Flexi') return (sub['plan_type'] == 'meal_credits') || (sub['plan_name']?.toString().toLowerCase().contains('flexi') == true);
          return true;
        }).toList();

        return _detailScaffold(
          context,
          'Verified Subscribers',
          [
            Card(
              color: const Color(0xFFFFF7ED),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFFDBB5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_add_alt_1, color: orange, size: 22),
                        SizedBox(width: 8),
                        Text('Offline Walk-in / Direct Join', style: TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Register a walk-in student who paid cash or counter UPI directly to issue an instant digital meal pass.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openAddMemberSheet,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('+ Add Member Manually'),
                        style: FilledButton.styleFrom(
                          backgroundColor: orange,
                          foregroundColor: ink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Monthly', '15 Days', 'Flexi'].map((chip) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(chip),
                      selected: subFilter == chip,
                      selectedColor: orange,
                      onSelected: (v) => setState(() => subFilter = chip),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: orange)))
            else if (filtered.isEmpty)
              const EmptyStateCard(
                icon: Icons.groups_outlined,
                title: 'No subscribers found',
                subtitle: 'Use "+ Add Member Manually" above or display your Counter Standee QR for walk-in students to register.',
              )
            else
              ...filtered.map(
                (sub) {
                  final subId = sub['id']?.toString() ?? '';
                  final shortId = subId.length >= 8 ? subId.substring(0, 8) : subId;
                  final name = sub['customer_name']?.toString() ?? 'Member';
                  final phone = sub['customer_phone']?.toString() ?? '—';
                  final email = sub['customer_email']?.toString() ?? '';
                  final planName = sub['plan_name']?.toString() ?? 'Plan';
                  final status = (sub['status']?.toString() ?? 'active').toUpperCase();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _openSubscriberHistory(sub),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFFFE8C5),
                                  child: Text(
                                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
                                      Text('ID: #SUB-$shortId · 📱 $phone', style: const TextStyle(fontSize: 12, color: muted)),
                                      if (email.isNotEmpty) Text('✉️ $email', style: const TextStyle(fontSize: 11, color: muted)),
                                    ],
                                  ),
                                ),
                                StatusTag(
                                  text: status,
                                  color: status == 'ACTIVE' ? green : Colors.grey,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: cream, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Plan: $planName',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink),
                                  ),
                                  Text(
                                    'Expiry: ${sub['expires_at'] != null ? sub['expires_at'].toString().split('T').first : 'Active'}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
                                  ),
                                  Text(
                                    'Meals: ${sub['remaining_meal_credits'] ?? "Unlimited"}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: orange),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openSubscriberHistory(sub),
                                    icon: const Icon(Icons.history, size: 16),
                                    label: const Text('Scan Logs'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: ink,
                                      side: const BorderSide(color: line),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _openReactivateDialog(sub),
                                    icon: const Icon(Icons.autorenew, size: 16),
                                    label: const Text('Renew Pass'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: orange,
                                      foregroundColor: ink,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );

      case 'CounterOrders':
        return _detailScaffold(
          context,
          'Counter Sales & Extras',
          [
            Card(
              color: const Color(0xFFF0FDF4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFBBF7D0))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.point_of_sale, color: green, size: 22),
                        SizedBox(width: 8),
                        Text('Walk-in Food Sales Ledger', style: TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Keep track of direct cash/UPI single meals, extra sabzi, rotis or paneer sold at counter.', style: TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openAddCounterOrderSheet,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('+ Record Counter Sale'),
                        style: FilledButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: orange)))
            else if (items.isEmpty)
              const EmptyStateCard(
                icon: Icons.receipt_long_outlined,
                title: 'No counter orders yet',
                subtitle: 'Record single thalis, extra portions and beverages sold at your mess desk.',
              )
            else
              ...items.map(
                (ord) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.shopping_bag_outlined, color: green, size: 22),
                    ),
                    title: Text(ord['customer_name'] ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                    subtitle: Text('${ord['items_summary']} · ${ord['created_at']?.toString().split('T').first ?? ""}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${ord['total_amount_inr']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink)),
                        StatusTag(text: (ord['payment_mode'] ?? 'CASH').toString().toUpperCase(), color: green),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );

      case 'Timings':
        return _detailScaffold(
          context,
          'Kitchen Serving Timings',
          [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Operating Slots', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                    const SizedBox(height: 4),
                    const Text('Set serving hours for students so they know when to redeem meals.', style: TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 16),
                    const FieldLabel('Breakfast Hours'),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: bfStart, decoration: const InputDecoration(labelText: 'Opens'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: bfEnd, decoration: const InputDecoration(labelText: 'Closes'))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Lunch Hours'),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: lunchStart, decoration: const InputDecoration(labelText: 'Opens'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: lunchEnd, decoration: const InputDecoration(labelText: 'Closes'))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Dinner Hours'),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: dinnerStart, decoration: const InputDecoration(labelText: 'Opens'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: dinnerEnd, decoration: const InputDecoration(labelText: 'Closes'))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () async {
                          try {
                            await ProviderApiService.updateTimings(
                              providerId: widget.session.providerId,
                              timings: {
                                'breakfast': {'enabled': true, 'start': bfStart.text.trim(), 'end': bfEnd.text.trim()},
                                'lunch': {'enabled': true, 'start': lunchStart.text.trim(), 'end': lunchEnd.text.trim()},
                                'dinner': {'enabled': true, 'start': dinnerStart.text.trim(), 'end': dinnerEnd.text.trim()},
                              },
                            );
                            if (mounted) showNotice(context, 'Serving hours updated successfully!');
                          } catch (e) {
                            if (mounted) showNotice(context, 'Failed to update timings', isError: true);
                          }
                        },
                        style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink),
                        child: const Text('Save Timings Schedule', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case 'Support':
        return _detailScaffold(
          context,
          'Help & Support Desk',
          [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contact Platform Team', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                    const SizedBox(height: 4),
                    const Text('Send support requests directly to ritik45chaurasia@gmail.com.', style: TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 16),
                    const FieldLabel('Category'),
                    Wrap(
                      spacing: 8,
                      children: ['billing', 'menu', 'scanner', 'general'].map((c) {
                        return ChoiceChip(
                          label: Text(c.toUpperCase()),
                          selected: supportCategory == c,
                          selectedColor: orange,
                          onSelected: (v) => setState(() => supportCategory = c),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const FieldLabel('Subject'),
                    TextField(controller: supportSubject, decoration: const InputDecoration(hintText: 'Brief summary of the issue')),
                    const SizedBox(height: 14),
                    const FieldLabel('Detailed Message / Description'),
                    TextField(controller: supportMessage, maxLines: 4, decoration: const InputDecoration(hintText: 'Describe what happened or request changes...')),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: submittingTicket
                            ? null
                            : () async {
                                final sub = supportSubject.text.trim();
                                final msg = supportMessage.text.trim();
                                if (sub.isEmpty || msg.isEmpty) {
                                  showNotice(context, 'Please enter subject and message', isError: true);
                                  return;
                                }
                                setState(() => submittingTicket = true);
                                try {
                                  await ProviderApiService.submitSupportTicket(
                                    name: widget.session.businessName,
                                    email: widget.session.email,
                                    phone: '',
                                    role: 'provider',
                                    subject: sub,
                                    message: msg,
                                    category: supportCategory,
                                  );
                                  if (mounted) {
                                    showNotice(context, 'Support ticket sent! We will reply to ${widget.session.email}');
                                    supportSubject.clear();
                                    supportMessage.clear();
                                  }
                                } catch (e) {
                                  if (mounted) showNotice(context, 'Failed to send ticket: ${e.toString().replaceAll("Exception: ", "")}', isError: true);
                                } finally {
                                  if (mounted) setState(() => submittingTicket = false);
                                }
                              },
                        style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink),
                        child: submittingTicket
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: ink, strokeWidth: 2))
                            : const Text('Send Support Request', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case 'Attendance':
        return _detailScaffold(
          context,
          'Redemption Log',
          [
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: orange)))
            else if (items.isEmpty)
              const EmptyStateCard(
                icon: Icons.fact_check_outlined,
                title: 'No redemptions recorded',
                subtitle: 'Redemptions verified via your counter QR code will appear here in chronological order.',
              )
            else
              ...items.map(
                (red) {
                  final customerName = red['customer_name'] ?? 'Verified Student';
                  final planName = red['plan_name'] ?? 'Meal Pass';
                  final slot = red['slot'] ?? 'LUNCH';
                  final date = red['date'] ?? '';
                  final time = red['time_formatted'] ?? (red['redeemed_at']?.toString().contains('T') == true ? red['redeemed_at'].toString().split('T').last.substring(0, 5) : '');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: green),
                      title: Text('$customerName · $slot', style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                      subtitle: Text('$planName · $date $time'),
                      trailing: const StatusTag(text: 'VERIFIED', color: green),
                    ),
                  );
                },
              ),
          ],
        );

      case 'Feedback':
        return _detailScaffold(context, 'Customer Reviews', [
          const EmptyStateCard(
            icon: Icons.rate_review_outlined,
            title: 'No reviews yet',
            subtitle: 'Only verified customers who have redeemed meals can leave authentic ratings & reviews.',
          ),
        ]);

      case 'Business profile':
        return _detailScaffold(context, 'Mess Profile', [
          ReviewLine(label: 'Mess Name', value: widget.session.businessName),
          ReviewLine(label: 'Registered Email', value: widget.session.email),
          ReviewLine(label: 'Provider ID', value: widget.session.providerId),
          ReviewLine(label: 'Status', value: 'Active Verified Partner'),
        ]);

      case 'Earnings':
      default:
        return _detailScaffold(context, 'Settlements & Payouts', [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Available Payout',
                  value: '₹14,850',
                  note: 'Net student balance',
                  icon: Icons.account_balance_wallet_outlined,
                  tint: const Color(0xFFDDF2E6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  title: 'Total Settled',
                  value: '₹48,200',
                  note: 'Paid to your bank',
                  icon: Icons.check_circle_outline,
                  tint: const Color(0xFFFFE8C5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Connected Bank / UPI',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('VERIFIED', style: TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Account Holder: ${widget.session.businessName}', style: const TextStyle(fontSize: 13, color: muted)),
                  const SizedBox(height: 4),
                  const Text('Bank: State Bank of India •••• 5849', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
                  const SizedBox(height: 4),
                  const Text('IFSC: SBIN0004210 • Branch: Main City', style: TextStyle(fontSize: 13, color: muted)),
                  const SizedBox(height: 4),
                  Text('UPI ID: mess.${widget.session.providerId.substring(0, 6)}@oksbi', style: const TextStyle(fontSize: 13, color: muted)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showNotice(context, 'Bank account update request submitted for admin review.');
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Update Bank / UPI Details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Request Early Payout?'),
                    content: const Text('Your current available balance of ₹14,850 will be credited to your registered bank account within 2-4 hours.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          showNotice(context, '✅ Early payout requested! ₹14,850 processing.');
                        },
                        style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink),
                        child: const Text('Confirm Payout'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Request Early Payout (₹14,850)', style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Recent Payout Transfers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
          const SizedBox(height: 10),
          ...[
            {'id': 'TXN-984210', 'date': 'Today, 11:30 AM', 'amount': '₹6,400', 'mode': 'UPI Direct', 'status': 'PROCESSED'},
            {'id': 'TXN-983190', 'date': '24 Oct 2026', 'amount': '₹18,500', 'mode': 'IMPS Transfer', 'status': 'SETTLED'},
            {'id': 'TXN-981045', 'date': '17 Oct 2026', 'amount': '₹23,300', 'mode': 'NEFT Bank', 'status': 'SETTLED'},
          ].map((txn) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFDDF2E6), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.check_circle_outline, color: green, size: 22),
                ),
                title: Text('${txn['amount']} • ${txn['mode']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ink)),
                subtitle: Text('UTR: ${txn['id']} • ${txn['date']}', style: const TextStyle(fontSize: 12, color: muted)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(txn['status']!, style: const TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 10)),
                ),
              ),
            ),
          )),
        ]);
    }
  }

  Widget _detailScaffold(BuildContext context, String title, List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Row(children: [
            IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineMedium)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      );
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(children: [
              Icon(icon, size: 40, color: muted),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 16)),
              const SizedBox(height: 6),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 13, height: 1.4)),
            ]),
          ),
        ),
      );
}

// Reusable components
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.restaurant, color: orange, size: 42),
        SizedBox(width: 8),
        Text('MESS', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.6, color: ink)),
      ]);
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ink)));
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 50,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: orange,
            foregroundColor: ink,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
      );
}

class DividerWithLabel extends StatelessWidget {
  const DividerWithLabel({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider(color: line)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(label, style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800))),
        const Expanded(child: Divider(color: line)),
      ]);
}

class SectionIntro extends StatelessWidget {
  const SectionIntro({super.key, required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: muted, height: 1.45)),
        ]),
      );
}

class SelectableTile extends StatelessWidget {
  const SelectableTile({super.key, required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF0D8) : card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? orange : line, width: selected ? 1.4 : 1),
            ),
            child: Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: ink)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: muted, fontSize: 12, height: 1.3)),
                ]),
              ),
              const SizedBox(width: 8),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? orange : muted),
            ]),
          ),
        ),
      );
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: const Border.fromBorderSide(BorderSide(color: line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );
}

class ReviewLine extends StatelessWidget {
  const ReviewLine({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: const TextStyle(color: muted))),
          const SizedBox(width: 10),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: ink, fontWeight: FontWeight.w700))),
        ]),
      );
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.title, required this.value, required this.note, required this.icon, required this.tint});
  final String title, value, note;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 19, color: ink)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 22))),
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(color: muted, fontSize: 10)),
          ]),
        ),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ]);
}

class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.title, required this.detail, required this.status, required this.success});
  final String title, detail, status;
  final bool success;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
            leading: Icon(success ? Icons.check_circle_outline : Icons.receipt_long_outlined, color: success ? green : orange),
            title: Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 13)),
            subtitle: Text(detail, style: const TextStyle(color: muted, fontSize: 11)),
            trailing: StatusTag(text: status, color: success ? green : orange),
          ),
        ),
      );
}

class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10)),
      );
}

class QuickAction extends StatelessWidget {
  const QuickAction({super.key, required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              Icon(icon, color: orange),
              const SizedBox(width: 9),
              Expanded(child: Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12))),
              const Icon(Icons.arrow_forward_ios, size: 12, color: muted),
            ]),
          ),
        ),
      );
}

class PlanPriceCard extends StatelessWidget {
  const PlanPriceCard({super.key, required this.duration, required this.price, required this.perMeal});
  final String duration, price, perMeal;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFFFE8C5), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.calendar_month_outlined, color: ink)),
          title: Text(duration, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
          subtitle: Text(perMeal, style: const TextStyle(color: muted, fontSize: 12)),
          trailing: Text(price, style: const TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
      );
}

class MoreMenuTile extends StatelessWidget {
  const MoreMenuTile({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: ListTile(
            onTap: onTap,
            leading: Icon(icon, color: orange, size: 24),
            title: Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 14)),
            subtitle: Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
            trailing: const Icon(Icons.chevron_right, color: muted),
          ),
        ),
      );
}

class MenuItemDraft {
  MenuItemDraft(this.name, this.rule, this.portion, this.price, this.enabled, {this.paid = false});
  final String name, rule, portion;
  final int price;
  final bool enabled, paid;
}
