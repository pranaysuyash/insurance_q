import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/qa_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/family_screen.dart';
import 'screens/more_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/claims_assistant_screen.dart';
import 'screens/renewal_calendar_screen.dart';
import 'screens/coverage_gap_screen.dart';
import 'screens/policy_comparison_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/privacy_security_screen.dart';
import 'screens/about_screen.dart';
import 'screens/policy_detail_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/claim_tracking_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/search_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/insurance_card_screen.dart';
import 'screens/insurance_literacy_screen.dart';
import 'screens/what_if_calculator_screen.dart';
import 'screens/account_screen.dart';
import 'screens/reset_password_screen.dart';
import 'config/app_config.dart';
import 'providers/policy_providers.dart';
import 'services/local_storage_service.dart';
import 'services/app_state_store.dart';
import 'services/app_state_repository.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/analytics_service.dart';
import 'services/install_service.dart';
import 'widgets/shared/global_error_boundary.dart';
import 'theme/coverwise_theme.dart';
import 'theme/coverwise_motion.dart';

void main() async {
  // Catch errors in the root zone
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Global error handlers are set up by GlobalErrorBoundary.initState()
    // when the widget tree mounts. No need to duplicate them here.

    AppConfig.validateReleaseConfiguration();
    if (AppConfig.isProduction) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }
    await Hive.initFlutter();
    await Hive.openBox<String>(LocalStorageService.documentsBoxName);
    await Hive.openBox(AppStateStore.boxName);

    if (AppConfig.hasSupabaseAuthConfig) {
      await AuthService.initializeAccountClient();
    }

    // R1.6 (2026-07-18): load install identity (install_id, is_reinstall,
    // days_since_install, install_referrer_*) from SharedPreferences before
    // AnalyticsService.init() runs, so the app_session_started event
    // emitted from init() has accurate values. Must run before init().
    await InstallService.ensureInitialized();

    // Acquire anonymous auth token if we don't have one yet (non-blocking —
    // the AuthInterceptor also acquires on first 401).
    unawaited(_warmAnonymousSession());

    // Initialize analytics (local-first, batch-syncs to backend)
    AnalyticsService.init();

    // Check if onboarding has been completed
    final prefs = await SharedPreferences.getInstance();
    final hasOnboarded = prefs.getBool('onboarding_complete') ?? false;

    runApp(
      GlobalErrorBoundary(
        child: ProviderScope(
          child: InsuranceApp(showOnboarding: !hasOnboarded),
        ),
      ),
    );
  }, (error, stackTrace) {
    // Catch zone errors that escape the framework
    if (kDebugMode) {
      debugPrint('=== ZONE ERROR ===');
      debugPrint('Error: $error');
      debugPrint('Stack: $stackTrace');
      debugPrint('==================');
    }
  });
}

Future<void> _warmAnonymousSession() async {
  if (await AuthService.accessToken() != null) return;
  final tempDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
  await AuthService.acquireToken(tempDio);
}

class InsuranceApp extends ConsumerStatefulWidget {
  final bool showOnboarding;

  const InsuranceApp({super.key, this.showOnboarding = false});

  @override
  ConsumerState<InsuranceApp> createState() => _InsuranceAppState();
}

class _InsuranceAppState extends ConsumerState<InsuranceApp> {
  late bool _showOnboarding;
  bool _showSplash = true;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding;
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (!mounted) return;
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    final path = uri.path;

