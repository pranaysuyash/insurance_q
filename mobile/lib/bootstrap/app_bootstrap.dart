import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/identity.dart';
import '../providers/capabilities_provider.dart';
import '../providers/policy_providers.dart';
import '../services/app_state_repository.dart';
import '../services/auth_service.dart';
import '../services/hive_workspace_service.dart';
import '../services/install_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/on_device_inference_service.dart';
import '../services/principal_key_service.dart';
import '../services/app_state_store.dart';
import '../services/consent_sync_service.dart';
import '../utils/ref_state.dart';
import '../widgets/shared/global_error_boundary.dart';

import '../app.dart';

/// Runs the full application bootstrap sequence.
///
/// This is the composition root that orchestrates:
/// 1. Configuration validation
/// 2. Sentry crash reporting init
/// 3. Hive local storage init
/// 4. Supabase auth init
/// 5. Principal resolution
/// 6. Legacy migration
/// 7. Workspace opening
/// 8. Deferred non-critical work (notifications, on-device inference, API token)
/// 9. `runApp()` with ProviderScope and error boundary
///
/// Extracted from main.dart to keep the composition root under 100 lines.
Future<void> runAppBootstrap() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Read package info (version + build number) before any other async work
    // so AppConfig.appVersion is available for Sentry tagging and display.
    await AppConfig.init();

    // Initialise Sentry crash reporting before any async work so startup
    // errors are captured. Sentry is silently disabled when the DSN is empty.
    if (AppConfig.hasSentryConfig) {
      await SentryFlutter.init(
        (options) {
          options.dsn = AppConfig.sentryDsn;
          options.environment = AppConfig.environment.name;
          options.release = AppConfig.appVersion;
          options.tracesSampleRate = AppConfig.isProduction ? 0.1 : 1.0;
          options.sendDefaultPii = false;
        },
        appRunner: () async => await _startup(),
      );
    } else {
      await _startup();
    }
  }, (error, stackTrace) {
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
  AppConfig.validateReleaseConfiguration();

  await Hive.initFlutter();

  // Initialize Supabase directly at bootstrap, before runApp().
  // The previous approach delegated to AuthNotifier via
  // AuthService.initializeAccountClient(), but the notifier doesn't
  // exist until runApp() creates the ProviderScope.
  if (AppConfig.hasSupabaseAuthConfig) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
  }

  // Load the persisted anonymous workspace claim flag from secure storage.
  // Bridges across process death into the synchronous
  // consumeAnonymousWorkspaceClaim() call in the auth listener.
  await AuthService.loadPersistedClaimFlag();

  // Load install identity before AnalyticsService.init() runs.
  await InstallService.ensureInitialized();

  // Initialize principal encryption AFTER auth is ready but BEFORE
  // opening encrypted boxes.
  final principal = _resolvePrincipal();

  await PrincipalKeyService().initForPrincipal(principal.principalId);

  // Migrate existing Hive boxes from device-key to principal-key encryption.
  await migrateLegacyHiveBoxes(principal);

  // Open encrypted Hive boxes at the principal's namespaced path.
  await HiveWorkspaceService.openForActivePrincipal(principal);

  // Warm the capabilities cache asynchronously so the first provider
  // access finds the server value (or falls back to AppConfig defaults).
  unawaited(capabilitiesService.fetch());

  // Defer non-critical startup work to after runApp().
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(NotificationService.init());
    if (AppConfig.hasOnDeviceInferenceConfig) {
      unawaited(OnDeviceInferenceService().initialize());
    }
    // Deferred Supabase anonymous sign-in.
    if (AppConfig.hasSupabaseAuthConfig && !AuthService.hasAccountSession) {
      unawaited(() async {
        try {
          await Supabase.instance.client.auth.signInAnonymously();
        } catch (e) {
          debugPrint('Anonymous sign-in (deferred) unavailable: $e');
        }
      }());
    }
    // Deferred API token acquisition.
    unawaited(_warmApiToken());
  });

  // Reconcile any local consent decisions that could not reach the server.
  unawaited(ConsentSyncService().syncAll());

  // CW-P0-004: Pull server consent authority into the local cache.
  // The server is the source of truth — if consent was revoked on another
  // device, the local cache must update before any upload gate checks it.
  unawaited(ConsentSyncService().pullFromServer());

  // Read stored locale before runApp() so the first frame renders correctly.
  final storedLocale = AppStateRepository.getLocale();

  // Check if onboarding has been completed.
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

/// Resolves the workspace principal based on the current auth state.
WorkspacePrincipal _resolvePrincipal() {
  if (AuthService.hasAccountSession) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser?.id != null) {
      return AccountPrincipal(currentUser!.id);
    }
  }
  // Local-only principal uses the persisted install id (stable until uninstall).
  return LocalPrincipal(InstallService.getInstallId());
}

/// Migrates legacy Hive boxes from device-key encryption to principal-scoped
/// DEK encryption. Checks for a stale migration journal on startup and retries
/// if a previous migration was interrupted.
Future<void> migrateLegacyHiveBoxes(WorkspacePrincipal principal) async {
  try {
    final principalKeys = PrincipalKeyService();
    if (!await principalKeys.hasLegacyDeviceKey()) {
      debugPrint('No legacy Hive key; migration is not required.');
      return;
    }

    final workspacePath = HiveWorkspaceService.workspacePathFor(principal);

    // Check for stale migration journal from a previous interrupted run.
    final staleJournalBox = await principalKeys.readMigrationJournal();
    if (staleJournalBox != null) {
      debugPrint('Stale migration journal found for "$staleJournalBox" — retrying...');
      try {
        await principalKeys.migrateBox(
          boxName: staleJournalBox,
          boxPath: '',
          targetPath: workspacePath,
        );
        debugPrint('Stale journal migration retry completed for "$staleJournalBox"');
      } catch (e) {
        try {
          final testBox = await Hive.openBox(
            staleJournalBox,
            path: workspacePath,
            encryptionCipher: HiveAesCipher(principalKeys.getOrThrow()),
          );
          final entryCount = testBox.length;
          await testBox.close();
          if (entryCount > 0) {
            await principalKeys.markMigrationComplete(staleJournalBox);
            debugPrint('Stale journal recovered: $entryCount entries in "$staleJournalBox"');
          } else {
            debugPrint('Stale journal: "$staleJournalBox" is empty after crash');
          }
        } catch (innerError) {
          debugPrint('Stale journal: cannot verify "$staleJournalBox": $e');
        }
      }
      await principalKeys.clearMigrationJournal();
    }

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
      final migrationCompleted = await principalKeys.migrateBox(
        boxName: boxName,
        boxPath: '',
        targetPath: workspacePath.isNotEmpty ? workspacePath : null,
      );
      if (migrationCompleted) {
        debugPrint('Successfully migrated Hive box: $boxName');
      } else {
        debugPrint('Migration skipped or already completed for: $boxName');
      }
    }

    // Verify all boxes migrated before clearing the legacy device key.
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
      await secureStorage.delete(key: PrincipalKeyService.oldDeviceKeyStorageKey);
      debugPrint('Legacy device-key cleared from secure storage');
    } else {
      debugPrint('Legacy device-key retained — some boxes did not migrate');
    }
  } catch (e) {
    debugPrint('Error during Hive box migration: $e');
    rethrow;
  }
}

/// Warm the API token cache outside the critical startup path.
Future<void> _warmApiToken() async {
  if (await AuthService.accessToken() != null) return;
  final tempDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
  await AuthService.acquireToken(tempDio);
}
