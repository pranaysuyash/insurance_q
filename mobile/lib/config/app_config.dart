import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';


/// The deployment environment for the current build.
///
/// Parsed from the compile-time `ENVIRONMENT` define. Any unrecognised value
/// fails at parse time so that a misconfigured release cannot silently bypass
/// validation. This is a product-contract decision, not a debug toggle.
enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment parse(String value) => switch (value) {
        'development' => AppEnvironment.development,
        'staging' => AppEnvironment.staging,
        'production' => AppEnvironment.production,
        _ => throw StateError('Unsupported ENVIRONMENT: "$value". '
            'Must be one of: development, staging, production.'),
      };
}

/// Whether a third-party integration is required, optional, or disabled.
///
/// - [required]: The app cannot function safely without this integration.
///   A missing required integration fails [validateReleaseConfiguration].
/// - [optional]: The integration provides value but the app degrades
///   gracefully when it is absent (e.g., Sentry crash reporting,
///   RevenueCat billing, on-device inference).
/// - [disabled]: The integration is intentionally turned off for this build.
///
/// Every feature getter in [AppConfig] returns a [FeatureAvailability] so
/// that callers can distinguish "configured and ready" from "intentionally
/// absent" from "misconfigured but we're letting the app degrade".
enum FeatureAvailability {
  /// Required for safe operation — build fails if unconfigured.
  required,

  /// Optional — the app degrades gracefully when absent.
  optional,

  /// Intentionally disabled for this build.
  disabled;
}

/// Build-time configuration for the CoverWise app.
///
/// Sensible defaults for compile-time `--dart-define` values. Never embed a
/// production API URL in the binary — the deployed backend is a release
/// contract set at build time.
///
/// Validation helpers that do not involve build configuration (email, phone,
/// disposable-domain lists) should migrate to `domain/contact/`.
class AppConfig {
  // ── Build-time constants ──────────────────────────────────────

  /// Runtime-applicable path for AppConfig caches that must reference
  /// an environment-specific root. Set by [init] at startup.
  /// Populated from `package_info_plus` at startup if [init] is called,
  /// otherwise falls back to a build-time default for tests and screens
  /// that display before startup completes.
  static String appVersion = '0.1.2+11'; // default; overridden by init()

  static final AppEnvironment environment = AppEnvironment.parse(
      String.fromEnvironment('ENVIRONMENT', defaultValue: 'production'));

  static const bool bootstrapPolicyDemo = bool.fromEnvironment(
    'BOOTSTRAP_POLICY_DEMO',
    defaultValue: false,
  );
  static const bool onDeviceInferenceEnabled = bool.fromEnvironment(
    'ON_DEVICE_INFERENCE_ENABLED',
    defaultValue: false,
  );
  static const String onDeviceModelUrl = String.fromEnvironment(
    'ON_DEVICE_MODEL_URL',
    defaultValue: '',
  );

  // A1-P1f: Model manifest fields — turning a naked URL into a verifiable
  // download contract. All fields are required when on-device inference is
  // enabled.
  static const String onDeviceModelVersion = String.fromEnvironment(
    'ON_DEVICE_MODEL_VERSION',
    defaultValue: '',
  );
  static const String onDeviceModelSha256 = String.fromEnvironment(
    'ON_DEVICE_MODEL_SHA256',
    defaultValue: '',
  );
  static const int onDeviceModelSize = int.fromEnvironment(
    'ON_DEVICE_MODEL_SIZE',
    defaultValue: 0,
  );
  static const String onDeviceModelProvenance = String.fromEnvironment(
    'ON_DEVICE_MODEL_PROVENANCE',
    defaultValue: '',
  );

