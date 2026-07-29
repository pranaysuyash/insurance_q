/// Deep link validation policy for CoverWise.
///
/// Defines the allowed schemes, hosts, paths, and query parameter constraints
/// for deep links. Deep links are a trust boundary — an attacker or malformed
/// source can forge parameters, so only bounded identifiers are accepted.
///
/// Citation maps, extracted text, confidence values, and other evidence must
/// NEVER be accepted from deep links. They must be loaded from the
/// authenticated backend or verified local workspace.
class DeepLinkPolicy {
  DeepLinkPolicy._();

  /// Allowed custom-scheme hosts, for example `io.coverwise://host`.
  static const Set<String> allowedCustomSchemeHosts = {
    'emergency',
    'claims',
    'renewals',
    'coverage-gaps',
    'compare',
    'what-if',
    'qa',
    'reset-callback',
    'login-callback',
  };

  /// Allowed universal-link hosts.
  static const Set<String> allowedUniversalLinkHosts = {
    'coverwise.app',
    'www.coverwise.app',
  };

  /// Maximum length for any query parameter value that is used as an
  /// identifier (documentId, etc.).
  static const int maxIdentifierLength = 128;

  /// Allowed characters for identifiers (alphanumeric, hyphens, underscores).
  static final RegExp identifierPattern = RegExp(r'^[a-zA-Z0-9_-]+$');

  /// Query parameter names that must NEVER be accepted from deep links.
  /// These carry untrusted evidence (citations, extracted text, confidence)
  /// that must only come from the authenticated backend.
  static const Set<String> forbiddenQueryParams = {
    'citations',
    'extractedText',
    'confidence',
    'evidence',
  };

  /// Validate that a deep link URI is from an allowed source.
  ///
  /// Returns a [DeepLinkValidationResult] indicating whether the link is
  /// valid and, if not, why.
  static DeepLinkValidationResult validate(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    if (scheme == 'io.coverwise') {
      return _validateCustomScheme(uri);
    }

    if (scheme == 'https') {
      return _validateUniversalLink(uri);
    }

    return DeepLinkValidationResult.invalid(
      'Unsupported scheme: $scheme',
    );
  }

  static DeepLinkValidationResult _validateCustomScheme(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!allowedCustomSchemeHosts.contains(host)) {
      return DeepLinkValidationResult.invalid(
        'Unknown custom-scheme host: $host',
      );
    }

    return _validatePathAndParams(uri, host);
  }

  static DeepLinkValidationResult _validateUniversalLink(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!allowedUniversalLinkHosts.contains(host)) {
      return DeepLinkValidationResult.invalid(
        'Unknown universal-link host: $host',
      );
    }

    // Universal links use path-based routing.
    final path = uri.path;
    if (path.isEmpty || path == '/') {
      return DeepLinkValidationResult.invalid(
        'Universal link has no path',
      );
    }

    // Validate identifier parameters if present.
    final docId = uri.queryParameters['documentId'];
    if (docId != null && !_isValidIdentifier(docId)) {
      return DeepLinkValidationResult.invalid(
        'Invalid documentId in universal link',
      );
    }

    return DeepLinkValidationResult.valid(
      path: path,
      host: host,
    );
  }

  static DeepLinkValidationResult _validatePathAndParams(
    Uri uri,
    String host,
  ) {
    // For custom-scheme links, the route is in the host.
    final path = uri.path.isNotEmpty ? uri.path : '/$host';

    // Reject forbidden query parameters (defense in depth).
    for (final param in uri.queryParameters.keys) {
      if (forbiddenQueryParams.contains(param)) {
        return DeepLinkValidationResult.invalid(
          'Forbidden query parameter: $param',
        );
      }
    }

    // Validate identifier parameters.
    final docId = uri.queryParameters['documentId'];
    if (docId != null && !_isValidIdentifier(docId)) {
      return DeepLinkValidationResult.invalid(
        'Invalid documentId parameter',
      );
    }

    return DeepLinkValidationResult.valid(
      path: path,
      host: host,
    );
  }

  static bool _isValidIdentifier(String value) {
    if (value.isEmpty || value.length > maxIdentifierLength) return false;
    return identifierPattern.hasMatch(value);
  }
}

/// Result of deep link validation.
class DeepLinkValidationResult {
  final bool isValid;
  final String? error;
  final String? path;
  final String? host;

  const DeepLinkValidationResult._({
    required this.isValid,
    this.error,
    this.path,
    this.host,
  });

  factory DeepLinkValidationResult.valid({
    required String path,
    required String host,
  }) =>
      DeepLinkValidationResult._(
        isValid: true,
        path: path,
        host: host,
      );

  factory DeepLinkValidationResult.invalid(String error) =>
      DeepLinkValidationResult._(
        isValid: false,
        error: error,
      );
}
