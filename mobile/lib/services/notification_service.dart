import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/policy_summary.dart';
import 'app_state_store.dart';

class RenewalReminder {
  final int id;
  final String documentId;
  final int daysBefore;
  final DateTime scheduledDate;
  final String title;
  final String body;

  const RenewalReminder({
    required this.id,
    required this.documentId,
    required this.daysBefore,
    required this.scheduledDate,
    required this.title,
    required this.body,
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Default reminder days if no preferences are saved.
  static const List<int> defaultReminderDays = [30, 14, 7];

  /// Load notification preferences from Hive with safe defaults on corruption.
  static Map<String, dynamic> loadPreferences() {
    try {
      final box = Hive.box(AppStateStore.boxName);
      return {
        'enabled': box.get(AppStateStore.notificationEnabledKey,
            defaultValue: true) as bool,
        'reminderDays':
            _safeIntList(box.get(AppStateStore.reminderDaysKey), [30, 14, 7]),
        'quietHoursStart':
            (box.get(AppStateStore.quietHoursStartKey) as int?) ?? 22,
        'quietHoursEnd': (box.get(AppStateStore.quietHoursEndKey) as int?) ?? 7,
        'disabledPolicies':
            _safeStringList(box.get(AppStateStore.disabledPoliciesKey)),
      };
    } catch (e) {
      debugPrint(
          'Notification preferences corrupted, falling back to defaults: $e');
      return {
        'enabled': true,
        'reminderDays': [30, 14, 7],
        'quietHoursStart': 22,
        'quietHoursEnd': 7,
        'disabledPolicies': <String>[],
      };
    }
  }

  static List<int> _safeIntList(dynamic value, List<int> defaultValue) {
    if (value is! List) return defaultValue;
    try {
      return value.cast<int>();
    } catch (e) {
      return defaultValue;
    }
  }

  static List<String> _safeStringList(dynamic value) {
    if (value is! List) return <String>[];
    try {
      return value.cast<String>();
    } catch (e) {
      return <String>[];
    }
  }

  /// Save notification preferences to Hive.
  static Future<void> savePreferences({
    bool? enabled,
    List<int>? reminderDays,
    int? quietHoursStart,
    int? quietHoursEnd,
    List<String>? disabledPolicies,
  }) async {
    final box = Hive.box(AppStateStore.boxName);
    if (enabled != null) {
      await box.put(AppStateStore.notificationEnabledKey, enabled);
    }
    if (reminderDays != null) {
      await box.put(AppStateStore.reminderDaysKey, reminderDays);
    }
    if (quietHoursStart != null) {
      await box.put(AppStateStore.quietHoursStartKey, quietHoursStart);
    }
    if (quietHoursEnd != null) {
      await box.put(AppStateStore.quietHoursEndKey, quietHoursEnd);
    }
    if (disabledPolicies != null) {
      await box.put(AppStateStore.disabledPoliciesKey, disabledPolicies);
    }
  }

  static Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      try {
        final localTimezone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localTimezone));
      } catch (error) {
        // UTC is the timezone package default. Keep startup usable when a
        // platform channel cannot provide the device timezone (for example,
        // on web or in a host-side test).
        debugPrint('Device timezone unavailable; using UTC: $error');
      }
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);
      await _plugin.initialize(settings: initSettings);
      _initialized = true;
      debugPrint('NotificationService initialized');
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      debugPrint('Notification permissions: $granted');
      return granted ?? false;
    } catch (e) {
      debugPrint('Permission request failed: $e');
      return false;
    }
  }

  static List<RenewalReminder> buildReminderPlan(
    List<PolicySummary> summaries, {
    Map<String, dynamic>? preferences,
    DateTime? now,
  }) {
    final prefs = preferences ?? loadPreferences();
    if (prefs['enabled'] != true) return const [];

    final configuredDays = (prefs['reminderDays'] as List<int>?) ?? const [];
    final daysBefore =
        configuredDays.isEmpty ? defaultReminderDays : configuredDays;
    final disabledPolicies =
        (prefs['disabledPolicies'] as List<String>?) ?? const [];
    final quietStart = prefs['quietHoursStart'] as int? ?? 22;
    final quietEnd = prefs['quietHoursEnd'] as int? ?? 7;
    final currentTime = now ?? DateTime.now();
    final notificationHour = _deliveryHour(
      preferredHour: 9,
      quietHoursStart: quietStart,
      quietHoursEnd: quietEnd,
    );
    final plan = <RenewalReminder>[];

    for (final summary in summaries) {
      final endDate = summary.endDate;
      if (endDate == null || !endDate.isAfter(currentTime)) continue;
      if (disabledPolicies.contains(summary.documentId)) continue;

      for (final days in daysBefore) {
        final reminderDate = endDate.subtract(Duration(days: days));
        final scheduledDate = DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          notificationHour,
        );
        if (!scheduledDate.isAfter(currentTime)) continue;
        plan.add(
          RenewalReminder(
            id: summary.documentId.hashCode + days,
            documentId: summary.documentId,
            daysBefore: days,
            scheduledDate: scheduledDate,
            title: 'Policy Renewal Reminder',
            body:
                'Your ${summary.documentType} from ${summary.insurer ?? "Unknown"} expires in $days days on ${summary.formattedExpiryDate}. Review your policy before renewal.',
          ),
        );
      }
    }
    return plan;
  }

  static int _deliveryHour({
    required int preferredHour,
    required int quietHoursStart,
    required int quietHoursEnd,
  }) {
    final inQuietHours = quietHoursStart == quietHoursEnd
        ? false
        : quietHoursStart > quietHoursEnd
            ? preferredHour >= quietHoursStart || preferredHour < quietHoursEnd
            : preferredHour >= quietHoursStart && preferredHour < quietHoursEnd;
    if (!inQuietHours) return preferredHour;
    return quietHoursEnd;
  }

  static Future<void> scheduleRenewalReminders(
      List<PolicySummary> summaries) async {
    await init();
    final plan = buildReminderPlan(summaries);
    try {
      // The app owns this notification plugin. Cancel first so removed
      // policies and changed reminder preferences cannot leave stale alerts.
      await _plugin.cancelAll();
      for (final reminder in plan) {
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tz.TZDateTime.from(reminder.scheduledDate, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'renewal_reminders',
              'Renewal Reminders',
              channelDescription: 'Reminders before policy renewal dates',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: reminder.documentId,
        );
      }
      debugPrint('Scheduled ${plan.length} renewal reminders');
    } catch (e) {
      debugPrint('Failed to schedule renewal notifications: $e');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      debugPrint('All notifications cancelled');
    } catch (e) {
      debugPrint('Failed to cancel notifications: $e');
    }
  }
}