  // Release addresses injected at build time.
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String privacyPolicyUrl =
      String.fromEnvironment('PRIVACY_POLICY_URL', defaultValue: '');
  static const String termsOfServiceUrl =
      String.fromEnvironment('TERMS_OF_SERVICE_URL', defaultValue: '');
  static const String supportEmail =
      String.fromEnvironment('SUPPORT_EMAIL', defaultValue: '');
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabasePublishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue:
          String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''));
  static const String privacyPolicyVersion = String.fromEnvironment(
      'PRIVACY_POLICY_VERSION',
      defaultValue: 'development-unversioned');

  // RevenueCat public SDK key (never embed a RevenueCat secret).
  static const String revenuecatApiKey =
      String.fromEnvironment('REVENUECAT_API_KEY', defaultValue: '');

  // Redirect URIs for Supabase auth flows. Must be allowlisted in the
  // Supabase project's Authentication > URL Configuration settings.
  // These are not secrets — they are public client configuration values
  // that must match the Supabase dashboard configuration.
  static const String loginRedirectUri =
      String.fromEnvironment('LOGIN_REDIRECT_URI', defaultValue: 'io.coverwise://login-callback');
  static const String resetPasswordRedirectUri =
      String.fromEnvironment('RESET_PASSWORD_REDIRECT_URI', defaultValue: 'io.coverwise://reset-callback');

  // Sentry DSN — silently disabled when empty.
  static const String sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  // Trust UI gates — REMOVED (A1-P0.3).
  //
  // confidenceCalibrated and contextualRetrievalEnabled are now server-
  // provided fields in [CapabilitiesResponse]. A compile-time constant
  // cannot prove calibration state because a stale binary may disagree
  // with the currently deployed backend.
  //
  // Use capabilitiesService.latest.confidenceCalibrated and
  // capabilitiesService.latest.contextualRetrievalEnabled instead.

  // App metadata
  static const String appName = 'CoverWise';

  // Upload constraints — conservative client limits.
  // Authoritative limits come from the backend capabilities endpoint.
  // These are UX-only guards; the backend enforces the real limits.
  // A1-P1b: Static defaults are the fallback when GET /capabilities is
  // unavailable. [CapabilitiesService] and [capabilitiesProvider] are the
  // primary source; services that have Riverpod access should prefer
  // [latestCapabilities] over these raw constants.
  static const int maxUploadFileSizeBytes = 20 * 1024 * 1024; // 20 MiB
  static const int maxUploadFileSizeMB =
      maxUploadFileSizeBytes ~/ (1024 * 1024);

  // Rate limiting — conservative UX constraint; backend is authoritative.
  // A1-P1b: Same fallback pattern — static defaults replaced by
  // [CapabilitiesResponse] when the endpoint is reachable.
  static const int defaultSessionLimit = 5;
  static const int defaultIpLimit = 10;
  static const Duration sessionDuration = Duration(hours: 24);

  // Timeouts — sentinel defaults for the network layer.
  // A1-P1b: [CapabilitiesResponse.connectTimeoutSeconds] and
  // [CapabilitiesResponse.receiveTimeoutSeconds] override these when
  // the backend /capabilities endpoint is available.
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 90);

  // Backward-compatible integer accessors for callers that still reference
  // connectTimeoutSeconds / receiveTimeoutSeconds.
  static int get connectTimeoutSeconds => connectTimeout.inSeconds;
  static int get receiveTimeoutSeconds => receiveTimeout.inSeconds;

  // Debug toggles
  static const bool enableDebugLogs = false;
  static const bool enableNetworkLogs = false;

  // ── Environment helpers ───────────────────────────────────────

  static bool get isProduction => environment == AppEnvironment.production;
  static bool get isDevelopment => environment == AppEnvironment.development;
  static bool get isStaging => environment == AppEnvironment.staging;

  /// Parsed, validated API base URI.
  static Uri get baseUri {
    if (_configuredBaseUrl.isNotEmpty) {
      final uri = Uri.tryParse(_configuredBaseUrl.trim());
      if (uri == null || uri.host.isEmpty) {
        throw StateError(
            'API_BASE_URL must be a valid URI with a non-empty host');
      }
      if (uri.userInfo.isNotEmpty) {
        throw StateError('API_BASE_URL must not contain embedded credentials');
      }
      if (uri.hasQuery) {
        throw StateError('API_BASE_URL must not contain query parameters');
      }
      if (uri.hasFragment) {
        throw StateError('API_BASE_URL must not contain a fragment');
      }
      if (uri.scheme != 'https' && environment != AppEnvironment.development) {
        throw StateError('API_BASE_URL must use HTTPS in $environment');
      }
      return uri;
    }
    if (environment == AppEnvironment.development) {
      return Uri.parse('http://localhost:8000');
    }
    throw StateError('API_BASE_URL is required in $environment');
  }

  /// Backward-compatible string accessor for the base URL.
  static String get baseUrl =>
      baseUri.toString().replaceFirst(RegExp(r'/+$'), '');

  // API endpoints
  static String get healthEndpoint => '$baseUrl/health';
  static String get queryEndpoint => '$baseUrl/query';
  static String get uploadEndpoint => '$baseUrl/documents/upload';
  static String get usageStatsEndpoint => '$baseUrl/documents/usage-stats';
  static String get docsEndpoint => '$baseUrl/docs';
  static String get subscriptionSyncEndpoint => '$baseUrl/subscription/sync';
  static String get qaPackBalanceEndpoint => '$baseUrl/subscription/qa-balance';

  // ── Integration-availability helpers (no private methods) ─────

  /// On-device inference — optional. Falls back to server-side inference.
  /// A1-P1e: Classified as [FeatureAvailability.optional]; the model lane is
  /// opt-in and the app degrades gracefully when unconfigured.
  static FeatureAvailability get onDeviceInferenceFeature =>
      hasOnDeviceInferenceConfig
          ? FeatureAvailability.optional
          : FeatureAvailability.disabled;

  /// The full model manifest, or null if on-device inference is disabled or
  /// any required manifest field is missing/empty.
  static OnDeviceModelManifest? get onDeviceModelManifest {
    if (!onDeviceInferenceEnabled) return null;
    if (onDeviceModelUrl.isEmpty ||
        onDeviceModelVersion.isEmpty ||
        onDeviceModelSha256.isEmpty ||
        onDeviceModelSize <= 0 ||
        onDeviceModelProvenance.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(onDeviceModelUrl.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return OnDeviceModelManifest(
      url: uri,
      version: onDeviceModelVersion,
      sha256: onDeviceModelSha256,
      sizeBytes: onDeviceModelSize,
      provenance: onDeviceModelProvenance,
    );
  }

  /// Whether on-device inference is configured with a valid model manifest.
  /// Replaces the old URL-only check with a full manifest validation.
  /// A1-P1f: Now requires all manifest fields to be present.
  static bool get hasOnDeviceInferenceConfig =>
      onDeviceModelManifest != null;

  /// The model download URL from the validated manifest.
  /// Falls back to the raw [onDeviceModelUrl] string for backward
  /// compatibility when the manifest is incomplete.
  /// **Callers must check [hasOnDeviceInferenceConfig] before using — the
  /// fallback is NOT validated for HTTPS or structural correctness.**
  static String get resolvedOnDeviceModelUrl =>
      onDeviceModelManifest?.url.toString() ?? onDeviceModelUrl;

  static bool get hasPrivacyPolicy {
    if (privacyPolicyUrl.isEmpty) return false;
    final uri = Uri.tryParse(privacyPolicyUrl.trim());
    return uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.scheme == 'https';
  }

  static bool get hasTermsOfService {
    if (termsOfServiceUrl.isEmpty) return false;
    final uri = Uri.tryParse(termsOfServiceUrl.trim());
    return uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.scheme == 'https';
  }

  /// Whether a support email is configured and structurally valid.
  /// Format validation uses a minimal regex — disposable-domain detection
  /// is unnecessary for a compile-time constant. For user-input validation,
  /// use [ContactValidator] from `domain/contact/`.
  static bool get hasSupportEmail {
    if (supportEmail.isEmpty) return false;
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(supportEmail);
  }

  /// Supabase authentication — optional. The app works in local-only mode
  /// without a Supabase project. When configured, provides auth, storage,
  /// and DB-backed features.
  /// A1-P1e: Classified as [FeatureAvailability.optional]; auth degrades to
  /// local-only principal when Supabase is absent.
  static FeatureAvailability get supabaseFeature =>
      hasSupabaseAuthConfig
          ? FeatureAvailability.optional
          : FeatureAvailability.disabled;

  static bool get hasSupabaseAuthConfig {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) return false;
    final uri = Uri.tryParse(supabaseUrl.trim());
    return uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.scheme == 'https';
  }

  /// RevenueCat subscriptions — optional. Billing gracefully degrades to
  /// free-tier-only when RevenueCat is absent. Entitlement checks return
  /// default values and subscription-related UI elements are hidden.
  /// A1-P1e: Classified as [FeatureAvailability.optional]; billing surfaces
  /// cleanly disable themselves when unconfigured.
  static FeatureAvailability get revenueCatFeature =>
      hasRevenueCatConfig
          ? FeatureAvailability.optional
          : FeatureAvailability.disabled;

  static bool get hasRevenueCatConfig => revenuecatApiKey.isNotEmpty;

  /// Sentry crash reporting — optional. Telemetry degrades gracefully.
  /// [Sentry.captureException] and [Sentry.configureScope] are safe no-ops
  /// when the SDK is not initialized.
  /// A1-P1e: Classified as [FeatureAvailability.optional]; all Sentry calls
  /// are guarded by hasSentryConfig and the SDK provides safe no-ops when
  /// uninitialized.
  static FeatureAvailability get sentryFeature =>
      hasSentryConfig
          ? FeatureAvailability.optional
          : FeatureAvailability.disabled;

  static bool get hasSentryConfig => sentryDsn.isNotEmpty;

  // ── Release validation ────────────────────────────────────────

  /// Initialise runtime-configurable values that depend on package info.
  /// Must be called early in startup (before Sentry init) so that
  /// [appVersion] is available for crash-report tagging, about-screen
  /// display, etc. Safe to call multiple times — subsequent calls are no-ops.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (e) {
      debugPrint('AppConfig.init: failed to read package info ($e); '
          'using fallback version "$appVersion"');
    }
    _initialized = true;
  }

  static bool _initialized = false;

  static void validateReleaseConfiguration() {
    // Development builds skip validation — they intentionally use
    // localhost, unversioned policies, and test configurations.
    // Staging and production builds MUST pass all checks.
    if (environment == AppEnvironment.development) return;
    final errors = <String>[];
    bool httpsOk(String v) {
      if (v.isEmpty) return false;
      final u = Uri.tryParse(v.trim());
      return u != null &&
          u.host.isNotEmpty &&
          u.userInfo.isEmpty &&
          !u.hasQuery &&
          !u.hasFragment &&
          u.scheme == 'https';
    }

    if (!httpsOk(_configuredBaseUrl) &&
        environment != AppEnvironment.development) {
      errors.add('API_BASE_URL must be a valid HTTPS URL');
    }
    if (!hasPrivacyPolicy) {
      errors.add('PRIVACY_POLICY_URL must be a valid HTTPS URL');
    }
    if (!hasTermsOfService) {
      errors.add('TERMS_OF_SERVICE_URL must be a valid HTTPS URL');
    }
    if (!hasSupportEmail) {
      errors.add('SUPPORT_EMAIL must be a valid email address');
    }
    if (privacyPolicyVersion == 'development-unversioned') {
      errors.add('PRIVACY_POLICY_VERSION is required');
    }
    if (bootstrapPolicyDemo) {
      errors.add('BOOTSTRAP_POLICY_DEMO cannot be enabled in a release build');
    }
    // A1-P1f: When on-device inference is enabled, all manifest fields
    // must be present. A staging/production build with a partial manifest
    // fails validation rather than silently degrading to disabled.
    if (onDeviceInferenceEnabled) {
      if (!httpsOk(onDeviceModelUrl)) {
        errors.add(
          'ON_DEVICE_MODEL_URL must be a valid HTTPS URL '
          'when on-device inference is enabled',
        );
      }
      if (onDeviceModelVersion.isEmpty) {
        errors.add(
          'ON_DEVICE_MODEL_VERSION is required when '
          'on-device inference is enabled',
        );
      }
      if (onDeviceModelSha256.isEmpty) {
        errors.add(
          'ON_DEVICE_MODEL_SHA256 is required when '
          'on-device inference is enabled',
        );
      }
      if (onDeviceModelSize <= 0) {
        errors.add(
          'ON_DEVICE_MODEL_SIZE must be > 0 when '
          'on-device inference is enabled',
        );
      }
      if (onDeviceModelProvenance.isEmpty) {
        errors.add(
          'ON_DEVICE_MODEL_PROVENANCE is required when '
          'on-device inference is enabled',
        );
      }
    }
    // Redirect URIs use custom URL schemes (e.g. io.coverwise://) for
    // mobile deep links — they are NOT HTTPS. Validate only that the URI
    // is structurally valid (non-empty host, no credentials/query/fragment).
    if (!_isValidRedirectUri(loginRedirectUri)) {
      errors.add('LOGIN_REDIRECT_URI must be a valid redirect URI '
          '(custom scheme, non-empty host, no query/fragment/credentials)');
    }
    if (!_isValidRedirectUri(resetPasswordRedirectUri)) {
      errors.add('RESET_PASSWORD_REDIRECT_URI must be a valid redirect URI '
          '(custom scheme, non-empty host, no query/fragment/credentials)');
    }

    // A1-P1e: Required-integration enforcement goes here.
    // When a third-party integration is classified as
    // [FeatureAvailability.required] and its configuration is absent, add a
    // check that appends to [errors]. No integrations are currently required.

    if (errors.isNotEmpty) {
      throw StateError(
          'Invalid CoverWise release configuration: ${errors.join('; ')}');
    }
  }

  /// Validates that a redirect URI is structurally sound for mobile auth flows.
  /// Accepts custom URL schemes (e.g. `io.coverwise://login-callback`) — unlike
  /// [httpsOk] which requires the HTTPS scheme.
  static bool _isValidRedirectUri(String v) {
    if (v.isEmpty) return false;
    final u = Uri.tryParse(v.trim());
    return u != null &&
        u.host.isNotEmpty &&
        u.userInfo.isEmpty &&
        !u.hasQuery &&
        !u.hasFragment;
  }
}

