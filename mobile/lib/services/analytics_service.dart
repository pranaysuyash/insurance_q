import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../config/app_config.dart';
import 'analytics_schema.dart';
import 'app_state_store.dart';
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

  /// Initialize the analytics service. Call once at app startup.
  static void init() {
    _uid = SessionService.getSessionIdSync();
    // Load any unsent events from storage
    _loadBuffer();

    // Periodic sync
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => flush());

    debugPrint('AnalyticsService initialized (uid=${_uid?.substring(0, 8)}..., '
        'queued=${_buffer.length})');
  }

  /// Track an analytics event.
  ///
  /// [name] must be a snake_case event name from the spec.
  /// [properties] must contain only safe, non-PII values (enums, buckets, counts).
  ///
  /// In debug builds, the payload is validated against [kEventSchemas] to
  /// catch accidental PII leakage and type mismatches early.
  static void track(String name, [Map<String, dynamic>? properties]) {
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
