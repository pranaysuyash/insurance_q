import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Stable per-install identity for analytics and lifecycle tracking.
///
/// Unlike [SessionService] which rotates every 24h, the install_id is created
/// once on the device's first launch and persists until the app is fully
/// uninstalled (SharedPreferences is wiped on uninstall). Re-installing the
/// app produces a new install_id, which is exactly what we want for D1/D7/D30
/// retention and re-engagement flows.
///
/// Why SharedPreferences (not Hive) for this data:
/// - The Android `InstallReferrerReceiver` (Kotlin) writes the parsed referrer
///   to SharedPreferences natively. Storing install_id in SharedPreferences too
///   keeps install identity in one platform-native store, simplifying the
///   Kotlin receiver and the Flutter reader.
/// - SharedPreferences has a sync `get*` API backed by an in-memory cache that
///   is loaded once on app start, so the synchronous reads in this class
///   do not block.
///
/// Install created-at is stored separately so the analytics pipeline can
/// compute `days_since_install` without a server round-trip.
class InstallService {
  static const Uuid _uuid = Uuid();

  // SharedPreferences keys.
  static const String _kInstallId = 'install_id';
  static const String _kInstallCreatedAtMs = 'install_created_at_ms';
  static const String _kPreviousInstallIds = 'previous_install_ids';
  static const String _kReferrerSource = 'install_referrer_source';
  static const String _kReferrerMedium = 'install_referrer_medium';
  static const String _kReferrerCampaign = 'install_referrer_campaign';
  static const String _kReferrerCapturedAtMs = 'install_referrer_captured_at_ms';

  // Cached values for the current isolate (avoid repeated SharedPreferences reads).
  static String? _cachedInstallId;
  static DateTime? _cachedInstallCreatedAt;
  static bool? _cachedIsReinstall;
  static Map<String, String>? _cachedReferrer;

  /// Must be called once during app startup, before any other InstallService
  /// method. Loads the install identity and (if present) the referrer from
  /// SharedPreferences. Subsequent calls are no-ops.
  ///
  /// Safe to call multiple times.
  static Future<void> ensureInitialized() async {
    if (_cachedInstallId != null) return;
    final prefs = await SharedPreferences.getInstance();
    _loadOrCreateInstallId(prefs);
    _loadReferrer(prefs);
  }

  /// Synchronous accessor. Returns the cached install_id. Callers should
  /// invoke [ensureInitialized] during app startup so the cache is populated
  /// before this is called.
  ///
  /// If [ensureInitialized] has not been called yet (should not happen in
  /// normal flow), returns a transient UUID. The next [ensureInitialized]
  /// call will overwrite the cache with the real persisted install_id. The
  /// app_session_started event emitted from [AnalyticsService.init] runs as
  /// a microtask after [ensureInitialized] in [main.dart], so this fallback
  /// path is only hit in unusual startup orders.
  static String getInstallId() {
    if (_cachedInstallId != null) return _cachedInstallId!;
    // Defensive: generate a transient id. Will be replaced on the next
    // ensureInitialized() call (which writes the real persisted id).
    final transient = _uuid.v4();
    _cachedInstallId = transient;
    return transient;
  }

  /// Load (or create) the install_id, install_created_at, and re-install
  /// history. This is the only place install_id is generated.
  static void _loadOrCreateInstallId(SharedPreferences prefs) {
    final existing = prefs.getString(_kInstallId);
    if (existing != null && existing.isNotEmpty) {
      _cachedInstallId = existing;
      _cachedIsReinstall = false;
      final ms = prefs.getInt(_kInstallCreatedAtMs);
      if (ms != null) {
        _cachedInstallCreatedAt = DateTime.fromMillisecondsSinceEpoch(ms);
      }
      return;
    }

    // First launch on this device for this app install.
    final newId = _uuid.v4();
    final now = DateTime.now();
    prefs.setString(_kInstallId, newId);
    prefs.setInt(_kInstallCreatedAtMs, now.millisecondsSinceEpoch);

    // Detect re-install via the history list. If a prior install_id was
    // recorded (e.g. shared device passed to a new user, or backup restore),
    // this is a re-install.
    final history = prefs.getStringList(_kPreviousInstallIds) ?? <String>[];
    _cachedIsReinstall = history.isNotEmpty;
    final newHistory = List<String>.from(history)..add(newId);
    if (newHistory.length > 10) {
      newHistory.removeRange(0, newHistory.length - 10);
    }
    prefs.setStringList(_kPreviousInstallIds, newHistory);

    _cachedInstallId = newId;
    _cachedInstallCreatedAt = now;
  }

  /// Load the install referrer (set by the Android-side InstallReferrerReceiver).
  /// On iOS, web, or organic installs, all three keys are absent and the
  /// cached referrer stays null.
  static void _loadReferrer(SharedPreferences prefs) {
    final source = prefs.getString(_kReferrerSource);
    final medium = prefs.getString(_kReferrerMedium);
    final campaign = prefs.getString(_kReferrerCampaign);
    final capturedAtMs = prefs.getInt(_kReferrerCapturedAtMs);
    if (source == null && medium == null && campaign == null) {
      _cachedReferrer = null;
      return;
    }
    _cachedReferrer = <String, String>{
      if (source != null) 'source': source,
      if (medium != null) 'medium': medium,
      if (campaign != null) 'campaign': campaign,
      if (capturedAtMs != null) 'captured_at_ms': capturedAtMs.toString(),
    };
  }

  /// Returns the install creation timestamp, or null if the install id
  /// has not been initialized yet (e.g. called before [ensureInitialized]).
  static DateTime? getInstallCreatedAt() => _cachedInstallCreatedAt;

  /// True if this device has had a prior install (e.g. uninstall + reinstall,
  /// backup restore, or shared device passed to a new user).
  static bool isReinstall() {
    if (_cachedIsReinstall != null) return _cachedIsReinstall!;
    return false;
  }

  /// Days since first install. 0 on install day, 1 the next day, etc.
  /// Returns 0 if the install timestamp is unavailable.
  static int daysSinceInstall() {
    final created = _cachedInstallCreatedAt;
    if (created == null) return 0;
    final diff = DateTime.now().difference(created);
    return diff.inDays;
  }

  /// Platform string suitable for analytics. 'android', 'ios', or 'other'
  /// (web, desktop, unknown). Never returns a value that could identify
  /// the device beyond platform family.
  static String platformTag() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
      return 'other';
    } catch (_) {
      return 'other';
    }
  }

  /// The cached install referrer, or null if no referrer was recorded.
  /// Returns synchronously from the in-memory cache populated by
  /// [ensureInitialized]. Safe to call from any place after init.
  static Map<String, String>? getInstallReferrerSync() => _cachedReferrer;

  /// Re-read the referrer from SharedPreferences. Useful if the Android
  /// receiver fires after the Flutter app has already initialized (which
  /// can happen in some edge cases; see InstallReferrerReceiver.kt comments).
  /// Safe to call multiple times.
  static Future<void> refreshInstallReferrerCache() async {
    final prefs = await SharedPreferences.getInstance();
    _loadReferrer(prefs);
  }

  /// Reset all caches. Test-only.
  @visibleForTesting
  static void resetForTest() {
    _cachedInstallId = null;
    _cachedInstallCreatedAt = null;
    _cachedIsReinstall = null;
    _cachedReferrer = null;
  }
}
