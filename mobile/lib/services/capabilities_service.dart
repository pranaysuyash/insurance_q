import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/capabilities_response.dart';

/// Fetch the backend [GET /capabilities] endpoint to obtain server-enforced
/// limits for uploads, usage, and network timeouts.
///
/// Returns [CapabilitiesResponse] with server values when the endpoint
/// responds successfully, or a fallback with [AppConfig]'s static defaults
/// when the endpoint is unreachable (offline, not yet implemented, or
/// older server version).
///
/// A1-P1b: Callers should prefer [capabilities] over raw [AppConfig]
/// constants. The fallback ensures the client works offline.
class CapabilitiesService {
  final Dio _dio;

  CapabilitiesService(this._dio);

  /// Cached capabilities after a successful fetch. Reset to null to force a
  /// re-fetch on the next call.
  CapabilitiesResponse? _cached;

  /// Latest fetched capabilities, or [AppConfig] defaults if never fetched.
  CapabilitiesResponse get latest =>
      _cached ?? _fromAppConfig();

  /// Fetch capabilities from the backend. Returns the server response on
  /// success, or the current [latest] (which may be the previous fetch or
  /// AppConfig defaults) on failure.
  ///
  /// Idempotent for the same server response: if the cached value is
  /// already present, the network call is still made (to detect changed
  /// limits at session boundaries), but the [latest] getter always returns
  /// the most recently fetched value.
  Future<CapabilitiesResponse> fetch() async {
    try {
      final response = await _dio.get(
        '/capabilities',
        options: Options(
          // Short timeout so this doesn't block startup.
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final caps = CapabilitiesResponse.fromJson(
          data,
          fallback: _cached,
        );
        _cached = caps;
        return caps;
      }
    } catch (_) {
      // Endpoint unavailable — return fallback defaults.
    }
    return latest;
  }

  /// Build a [CapabilitiesResponse] from the current [AppConfig] static
  /// constants. Used as the fallback when the backend is unreachable.
  CapabilitiesResponse _fromAppConfig() => CapabilitiesResponse(
        maxUploadFileSizeBytes: AppConfig.maxUploadFileSizeBytes,
        defaultSessionLimit: AppConfig.defaultSessionLimit,
        defaultIpLimit: AppConfig.defaultIpLimit,
        sessionDurationSeconds: AppConfig.sessionDuration.inSeconds,
        connectTimeoutSeconds: AppConfig.connectTimeoutSeconds,
        receiveTimeoutSeconds: AppConfig.receiveTimeoutSeconds,
        // A1-P0.3: Trust gates default to false — never show calibrated
        // confidence UI unless the server explicitly enables it.
        confidenceCalibrated: false,
        contextualRetrievalEnabled: false,
      );
}
