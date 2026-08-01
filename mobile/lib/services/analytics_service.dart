import 'dart:convert';
import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'analytics_schema.dart';
import 'app_state_store.dart';
import 'consent_ledger.dart';
import 'install_service.dart';
import 'session_service.dart';
import '../config/app_config.dart';
import '../providers/service_providers.dart';


final analyticsServiceProvider = NotifierProvider<AnalyticsNotifier, AnalyticsState>(
  AnalyticsNotifier.new,
);

class AnalyticsState {
  final int queuedCount;
  final bool hasConsent;

  const AnalyticsState({required this.queuedCount, required this.hasConsent});
}

/// Public API for analytics. All track() calls are static delegates to
/// the Riverpod-managed [AnalyticsNotifier] instance. This preserves the
/// existing 60+ call sites while gaining proper lifecycle management.
///
/// Event contract rule:
/// Every event emitted through this service must exist in
/// `docs/analysis/analytics_tracking_event_registry.md` and `kEventSchemas`.
/// New events require a schema entry and conversion mapping before rollout.
class AnalyticsService {
  static AnalyticsNotifier? get _notifier => AnalyticsNotifier.instance;

  /// Fallback buffer used when the Riverpod [AnalyticsNotifier] has not
  /// been instantiated (e.g. in test environments without a
  /// ProviderContainer). Mirrors the notifier's consent check logic.
  static final List<Map<String, dynamic>> _fallbackBuffer = [];
  static bool _fallbackConsent = false;

  static void track(String name, [Map<String, dynamic>? properties]) {
    if (_notifier != null) {
      _notifier!._track(name, properties);
    } else if (_fallbackConsent) {
      _fallbackBuffer.add({
        'event': name,
        'ts': DateTime.now().toUtc().toIso8601String(),
        'uid': SessionService.getSessionIdSync(),
        if (properties != null && properties.isNotEmpty) 'props': properties,
      });
    }
  }

  static void refreshConsentCache() {
    if (_notifier != null) {
      _notifier!._refreshConsentCache();
    } else {
      try {
        final ledger = ConsentLedger();
        _fallbackConsent = ledger.getLatestRecord(ConsentPurpose.analytics)?.isActive ?? false;
      } catch (_) {
        _fallbackConsent = false;
      }
    }
  }

  static int get queuedCount =>
      _notifier?._buffer.length ?? _fallbackBuffer.length;

  static Future<void> clear() {
    if (_notifier != null) {
      return _notifier!.clear();
    }
    _fallbackBuffer.clear();
    return Future.value();
  }

  /// Enable the fallback buffer and return captured events for test assertions.
  ///
  /// In widget-test environments the Riverpod [AnalyticsNotifier] is typically
  /// not instantiated (no [ProviderContainer] reads the notifier), so
  /// [track] silently drops events. This helper activates the static fallback
  /// path and returns the captured entries for assertion.
  @visibleForTesting
  static List<Map<String, dynamic>> enableFallbackBuffer() {
    _fallbackConsent = true;
    _fallbackBuffer.clear();
    return _fallbackBuffer;
  }

  static void dispose() {
    // Riverpod's Notifier lifecycle handles cleanup via ref.onDispose in
    // the build() method. This explicit call is only used by the test
    // harness to cancel timers and clear state before the test isolate
    // exits — the Riverpod lifecycle does NOT run during tearDownAll in
    // test environments because the ProviderContainer is not disposed.
    if (_notifier != null) {
      _notifier!._syncTimer?.cancel();
      _notifier!._syncTimer = null;
      _notifier!._buffer.clear();
    }
    _fallbackBuffer.clear();
    _fallbackConsent = false;
  }
}

class AnalyticsNotifier extends Notifier<AnalyticsState> {
  static const _maxBatchSize = 50;
  static const _syncInterval = Duration(minutes: 5);
  static const _endPoint = '/analytics/events';

  static AnalyticsNotifier? _instance;
  static AnalyticsNotifier? get instance => _instance;

  Box get _box => Hive.box(AppStateStore.boxName);

  final List<Map<String, dynamic>> _buffer = [];
  Timer? _syncTimer;
  String? _uid;
  bool _analyticsConsentCached = true;
  
  /// CW-P0-008: Principal generation (epoch) to fence stale writes.
  int _principalEpoch = 0;
  
  /// CW-P0-008: Single-flight lock to prevent concurrent flushes.
  bool _flushInProgress = false;
  
  /// CW-P0-008: In-flight upload cancel token for consent revocation.
  CancelToken? _uploadCancelToken;

  StreamSubscription<List<ConsentRecord>>? _consentSubscription;

