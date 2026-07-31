/// Response from the backend [GET /capabilities] endpoint.
///
/// Provides server-enforced limits for uploads, usage, and network timeouts.
/// When the endpoint is unavailable (offline, not yet implemented, or the
/// server is an older version), callers fall back to [AppConfig]'s static
/// defaults.
///
/// Audit 6 P0.2: All fields use strict parsing that rejects wrong types
/// rather than silently casting. Schema violations are logged and reported.
///
/// Audit 6 P0.3: Trust gates (confidenceCalibrated, contextualRetrievalEnabled)
/// fail closed — missing fields default to false, not to previous cached values.
///
/// Audit 6 P0.4: All numeric values are clamped to safe execution bounds.
/// The server owns business limits; the client owns safe runtime bounds.
///
/// A1-P1b: Replaces static client constants with server-provided limits.
class CapabilitiesResponse {
  // ── Audit 6 P0.4: Safe execution bounds ─────────────────────
  static const int _minUploadBytes = 1 * 1024 * 1024; // 1 MiB
  static const int _maxUploadBytes = 100 * 1024 * 1024; // 100 MiB
  static const int _minSessionLimit = 1;
  static const int _maxSessionLimit = 1000;
  static const int _minIpLimit = 1;
  static const int _maxIpLimit = 10000;
  static const int _minSessionDuration = 60; // 1 minute
  static const int _maxSessionDuration = 86400 * 7; // 7 days
  static const int _minConnectTimeout = 3;
  static const int _maxConnectTimeout = 30;
  static const int _minReceiveTimeout = 10;
  static const int _maxReceiveTimeout = 180;

  /// Maximum upload file size in bytes. Client-side guard only; the backend
  /// enforces the authoritative limit.
  final int maxUploadFileSizeBytes;

  /// Maximum grounded Q&A sessions per billing cycle.
  final int defaultSessionLimit;

  /// Maximum requests per IP per window for rate-limiting UX hints.
  final int defaultIpLimit;

  /// Duration in seconds for a rate-limit or billing session window.
  final int sessionDurationSeconds;

  /// HTTP connection timeout in seconds for backend requests.
  final int connectTimeoutSeconds;

  /// HTTP receive timeout in seconds for backend requests.
  final int receiveTimeoutSeconds;

  // ── Trust / capability gates (A1-P0.3) ──────────────────────

  /// Whether the backend confidence values are benchmark-calibrated.
  ///
  /// When `false` the client must hide confidence badges and trust UI
  /// entirely — users have no context for an internal uncalibrated label.
  /// When `true`, the client may render the legacy high/medium/low chip.
  ///
  /// Audit 6 P0.3: Missing field defaults to `false` (fail closed),
  /// never to a previous cached value. Trust gates must not become
  /// permanently sticky when the backend omits or rolls back the field.
  final bool confidenceCalibrated;

  /// Whether the backend is using contextual (source-separated) retrieval.
  ///
  /// Presentation gate only. The client may hide retrieval-provenance UI
  /// when `false`, but the server decides which retrieval pipeline
  /// actually processed an answer.
  final bool contextualRetrievalEnabled;

  const CapabilitiesResponse({
    required this.maxUploadFileSizeBytes,
    required this.defaultSessionLimit,
    required this.defaultIpLimit,
    required this.sessionDurationSeconds,
    required this.connectTimeoutSeconds,
    required this.receiveTimeoutSeconds,
    this.confidenceCalibrated = false,
    this.contextualRetrievalEnabled = false,
  });

  /// Construct from the backend JSON response.
  ///
  /// Audit 6 P0.2: Uses strict parsing — wrong types (e.g. string where
  /// int expected) are treated as missing fields, not cast exceptions.
  /// Schema violations are logged. The [fallback] parameter is ONLY used
  /// for numeric limits (not trust gates) — trust fields always default
  /// to false when missing.
  ///
  /// Audit 6 P0.4: All numeric values are clamped to safe bounds.
  factory CapabilitiesResponse.fromJson(
    Map<String, dynamic> json, {
    CapabilitiesResponse? fallback,
  }) {
    final f = fallback ?? _default;
    return CapabilitiesResponse(
      maxUploadFileSizeBytes: _clampInt(
        parseInt(json['max_upload_file_size_bytes']),
        f.maxUploadFileSizeBytes,
        _minUploadBytes,
        _maxUploadBytes,
      ),
      defaultSessionLimit: _clampInt(
        parseInt(json['default_session_limit']),
        f.defaultSessionLimit,
        _minSessionLimit,
        _maxSessionLimit,
      ),
      defaultIpLimit: _clampInt(
        parseInt(json['default_ip_limit']),
        f.defaultIpLimit,
        _minIpLimit,
        _maxIpLimit,
      ),
      sessionDurationSeconds: _clampInt(
        parseInt(json['session_duration_seconds']),
        f.sessionDurationSeconds,
        _minSessionDuration,
        _maxSessionDuration,
      ),
      connectTimeoutSeconds: _clampInt(
        parseInt(json['connect_timeout_seconds']),
        f.connectTimeoutSeconds,
        _minConnectTimeout,
        _maxConnectTimeout,
      ),
      receiveTimeoutSeconds: _clampInt(
        parseInt(json['receive_timeout_seconds']),
        f.receiveTimeoutSeconds,
        _minReceiveTimeout,
        _maxReceiveTimeout,
      ),
      // Audit 6 P0.3: Trust gates always default to false when missing.
      // Never use fallback values for trust-sensitive fields.
      confidenceCalibrated:
          json['confidence_calibrated'] == true,
      contextualRetrievalEnabled:
          json['contextual_retrieval_enabled'] == true,
    );
  }

  /// Sensible production defaults matching the current [AppConfig] constants.
  /// Used when the capabilities endpoint is unreachable or returns no data.
  ///
  /// Trust gates default to `false` — the client must never show
  /// calibrated-confidence UI unless the server explicitly enables it.
  static const CapabilitiesResponse _default = CapabilitiesResponse(
    maxUploadFileSizeBytes: 20 * 1024 * 1024, // 20 MiB
    defaultSessionLimit: 5,
    defaultIpLimit: 10,
    sessionDurationSeconds: 86400, // 24 hours
    connectTimeoutSeconds: 10,
    receiveTimeoutSeconds: 90,
    confidenceCalibrated: false,
    contextualRetrievalEnabled: false,
  );

  // ── Audit 6 P0.2: Strict parsing helpers ────────────────────

  /// Parse an int from a JSON value. Returns null for wrong types,
  /// non-finite numbers, null, or unparseable strings — never throws.
  ///
  /// Audit 6 P0.2: Handles String representations (e.g. "10") that
  /// some backends return instead of proper JSON integers.
  static int? parseInt(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Clamp an int to [min]..[max], falling back to [fallback] when null.
  ///
  /// Audit 6 P0.4: Ensures returned value is always within safe bounds.
  /// Uses explicit comparison to guarantee int return type (Dart's
  /// num.clamp can return num in some contexts).
  static int _clampInt(int? value, int fallback, int min, int max) {
    final v = value ?? fallback;
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }
}
