import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'l10n/app_localizations_gen.dart';
import 'utils/deep_link_policy.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'utils/ref_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/qa_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/family_screen.dart';
import 'screens/family_visualization_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/claims_assistant_screen.dart';
import 'screens/renewal_calendar_screen.dart';
import 'screens/coverage_gap_screen.dart';
import 'models/field_citation.dart';
import 'models/policy_summary.dart';
import 'models/reset_password_args.dart';
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
import 'config/app_config.dart';
import 'providers/entitlement_provider.dart';
import 'providers/policy_providers.dart';
import 'providers/document_providers.dart';
import 'services/local_storage_service.dart';
import 'services/document_service.dart';
import 'services/app_state_store.dart';
import 'services/app_state_repository.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/analytics_service.dart';
import 'services/claims_sync_service.dart';
import 'services/consent_sync_service.dart';
import 'services/install_service.dart';
import 'services/principal_key_service.dart';
import 'services/hive_workspace_service.dart';
import 'services/on_device_inference_service.dart';
import 'providers/auth_provider.dart';
import 'widgets/shared/global_error_boundary.dart';
import 'widgets/shared/screen_error_boundary.dart';
import 'widgets/shared/coverwise_snackbar.dart';
import 'widgets/shared/offline_banner.dart';
import 'widgets/shared/auth_expired_banner.dart';
import 'theme/coverwise_theme.dart';
import 'theme/coverwise_motion.dart';

void main() async {
  // Catch errors in the root zone
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // P0-01: Initialise Sentry crash reporting before any async work so
    // startup errors (including Hive failures, key migration, etc.) are
    // captured. The DSN is injected at build time via --dart-define;
    // Sentry is silently disabled when the DSN is empty.
    if (AppConfig.hasSentryConfig) {
      await SentryFlutter.init(
        (options) {
          options.dsn = AppConfig.sentryDsn;
          options.environment = AppConfig.environment.name;
          options.release = AppConfig.appVersion;
          options.tracesSampleRate = AppConfig.isProduction ? 0.1 : 1.0;
        },
        appRunner: () async {
          // The appRunner callback runs the rest of startup inside
          // Sentry's error-wrapped zone. All code below this block
          // (up to runApp) is now covered by Sentry.
          await _startup();
        },
      );
    } else {
      await _startup();
    }
  }, (error, stackTrace) {
    // Catch zone errors that escape the framework.
    // Always report to Sentry when available; in debug also print locally.
    if (AppConfig.hasSentryConfig) {
      Sentry.captureException(error, stackTrace: stackTrace);
    }
    if (kDebugMode) {
      debugPrint('=== ZONE ERROR ===');
      debugPrint('Error: $error');
      debugPrint('Stack: $stackTrace');
      debugPrint('==================');
    }
  });
}