    switch (path) {
      case '/emergency':
        nav.pushNamed('/emergency');
      case '/claims':
        nav.pushNamed('/claims');
      case '/renewals':
        nav.pushNamed('/renewals');
      case '/coverage-gaps':
        nav.pushNamed('/coverage-gaps');
      case '/compare':
        nav.pushNamed('/compare');
      case '/qa':
        final docId = uri.queryParameters['documentId'];
        nav.pushNamed('/qa', arguments: docId);
      case '/reset-callback':
        // Password reset redirect from Supabase email link.
        // The access_token and refresh_token are in the fragment (#) for PKCE flow.
        nav.pushNamed('/reset-password', arguments: uri.toString());
      case '/login-callback':
        // Google Sign-In redirect — Supabase handles token exchange.
        // The session is established automatically by the Supabase client.
        break;
      default:
        break;
    }
  }

  ThemeMode _getThemeMode() {
    switch (AppStateRepository.getThemeMode()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch theme changes — rebuilds MaterialApp when user toggles theme.
    final _ = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConfig.appName,
      theme: CoverWiseTheme.light(),
      darkTheme: CoverWiseTheme.dark(),
      themeMode: _getThemeMode(),
      home: AnimatedSwitcher(
        duration: CoverWiseMotion.duration(context, CoverWiseMotion.onboarding),
        switchInCurve: CoverWiseMotion.enterCurve,
        switchOutCurve: CoverWiseMotion.exitCurve,
        child: _showSplash
            ? SplashScreen(
                key: const ValueKey('splash'),
                onComplete: () {
                  if (mounted) setState(() => _showSplash = false);
                },
              )
            : _showOnboarding
                ? OnboardingScreen(
                    key: const ValueKey('onboarding'),
                    onComplete: ({bool openFilePicker = false}) {
                      setState(() => _showOnboarding = false);
                      // If the user completed onboarding via "Add my first policy",
                      // open the DocumentsScreen with the file picker pre-triggered
                      // so they go straight to file selection (2 taps instead of 4).
                      if (openFilePicker) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DocumentsScreen(
                                startWithFilePicker: true,
                              ),
                            ),
                          );
                        });
                      }
                    },
                  )
                : const MainNavigation(key: ValueKey('main')),
      ),
      routes: {
        '/qa': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as String?;
          return QaScreen(initialDocumentId: args);
        },
        '/emergency': (context) => const EmergencyScreen(),
        '/claims': (context) => const ClaimsAssistantScreen(),
        '/renewals': (context) => const RenewalCalendarScreen(),
        '/coverage-gaps': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return CoverageGapScreen(
            documentId: args?['documentId'] as String? ?? '',
            citations: (args?['citations'] as List?)?.cast() ?? const [],
          );
        },
        '/compare': (context) => const PolicyComparisonScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/help': (context) => const HelpSupportScreen(),
        '/privacy': (context) => const PrivacySecurityScreen(),
        '/about': (context) => const AboutScreen(),
        '/policy-detail': (context) {
          final documentId =
              ModalRoute.of(context)?.settings.arguments as String;
          return PolicyDetailScreen(documentId: documentId);
        },
        '/claim-tracker': (context) => const ClaimTrackingScreen(),
        '/search': (context) => const SearchScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/insurance-cards': (context) => const InsuranceCardScreen(),
        '/literacy': (context) => const InsuranceLiteracyScreen(),
        '/what-if': (context) => const WhatIfCalculatorScreen(),
        '/account': (context) => const AccountScreen(),
        '/reset-password': (context) {
          final redirectUrl =
              ModalRoute.of(context)?.settings.arguments as String? ?? '';
          return ResetPasswordScreen(redirectUrl: redirectUrl);
        },
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _selectedIndex = 0;
  bool _demoNavigationScheduled = false;
  bool _notificationsScheduled = false;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    if (AppConfig.bootstrapPolicyDemo) {
      _selectedIndex = 1;
      _scheduleDemoNavigation();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Schedule renewal reminders when summaries are loaded (once per session).
    final summaries = ref.watch(policySummariesProvider);
    if (!_notificationsScheduled && summaries.isNotEmpty) {
      _notificationsScheduled = true;
      NotificationService.scheduleRenewalReminders(summaries);
    }

    return Scaffold(
      body: _buildPage(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: 'Documents',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Ask',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group_rounded),
            label: 'Family',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }

  void _scheduleDemoNavigation() {
    if (_demoNavigationScheduled) return;
    _demoNavigationScheduled = true;
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _selectedIndex = 2;
      });
    });
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const DocumentsScreen();
      case 2:
        return QaScreen(isActive: _selectedIndex == 2);
      case 3:
        return const FamilyScreen();
      case 4:
        return const MoreScreen();
      default:
        return const DashboardScreen();
    }
  }
}