/// A1-P1f: Model manifest — turns a naked download URL into a verifiable
/// contract. All fields are required for [AppConfig.onDeviceModelManifest]
/// to return a non-null value.
///
/// Fields:
///   [url] — HTTPS download URL for the model binary
///   [version] — semver or release tag identifying the model version
///   [sha256] — hex-encoded SHA-256 hash for integrity verification
///   [sizeBytes] — expected file size in bytes for download validation
///   [provenance] — license/source attribution (e.g. "Google Gemma 2B IT")
class OnDeviceModelManifest {
  /// HTTPS download URL for the model binary.
  final Uri url;

  /// Semantic version or release tag (e.g. "1.2.0").
  final String version;

  /// Hex-encoded SHA-256 hash for integrity verification.
  final String sha256;

  /// Expected file size in bytes.
  final int sizeBytes;

  /// License and source attribution for the model.
  /// E.g. "Google Gemma 2B IT — Google Terms of Use".
  final String provenance;

  const OnDeviceModelManifest({
    required this.url,
    required this.version,
    required this.sha256,
    required this.sizeBytes,
    required this.provenance,
  });

  @override
  String toString() =>
      'OnDeviceModelManifest(url: $url, version: $version, '
      'sha256: $sha256, sizeBytes: $sizeBytes, provenance: $provenance)';
}
