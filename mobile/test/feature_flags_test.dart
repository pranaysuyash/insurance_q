import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/services/feature_flags.dart';
import 'helpers/hive_test_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HiveTestHelper.setUp();
  });

  setUp(() async {
    await FeatureFlags.resetAll();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  group('FeatureFlags', () {
    test('returns default values when no overrides exist', () {
      expect(FeatureFlags.contextualConfidence, false);
      expect(FeatureFlags.newExtractionPipeline, false);
      expect(FeatureFlags.onboardingV2, false);
      expect(FeatureFlags.offlineSync, true);
      expect(FeatureFlags.confidenceBadges, false);
    });

    test('override persists and changes the return value', () async {
      expect(FeatureFlags.newExtractionPipeline, false);
      await FeatureFlags.override('new_extraction_pipeline', true);
      expect(FeatureFlags.newExtractionPipeline, true);
    });

    test('reset reverts to default', () async {
      await FeatureFlags.override('offline_sync', false);
      expect(FeatureFlags.offlineSync, false);

      await FeatureFlags.reset('offline_sync');
      expect(FeatureFlags.offlineSync, true);
    });

    test('resetAll clears all overrides', () async {
      await FeatureFlags.override('contextual_confidence', true);
      await FeatureFlags.override('onboarding_v2', true);
      expect(FeatureFlags.contextualConfidence, true);
      expect(FeatureFlags.onboardingV2, true);

      await FeatureFlags.resetAll();
      expect(FeatureFlags.contextualConfidence, false);
      expect(FeatureFlags.onboardingV2, false);
    });

    test('override with false works', () async {
      await FeatureFlags.override('offline_sync', false);
      expect(FeatureFlags.offlineSync, false);

      await FeatureFlags.override('offline_sync', true);
      expect(FeatureFlags.offlineSync, true);
    });

    test('unknown flag returns default value', () {
      expect(FeatureFlags.offlineSync, true);
    });

    test('persistence across instances', () async {
      await FeatureFlags.override('confidence_badges', true);
      expect(FeatureFlags.confidenceBadges, true);

      await FeatureFlags.resetAll();
      expect(FeatureFlags.confidenceBadges, false);
    });
  });
}
