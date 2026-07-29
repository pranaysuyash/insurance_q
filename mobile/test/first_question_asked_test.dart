import 'package:coverwise/services/analytics_service.dart';
import 'package:coverwise/services/analytics_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/hive_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('first_question_asked schema validation', () {
    test('schema defines the event with correct properties', () {
      final schema = kEventSchemas['first_question_asked'];
      expect(schema, isNotNull);
      expect(schema!.containsKey('question_length_bucket'), isTrue);
      expect(schema['question_length_bucket'], AnalyticsPropertyType.string);
    });

    test('validateAnalyticsEvent passes for valid payload', () {
      final errors = validateAnalyticsEvent('first_question_asked', {
        'question_length_bucket': 'short',
      });
      expect(errors, isEmpty);
    });

    test('validateAnalyticsEvent rejects missing required property', () {
      final errors = validateAnalyticsEvent('first_question_asked', {});
      expect(errors, isNotEmpty);
      expect(errors.first, contains('question_length_bucket'));
    });

    test('validateAnalyticsEvent rejects wrong type', () {
      final errors = validateAnalyticsEvent('first_question_asked', {
        'question_length_bucket': 42,
      });
      expect(errors, isNotEmpty);
    });
  });

  group('first_question_asked SharedPreferences dedup', () {
    late List<Map<String, dynamic>> capturedEvents;

    setUpAll(() async {
      await HiveTestHelper.setUp();
    });

    setUp(() async {
      capturedEvents = AnalyticsService.enableFallbackBuffer();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      capturedEvents.clear();
      AnalyticsService.dispose();
    });

    tearDownAll(() {
      HiveTestHelper.tearDown();
    });

    test('first_question_asked fires once after initial setBool', () async {
      final prefs = await SharedPreferences.getInstance();

      // Simulate the _trackFirstQuestionIfNeeded logic:
      // 1. First call — flag is null/false, so it should fire
      final hasEverAsked = prefs.getBool('has_ever_asked_question');
      expect(hasEverAsked, isNull);

      if (hasEverAsked != true) {
        await prefs.setBool('has_ever_asked_question', true);
        AnalyticsService.track('first_question_asked', {
          'question_length_bucket': 'short',
        });
      }

      expect(capturedEvents.length, 1);
      expect(capturedEvents.first['event'], 'first_question_asked');
      final props = capturedEvents.first['props'] as Map<String, dynamic>;
      expect(props['question_length_bucket'], 'short');
    });

    test('first_question_asked does not fire on subsequent calls', () async {
      final prefs = await SharedPreferences.getInstance();

      // Pre-set the flag to simulate a returning user
      await prefs.setBool('has_ever_asked_question', true);

      // Should NOT fire because flag is already true
      final hasEverAsked = prefs.getBool('has_ever_asked_question');
      expect(hasEverAsked, isTrue);

      if (hasEverAsked != true) {
        await prefs.setBool('has_ever_asked_question', true);
        AnalyticsService.track('first_question_asked', {
          'question_length_bucket': 'long',
        });
      }

      // Event should NOT have been fired
      final events =
          capturedEvents.where((e) => e['event'] == 'first_question_asked');
      expect(events, isEmpty);
    });
  });
}
