import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/services/notification_service.dart';

PolicySummary _summary({
  String id = 'policy-1',
  DateTime? endDate,
}) {
  final expiry = endDate ?? DateTime(2030, 7, 31);
  return PolicySummary(
    documentId: id,
    policyNumber: 'P-$id',
    insurer: 'Example Insurer',
    documentType: 'Health Insurance',
    startDate: DateTime(2029, 8, 1),
    endDate: expiry,
    coverageAmount: 500000,
    extractedAt: DateTime(2029, 8, 1),
  );
}

void main() {
  group('NotificationService.buildReminderPlan', () {
    final now = DateTime(2030, 6, 1, 12);
    final preferences = <String, dynamic>{
      'enabled': true,
      'reminderDays': <int>[30, 7],
      'quietHoursStart': 22,
      'quietHoursEnd': 7,
      'disabledPolicies': <String>[],
    };

    test('plans reminders at 9am before expiry', () {
      final plan = NotificationService.buildReminderPlan(
        [_summary()],
        preferences: preferences,
        now: now,
      );

      expect(plan, hasLength(2));
      expect(plan.map((reminder) => reminder.daysBefore), containsAll([30, 7]));
      expect(
          plan.every((reminder) => reminder.scheduledDate.hour == 9), isTrue);
      expect(plan.every((reminder) => reminder.scheduledDate.isAfter(now)),
          isTrue);
    });

    test('returns no plan when reminders are disabled', () {
      final plan = NotificationService.buildReminderPlan(
        [_summary()],
        preferences: {...preferences, 'enabled': false},
        now: now,
      );

      expect(plan, isEmpty);
    });

    test('does not plan disabled policies or reminders in the past', () {
      final plan = NotificationService.buildReminderPlan(
        [
          _summary(id: 'disabled-policy'),
          _summary(id: 'expired-policy', endDate: DateTime(2030, 5, 31)),
        ],
        preferences: {
          ...preferences,
          'disabledPolicies': <String>['disabled-policy'],
        },
        now: now,
      );

      expect(plan, isEmpty);
    });

    test('moves delivery out of a quiet period', () {
      final plan = NotificationService.buildReminderPlan(
        [_summary()],
        preferences: {
          ...preferences,
          'quietHoursStart': 8,
          'quietHoursEnd': 10,
        },
        now: now,
      );

      expect(plan, isNotEmpty);
      expect(
          plan.every((reminder) => reminder.scheduledDate.hour == 10), isTrue);
    });

    test('falls back to default reminder days when configured list is empty',
        () {
      final plan = NotificationService.buildReminderPlan(
        [_summary()],
        preferences: {...preferences, 'reminderDays': <int>[]},
        now: now,
      );

      expect(
        plan.map((reminder) => reminder.daysBefore),
        containsAll(NotificationService.defaultReminderDays),
      );
    });
  });
}
