import 'package:hive/hive.dart';
import 'app_state_store.dart';

/// Feature flag system supporting compile-time defaults and runtime overrides.
///
/// Each flag has:
/// - A compile-time default (via `bool.fromEnvironment` for build-specific toggles)
/// - An optional runtime override persisted in [AppStateStore.boxName]
///
/// Priority (highest to lowest):
///   1. Runtime override (Hive)
///   2. Compile-time default (declared per-flag)
///
/// Usage in production code:
/// ```dart
/// if (FeatureFlags.newExtractionPipeline) { ... }
/// ```
///
/// Usage in tests:
/// ```dart
/// FeatureFlags.override('new_extraction_pipeline', true);
/// // ... test ...
/// FeatureFlags.reset('new_extraction_pipeline');
/// ```
class FeatureFlags {
  FeatureFlags._();

  static const String _hiveKeyPrefix = 'feature_flag_';

  // ---------------------------------------------------------------------------
  // Known flags — add new flags here with their compile-time default.
  // ---------------------------------------------------------------------------

  /// Whether the contextual confidence-scoring pipeline is enabled.
  static const bool _contextualConfidenceDefault = false;

  /// Whether the new Supabase-backed extraction pipeline is live.
  static const bool _newExtractionPipelineDefault = false;

  /// Whether the v2 onboarding flow (with camera-first UX) is enabled.
  static const bool _onboardingV2Default = false;

  /// Whether the offline-first sync queue is enabled for documents.
  static const bool _offlineSyncDefault = true;

  /// Whether to show confidence badges to end users.
  static const bool _confidenceBadgesDefault = false;

  // ---------------------------------------------------------------------------
  // Public flag accessors.
  // ---------------------------------------------------------------------------

  static bool get contextualConfidence =>
      _read('contextual_confidence', _contextualConfidenceDefault);

  static bool get newExtractionPipeline =>
      _read('new_extraction_pipeline', _newExtractionPipelineDefault);

  static bool get onboardingV2 =>
      _read('onboarding_v2', _onboardingV2Default);

  static bool get offlineSync =>
      _read('offline_sync', _offlineSyncDefault);

  static bool get confidenceBadges =>
      _read('confidence_badges', _confidenceBadgesDefault);

  // ---------------------------------------------------------------------------
  // Internal helpers.
  // ---------------------------------------------------------------------------

  static Box<dynamic> get _box => Hive.box(AppStateStore.boxName);

  static bool _read(String flagName, bool defaultValue) {
    final override = _box.get('$_hiveKeyPrefix$flagName');
    if (override is bool) return override;
    return defaultValue;
  }

  /// Override a feature flag at runtime. Persists to Hive.
  static Future<void> override(String flagName, bool value) async {
    await _box.put('$_hiveKeyPrefix$flagName', value);
  }

  /// Remove a runtime override, reverting to the compile-time default.
  static Future<void> reset(String flagName) async {
    await _box.delete('$_hiveKeyPrefix$flagName');
  }

  /// Remove all runtime overrides.
  static Future<void> resetAll() async {
    final keys = _box.keys
        .where((k) => k.toString().startsWith(_hiveKeyPrefix))
        .toList();
    for (final key in keys) {
      await _box.delete(key);
    }
  }
}
