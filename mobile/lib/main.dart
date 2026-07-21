import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/qa_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/family_screen.dart';
import 'screens/more_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/claims_assistant_screen.dart';
import 'screens/renewal_calendar_screen.dart';
import 'screens/coverage_gap_screen.dart';
import 'models/field_citation.dart';
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
import 'screens/notification_preferences_screen.dart';
import 'config/app_config.dart';
import 'providers/entitlement_provider.dart';
import 'providers/policy_providers.dart';
import 'services/local_storage_service.dart';
import 'services/app_state_store.dart';
import 'services/app_state_repository.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/analytics_service.dart';
import 'services/install_service.dart';
import 'services/principal_key_service.dart';
import 'services/hive_workspace_service.dart';
import 'providers/auth_provider.dart';
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

    // Initialize principal encryption AFTER auth is ready but BEFORE opening encrypted boxes
    // This ensures we have the principal ID for encryption key derivation
    String principalId;
    if (AuthService.hasAccountSession) {
      // For authenticated sessions, use the account user ID
      final currentUser = Supabase.instance.client.auth.currentUser;
      principalId = currentUser?.id ?? 'anonymous';
    } else if (AppConfig.hasSupabaseAuthConfig) {
      // For anonymous sessions, use the Supabase anonymous user ID when the
      // project enables anonymous sign-ins. Some production projects disable
      // that provider while still supporting email/OAuth accounts; in that
      // case the account client remains available and local-only encryption is
      // the safe startup fallback.
      try {
        final anonSession =
            await Supabase.instance.client.auth.signInAnonymously();
        principalId = anonSession.user?.id ?? 'anonymous';
      } catch (error) {
        debugPrint(
          'Anonymous Supabase auth unavailable; using local principal: $error',
        );
        principalId = 'local-only-${InstallService.getInstallId()}';
      }
    } else {
      // Local-only installs still need a stable principal. A timestamp here
      // rotates the encryption key on every launch and makes existing Hive
      // boxes unreadable. The persisted install id is stable until uninstall.
      principalId = 'local-only-${InstallService.getInstallId()}';
    }

    // Initialize PrincipalKeyService with the principal ID
    await PrincipalKeyService().initForPrincipal(principalId);

    // Migrate existing Hive boxes from device-key to principal-key encryption
    await _migrateLegacyHiveBoxes();

    // Now open encrypted Hive boxes
    await HiveWorkspaceService.openForActivePrincipal();

    // Initialize analytics only after its AppState and ledger boxes exist.
    // AnalyticsService.init() synchronously reads the session from AppStateStore;
    // calling it earlier causes a first-launch HiveError before the UI mounts.
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

