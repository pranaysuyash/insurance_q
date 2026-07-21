import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'analytics_schema.dart';
import 'app_state_store.dart';
import 'consent_ledger.dart';
import 'document_service.dart';
import 'install_service.dart';
import 'session_service.dart';

/// App version string. Mirrors `version:` in pubspec.yaml. Update on every
/// version bump. We avoid adding `package_info_plus` to pubspec.yaml per
/// motto v3 §0 (no new packages for things the build can supply directly).
const String kAppVersion = '0.1.2+11';

/// Privacy-respecting analytics for CoverWise.
///
/// Events are stored locally in Hive (offline-first) and batch-synced to the
/// backend when network is available. No PII is ever included in event
/// payloads — only event name, timestamp, anonymous UID, and safe properties
/// per the analytics event spec (docs/review/coverwise_analytics_event_spec.md).
///
/// In debug builds, event payloads are validated against the registered schema
/// to catch accidental PII leakage and type mismatches early.
///
/// Usage: `AnalyticsService.track('event_name', {'key': 'value'})`.
/// The service handles queueing, batching, and retry automatically.
class AnalyticsService {
  static const _maxBatchSize = 50;
  static const _syncInterval = Duration(minutes: 5);
  static const _endPoint = '/analytics/events';

  static Box get _box => Hive.box(AppStateStore.boxName);

  static final List<Map<String, dynamic>> _buffer = [];
  static Timer? _syncTimer;
  static String? _uid;

  /// Cached analytics consent state — refreshed at init and on toggle.
  /// Avoids Hive reads on every track() call.
  static bool _analyticsConsentCached = true;

  /// Initialize the analytics service. Call once at app startup.
  static void init() {
    _uid = SessionService.getSessionIdSync();
    // Load any unsent events from storage
    _loadBuffer();

    // Record analytics consent in the purpose-specific ledger for auditability.
    // This happens on every startup so the ledger reflects the current state.
    // Read the actual consent state synchronously (_loadRecords is sync) so
    // revoked consent stays revoked across restarts. The async write only
    // fires on first launch (when no record exists).
    _analyticsConsentCached = _checkConsentFresh();
    unawaited(_recordAnalyticsConsent());

    // Periodic sync
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => flush());

    // R1.6 (2026-07-18): emit app_session_started on every cold start.
    // Runs after consent is checked, so a user who revoked consent will not
    // have their session tracked. Runs after the sync timer is up so the
    // event is flushed in the next batch within 5 minutes.
    //
    // The emission is scheduled as a microtask after a fresh referrer cache
    // refresh so install_referrer_source/medium/campaign are populated when
    // the Play Store INSTALL_REFERRER was received. On iOS / organic installs
    // / channel errors, the referrer properties are null and the schema
    // validator skips them.
    _scheduleAppSessionStarted();

