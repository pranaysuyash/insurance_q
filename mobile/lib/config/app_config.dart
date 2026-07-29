import 'package:flutter/foundation.dart';

import '../domain/contact/contact_validator.dart';

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

  static const String appVersion = '0.1.2+11';

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

  // Sentry DSN — silently disabled when empty.
  static const String sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  // Trust UI gates — client may hide risky UI, but backend is the source
  // of truth for calibration and pipeline capability.
  //
  // These are LOCAL PRESENTATION GATES ONLY. They control whether the
  // client renders trust-sensitive UI elements (e.g., confidence badges).
  // They must NEVER be the source of truth for whether a backend
  // capability exists. The server must return answer-level provenance
  // (calibration ID, pipeline version, retrieval mode) and the client
  // uses these flags only to decide whether to display trust UI.
  //
  // Long-term: these should be replaced by a server-provided
  // RuntimeCapabilities response, but as kill switches / presentation
  // gates they remain useful for emergency UI hiding.
  static const bool confidenceCalibrated = bool.fromEnvironment(
    'CONFIDENCE_CALIBRATED',
    defaultValue: false,
  );
  static const bool contextualRetrievalEnabled = bool.fromEnvironment(
    'CONTEXTUAL_RETRIEVAL_ENABLED',
    defaultValue: false,
  );

  // App metadata
  static const String appName = 'CoverWise';

  // Upload constraints — conservative client limits.
  // Authoritative limits come from the backend capabilities endpoint.
  // These are UX-only guards; the backend enforces the real limits.
  static const int maxUploadFileSizeBytes = 20 * 1024 * 1024; // 20 MiB
  static const int maxUploadFileSizeMB =
      maxUploadFileSizeBytes ~/ (1024 * 1024);

  // Rate limiting — conservative UX constraint; backend is authoritative.
  static const int defaultSessionLimit = 5;
  static const int defaultIpLimit = 10;
  static const Duration sessionDuration = Duration(hours: 24);

  // Timeouts — sentinel defaults for the network layer.
  // Operation-level timeouts (health-check, upload, query) should be set
  // in the network layer with appropriate per-operation values.
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

  static bool get hasOnDeviceInferenceConfig {
    if (!onDeviceInferenceEnabled) return false;
    final uri = Uri.tryParse(onDeviceModelUrl.trim());
    return uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

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

  static bool get hasSupportEmail {
    if (supportEmail.isEmpty) return false;
    return ContactValidator.isValidEmail(supportEmail);
  }

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

  static bool get hasRevenueCatConfig => revenuecatApiKey.isNotEmpty;
  static bool get hasSentryConfig => sentryDsn.isNotEmpty;

  // ── Release validation ────────────────────────────────────────

  static void validateReleaseConfiguration() {
    if (!kReleaseMode) return;
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
    if (onDeviceInferenceEnabled && !httpsOk(onDeviceModelUrl)) {
      errors.add(
        'ON_DEVICE_MODEL_URL must be a valid HTTPS URL '
        'when on-device inference is enabled',
      );
    }
    if (errors.isNotEmpty) {
      throw StateError(
          'Invalid CoverWise release configuration: ${errors.join('; ')}');
    }
  }
}
