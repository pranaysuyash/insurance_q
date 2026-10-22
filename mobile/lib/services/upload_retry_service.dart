import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'document_service.dart';
import '../providers/service_providers.dart';

/// Listens for connectivity changes and retries pending uploads automatically.
///
/// Architecture:
/// - Subscribes to Connectivity plugin stream
/// - On reconnect (offline->online transition): triggers retryPendingUploads
///   with exponential backoff (1s, 2s, 4s, max 3 attempts per reconnect event)
/// - Cancellable: disposes cleanly on logout/app close
///
/// See DECISION_LOG.md Decision 11, debt register H-03.
class UploadRetryService {
  UploadRetryService({
    required this.documentService,
    Connectivity? connectivity,
    List<Duration>? backoffDelays,
  })  : _connectivity = connectivity ?? Connectivity(),
        _backoffDelays = backoffDelays ??
            const [
              Duration(seconds: 1),
              Duration(seconds: 2),
              Duration(seconds: 4),
            ];

  final DocumentService documentService;
  final Connectivity _connectivity;
  final List<Duration> _backoffDelays;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _wasOffline = false;
  bool _isRetrying = false;

  bool get isRetrying => _isRetrying;
  bool get wasOffline => _wasOffline;

  void start() {
    _connectivitySub =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChange);
  }

  @visibleForTesting
  Future<void> handleConnectivityChange(List<ConnectivityResult> results) async {
    await _onConnectivityChange(results);
  }

  Future<void> _onConnectivityChange(List<ConnectivityResult> results) async {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (isOnline && _wasOffline && !_isRetrying) {
      await retryWithBackoff();
    }
    _wasOffline = !isOnline;
  }

  Future<Map<String, int>> retryWithBackoff() async {
    _isRetrying = true;
    Map<String, int> lastResult = const {'synced': 0, 'failed': 0, 'pending': 0};
    try {
      for (final delay in _backoffDelays) {
        try {
          lastResult = await documentService.retryPendingUploads();
          final pending = lastResult['pending'] ?? 0;
          final synced = lastResult['synced'] ?? 0;
          if (pending == 0 || synced > 0) {
            break;
          }
        } catch (e) {
          debugPrint('UploadRetryService: retry attempt failed: $e');
        }
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
      }
    } finally {
      _isRetrying = false;
    }
    return lastResult;
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}

final uploadRetryServiceProvider = Provider<UploadRetryService>((ref) {
  final svc = UploadRetryService(
    documentService: ref.read(documentServiceProvider),
  );
  svc.start();
  ref.onDispose(svc.dispose);
  return svc;
});
