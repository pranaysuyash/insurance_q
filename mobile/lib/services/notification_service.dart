import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../models/policy_summary.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

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
    const daysBefore = [30, 14, 7];
    for (final summary in summaries) {
      if (summary.endDate == null || summary.isExpired) continue;

      for (final days in daysBefore) {
        final scheduledDate = summary.endDate!.subtract(Duration(days: days));
        if (scheduledDate.isAfter(DateTime.now())) {
          try {
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