import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations_gen.dart';
import 'config/app_config.dart';
import 'models/identity.dart';
import 'models/reset_password_args.dart';
import 'providers/auth_provider.dart';
import 'providers/entitlement_provider.dart';
import 'providers/policy_providers.dart';
import 'services/analytics_service.dart';
import 'services/app_state_repository.dart';
import 'services/auth_service.dart';
import 'services/install_service.dart';
import 'sync/reconciliation_coordinator.dart';
import 'utils/deep_link_policy.dart';
import 'widgets/shared/coverwise_snackbar.dart';
import 'theme/coverwise_motion.dart';
import 'theme/coverwise_theme.dart';

// Extracted modules
import 'navigation/app_router.dart';
import 'navigation/main_navigation.dart';

// Screens needed only for the home/onboarding flow
import 'screens/documents_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';

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
    // ignore: unused_local_variable rebuild triggers
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
      onUnknownRoute: appOnUnknownRoute,
      routes: buildAppRoutes(),
      navigatorObservers: [CoverWiseSnackBarObserver()],
      debugShowCheckedModeBanner: false,
    );
  }
}
