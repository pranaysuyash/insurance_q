import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../providers/family_providers.dart';
import '../providers/questions_provider.dart';
import '../services/app_state_store.dart';
import '../services/app_state_repository.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../widgets/phone_capture_sheet.dart';
import 'notification_preferences_screen.dart';

/// App settings. Currently exposes the backend environment display and a
/// clear-data action. Kept deliberately small: only settings that actually
/// do something are shown.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _resolvedBaseUrl;

  @override
  void initState() {
    super.initState();
    _resolvedBaseUrl = AppConfig.baseUrl;
  }

  String _themeModeLabel(String mode) {
    switch (mode) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System default';
    }
  }

  void _showThemePicker() async {
    final current = AppStateRepository.getThemeMode();
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Appearance'),
        children: [
          _themeOption(ctx, 'system', 'System default', Icons.brightness_auto, current),
          _themeOption(ctx, 'light', 'Light', Icons.light_mode, current),
          _themeOption(ctx, 'dark', 'Dark', Icons.dark_mode, current),
        ],
      ),
    );
    if (selected != null && selected != current) {
      await AppStateRepository.setThemeMode(selected);
      // Trigger MaterialApp rebuild by incrementing the theme provider.
      ref.read(themeModeProvider.notifier).state++;
      if (mounted) setState(() {});
    }
  }

  Widget _themeOption(BuildContext ctx, String value, String label, IconData icon, String current) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, value),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (value == current) const Icon(Icons.check, color: Colors.blue),
        ],
      ),
    );
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all local data?'),
        content: const Text(
          'This permanently removes all locally stored documents, policy '
          'summaries, Q&A history, family members, and session data from '
          'this device. Uploaded documents on the server are not affected. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      // 1. Clear Hive boxes (documents + all app state)
      await Hive.box<String>(LocalStorageService.documentsBoxName).clear();
      await Hive.box(AppStateStore.boxName).clear();

      // 2. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 3. Delete physical document files
      final appDir = await getApplicationDocumentsDirectory();
      if (appDir.existsSync()) {
        await appDir.delete(recursive: true);
        appDir.createSync(recursive: true);
      }

      // 4. Invalidate all in-memory providers so the UI rebuilds empty
      ref.invalidate(documentsProvider);
      ref.invalidate(policySummariesProvider);
      ref.invalidate(qaHistoryProvider);
      refreshManualFamilyMembers(ref);

      // 5. Cancel all scheduled renewal notifications
      await NotificationService.cancelAll();

      // 6. Clear the auth token
      await AuthService.clearToken();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All local data cleared.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box(AppStateStore.boxName);
    final phone = box.get(AppStateStore.phoneNumberKey) as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Identity section
          ListTile(
            leading: Icon(
              phone != null ? Icons.verified_user_outlined : Icons.phone_android,
              color: phone != null ? Colors.green : Colors.grey,
            ),
            title: Text(phone != null ? 'Account linked' : 'Link your phone'),
            subtitle: Text(phone != null
                ? 'Connected as $phone'
                : 'Back up your policies and access from any device'),
            trailing: phone != null
                ? TextButton(
                    onPressed: () async {
                      await box.delete(AppStateStore.phoneNumberKey);
                      setState(() {});
                    },
                    child: const Text('Remove'),
                  )
                : TextButton(
                    onPressed: () async {
                      // Re-trigger the phone capture sheet
                      await box.put(AppStateStore.phonePromptCountKey, 0);
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      PhoneCaptureSheet.maybeShow(context);
                      setState(() {});
                    },
                    child: const Text('Add'),
                  ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Backend endpoint'),
            subtitle: Text(_resolvedBaseUrl ?? AppConfig.baseUrl),
          ),
          ListTile(
            leading: const Icon(Icons.tag),
            title: const Text('App version'),
            subtitle: Text('${AppConfig.appName} ${AppConfig.appVersion}'),
          ),
          const Divider(),
          // Theme toggle
          ListTile(
            leading: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            title: const Text('Appearance'),
            subtitle: Text(_themeModeLabel(AppStateRepository.getThemeMode())),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showThemePicker,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification Preferences'),
            subtitle: const Text('Manage renewal reminders and quiet hours'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationPreferencesScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
            title: Text('Clear local data',
                style: TextStyle(color: Colors.red.shade700)),
            subtitle: const Text(
                'Documents, summaries, history, family members, and session'),
            onTap: _confirmClearData,
          ),
        ],
      ),
    );
  }
}
