import 'package:flutter/material.dart';
import '../providers/policy_providers.dart';
import '../services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';

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
        title: const Text('Renewal reminders'),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    setState(() => _saving = true);
                    try {
                      await _savePreferences();
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Preferences saved')),
                      );
                      navigator.pop();
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const CoverWisePageHeader(
            title: 'Stay ahead of renewals',
            subtitle:
                'Choose when this device should remind you. Notifications are reminders, not insurer renewal notices.',
          ),
          // Master toggle
          CoverWiseSurface(
            child: SwitchListTile(
              title: const Text(
                'Renewal reminders',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _enabled ? 'Enabled on this device' : 'Disabled',
                style: TextStyle(
                  color: _enabled
                      ? const Color(0xFF16825D)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: _enabled,
              onChanged: (value) {
                setState(() => _enabled = value);
              },
              secondary: CoverWiseIconBadge(
                icon: _enabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: _enabled
                    ? const Color(0xFF16825D)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Reminder days section
          const CoverWiseSectionLabel('Remind me before expiry'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Choose how many days before your policy expires to receive a reminder.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          CoverWiseSurface(
            child: Column(
              children: [
                for (var i = 0; i < _availableDays.length; i++) ...[
                  CheckboxListTile(
                    title: Text('${_availableDays[i]} days before'),
                    value: _reminderDays.contains(_availableDays[i]),
                    onChanged: _enabled
                        ? (checked) {
                            final days = _availableDays[i];
                            setState(() {
                              if (checked == true) {
                                _reminderDays.add(days);
                                _reminderDays.sort((a, b) => b.compareTo(a));
                              } else if (_reminderDays.length > 1) {
                                _reminderDays.remove(days);
                              }
                            });
                          }
                        : null,
                    secondary: Icon(
                      _availableDays[i] >= 14
                          ? Icons.calendar_month_outlined
                          : Icons.schedule_outlined,
                      color: _reminderDays.contains(_availableDays[i])
                          ? CoverWiseColors.blueDeep
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (i < _availableDays.length - 1) const Divider(),
                ],
              ],
            ),
          ),
          if (_reminderDays.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'No reminder times are selected.',
                style: const TextStyle(color: Color(0xFFD97706), fontSize: 13),
              ),
            ),
          // Quiet hours section
          const CoverWiseSectionLabel('Quiet hours'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No notifications during these hours. Reminders will be delivered when quiet hours end.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          CoverWiseSurface(
            child: Column(children: [
              ListTile(
                leading: const CoverWiseIconBadge(
                    icon: Icons.bedtime_outlined,
                    color: Color(0xFF7C5AC7),
                    size: 40),
                title: const Text('Start time'),
                trailing: Text(
                  _formatHour(_quietHoursStart),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: _enabled
                    ? () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime:
                              TimeOfDay(hour: _quietHoursStart, minute: 0),
                        );
                        if (picked != null) {
                          setState(() => _quietHoursStart = picked.hour);
                        }
                      }
                    : null,
              ),
              const Divider(),
              ListTile(
                leading: const CoverWiseIconBadge(
                    icon: Icons.wb_sunny_outlined,
                    color: Color(0xFFD97706),
                    size: 40),
                title: const Text('End time'),
                trailing: Text(
                  _formatHour(_quietHoursEnd),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: _enabled
                    ? () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime:
                              TimeOfDay(hour: _quietHoursEnd, minute: 0),
                        );
                        if (picked != null) {
                          setState(() => _quietHoursEnd = picked.hour);
                        }
                      }
                    : null,
              ),
            ]),
          ),

          // Per-policy toggles
          if (summaries.isNotEmpty) ...[
            const CoverWiseSectionLabel('Per-policy reminders'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Toggle reminders for individual policies.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            CoverWiseSurface(
                child: Column(
                    children: summaries.indexed.map((entry) {
              final (index, summary) = entry;
              final isDisabled = _disabledPolicies.contains(summary.documentId);
              return Column(children: [
                SwitchListTile(
                  title: Text(summary.documentType),
                  subtitle: Text(
                    summary.insurer ?? 'Unknown insurer',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
                    isDisabled
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                    color: isDisabled
                        ? theme.colorScheme.onSurfaceVariant
                        : const Color(0xFF16825D),
                  ),
                ),
                if (index < summaries.length - 1) const Divider()
              ]);
            }).toList())),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
