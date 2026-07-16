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
import 'config/app_config.dart';
import 'providers/policy_providers.dart';
import 'services/local_storage_service.dart';
import 'services/app_state_store.dart';
import 'services/app_state_repository.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/analytics_service.dart';
import 'widgets/shared/global_error_boundary.dart';

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

    // Acquire anonymous auth token if we don't have one yet (non-blocking —
    // the AuthInterceptor also acquires on first 401).
    if (await AuthService.cachedToken() == null) {
      final tempDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
      await AuthService.acquireToken(tempDio);
    }

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
    if (_showSplash) {
      return SplashScreen(
        onComplete: () {
          if (mounted) setState(() => _showSplash = false);
        },
      );
    }

    // Watch theme changes — rebuilds MaterialApp when user toggles theme.
    final _ = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _getThemeMode(),
      home: _showOnboarding
          ? OnboardingScreen(onComplete: () {
              setState(() => _showOnboarding = false);
            })
          : const MainNavigation(),
      routes: {
        '/qa': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as String?;
          return QaScreen(initialDocumentId: args);
        },
        '/emergency': (context) => const EmergencyScreen(),
        '/claims': (context) => const ClaimsAssistantScreen(),
        '/renewals': (context) => const RenewalCalendarScreen(),
        '/coverage-gaps': (context) => const CoverageGapScreen(),
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
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.description), label: 'Documents'),
          NavigationDestination(icon: Icon(Icons.question_answer), label: 'QA'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Family'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
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