/// All startup logic after Sentry initialisation (or skip if no DSN).
Future<void> _startup() async {
  // Global error handlers are set up by GlobalErrorBoundary.initState()
  // when the widget tree mounts. No need to duplicate them here.

  AppConfig.validateReleaseConfiguration();
  // The local model lane is opt-in and stays unloaded for normal builds.
  // Model installation is user/operator initiated after a model URL has
  // passed the mobile model and data-handling approval gates.
  if (AppConfig.hasOnDeviceInferenceConfig) {
    await OnDeviceInferenceService().initialize();
  }
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

  // Initialize principal encryption AFTER auth is ready but BEFORE opening encrypted boxes
  // This ensures we have the principal ID for encryption key derivation
  String principalId;
  if (AuthService.hasAccountSession) {
    // For authenticated sessions, use the account user ID
    final currentUser = Supabase.instance.client.auth.currentUser;
    principalId =
        currentUser?.id ?? 'local-only-${InstallService.getInstallId()}';
  } else if (AppConfig.hasSupabaseAuthConfig) {
    // For anonymous sessions, use the Supabase anonymous user ID when the
    // project enables anonymous sign-ins. Some production projects disable
    // that provider while still supporting email/OAuth accounts; in that
    // case the account client remains available and local-only encryption is
    // the safe startup fallback.
    try {
      final anonSession =
          await Supabase.instance.client.auth.signInAnonymously();
      principalId =
          anonSession.user?.id ?? 'local-only-${InstallService.getInstallId()}';
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

  // Initialize local notifications and the device timezone before any
  // policy summaries can trigger renewal reminder scheduling.
  await NotificationService.init();

  // Analytics is initialized eagerly in _InsuranceAppState.initState()
  // via ref.read(analyticsServiceProvider.notifier), which runs during
  // runApp() after Hive/workspace boxes are open.
  // The custom API anonymous identity and the Supabase principal are
  // intentionally separate contracts. Acquire the API token only after the
  // principal-scoped Hive/analytics workspace exists, so identity-created
  // telemetry cannot race an unopened app-state box. AuthInterceptor still
  // retains its first-request acquisition fallback.
  unawaited(_warmAnonymousSession());
  // Reconcile any local consent decisions that could not reach the server
  // during onboarding or an offline upload. The service is principal-scoped
  // and idempotent by current-decision signature.
  unawaited(ConsentSyncService().syncAll());

  // Read stored locale from Hive (box already open) before runApp() so the
  // first frame renders with the correct locale — no language flash.
  final storedLocale = AppStateRepository.getLocale();

  // Check if onboarding has been completed
  final prefs = await SharedPreferences.getInstance();
  final hasOnboarded = prefs.getBool('onboarding_complete') ?? false;

  runApp(
    GlobalErrorBoundary(
      child: ProviderScope(
        overrides: [
          localeTagProvider.overrideWith(
            () => RefState<String?>(storedLocale),
          ),
        ],
        child: InsuranceApp(showOnboarding: !hasOnboarded),
      ),
    ),
  );
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

    // Verify all boxes migrated before clearing the legacy device key.
    // If any box failed, the key must remain so migration can retry
    // on the next launch.
    bool allMigrated = true;
    for (final boxName in boxesToMigrate) {
      if (!await principalKeys.hasMigrationRun(boxName)) {
        debugPrint('Migration incomplete for $boxName — retaining legacy key');
        allMigrated = false;
        break;
      }
    }
    if (allMigrated) {
      final secureStorage = FlutterSecureStorage();
      await secureStorage.delete(
          key: PrincipalKeyService.oldDeviceKeyStorageKey);
      debugPrint('Legacy device-key cleared from secure storage');
    } else {
      debugPrint('Legacy device-key retained — some boxes did not migrate');
    }
  } catch (e) {
    debugPrint('Error during Hive box migration: $e');
    // Do not open the new-key workspace after a failed migration: doing so
    // would hide the legacy data behind an unreadable new-key box. The zone
    // boundary surfaces startup failure and the next launch can retry.
    rethrow;
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// The principal ID that is currently being transitioned to. Used to
  /// detect stale transitions and serialize concurrent auth events.
  String? _desiredPrincipalId;

  /// Monotonically increasing epoch for each principal change. Used to
  /// discard stale reconciliation results after a newer transition.
  int _principalEpoch = 0;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider.notifier);
    _showOnboarding = widget.showOnboarding;

    // M10: locale was already loaded in _startup() and passed via
    // ProviderScope override — no initState read needed, no flash.

    _authSubscription = ref.listenManual<AsyncValue<AuthState>>(
      authStateProvider,
      (_, next) {
        final session = next.asData?.value.session;
        if (session != null) {
          // Authenticated session arrived — transition workspace.
          final principalId = session.user.id;
          ref.read(authServiceProvider.notifier).updateSessionExpired(false);

          final preserveWorkspace =
              AuthService.consumeAnonymousWorkspaceClaim();
          _desiredPrincipalId = principalId;
          _principalEpoch++;
          final epoch = _principalEpoch;

          unawaited(_handleAuthenticatedSessionTransition(
            principalId,
            preserveCurrentWorkspace: preserveWorkspace,
            principalEpoch: epoch,
          ).then((_) => _retryPendingUploads(epoch: epoch)));
          unawaited(_syncClaims(epoch: epoch));
          if (AppConfig.hasRevenueCatConfig) {
            unawaited(
                ref.read(billingAdapterProvider).identifyAccount(principalId));
          }
        } else {
          // Session became null — user signed out or session expired.
          // Transition to local-only workspace and clear the old principal's
          // encryption key from memory.
          PrincipalKeyService().clearKey();
          final localPrincipal = 'local-only-${InstallService.getInstallId()}';
          _desiredPrincipalId = localPrincipal;
          _principalEpoch++;
          final epoch = _principalEpoch;

          unawaited(_handleAuthenticatedSessionTransition(
            localPrincipal,
            preserveCurrentWorkspace: false,
            principalEpoch: epoch,
          ));
        }
      },
    );
    _initDeepLinks();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(_retryPendingUploads());
        unawaited(_syncClaims());
      }
    });
    unawaited(_retryPendingUploads());
    unawaited(_syncClaims());
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _authSubscription?.close();
    super.dispose();
  }

  /// Epoch-gated upload reconciliation. Stale requests are discarded
  /// both before and after the work to prevent cross-principal data
  /// corruption.
  Future<void> _retryPendingUploads({int? epoch}) async {
    final e = epoch ?? _principalEpoch;
    // Discard stale requests early — do not execute work for a
    // principal that is no longer desired.
    if (e != _principalEpoch) return;
    try {
      await DocumentService(DocumentService.authenticatedDio)
          .retryPendingUploads();
      if (mounted && e == _principalEpoch) {
        ref.invalidate(documentsProvider);
      }
    } catch (error) {
      debugPrint('Pending upload reconciliation failed: $error');
    }
  }

  /// Epoch-gated claims sync. Stale requests are discarded both
  /// before and after the work.
  Future<void> _syncClaims({int? epoch}) async {
    final e = epoch ?? _principalEpoch;
    if (e != _principalEpoch) return;
    try {
      final syncService = ClaimsSyncService(ClaimsSyncService.authenticatedDio);
      final result = await syncService.fullSync();
      if (result.errorMessage != null) {
        debugPrint('Claims sync failed: ${result.errorMessage}');
      }
    } catch (error) {
      debugPrint('Claims sync error: $error');
    }
  }

  Future<void> _handleAuthenticatedSessionTransition(
    String principalId, {
    bool preserveCurrentWorkspace = false,
    required int principalEpoch,
  }) async {
    // If a newer transition has been requested since this one started,
    // skip the workspace reopen — the newer request will handle it.
    if (principalEpoch != _principalEpoch ||
        _desiredPrincipalId != principalId) {
      return;
    }

    try {
      await _reopenWorkspaceForPrincipal(
        principalId,
        preserveCurrentWorkspace: preserveCurrentWorkspace,
      );
    } catch (error) {
      // Workspace transition failure is logged and observed but does not
      // propagate to the zone handler via rethrow. The caller (unawaited)
      // cannot catch zone-level exceptions. The workspace remains in its
      // previous state and the user sees stale or empty data until retry.
      debugPrint('Workspace transition failed (epoch $principalEpoch): $error');
      return;
    }

    if (!preserveCurrentWorkspace) return;

    // Only claim anonymous data if this is still the desired principal.
    if (principalEpoch != _principalEpoch ||
        _desiredPrincipalId != principalId) {
      return;
    }
    try {
      await AuthService.claimAnonymousData();
    } catch (error) {
      debugPrint(
          'Anonymous workspace claim failed after auth transition: $error');
    }
  }

  Future<void> _reopenWorkspaceForPrincipal(
    String principalId, {
    bool preserveCurrentWorkspace = false,
  }) async {
    if (PrincipalKeyService().principalId == principalId) {
      return;
    }
    // Do not carry account A's buffered analytics into account B's session.
    ref.read(analyticsServiceProvider.notifier).resetForWorkspace();
    await HiveWorkspaceService.resetForPrincipal(
      principalId,
      preserveCurrentWorkspace: preserveCurrentWorkspace,
    );
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

    // Validate the deep link against the security policy before routing.
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
        // Only accept a bounded documentId identifier from the URL.
        // Citations, extracted text, confidence values, and other evidence
        // must NEVER come from deep links — they are loaded from the
        // authenticated backend or verified local workspace.
        final docId = uri.queryParameters['documentId'] ?? '';
        nav.pushNamed('/coverage-gaps', arguments: {
          'documentId': docId,
          // Citations are fetched from the backend by CoverageGapScreen.
        });
      case '/compare':
        nav.pushNamed('/compare');
      case '/what-if':
        nav.pushNamed('/what-if');
      case '/qa':
        final docId = uri.queryParameters['documentId'];
        nav.pushNamed('/qa', arguments: docId);
      case '/reset-callback':
        // Password reset redirect from Supabase email link.
        // Supabase handles the token exchange internally via the deep link.
        // Do NOT pass the raw URI — it may contain auth material in the
        // fragment that would leak through route settings, crash breadcrumbs,
        // and debug logs. ResetPasswordScreen calls Supabase auth.updateUser()
        // directly and does not need the redirect URL.
        nav.pushNamed('/reset-password', arguments: const ResetPasswordArgs());
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
    // Watch locale changes — rebuilds MaterialApp when user changes language.
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
          return ScreenErrorBoundary(
            screenName: 'qa',
            child: QaScreen(initialDocumentId: args),
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
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final documentId = args?['documentId'] as String?;
          if (documentId == null || documentId.isEmpty) {
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
          // Deep links pass citations as URL-encoded JSON arrays of raw maps,
          // not pre-deserialized FieldCitation objects. Deserialize them here.
          final citationsRaw = args?['citations'];
          final citations = citationsRaw is List
              ? citationsRaw
                  .whereType<Map<String, dynamic>>()
                  .map(FieldCitation.fromJson)
                  .toList()
              : const <FieldCitation>[];
          return ScreenErrorBoundary(
            screenName: 'coverage-gaps',
            child: CoverageGapScreen(
              documentId: documentId,
              citations: citations,
            ),
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
          final documentId = args is String ? args : null;
          if (documentId == null || documentId.isEmpty) {
            return const ScreenErrorBoundary(
              screenName: 'policy-detail',
              child: _MissingArgsScreen(
                title: 'Policy details',
                message:
                    'No policy was specified. Open a policy from Documents.',
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
    _initBilling();
  }

  @override
  Widget build(BuildContext context) {
    // Schedule renewal reminders when summaries are loaded (once per session).
    // Side effects must not run inside build(); use a listener instead.
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
    // Schedule asynchronously — never inside build().
    unawaited(NotificationService.scheduleRenewalReminders(summaries));
  }

  void _initBilling() {
    if (!AppConfig.hasRevenueCatConfig) return;
    // Kick off RevenueCat billing init + entitlement sync.
    // Use ref.read to trigger the FutureProvider's auto-run exactly once.
    ref.read(billingInitProvider);
  }
}
