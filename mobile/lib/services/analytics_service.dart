import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../config/app_config.dart';
import 'analytics_schema.dart';
import 'app_state_store.dart';
import 'consent_ledger.dart';
import 'session_service.dart';

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

    debugPrint('AnalyticsService initialized (uid=${_uid?.substring(0, 8)}..., queued=${_buffer.length})');
  }

  /// Records analytics consent in the purpose-specific ledger.
  /// Analytics is always-on for non-content, bucketed event tracking as
  /// disclosed in the privacy policy. This record exists for auditability.
  ///
  /// Called on every startup. If consent was previously revoked, it stays
  /// revoked — we only record the initial grant, not a re-grant.
  static Future<void> _recordAnalyticsConsent() async {
    try {
      final ledger = ConsentLedger();
      final latest = ledger.getLatestRecord(ConsentPurpose.analytics);
      if (latest == null) {
        // First startup — record analytics consent as granted.
        await ledger.recordConsent(
          purpose: ConsentPurpose.analytics,
          version: 'analytics-v1',
          granted: true,
        );
      }
      // If consent exists (granted or revoked), don't overwrite.
      // The user controls revocation from the privacy settings.
    } catch (e) {
      // Analytics consent recording is best-effort — don't disrupt init.
      debugPrint('Analytics: failed to record consent in ledger: $e');
    }
  }

  /// Check if analytics consent is currently granted (fresh from ledger).
  ///
  /// Returns `true` (analytics on) when:
  /// - No consent record exists (first launch — consent granted by default).
  /// - Ledger is corrupted (can't determine state — fail open).
  ///
  /// Returns `false` only when the user has explicitly revoked consent.
  static bool _checkConsentFresh() {
    try {
      final ledger = ConsentLedger();
      final records = ledger.getAllRecords();
      if (records.isEmpty) {
        // No consent record or corrupted data — default to true.
        return true;
      }
      // Check the latest analytics consent state from already-loaded records.
      for (var i = records.length - 1; i >= 0; i--) {
        if (records[i].purpose == ConsentPurpose.analytics) {
          return records[i].isActive;
        }
      }
      // No analytics record found — default to true.
      return true;
    } catch (e) {
      // If we can't check consent at all, default to true.
      return true;
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
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ));

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
