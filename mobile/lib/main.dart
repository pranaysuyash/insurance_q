import 'package:dio/dio.dart';
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
import 'config/app_config.dart';
import 'providers/policy_providers.dart';
import 'services/local_storage_service.dart';
import 'services/app_state_store.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.isProduction) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  await Hive.initFlutter();
  await Hive.openBox<String>(LocalStorageService.documentsBoxName);
  await Hive.openBox(AppStateStore.boxName);

  // Acquire anonymous auth token if we don't have one yet (non-blocking —
  // the AuthInterceptor also acquires on first 401).
  if (AuthService.cachedToken == null) {
    final tempDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
    await AuthService.acquireToken(tempDio);
  }

  // Check if onboarding has been completed
  final prefs = await SharedPreferences.getInstance();
  final hasOnboarded = prefs.getBool('onboarding_complete') ?? false;

  runApp(
    ProviderScope(
      child: InsuranceApp(showOnboarding: !hasOnboarded),
    ),
  );
}

class InsuranceApp extends StatefulWidget {
  final bool showOnboarding;

  const InsuranceApp({super.key, this.showOnboarding = false});

  @override
  State<InsuranceApp> createState() => _InsuranceAppState();
}

class _InsuranceAppState extends State<InsuranceApp> {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
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
