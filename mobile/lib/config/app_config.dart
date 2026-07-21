import 'package:flutter/foundation.dart';

class AppConfig {
  // Environment configuration
  static const String environment =
      String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
  static const bool bootstrapPolicyDemo = bool.fromEnvironment(
    'BOOTSTRAP_POLICY_DEMO',
    defaultValue: false,
  );

  // Release addresses are injected at build time. Never embed an old hosting
  // provider URL in a store binary—the deployed API is a release contract.
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL', defaultValue: '');
  static const String termsOfServiceUrl = String.fromEnvironment('TERMS_OF_SERVICE_URL', defaultValue: '');
  static const String supportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: '');
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabasePublishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''));
  static const String privacyPolicyVersion = String.fromEnvironment(
      'PRIVACY_POLICY_VERSION', defaultValue: 'development-unversioned');

  // RevenueCat public API key — platform-specific, injected at build time.
  // iOS uses SUPABASE_PUBLISHABLE_KEY_*, Android uses SUPABASE_PUBLISHABLE_KEY_*.
  static const String revenuecatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: '',
  );

  // Phase 0 P0-0.3 (trust audit, 2026-07-18): confidence badge calibration
  // gate. The trust audit's NO-GO verdict says confidence badges must be
  // hidden or labelled "uncalibrated" until the backend's confidence is
  // calibrated against a real benchmark (Trust audit §12.5 release gates).
  // Default is false (NOT calibrated) because the audit states the existing
  // confidence is "max(model_confidence, retrieval_confidence)" which inflates
  // weak answers. Flip to true ONLY after a benchmark shows calibration.
  static const bool confidenceCalibrated = bool.fromEnvironment(
    'CONFIDENCE_CALIBRATED',
    defaultValue: false,
  );

  // Phase 0 P0-0.6 (trust audit): contextual retrieval contamination. The
  // trust audit says contextualization prepends model-generated text to
  // stored source chunks, contaminating citations. Disable in production
  // until source-vs-retrieval text separation exists (Trust Phase 1+).
  static const bool contextualRetrievalEnabled = bool.fromEnvironment(
    'CONTEXTUAL_RETRIEVAL_ENABLED',
    defaultValue: false,
  );

  // Get the appropriate base URL based on environment
  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    }
    // Debug/test builds can target a local service without accidentally giving
    // release builds an invented endpoint.
    if (!kReleaseMode) return 'http://localhost:8000';
    throw StateError('API_BASE_URL is required in a production release build');
  }

  // API endpoints
  static String get healthEndpoint => '$baseUrl/health';
  static String get queryEndpoint => '$baseUrl/query';
  static String get uploadEndpoint => '$baseUrl/documents/upload';
  static String get usageStatsEndpoint => '$baseUrl/documents/usage-stats';
  static String get docsEndpoint => '$baseUrl/docs';
  static String get subscriptionSyncEndpoint => '$baseUrl/subscription/sync';

  // App configuration
  static const String appName = 'CoverWise';
  static const String appVersion = '0.1.2+11';

  // Upload constraints
  static const int maxUploadFileSizeBytes = 20 * 1024 * 1024; // 20 MB
  static const int maxUploadFileSizeMB =
      maxUploadFileSizeBytes ~/ (1024 * 1024);

  // Rate limiting configuration (should match backend)
  static const int defaultSessionLimit = 5;
  static const int defaultIpLimit = 10;

  // Session configuration
  static const int sessionDurationHours = 24;

  // Contact validation
  static const List<String> disposableEmailDomains = [
    '10minutemail.com',
    'tempmail.org',
    'guerrillamail.com',
    'mailinator.com',
    'throwaway.email',
    'temp-mail.org',
    'yopmail.com',
    'maildrop.cc',
    'sharklasers.com',
    'getairmail.com',
    'dispostable.com',
    'tempail.com',
    'temp-mail.io',
    'mohmal.com',
    'emailondeck.com',
    'fakeinbox.com',
    'trashmail.com',
    'getnada.com',
    'tempinbox.com',
    'guerrillamailblock.com',
    'spam4.me',
    'mailnesia.com',
    'trbvm.com',
    'incognitomail.org',
    'anonymbox.com',
    'mintemail.com'
  ];

  // Debug configuration
  static const bool enableDebugLogs = false;
  static const bool enableNetworkLogs = false;

  // Timeout configuration
  static const int connectTimeoutSeconds = 10;
  static const int receiveTimeoutSeconds = 90;

  // Helper methods
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';

  static bool get hasPrivacyPolicy => privacyPolicyUrl.startsWith('https://');
  static bool get hasTermsOfService => termsOfServiceUrl.startsWith('https://');
  static bool get hasSupportEmail => isValidEmail(supportEmail);
  static bool get hasSupabaseAuthConfig =>
      supabaseUrl.startsWith('https://') && supabasePublishableKey.isNotEmpty;
  static bool get hasRevenueCatConfig => revenuecatApiKey.isNotEmpty;

  static void validateReleaseConfiguration() {
    if (!kReleaseMode || !isProduction) return;
    final errors = <String>[];
    if (!_configuredBaseUrl.startsWith('https://')) {
      errors.add('API_BASE_URL must be an HTTPS URL');
    }
    if (!hasPrivacyPolicy) {
      errors.add('PRIVACY_POLICY_URL must be an HTTPS URL');
    }
    if (!hasTermsOfService) {
      errors.add('TERMS_OF_SERVICE_URL must be an HTTPS URL');
    }
    if (!hasSupportEmail) {
      errors.add('SUPPORT_EMAIL must be a valid non-disposable email');
    }
    if (privacyPolicyVersion == 'development-unversioned') {
      errors.add('PRIVACY_POLICY_VERSION is required');
    }
    if (bootstrapPolicyDemo) {
      errors.add('BOOTSTRAP_POLICY_DEMO cannot be enabled in a release build');
    }
    if (errors.isNotEmpty) {
      throw StateError(
          'Invalid CoverWise release configuration: ${errors.join('; ')}');
    }
  }

  // Validation helpers
  static bool isDisposableEmail(String email) {
    final domain = email.split('@').last.toLowerCase();
    return disposableEmailDomains.contains(domain);
  }

  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email) && !isDisposableEmail(email);
  }

  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
    return phoneRegex.hasMatch(phone);
  }
}
