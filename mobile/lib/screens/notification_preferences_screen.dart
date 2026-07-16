import 'package:flutter/material.dart';
import '../providers/policy_providers.dart';
import '../services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen for managing notification preferences.
///
/// Allows users to:
/// - Enable/disable all renewal reminders
/// - Customize which days before expiry to be reminded (e.g., 30, 14, 7, 3, 1)
/// - Set quiet hours (do not disturb period)
/// - Disable reminders for specific policies
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  late bool _enabled;
  late List<int> _reminderDays;
  late int _quietHoursStart;
  late int _quietHoursEnd;
  late List<String> _disabledPolicies;
  bool _saving = false;

  // Available reminder day options
  static const List<int> _availableDays = [30, 14, 7, 3, 1];

  @override
  void initState() {
    super.initState();
    final prefs = NotificationService.loadPreferences();
    _enabled = prefs['enabled'] as bool;
    _reminderDays = List<int>.from(prefs['reminderDays'] as List);
    _quietHoursStart = prefs['quietHoursStart'] as int;
    _quietHoursEnd = prefs['quietHoursEnd'] as int;
    _disabledPolicies = List<String>.from(prefs['disabledPolicies'] as List);
  }

  Future<void> _savePreferences() async {
    await NotificationService.savePreferences(
      enabled: _enabled,
      reminderDays: _reminderDays,
      quietHoursStart: _quietHoursStart,
      quietHoursEnd: _quietHoursEnd,
      disabledPolicies: _disabledPolicies,
    );

    // Reschedule notifications with new preferences
    final summaries = ref.read(policySummariesProvider);
    if (_enabled) {
      await NotificationService.scheduleRenewalReminders(summaries);
    } else {
      await NotificationService.cancelAll();
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(policySummariesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await _savePreferences();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preferences saved')),
                      );
                      Navigator.pop(context);
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Master toggle
          SwitchListTile(
            title: const Text('Renewal Reminders'),
            subtitle: Text(
              _enabled ? 'Notifications are ON' : 'Notifications are OFF',
              style: TextStyle(color: _enabled ? Colors.green : Colors.grey),
            ),
            value: _enabled,
            onChanged: (value) {
              setState(() => _enabled = value);
            },
            secondary: Icon(
              _enabled ? Icons.notifications_active : Icons.notifications_off,
              color: _enabled ? Colors.green : Colors.grey,
            ),
          ),
          const Divider(),

          // Reminder days section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Remind me before expiry',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Choose how many days before your policy expires to receive a reminder.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          ..._availableDays.map((days) => CheckboxListTile(
                title: Text('$days days before'),
                value: _reminderDays.contains(days),
                onChanged: _enabled
                    ? (checked) {
                        setState(() {
                          if (checked == true) {
                            _reminderDays.add(days);
                            _reminderDays.sort((a, b) => b.compareTo(a));
                          } else if (_reminderDays.length > 1) {
                            // Prevent deselecting the last reminder day
                            _reminderDays.remove(days);
                          }
                        });
                      }
                    : null,
                secondary: Icon(
                  days >= 14 ? Icons.event : Icons.event_busy,
                  color: _reminderDays.contains(days) ? Colors.blue : Colors.grey,
                ),
              )),
          if (_reminderDays.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '⚠️ No reminders selected. You won\'t receive any renewal alerts.',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
              ),
            ),
          const Divider(),

          // Quiet hours section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Quiet Hours',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No notifications during these hours. Reminders will be delivered when quiet hours end.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('Start time'),
            trailing: Text(
              _formatHour(_quietHoursStart),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: _enabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: _quietHoursStart, minute: 0),
                    );
                    if (picked != null) {
                      setState(() => _quietHoursStart = picked.hour);
                    }
                  }
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('End time'),
            trailing: Text(
              _formatHour(_quietHoursEnd),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: _enabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: _quietHoursEnd, minute: 0),
                    );
                    if (picked != null) {
                      setState(() => _quietHoursEnd = picked.hour);
                    }
                  }
                : null,
          ),
          const Divider(),

          // Per-policy toggles
          if (summaries.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Per-Policy Reminders',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Toggle reminders for individual policies.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            ...summaries.map((summary) {
              final isDisabled = _disabledPolicies.contains(summary.documentId);
              return SwitchListTile(
                title: Text(summary.documentType),
                subtitle: Text(
                  summary.insurer ?? 'Unknown insurer',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                value: !isDisabled,
                onChanged: _enabled
                    ? (enabled) {
                        setState(() {
                          if (enabled) {
                            _disabledPolicies.remove(summary.documentId);
                          } else {
                            _disabledPolicies.add(summary.documentId);
                          }
                        });
                      }
                    : null,
                secondary: Icon(
                  isDisabled ? Icons.notifications_off : Icons.notifications_active,
                  color: isDisabled ? Colors.grey : Colors.green,
                ),
              );
            }),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
