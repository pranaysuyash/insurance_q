/// Response from the backend [GET /capabilities] endpoint.
///
/// Provides server-enforced limits for uploads, usage, and network timeouts.
/// When the endpoint is unavailable (offline, not yet implemented, or the
/// server is an older version), callers fall back to [AppConfig]'s static
/// defaults.
///
/// All fields have safe defaults so that a partial server response (missing
/// fields, wrong types) does not break the client.
///
/// A1-P1b: Replaces static client constants with server-provided limits.
class CapabilitiesResponse {
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
  /// The server is the source of truth. A compile-time constant cannot
  /// prove calibration state because a stale binary may disagree with
  /// the currently deployed backend.
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

  /// Construct from the backend JSON response. Uses ?? with the provided
  /// [fallback] for any missing/null field so that a partial server response
  /// does not produce null fields.
  factory CapabilitiesResponse.fromJson(
    Map<String, dynamic> json, {
    CapabilitiesResponse? fallback,
  }) {
    final f = fallback ?? _default;
    return CapabilitiesResponse(
      maxUploadFileSizeBytes:
          json['max_upload_file_size_bytes'] as int? ?? f.maxUploadFileSizeBytes,
      defaultSessionLimit:
          json['default_session_limit'] as int? ?? f.defaultSessionLimit,
      defaultIpLimit:
          json['default_ip_limit'] as int? ?? f.defaultIpLimit,
      sessionDurationSeconds:
          json['session_duration_seconds'] as int? ?? f.sessionDurationSeconds,
      connectTimeoutSeconds:
          json['connect_timeout_seconds'] as int? ?? f.connectTimeoutSeconds,
      receiveTimeoutSeconds:
          json['receive_timeout_seconds'] as int? ?? f.receiveTimeoutSeconds,
      confidenceCalibrated:
          json['confidence_calibrated'] as bool? ?? f.confidenceCalibrated,
      contextualRetrievalEnabled:
          json['contextual_retrieval_enabled'] as bool? ??
              f.contextualRetrievalEnabled,
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
}
