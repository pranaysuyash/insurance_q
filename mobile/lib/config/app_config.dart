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
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''));
  static const String privacyPolicyVersion =
      String.fromEnvironment(
          'PRIVACY_POLICY_VERSION', defaultValue: 'development-unversioned');

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

  // App configuration
  static const String appName = 'CoverWise';
  static const String appVersion = '0.1.2+11';

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