/// Migrates legacy Hive boxes from device-key encryption to principal-scoped DEK encryption
Future<void> _migrateLegacyHiveBoxes() async {
  try {
    final principalKeys = PrincipalKeyService();
    if (!await principalKeys.hasLegacyDeviceKey()) {
      debugPrint('No legacy Hive key; migration is not required.');
      return;
    }

    // List of Hive boxes that need migration to principal-scoped encryption
    final boxesToMigrate = [
      LocalStorageService.documentsBoxName,
      AppStateStore.boxName,
      'resolved_gaps',
      'analytics_events',
      'consent_ledger',
      'qa_history',
      'field_overrides_box',
      'entitlements',
    ];

    for (final boxName in boxesToMigrate) {
      final migrationCompleted =
          await principalKeys.migrateBox(boxName: boxName, boxPath: '');
      if (migrationCompleted) {
        debugPrint('Successfully migrated Hive box: $boxName');
      } else {
        debugPrint('Migration skipped or already completed for: $boxName');
      }
    }

    // Clear the legacy device-key from secure storage after migration
    final secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: PrincipalKeyService.oldDeviceKeyStorageKey);
    debugPrint('Legacy device-key cleared from secure storage');
  } catch (e) {
    debugPrint('Error during Hive box migration: $e');
    // Don't throw - allow app to continue with potentially unencrypted boxes
    // Migration will be retried on next startup
  }
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
  ProviderSubscription<AsyncValue<AuthState>>? _authSubscription;
  bool _workspaceTransitionInProgress = false;

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding;
    _authSubscription = ref.listenManual<AsyncValue<AuthState>>(
      authStateProvider,
      (_, next) {
        final principalId = next.valueOrNull?.session?.user.id;
        if (principalId != null) {
          unawaited(_reopenWorkspaceForPrincipal(principalId));
          if (AppConfig.hasRevenueCatConfig) {
            unawaited(
                ref.read(billingAdapterProvider).identifyAccount(principalId));
          }
        }
      },
    );
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.close();
    super.dispose();
  }

  Future<void> _reopenWorkspaceForPrincipal(String principalId) async {
    if (_workspaceTransitionInProgress ||
        PrincipalKeyService().principalId == principalId) {
      return;
    }
    _workspaceTransitionInProgress = true;
    try {
      // Do not carry account A's buffered analytics into account B's session.
      await AnalyticsService.clear();
      AnalyticsService.dispose();
      await HiveWorkspaceService.resetForPrincipal(principalId);
      AnalyticsService.init();
    } catch (error, stackTrace) {
      debugPrint('Workspace principal transition failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _workspaceTransitionInProgress = false;
    }
  }

  void _initDeepLinks() {
    _appLinks.getInitialLink().then((uri) {
      if (!mounted || uri == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleDeepLink(uri);
      });
    }).catchError((Object error, StackTrace stackTrace) {
      debugPrint('Initial deep link unavailable: $error');
    });
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (!mounted) return;
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    // Custom-scheme links such as io.coverwise://emergency place the route in
    // the URI host, while universal links place it in the path.
    final path = uri.path.isNotEmpty ? uri.path : '/${uri.host}';

    switch (path) {
      case '/emergency':
        nav.pushNamed('/emergency');
      case '/claims':
        nav.pushNamed('/claims');
      case '/renewals':
        nav.pushNamed('/renewals');
      case '/coverage-gaps':
        final docId = uri.queryParameters['documentId'] ?? '';
        final citationsJson = uri.queryParameters['citations'];
        List<Map<String, dynamic>> citations = [];
        if (citationsJson != null && citationsJson.isNotEmpty) {
          try {
            final decoded = Uri.decodeComponent(citationsJson);
            final parsed = jsonDecode(decoded);
            if (parsed is List) {
              citations = parsed.cast<Map<String, dynamic>>();
            }
          } catch (_) {
            // Malformed citations — render empty
          }
        }
        nav.pushNamed('/coverage-gaps', arguments: {
          'documentId': docId,
          'citations': citations,
        });
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

    // Kick off RevenueCat billing init + entitlement sync.
    // The FutureProvider auto-runs once; its result is cached.
    if (AppConfig.hasRevenueCatConfig) {
      ref.watch(billingInitProvider);
    }

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
          final documentId = args?['documentId'] as String?;
          if (documentId == null || documentId.isEmpty) {
            return const _MissingArgsScreen(
              title: 'Coverage gaps',
              message: 'No document was specified. '
                  'Choose a policy in Documents, then open its coverage details.',
              recoveryRoute: '/documents',
              recoveryLabel: 'Choose a policy',
            );
          }
          // Deep links pass citations as URL-encoded JSON arrays of raw maps,
          // not pre-deserialized FieldCitation objects. Deserialize them here.
          final citationsRaw = args?['citations'];
          final citations = citationsRaw is List
              ? citationsRaw
                  .whereType<Map<String, dynamic>>()
                  .map(FieldCitation.fromJson)
                  .toList()
              : const <FieldCitation>[];
          return CoverageGapScreen(
            documentId: documentId,
            citations: citations,
          );
        },
        '/compare': (context) => const PolicyComparisonScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/help': (context) => const HelpSupportScreen(),
        '/privacy': (context) => const PrivacySecurityScreen(),
        '/about': (context) => const AboutScreen(),
        '/policy-detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final documentId = args is String ? args : null;
          if (documentId == null || documentId.isEmpty) {
            return const _MissingArgsScreen(
              title: 'Policy details',
              message: 'No policy was specified. Open a policy from Documents.',
              recoveryRoute: '/documents',
              recoveryLabel: 'Open documents',
            );
          }
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
        '/family': (context) => const FamilyScreen(),
        '/notifications': (context) => const NotificationPreferencesScreen(),
        '/documents': (context) => const DocumentsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Fallback screen shown when a deep link arrives without required arguments.
class _MissingArgsScreen extends StatelessWidget {
  final String title;
  final String message;
  final String? recoveryRoute;
  final String recoveryLabel;

  const _MissingArgsScreen({
    required this.title,
    required this.message,
    this.recoveryRoute,
    this.recoveryLabel = 'Go back',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_off_rounded,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () {
                  if (recoveryRoute case final route?) {
                    Navigator.of(context).pushReplacementNamed(route);
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                child: Text(recoveryLabel),
              ),
            ],
          ),
        ),
      ),
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
  final Set<int> _visitedTabs = {0};
  bool _demoNavigationScheduled = false;
  bool _notificationsScheduled = false;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
  }

  @override
  void initState() {
    super.initState();
    if (AppConfig.bootstrapPolicyDemo) {
      _selectedIndex = 1;
      _visitedTabs.add(1);
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const DashboardScreen(),
          _visitedTabs.contains(1)
              ? const DocumentsScreen()
              : const SizedBox.shrink(),
          _visitedTabs.contains(2)
              ? QaScreen(
                  key: const ValueKey('qa-tab'),
                  isActive: _selectedIndex == 2,
                )
              : const SizedBox.shrink(),
          _visitedTabs.contains(3)
              ? const FamilyScreen()
              : const SizedBox.shrink(),
          _visitedTabs.contains(4)
              ? const MoreScreen()
              : const SizedBox.shrink(),
        ],
      ),
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
        _visitedTabs.add(2);
      });
    });
  }
}
