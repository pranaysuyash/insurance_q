import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations_gen.dart';
import 'config/app_config.dart';
import 'models/identity.dart';
import 'models/policy_summary.dart';
import 'models/reset_password_args.dart';
import 'providers/auth_provider.dart';
import 'providers/entitlement_provider.dart';
import 'providers/policy_providers.dart';
import 'services/analytics_service.dart';
import 'services/app_state_repository.dart';
import 'services/auth_service.dart';
import 'services/install_service.dart';
import 'services/notification_service.dart';
import 'sync/reconciliation_coordinator.dart';
import 'utils/deep_link_policy.dart';
import 'widgets/shared/auth_expired_banner.dart';
import 'widgets/shared/coverwise_snackbar.dart';
import 'widgets/shared/offline_banner.dart';
import 'widgets/shared/screen_error_boundary.dart';
import 'theme/coverwise_motion.dart';
import 'theme/coverwise_theme.dart';

// Screens
import 'screens/qa_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/family_screen.dart';
import 'screens/family_visualization_screen.dart';
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
import 'screens/account_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/notification_preferences_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/what_if_calculator_screen.dart';

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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  late final ReconciliationCoordinator _reconciliation;

  /// Set to true after the first frame posts. Auth stream events that fire
  /// during widget mounting (initialSession replay from Supabase) are skipped.
  bool _startupComplete = false;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider.notifier);
    _showOnboarding = widget.showOnboarding;
    _reconciliation = ReconciliationCoordinator(ref: ref);

    // Defer auth processing until after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupComplete = true;
    });

    _authSubscription = ref.listenManual<AsyncValue<AuthState>>(
      authStateProvider,
      (_, next) {
        if (!_startupComplete) return;
        final authState = next.asData?.value;
        if (authState == null) return;

        final session = authState.session;
        final event = authState.event;

        switch (event) {
          case AuthChangeEvent.signedIn:
            if (session == null) return;
            final principal = AccountPrincipal(session.user.id);
            ref.read(authServiceProvider.notifier).updateSessionExpired(false);
            final preserveWorkspace =
                ref.read(authServiceProvider.notifier).consumeAnonymousWorkspaceClaim();
            final epoch = _reconciliation.prepareTransition(principal);
            unawaited(_reconciliation.handleAuthenticatedSessionTransition(
              principal,
              preserveCurrentWorkspace: preserveWorkspace,
              principalEpoch: epoch,
            ).then((_) => _reconciliation.scheduleReconciliation(epoch: epoch)));
            if (AppConfig.hasRevenueCatConfig) {
              unawaited(ref
                  .read(billingAdapterProvider)
                  .identifyAccount(principal.principalId));
            }

          case AuthChangeEvent.signedOut:
            _reconciliation.prepareSignOut();
            final principal = LocalPrincipal(InstallService.getInstallId());
            final epoch = _reconciliation.prepareTransition(principal);
            unawaited(_reconciliation.handleAuthenticatedSessionTransition(
              principal,
              preserveCurrentWorkspace: false,
              principalEpoch: epoch,
            ));

          case AuthChangeEvent.tokenRefreshed:
            ref.read(authServiceProvider.notifier).updateSessionExpired(false);

          default:
            break;
        }
      },
    );
    _initDeepLinks();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        _reconciliation.scheduleReconciliation();
      }
    });
    _reconciliation.scheduleReconciliation();
  }

  @override
  void dispose() {
    _reconciliation.mounted = false;
    _linkSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _authSubscription?.close();
    _reconciliation.dispose();
    super.dispose();
  }

  // ── Deep links ──────────────────────────────────────────────────────

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
    final validation = DeepLinkPolicy.validate(uri);
    if (!validation.isValid) {
      debugPrint('Deep link rejected: ${validation.error}');
      return;
    }
    final path = validation.path!;
    switch (path) {
      case '/emergency':
        nav.pushNamed('/emergency');
      case '/claims':
        nav.pushNamed('/claims');
      case '/renewals':
        nav.pushNamed('/renewals');
      case '/coverage-gaps':
        final docId = uri.queryParameters['documentId'] ?? '';
        nav.pushNamed('/coverage-gaps', arguments: {'documentId': docId});
      case '/compare':
        nav.pushNamed('/compare');
      case '/what-if':
        nav.pushNamed('/what-if');
      case '/qa':
        final docId = uri.queryParameters['documentId'];
        nav.pushNamed('/qa', arguments: docId);
      case '/reset-callback':
        nav.pushNamed('/reset-password', arguments: const ResetPasswordArgs());
      case '/login-callback':
        break;
      default:
        break;
    }
  }

  // ── Theme ───────────────────────────────────────────────────────────

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

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(themeModeProvider);
    ref.watch(localeTagProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: CoverWiseSnackBar.scaffoldMessengerKey,
      title: AppConfig.appName,
      theme: CoverWiseTheme.light(),
      darkTheme: CoverWiseTheme.dark(),
      themeMode: _getThemeMode(),
      localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
      supportedLocales: AppLocalizationsGen.supportedLocales,
      locale: ref.watch(activeLocaleProvider),
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
      onUnknownRoute: (settings) {
        debugPrint('Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (_) => _MissingArgsScreen(
            title: 'Page not found',
            message: 'The page you\'re looking for does not exist. '
                'Navigate from the home screen.',
            recoveryRoute: '/',
            recoveryLabel: 'Go home',
          ),
          settings: settings,
        );
      },
      routes: {
        '/qa': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final documentId = switch (args) {
            final String id => id,
            _ => null,
          };
          return ScreenErrorBoundary(
            screenName: 'qa',
            child: QaScreen(initialDocumentId: documentId),
          );
        },
        '/emergency': (context) => const ScreenErrorBoundary(
              screenName: 'emergency',
              child: EmergencyScreen(),
            ),
        '/claims': (context) => const ScreenErrorBoundary(
              screenName: 'claims',
              child: ClaimsAssistantScreen(),
            ),
        '/renewals': (context) => const ScreenErrorBoundary(
              screenName: 'renewals',
              child: RenewalCalendarScreen(),
            ),
        '/coverage-gaps': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final documentId = switch (args) {
            {'documentId': final String id} when id.isNotEmpty => id,
            {'documentId': _} => null,
            _ => null,
          };
          if (documentId == null) {
            return const ScreenErrorBoundary(
              screenName: 'coverage-gaps',
              child: _MissingArgsScreen(
                title: 'Coverage overview',
                message: 'No document was specified. '
                    'Choose a policy in Documents, then open its coverage details.',
                recoveryRoute: '/documents',
                recoveryLabel: 'Choose a policy',
              ),
            );
          }
          return ScreenErrorBoundary(
            screenName: 'coverage-gaps',
            child: CoverageGapScreen(documentId: documentId),
          );
        },
        '/compare': (context) => const ScreenErrorBoundary(
              screenName: 'compare',
              child: PolicyComparisonScreen(),
            ),
        '/what-if': (context) => const ScreenErrorBoundary(
              screenName: 'what-if',
              child: WhatIfCalculatorScreen(),
            ),
        '/settings': (context) => const ScreenErrorBoundary(
              screenName: 'settings',
              child: SettingsScreen(),
            ),
        '/help': (context) => const ScreenErrorBoundary(
              screenName: 'help',
              child: HelpSupportScreen(),
            ),
        '/privacy': (context) => const ScreenErrorBoundary(
              screenName: 'privacy',
              child: PrivacySecurityScreen(),
            ),
        '/about': (context) => const ScreenErrorBoundary(
              screenName: 'about',
              child: AboutScreen(),
            ),
        '/policy-detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final documentId = switch (args) {
            final String id when id.isNotEmpty => id,
            _ => null,
          };
          if (documentId == null) {
            return const ScreenErrorBoundary(
              screenName: 'policy-detail',
              child: _MissingArgsScreen(
                title: 'Policy details',
                message: 'No policy was specified. Open a policy from Documents.',
                recoveryRoute: '/documents',
                recoveryLabel: 'Open documents',
              ),
            );
          }
          return ScreenErrorBoundary(
            screenName: 'policy-detail',
            child: PolicyDetailScreen(documentId: documentId),
          );
        },
        '/claim-tracker': (context) => const ScreenErrorBoundary(
              screenName: 'claim-tracker',
              child: ClaimTrackingScreen(),
            ),
        '/search': (context) => const ScreenErrorBoundary(
              screenName: 'search',
              child: SearchScreen(),
            ),
        '/profile': (context) => const ScreenErrorBoundary(
              screenName: 'profile',
              child: ProfileScreen(),
            ),
        '/insurance-cards': (context) => const ScreenErrorBoundary(
              screenName: 'insurance-cards',
              child: InsuranceCardScreen(),
            ),
        '/literacy': (context) => const ScreenErrorBoundary(
              screenName: 'literacy',
              child: InsuranceLiteracyScreen(),
            ),
        '/account': (context) => const ScreenErrorBoundary(
              screenName: 'account',
              child: AccountScreen(),
            ),
        '/reset-password': (context) => const ScreenErrorBoundary(
              screenName: 'reset-password',
              child: ResetPasswordScreen(),
            ),
        '/family': (context) => const ScreenErrorBoundary(
              screenName: 'family',
              child: FamilyScreen(),
            ),
        '/family/visualization': (context) => const ScreenErrorBoundary(
              screenName: 'family-visualization',
              child: FamilyVisualizationScreen(),
            ),
        '/notifications': (context) => const ScreenErrorBoundary(
              screenName: 'notifications',
              child: NotificationPreferencesScreen(),
            ),
        '/documents': (context) => const ScreenErrorBoundary(
              screenName: 'documents',
              child: DocumentsScreen(),
            ),
      },
      navigatorObservers: [CoverWiseSnackBarObserver()],
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
  final Set<int> _visitedTabs = {0, 1};
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
    _initBilling();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(policySummariesProvider, (prev, next) {
      if (next.isNotEmpty) {
        _scheduleRenewalReminders(next);
      }
    });

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          const AuthExpiredBanner(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const ScreenErrorBoundary(
                  screenName: 'dashboard',
                  child: DashboardScreen(),
                ),
                _visitedTabs.contains(1)
                    ? const ScreenErrorBoundary(
                        screenName: 'policies',
                        child: DocumentsScreen(),
                      )
                    : const SizedBox.shrink(),
                _visitedTabs.contains(2)
                    ? ScreenErrorBoundary(
                        screenName: 'insights',
                        child: const InsightsScreen(),
                      )
                    : const SizedBox.shrink(),
                _visitedTabs.contains(3)
                    ? const ScreenErrorBoundary(
                        screenName: 'profile',
                        child: ProfileScreen(),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/qa'),
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Ask'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
            label: 'Policies',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
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
        _selectedIndex = 1;
        _visitedTabs.add(1);
      });
    });
  }

  void _scheduleRenewalReminders(List<PolicySummary> summaries) {
    if (_notificationsScheduled || summaries.isEmpty) return;
    _notificationsScheduled = true;
    unawaited(NotificationService.scheduleRenewalReminders(summaries));
  }

  void _initBilling() {
    if (!AppConfig.hasRevenueCatConfig) return;
    ref.read(billingInitProvider);
  }
}
