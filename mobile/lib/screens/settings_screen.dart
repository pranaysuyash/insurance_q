import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../providers/family_providers.dart';
import '../providers/entitlement_provider.dart';
import '../providers/questions_provider.dart';
import '../services/app_state_store.dart';
import '../services/app_state_repository.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../widgets/phone_capture_sheet.dart';
import '../widgets/shared/coverwise_components.dart';
import '../theme/coverwise_theme.dart';
import '../models/entitlement.dart';
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
          _themeOption(
              ctx, 'system', 'System default', Icons.brightness_auto, current),
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

  Widget _themeOption(BuildContext ctx, String value, String label,
      IconData icon, String current) {
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
      ref.read(entitlementProvider.notifier).resetToFree();
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
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const CoverWisePageHeader(
            title: 'Your app, your preferences',
            subtitle: 'Manage access, reminders and what stays on this device.',
          ),
          const CoverWiseSectionLabel('Plan'),
          Consumer(
            builder: (context, ref, _) {
              final entitlement = ref.watch(entitlementProvider);
              return CoverWiseSurface(
                child: Column(children: [
                  CoverWiseActionRow(
                    icon: Icons.workspace_premium_rounded,
                    color: entitlement.planTier == PlanTier.free
                        ? const Color(0xFF637083)
                        : const Color(0xFF7557D3),
                    title: 'Current plan: ${entitlement.planTier.displayName}',
                    subtitle: entitlement.planTier.tagline,
                    trailing: entitlement.planTier == PlanTier.free
                        ? TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Upgrade coming soon')),
                              );
                            },
                            child: const Text('Upgrade'),
                          )
                        : TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Plan management coming soon')),
                              );
                            },
                            child: const Text('Manage'),
                          ),
                    onTap: null,
                  ),
                  if (entitlement.planTier != PlanTier.free) ...[
                    const Divider(indent: 74),
                    CoverWiseActionRow(
                      icon: Icons.calendar_today_rounded,
                      color: const Color(0xFF0F9D84),
                      title: 'Renews',
                      subtitle: entitlement.expiresAt != null
                          ? '${entitlement.expiresAt!.day}/${entitlement.expiresAt!.month}/${entitlement.expiresAt!.year}'
                          : 'Unknown',
                      trailing: const SizedBox.shrink(),
                      onTap: null,
                    ),
                  ],
                ]),
              );
            },
          ),
          const CoverWiseSectionLabel('Account'),
          CoverWiseSurface(
            child: CoverWiseActionRow(
              icon: phone != null
                  ? Icons.verified_user_rounded
                  : Icons.phone_iphone_rounded,
              color: phone != null
                  ? const Color(0xFF0F9D84)
                  : CoverWiseColors.blue,
              title: phone != null ? 'Account linked' : 'Link your phone',
              subtitle: phone != null
                  ? 'Connected as $phone'
                  : 'Back up policies and use them on another device',
              trailing: TextButton(
                onPressed: () async {
                  if (phone != null) {
                    await box.delete(AppStateStore.phoneNumberKey);
                  } else {
                    await box.put(AppStateStore.phonePromptCountKey, 0);
                    if (!context.mounted) return;
                    PhoneCaptureSheet.maybeShow(context);
                  }
                  if (mounted) setState(() {});
                },
                child: Text(phone != null ? 'Remove' : 'Add'),
              ),
              onTap: null,
            ),
          ),
          const CoverWiseSectionLabel('Experience'),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Theme.of(context).brightness == Brightness.dark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: const Color(0xFF7557D3),
                title: 'Appearance',
                subtitle: _themeModeLabel(AppStateRepository.getThemeMode()),
                onTap: _showThemePicker,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.notifications_active_outlined,
                color: const Color(0xFFE58726),
                title: 'Notifications',
                subtitle: 'Renewal reminders and quiet hours',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationPreferencesScreen(),
                  ),
                ),
              ),
            ]),
          ),
          const CoverWiseSectionLabel('App details'),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Icons.info_outline_rounded,
                color: CoverWiseColors.blue,
                title: 'Version',
                subtitle: '${AppConfig.appName} ${AppConfig.appVersion}',
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.dns_outlined,
                color: const Color(0xFF637083),
                title: 'Service endpoint',
                subtitle: _resolvedBaseUrl ?? AppConfig.baseUrl,
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
            ]),
          ),
          const CoverWiseSectionLabel('Device data'),
          CoverWiseSurface(
            child: CoverWiseActionRow(
              icon: Icons.delete_outline_rounded,
              color: const Color(0xFFC43D4B),
              title: 'Clear local data',
              subtitle:
                  'Remove documents, summaries, history and family members',
              onTap: _confirmClearData,
            ),
          ),
        ],
      ),
    );
  }
}
