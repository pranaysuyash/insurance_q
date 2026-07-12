import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the device connectivity state and exposes a simple [bool] for "is
/// the device online".
///
/// The app is offline-first (documents and sessions are stored locally via
/// Hive), but the QA and document-type-inference flows require the backend.
/// This provider lets those screens surface a clear offline state instead of a
/// generic network error SnackBar.
///
/// Note: `connectivity_plus` >= 6.0 returns `List<ConnectivityResult>` from
/// both `checkConnectivity()` and `onConnectivityChanged` (a device can be on
/// multiple transports at once). We treat the device as online when any result
/// other than `none` is present.
final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) async* {
  // Emit the current state immediately so consumers render the right UI on
  // first frame instead of waiting for the first stream event.
  yield await Connectivity().checkConnectivity();
  yield* Connectivity().onConnectivityChanged;
});

/// Convenience selector: true when the device has any active network path.
final isOnlineProvider = Provider<bool>((ref) {
  final results = ref.watch(connectivityProvider).valueOrNull;
  if (results == null || results.isEmpty) return false;
  return results.any((r) => r != ConnectivityResult.none);
});

/// One-time connectivity probe for call sites that want an immediate answer
/// (for example, before kicking off a backend query) without subscribing to a
/// stream. Returns false on any error so callers degrade gracefully.
Future<bool> checkOnline() async {
  try {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  } catch (e) {
    debugPrint('connectivity check failed: $e');
    return false;
  }
}
