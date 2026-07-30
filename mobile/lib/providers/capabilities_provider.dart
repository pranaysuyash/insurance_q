import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/capabilities_response.dart';
import '../services/capabilities_service.dart';

/// Shared instance of [CapabilitiesService], lazily created with a short-timeout
/// Dio client. Used by [capabilitiesProvider] and by startup code that needs
/// to warm the cache before the first widget frame.
CapabilitiesService _createService() => CapabilitiesService(
      Dio(BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      )),
    );

/// The shared [CapabilitiesService] instance. Initialised lazily.
CapabilitiesService? _cachedService;
CapabilitiesService get capabilitiesService {
  _cachedService ??= _createService();
  return _cachedService!;
}

/// Riverpod provider that exposes the latest [CapabilitiesResponse].
///
/// Returns the cached value immediately (from a prior warm-up or from AppConfig
/// defaults), then fetches the server on first access. Consumers should handle
/// the loading/error states gracefully — the [CapabilitiesService.latest]
/// getter always returns a usable value even when the fetch fails.
final capabilitiesProvider =
    FutureProvider<CapabilitiesResponse>((ref) async {
  return capabilitiesService.fetch();
});

// Synchronous accessor via capabilitiesService.latest for startup code.

// For callers with Riverpod access, use capabilitiesProvider.watch().
// For startup code before Riverpod, use capabilitiesService.latest.