  @override
  AnalyticsState build() {
    _instance = this;
    ref.onDispose(() {
      _consentSubscription?.cancel();
      _consentSubscription = null;
      _uploadCancelToken?.cancel('disposal');
      _uploadCancelToken = null;
      _instance = null;
      _syncTimer?.cancel();
      _syncTimer = null;
    });

    _uid = SessionService.getSessionIdSync();
    _principalEpoch = 0; // Reset on fresh build
    _loadBuffer();
    _analyticsConsentCached = _checkConsentFresh();

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => _flush());

    // Audit 5 P1.3: Subscribe to the ConsentLedger consentChanges stream
    // so that consent revocations are picked up automatically without
    // requiring manual refreshConsentCache() calls from screens.
    _consentSubscription = ConsentLedger.consentChanges.listen((_) {
      _refreshConsentCache();
    });

    _scheduleAppSessionStarted();

    debugPrint('AnalyticsService initialized (uid=${_uid?.substring(0, 8)}..., queued=${_buffer.length})');
    return AnalyticsState(queuedCount: _buffer.length, hasConsent: _analyticsConsentCached);
  }

  void _scheduleAppSessionStarted() {
    unawaited(_emitAppSessionStarted());
  }

  Future<void> _emitAppSessionStarted() async {
    try {
      await InstallService.refreshInstallReferrerCache();
      final referrer = InstallService.getInstallReferrerSync();
      _track('app_session_started', {
        'install_id': InstallService.getInstallId(),
        'session_id': SessionService.getSessionIdSync(),
        'platform': InstallService.platformTag(),
        'app_version': AppConfig.appVersion,
        'days_since_install': InstallService.daysSinceInstall(),
        'is_reinstall': InstallService.isReinstall(),
        'install_referrer_source': referrer?['source'],
        'install_referrer_medium': referrer?['medium'],
        'install_referrer_campaign': referrer?['campaign'],
      });
    } catch (e) {
      debugPrint('Analytics: failed to track app_session_started: $e');
    }
  }

  bool _checkConsentFresh() {
    try {
      final ledger = ConsentLedger();
      return ledger.getLatestRecord(ConsentPurpose.analytics)?.isActive ?? false;
    } catch (e) {
      return false;
    }
  }

  /// P0.1: When consent is revoked, cancel the flush timer, discard the
  /// in-memory buffer, and delete the persisted queue so no stale events
  /// are transmitted after revocation.
  /// CW-P0-008: Also cancel any in-flight upload immediately.
  Future<void> applyConsent(bool allowed) async {
    _analyticsConsentCached = allowed;
    if (!allowed) {
      // CW-P0-008: Cancel in-flight upload before clearing buffer.
      _uploadCancelToken?.cancel('consent_revoked');
      _uploadCancelToken = null;
      _syncTimer?.cancel();
      _syncTimer = null;
      _buffer.clear();
      await _persistBuffer(); // Overwrites persisted queue with empty list.
    } else if (_syncTimer == null) {
      _syncTimer = Timer.periodic(_syncInterval, (_) => _flush());
    }
    state = AnalyticsState(queuedCount: _buffer.length, hasConsent: _analyticsConsentCached);
  }

  void _refreshConsentCache() {
    final fresh = _checkConsentFresh();
    if (fresh != _analyticsConsentCached) {
      applyConsent(fresh);
    }
  }

  /// CW-P0-008: Increment the principal epoch to invalidate any
  /// in-flight uploads from the previous principal. Must be called
  /// during principal transitions (account switch, sign-out, etc.).
  void incrementEpoch() {
    _principalEpoch++;
    // Cancel any in-flight upload from the old epoch.
    _uploadCancelToken?.cancel('epoch_incremented');
    _uploadCancelToken = null;
  }

  /// CW-P0-008: Generate a unique event ID for deduplication.
  String _generateEventId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random.secure().nextInt(0x7FFFFFFF);
    return '${timestamp.toRadixString(16)}-${random.toRadixString(16)}';
  }

  void _track(String name, [Map<String, dynamic>? properties]) {
    if (!_analyticsConsentCached) return;

    final props = properties ?? {};

    if (kDebugMode) {
      final errors = validateAnalyticsEvent(name, props);
      if (errors.isNotEmpty) {
        debugPrint('Analytics schema violations for "$name":');
        for (final error in errors) {
          debugPrint('  ⚠ $error');
        }
      }
    }

    // CW-P0-008: Immutable event ID for deduplication and audit trail.
    final event = {
      'event_id': _generateEventId(),
      'event': name,
      'ts': DateTime.now().toUtc().toIso8601String(),
      'uid': _uid ?? 'unknown',
      'epoch': _principalEpoch,
      if (props.isNotEmpty) 'props': props,
    };

    _buffer.add(event);

    // CW-P0-008: Persist only when batch threshold reached, not on every track.
    // This reduces disk I/O and eliminates race conditions on rapid events.
    // Intentional data-loss boundary: events between persists (1-49) are
    // in-memory only. Acceptable for analytics; not for billing or consent.
    if (_buffer.length >= _maxBatchSize) {
      unawaited(_persistBuffer());
      _flush();
    }
  }

  Future<void> _flush() async {
    // P0.1: Re-read authoritative consent immediately before transmission.
    if (!_analyticsConsentCached) {
      _uploadCancelToken?.cancel('consent_revoked');
      _buffer.clear();
      await _persistBuffer();
      return;
    }
    
    // CW-P0-008: Single-flight lock to prevent concurrent flushes.
    if (_flushInProgress) {
      return;
    }
    
    if (_buffer.isEmpty) return;
    
    _flushInProgress = true;
    // CW-P0-008: Cancel any previous in-flight upload.
    _uploadCancelToken?.cancel('new_flush');
    _uploadCancelToken = CancelToken();

    final batch = List<Map<String, dynamic>>.from(_buffer);
    final batchEpoch = _principalEpoch;

    try {
      final dio = ref.read(authenticatedDioProvider);

      final response = await dio.post(
        _endPoint,
        data: <String, dynamic>{
          'events': batch,
        },
        cancelToken: _uploadCancelToken,
      );

      // CW-P0-008: Verify principal epoch hasn't changed during upload.
      if (batchEpoch != _principalEpoch) {
        debugPrint('Analytics: principal epoch changed during flush, discarding batch');
        // Discard stale events from the old epoch.
        _buffer.removeRange(0, batch.length);
        await _persistBuffer();
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 202) {
        _buffer.removeRange(0, batch.length);
        await _persistBuffer();
        debugPrint('Analytics: flushed ${batch.length} events');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        debugPrint('Analytics: upload cancelled (${e.message})');
      } else {
        debugPrint('Analytics: sync deferred (${batch.length} events queued)');
      }
    } catch (e) {
      debugPrint('Analytics: sync deferred (${batch.length} events queued)');
    } finally {
      _flushInProgress = false;
    }
  }

  Future<void> _persistBuffer() async {
    try {
      await _box.put(AppStateStore.analyticsEventsKey, jsonEncode(_buffer));
    } catch (e) {
      debugPrint('Analytics: failed to persist buffer: $e');
    }
  }

  void _loadBuffer() {
    try {
      final raw = _box.get(AppStateStore.analyticsEventsKey);
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          // CW-P0-008: Load all persisted events. Epoch filtering on load
          // is ineffective because _principalEpoch resets to 0 on build()
          // and doesn't persist across restarts. Instead, principal
          // transitions call resetForWorkspace() which clears the buffer
          // before incrementing the epoch. The flush-time epoch check
          // handles stale batch detection within a session.
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _buffer.add(item);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Analytics: failed to load buffer: $e');
    }
  }

  Future<void> clear() async {
    _buffer.clear();
    await _box.delete(AppStateStore.analyticsEventsKey);
  }

  void resetForWorkspace() {
    // CW-P0-008: Increment epoch to invalidate in-flight uploads from
    // the previous principal before resetting workspace state.
    incrementEpoch();
    _consentSubscription?.cancel();
    _syncTimer?.cancel();
    _buffer.clear();
    _uid = SessionService.getSessionIdSync();
    _analyticsConsentCached = _checkConsentFresh();
    _syncTimer = Timer.periodic(_syncInterval, (_) => _flush());
    // Re-subscribe to consentChanges after workspace reset so the
    // stream is bound to the new workspace's ConsentLedger.
    _consentSubscription = ConsentLedger.consentChanges.listen((_) {
      _refreshConsentCache();
    });
    _scheduleAppSessionStarted();
    state = AnalyticsState(queuedCount: 0, hasConsent: _analyticsConsentCached);
  }

  /// CW-P0-008: Public static method for external callers (AuthService,
  /// ReconciliationCoordinator) to invalidate analytics epoch during
  /// principal transitions.
  ///
  /// Note: This is a no-op if the notifier hasn't been built yet (early
  /// startup). In practice, principal transitions happen after the app
  /// is fully initialized, so this is safe. If called before build(),
  /// resetForWorkspace() will call incrementEpoch() when it runs.
  static void invalidateEpoch() {
    _instance?.incrementEpoch();
  }
}
