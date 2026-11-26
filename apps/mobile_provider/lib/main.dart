import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/thali_partner_theme.dart';
import 'core/widgets/partner_widgets.dart';
import 'features/daily_qr_tab.dart';
import 'features/menu_management_tab.dart';
import 'features/partner_auth_screens.dart';
import 'features/partner_overview_tab.dart';
import 'features/plans_management_tab.dart';
import 'features/provider_ad_onboarding_screen.dart';
import 'models/models.dart';
import 'services/provider_api_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  final savedSession = await ProviderApiService.loadSavedSession();
  bool hasSeenAd = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    hasSeenAd = prefs.getBool('thali_partner_has_seen_ad_onboarding') ?? false;
  } catch (_) {}
  runApp(MessProviderApp(initialSession: savedSession, hasSeenAd: hasSeenAd));
}

class MessProviderApp extends StatefulWidget {
  const MessProviderApp({super.key, this.initialSession, this.hasSeenAd = true});
  final ProviderSession? initialSession;
  final bool hasSeenAd;

  @override
  State<MessProviderApp> createState() => _MessProviderAppState();
}

class _MessProviderAppState extends State<MessProviderApp> {
  ProviderSession? _session;
  late bool _hasSeenAd;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _hasSeenAd = widget.hasSeenAd;
    Future.delayed(const Duration(milliseconds: 950), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  Future<void> _markAdSeen() async {
    setState(() => _hasSeenAd = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('thali_partner_has_seen_ad_onboarding', true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thali Partner',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: ThaliPartnerTheme.light,
      home: _showSplash
          ? const _PartnerSplashScreen()
          : (_session != null
              ? ProviderShell(
                  session: _session!,
                  onSessionUpdated: (updated) {
                    ProviderApiService.saveSession(updated);
                    if (mounted) setState(() => _session = updated);
                  },
                  onSignOut: () async {
                    await ProviderApiService.clearSession();
                    if (mounted) setState(() => _session = null);
                  },
                )
              : (!_hasSeenAd
                  ? ProviderAdOnboardingScreen(
                      onSignIn: _markAdSeen,
                      onRegister: () {
                        _markAdSeen();
                        appNavigatorKey.currentState?.push(
                          partnerRoute(
                            ProviderOnboardingScreen(
                              onComplete: (s) => setState(() => _session = s),
                            ),
                          ),
                        );
                      },
                    )
                  : ProviderLoginScreen(
                      onLoginSuccess: (s) => setState(() => _session = s),
                      onRegister: () {
                        appNavigatorKey.currentState?.push(
                          partnerRoute(
                            ProviderOnboardingScreen(
                              onComplete: (s) => setState(() => _session = s),
                            ),
                          ),
                        );
                      },
                    ))),
    );
  }
}

class _PartnerSplashScreen extends StatelessWidget {
  const _PartnerSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ThaliColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThaliLogoMark(size: 74, whiteContainer: true),
            SizedBox(height: 18),
            Text(
              'Thali Partner',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.6,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Kitchen Operations & Subscriber Hub',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFFE5DC)),
            ),
          ],
        ),
      ),
    );
  }
}

class ProviderShell extends StatefulWidget {
  const ProviderShell({
    super.key,
    required this.session,
    required this.onSignOut,
    this.onSessionUpdated,
  });
  final ProviderSession session;
  final VoidCallback onSignOut;
  final ValueChanged<ProviderSession>? onSessionUpdated;

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      PartnerOverviewTab(
        session: widget.session,
        onSignOut: widget.onSignOut,
        onSessionUpdated: widget.onSessionUpdated,
        onSwitchTab: (i) => setState(() => _tab = i),
      ),
      MenuManagementTab(session: widget.session),
      PlansManagementTab(session: widget.session),
      DailyQrTab(session: widget.session),
    ];

    return Scaffold(
      backgroundColor: ThaliColors.scaffold,
      body: Stack(
        children: [
          IndexedStack(index: _tab, children: pages),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: Container(
                height: 64,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ThaliColors.card,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: ThaliColors.stroke),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1418181B), blurRadius: 20, offset: Offset(0, 6)),
                  ],
                ),
                child: Row(
                  children: [
                    _navItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                    _navItem(1, Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded, 'Menu'),
                    _navItem(2, Icons.card_membership_outlined, Icons.card_membership_rounded, 'Plans'),
                    _navItem(3, Icons.qr_code_2_outlined, Icons.qr_code_2_rounded, 'Check-In'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final active = _tab == index;
    return Expanded(
      child: PressScale(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active ? ThaliColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? activeIcon : icon,
                size: 20,
                color: active ? ThaliColors.primary : ThaliColors.muted,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? ThaliColors.primary : ThaliColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
