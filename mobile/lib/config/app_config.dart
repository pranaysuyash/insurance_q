class AppConfig {
  // Environment configuration
  static const String environment =
      String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
  static const bool bootstrapPolicyDemo = bool.fromEnvironment(
    'BOOTSTRAP_POLICY_DEMO',
    defaultValue: false,
  );

  // Backend URL configuration - STABLE URL (never changes)
  static const String _productionBaseUrl =
      'https://aa2485vt7t.ap-south-1.awsapprunner.com'; // STABLE production URL
  static const String _stagingBaseUrl =
      'https://aa2485vt7t.ap-south-1.awsapprunner.com'; // Same for now
  static const String _developmentBaseUrl =
      'http://localhost:8000'; // Local development

  // Get the appropriate base URL based on environment
  static String get baseUrl {
    switch (environment) {
      case 'development':
        return _developmentBaseUrl;
      case 'staging':
        return _stagingBaseUrl;
      case 'production':
      default:
        return _productionBaseUrl;
    }
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

  // Method to update production URL (for stable deployment)
  static String getStableUrl() {
    // This will be updated when we deploy the stable service
    return 'https://STABLE_URL_TO_BE_SET.ap-south-1.awsapprunner.com';
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