    debugPrint('AnalyticsService initialized (uid=${_uid?.substring(0, 8)}..., queued=${_buffer.length})');
  }

  /// Refresh the install referrer cache and emit app_session_started.
  ///
  /// Split from init() so the async referrer fetch completes before the
  /// event is emitted. The emission itself remains synchronous (track()
  /// is sync); only the referrer cache refresh is async.
  static void _scheduleAppSessionStarted() {
    // Use unawaited so init() returns immediately. The microtask chain runs
    // after the current event loop turn, which is the right moment: Hive is
    // initialized, consent is loaded, and any pending flush can pick up the
    // event in the next batch.
    unawaited(_emitAppSessionStarted());
  }

  static Future<void> _emitAppSessionStarted() async {
    try {
      // Refresh the referrer cache before reading. On iOS / web / no-referrer
      // this is a no-op (returns null) so the synchronous read below is safe.
      await InstallService.refreshInstallReferrerCache();
      final referrer = InstallService.getInstallReferrerSync();
      track('app_session_started', {
        'install_id': InstallService.getInstallId(),
        'session_id': SessionService.getSessionIdSync(),
        'platform': InstallService.platformTag(),
        // App version is maintained as a const by the build; update on each
        // version bump. Keeping it as a const avoids adding package_info_plus
        // to pubspec.yaml per motto v3 §0 (no new packages for things the
        // build can supply directly).
        'app_version': kAppVersion,
        'days_since_install': InstallService.daysSinceInstall(),
        'is_reinstall': InstallService.isReinstall(),
        'install_referrer_source': referrer?['source'],
        'install_referrer_medium': referrer?['medium'],
        'install_referrer_campaign': referrer?['campaign'],
      });
    } catch (e) {
      // app_session_started is best-effort. Failures here must not block init.
      debugPrint('Analytics: failed to track app_session_started: $e');
    }
  }

  /// Records analytics consent in the purpose-specific ledger.
  ///
  /// Security audit P0-10 (2026-07-18): the previous behaviour
  /// auto-recorded an analytics GRANT on first launch with no user
  /// action. The audit says optional analytics must "fail closed and
  /// require an explicit recorded action". The fix is:
  /// - do NOT auto-record a grant;
  /// - the user must grant analytics through the privacy screen
  ///   (which calls [recordConsent] explicitly);
  /// - the on-device `track()` is gated on [hasAnalyticsConsent].
  ///
  /// This method now only does a no-op refresh so the cache is
  /// consistent with whatever the user has explicitly recorded.
  static Future<void> _recordAnalyticsConsent() async {
    // No-op. The previous auto-grant has been removed per the
    // security audit. The user must grant analytics explicitly
    // through the privacy screen.
    return;
  }

  /// Check if analytics consent is currently granted (fresh from ledger).
  ///
  /// Security audit P0-10: returns `true` only when the user has
  /// explicitly GRANTED analytics. Returns `false` for:
  /// - no consent record (first launch — the user has not decided yet)
  /// - ledger is corrupted or unreadable (fail closed, not fail open)
  /// - latest record is a REVOCATION
  static bool _checkConsentFresh() {
    try {
      final ledger = ConsentLedger();
      // ConsentLedger owns the append-only ordering and tie handling. Using
      // its purpose-specific latest lookup prevents an older grant from
      // winning after a revoke or re-grant that happens in the same tick.
      return ledger.getLatestRecord(ConsentPurpose.analytics)?.isActive ?? false;
    } catch (e) {
      // If we can't check consent at all, fail closed (not open).
      // The audit explicitly says missing/corrupt consent must not
      // default to granted.
      return false;
    }
  }

  /// Called by PrivacySecurityScreen when the user toggles analytics consent.
  /// Updates the cached state so track() respects it immediately.
  static void refreshConsentCache() {
    _analyticsConsentCached = _checkConsentFresh();
  }

  /// Track an analytics event.
  ///
  /// [name] must be a snake_case event name from the spec.
  /// [properties] must contain only safe, non-PII values (enums, buckets, counts).
  ///
  /// In debug builds, the payload is validated against [kEventSchemas] to
  /// catch accidental PII leakage and type mismatches early.
  ///
  /// If the user has revoked analytics consent, events are silently dropped.
  static void track(String name, [Map<String, dynamic>? properties]) {
    // Respect analytics consent — drop events if consent is revoked.
    if (!_analyticsConsentCached) return;

    final props = properties ?? {};

    // Schema validation in debug builds only.
    if (kDebugMode) {
      final errors = validateAnalyticsEvent(name, props);
      if (errors.isNotEmpty) {
        debugPrint('Analytics schema violations for "$name":');
        for (final error in errors) {
          debugPrint('  ⚠ $error');
        }
      }
    }

    final event = {
      'event': name,
      'ts': DateTime.now().toUtc().toIso8601String(),
      'uid': _uid ?? 'unknown',
      if (props.isNotEmpty) 'props': props,
    };

    _buffer.add(event);
    _persistBuffer();

    // Flush immediately if buffer is full
    if (_buffer.length >= _maxBatchSize) {
      flush();
    }
  }

  /// Flush queued events to the backend. Safe to call repeatedly.
  static Future<void> flush() async {
    if (_buffer.isEmpty) return;

    // Take a snapshot of the buffer
    final batch = List<Map<String, dynamic>>.from(_buffer);

    try {
      final dio = DocumentService.authenticatedDio;

      final response = await dio.post(_endPoint, data: {
        'events': batch,
      });

      if (response.statusCode == 200 || response.statusCode == 202) {
        // Remove sent events from buffer
        _buffer.removeRange(0, batch.length);
        _persistBuffer();
        debugPrint('Analytics: flushed ${batch.length} events');
      }
    } catch (e) {
      // Keep events in buffer for next retry. Don't log as error —
      // analytics failure should never disrupt the user.
      debugPrint('Analytics: sync deferred (${batch.length} events queued)');
    }
  }

  /// Get the number of queued (unsent) events.
  static int get queuedCount => _buffer.length;

  static void _persistBuffer() {
    try {
      _box.put(AppStateStore.analyticsEventsKey, jsonEncode(_buffer));
    } catch (e) {
      debugPrint('Analytics: failed to persist buffer: $e');
    }
  }

  static void _loadBuffer() {
    try {
      final raw = _box.get(AppStateStore.analyticsEventsKey);
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _buffer.addAll(
            decoded.cast<Map<String, dynamic>>(),
          );
        }
      }
    } catch (e) {
      debugPrint('Analytics: failed to load buffer: $e');
    }
  }

  /// Clear all queued events (used on clear-data).
  static Future<void> clear() async {
    _buffer.clear();
    await _box.delete(AppStateStore.analyticsEventsKey);
  }

  /// Dispose timer (called on app shutdown).
  static void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}
