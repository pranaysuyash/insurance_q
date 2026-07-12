import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/policy_summary.dart';

/// Schedules local notifications for policy renewal reminders.
///
/// Reminders are scheduled at 30, 15, 7, and 1 day(s) before each policy's
/// expiry date. All notifications are local (no server, no push token needed).
/// They survive app restarts (scheduled in the OS notification system).
///
/// Call [scheduleRenewalReminders] after summaries are loaded/updated.
/// Call [cancelAll] when the user clears data.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (error) {
      // Scheduling remains functional with the timezone package's default
      // location, but retain a diagnostic for unsupported desktop/web hosts.
      debugPrint('Unable to resolve device timezone: $error');
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      // Do not interrupt first launch before the user has seen a policy or
      // opted into renewal reminders. `requestPermissions` is called from the
      // dedicated reminder action instead.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        // Could navigate to the renewal screen here. For now, the notification
        // body tells the user to open the app.
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Requests notification permission (iOS). On Android 13+, the permission
  /// is requested automatically when the first notification is posted.
  static Future<bool> requestPermissions() async {
    await init();
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return result ?? true;
  }

  /// Schedules renewal reminders for all policies with a known expiry date.
  ///
  /// Cancels all existing reminders first, then schedules new ones. This is
  /// idempotent — safe to call after every summaries refresh.
  static Future<void> scheduleRenewalReminders(
      List<PolicySummary> summaries) async {
    await init();
    await _plugin.cancelAll();

    for (final summary in summaries) {
      if (summary.endDate == null || summary.isExpired) continue;

      final daysLeft = summary.daysUntilExpiry;
      if (daysLeft < 0) continue;

      for (final reminderDays in [30, 15, 7, 1]) {
        if (daysLeft > reminderDays) {
          final reminderDate = summary.endDate!.subtract(
            Duration(days: reminderDays),
          );
          // Policy expiry dates have no time component. Deliver at a useful,
          // predictable local time rather than midnight.
          final scheduledDate = DateTime(
            reminderDate.year,
            reminderDate.month,
            reminderDate.day,
            9,
          );

          // Don't schedule in the past
          if (scheduledDate.isBefore(DateTime.now())) continue;

          final id = _notificationId(summary.documentId, reminderDays);
          final title = reminderDays == 1
              ? 'Policy expires tomorrow!'
              : 'Policy expires in $reminderDays days';
          final body =
              'Your ${summary.documentType} from ${summary.insurer ?? 'your insurer'} '
              'expires on ${summary.formattedExpiryDate}. Renew to avoid a coverage gap.';

          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                'renewal_reminders',
                'Renewal Reminders',
                channelDescription:
                    'Reminders before your insurance policies expire',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: const DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: summary.documentId,
          );
        }
      }
    }
  }

  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Generates a stable notification ID from the document ID and reminder day.
  static int _notificationId(String documentId, int reminderDays) {
    // Simple hash: combine document ID hash with reminder days.
    // Keeps IDs unique per document+reminder combination and within int32 range.
    var hash = documentId.hashCode;
    hash = (hash ^ (reminderDays * 1000)) & 0x7FFFFFFF;
    return hash;
  }
}
