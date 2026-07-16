import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/policy_summary.dart';
import 'app_state_store.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Default reminder days if no preferences are saved.
  static const List<int> defaultReminderDays = [30, 14, 7];

  /// Load notification preferences from Hive with safe defaults on corruption.
  static Map<String, dynamic> loadPreferences() {
    try {
      final box = Hive.box(AppStateStore.boxName);
      return {
        'enabled': box.get(AppStateStore.notificationEnabledKey, defaultValue: true) as bool,
        'reminderDays': _safeIntList(box.get(AppStateStore.reminderDaysKey), [30, 14, 7]),
        'quietHoursStart': (box.get(AppStateStore.quietHoursStartKey) as int?) ?? 22,
        'quietHoursEnd': (box.get(AppStateStore.quietHoursEndKey) as int?) ?? 7,
        'disabledPolicies': _safeStringList(box.get(AppStateStore.disabledPoliciesKey)),
      };
    } catch (e) {
      debugPrint('Notification preferences corrupted, falling back to defaults: $e');
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
    if (enabled != null) await box.put(AppStateStore.notificationEnabledKey, enabled);
    if (reminderDays != null) await box.put(AppStateStore.reminderDaysKey, reminderDays);
    if (quietHoursStart != null) await box.put(AppStateStore.quietHoursStartKey, quietHoursStart);
    if (quietHoursEnd != null) await box.put(AppStateStore.quietHoursEndKey, quietHoursEnd);
    if (disabledPolicies != null) await box.put(AppStateStore.disabledPoliciesKey, disabledPolicies);
  }

  static Future<void> init() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
      await _plugin.initialize(settings: initSettings);
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

  static Future<void> scheduleRenewalReminders(List<PolicySummary> summaries) async {
    final prefs = loadPreferences();
    if (!prefs['enabled']) return;

    final daysBefore = (prefs['reminderDays'] as List<int>).isEmpty
        ? defaultReminderDays
        : prefs['reminderDays'] as List<int>;
    final disabledPolicies = prefs['disabledPolicies'] as List<String>;
    final quietStart = prefs['quietHoursStart'] as int;
    final quietEnd = prefs['quietHoursEnd'] as int;

    // Check if we're in quiet hours
    final now = DateTime.now();
    final currentHour = now.hour;
    final inQuietHours = quietStart > quietEnd
        ? (currentHour >= quietStart || currentHour < quietEnd)
        : (currentHour >= quietStart && currentHour < quietEnd);

    for (final summary in summaries) {
      if (summary.endDate == null || summary.isExpired) continue;
      if (disabledPolicies.contains(summary.documentId)) continue;

      for (final days in daysBefore) {
        final scheduledDate = summary.endDate!.subtract(Duration(days: days));
        if (scheduledDate.isAfter(DateTime.now())) {
          try {
            // Skip if in quiet hours
            if (inQuietHours) continue;

            await _plugin.show(
              id: summary.documentId.hashCode + days,
              title: 'Policy Renewal Reminder',
              body: 'Your ${summary.documentType} from ${summary.insurer ?? "Unknown"} expires in $days days on ${summary.formattedExpiryDate}. Renew now to avoid a coverage gap.',
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  'renewal_reminders',
                  'Renewal Reminders',
                  importance: Importance.high,
                  priority: Priority.high,
                ),
                iOS: DarwinNotificationDetails(),
              ),
            );
          } catch (e) {
            debugPrint('Failed to schedule notification: $e');
          }
        }
      }
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