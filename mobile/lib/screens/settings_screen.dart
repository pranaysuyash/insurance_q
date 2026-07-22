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
import '../services/consent_ledger.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/phone_capture_sheet.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../localization/app_localizations.dart';
import '../theme/coverwise_theme.dart';
import '../models/entitlement.dart';
import '../utils/app_error.dart';
import 'notification_preferences_screen.dart';
import 'qa_packs_screen.dart';
import 'upgrade_screen.dart';

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
      final mode = ref.read(themeModeProvider);
      ref.read(themeModeProvider.notifier).setState(mode + 1);
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
        title: Text(S.settingsClearDataTitle),
        content: Text(S.settingsClearDataContent),
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
            child: Text(S.clear),
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

      // 6. Clear the consent ledger
      await ConsentLedger().clear();

      // 7. Clear the auth token
      await AuthService.clearToken();

      if (!mounted) return;
      CoverWiseSnackBar.success(context, S.settingsClearDataSuccess);
    } catch (e) {
      if (!mounted) return;
      CoverWiseSnackBar.error(
          context, AppError.contextual(error: e, operation: 'clear_data'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box(AppStateStore.boxName);
    final phone = box.get(AppStateStore.phoneNumberKey) as String?;
    final accountUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(S.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          CoverWisePageHeader(
            title: S.settingsHeaderTitle,
            subtitle: S.settingsHeaderSubtitle,
          ),
          CoverWiseSectionLabel(S.settingsSectionPlan),
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
                    title:
                        S.settingsCurrentPlan(entitlement.planTier.displayName),
                    subtitle: entitlement.planTier.tagline,
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UpgradeScreen(),
                        ),
                      ),
                      child: Text(
                        entitlement.planTier == PlanTier.free
                            ? S.upgrade
                            : S.manage,
                      ),
                    ),
                    onTap: null,
                  ),
                  const Divider(indent: 74),
                  CoverWiseActionRow(
                    icon: Icons.shopping_bag_outlined,
                    color: const Color(0xFFE58726),
                    title: S.settingsQaPacks,
                    subtitle: entitlement.hasPackQuestionsRemaining
                        ? S.settingsQuestionsInPacks(
                            entitlement.packQuestionsRemaining)
                        : S.settingsBuyQuestions,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const QaPacksScreen(),
                      ),
                    ),
                  ),
                  if (entitlement.planTier != PlanTier.free) ...[
                    const Divider(indent: 74),
                    CoverWiseActionRow(
                      icon: Icons.calendar_today_rounded,
                      color: const Color(0xFF0F9D84),
                      title: S.settingsRenews,
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
          CoverWiseSectionLabel(S.settingsSectionAccount),
          CoverWiseSurface(
            child: Column(children: [
              if (accountUser != null) ...[
                CoverWiseActionRow(
                  icon: Icons.email_outlined,
                  color: const Color(0xFF0F9D84),
                  title: accountUser.email ?? S.settingsSignedIn,
                  subtitle: S.settingsSupabaseAccount,
                  trailing: const SizedBox.shrink(),
                  onTap: null,
                ),
                const Divider(indent: 74),
              ],
              CoverWiseActionRow(
                icon: phone != null
                    ? Icons.verified_user_rounded
                    : Icons.phone_iphone_rounded,
                color: phone != null
                    ? const Color(0xFF0F9D84)
                    : CoverWiseColors.blue,
                title: phone != null
                    ? S.settingsAccountLinked
                    : S.settingsLinkYourPhone,
                subtitle: phone != null
                    ? S.settingsConnectedAs(phone)
                    : S.settingsBackupSubtitle,
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
                  child: Text(phone != null ? S.remove : S.add),
                ),
                onTap: null,
              ),
            ]),
          ),
          CoverWiseSectionLabel(S.settingsSectionExperience),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Theme.of(context).brightness == Brightness.dark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: const Color(0xFF7557D3),
                title: S.settingsAppearance,
                subtitle: _themeModeLabel(AppStateRepository.getThemeMode()),
                onTap: _showThemePicker,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.notifications_active_outlined,
                color: const Color(0xFFE58726),
                title: S.settingsNotifications,
                subtitle: S.settingsNotificationsSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationPreferencesScreen(),
                  ),
                ),
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.auto_awesome_outlined,
                color: Color(0xFF7557D3),
                title: S.settingsSmartSuggestions,
                subtitle: S.settingsSmartSuggestionsSubtitle,
                trailing: CoverWiseSoonBadge(),
                onTap: null,
              ),
            ]),
          ),
          CoverWiseSectionLabel(S.settingsSectionAppDetails),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Icons.info_outline_rounded,
                color: CoverWiseColors.blue,
                title: S.version,
                subtitle: '${AppConfig.appName} ${AppConfig.appVersion}',
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.dns_outlined,
                color: const Color(0xFF637083),
                title: S.settingsServiceEndpoint,
                subtitle: _resolvedBaseUrl ?? AppConfig.baseUrl,
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
            ]),
          ),
          CoverWiseSectionLabel(S.settingsSectionPrivacy),
          _ConsentLedgerSection(),
          CoverWiseSectionLabel(S.settingsSectionDeviceData),
          CoverWiseSurface(
            child: CoverWiseActionRow(
              icon: Icons.delete_outline_rounded,
              color: const Color(0xFFC43D4B),
              title: S.settingsClearDataAction,
              subtitle: S.settingsClearDataSubtitle,
              onTap: _confirmClearData,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays the purpose-specific consent ledger records so users can see
/// exactly what consent they've granted, when, and for which purpose.
///
/// Uses ConsumerWidget so the section rebuilds after consent changes
/// during the current session.
class _ConsentLedgerSection extends ConsumerWidget {
  const _ConsentLedgerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the entitlement provider to trigger rebuilds after consent changes.
    ref.watch(entitlementProvider);
    final ledger = ConsentLedger();
    final records = ledger.getAllRecords();

    if (records.isEmpty) {
      return CoverWiseSurface(
        child: CoverWiseActionRow(
          icon: Icons.shield_outlined,
          color: const Color(0xFF0F9D84),
          title: S.settingsNoConsentRecords,
          subtitle: S.settingsConsentRecorded,
          trailing: const SizedBox.shrink(),
          onTap: null,
        ),
      );
    }

    // Group by purpose, show latest state for each.
    final latestByPurpose = <ConsentPurpose, ConsentRecord>{};
    for (final r in records) {
      latestByPurpose[r.purpose] = r;
    }

    return CoverWiseSurface(
      child: Column(
        children: [
          for (final entry in latestByPurpose.entries) ...[
            _ConsentRecordRow(record: entry.value),
            if (entry.key != latestByPurpose.keys.last)
              const Divider(indent: 74),
          ],
        ],
      ),
    );
  }
}

class _ConsentRecordRow extends StatelessWidget {
  final ConsentRecord record;
  const _ConsentRecordRow({required this.record});

  String _purposeLabel(ConsentPurpose purpose) {
    switch (purpose) {
      case ConsentPurpose.documentProcessing:
        return S.settingsConsentPolicyProcessing;
      case ConsentPurpose.analytics:
        return S.settingsConsentAnalytics;
      case ConsentPurpose.marketingEmails:
        return 'Marketing Emails';
      case ConsentPurpose.privacyPolicy:
        return S.settingsConsentTermsAccepted;
      case ConsentPurpose.cameraAccess:
        return 'Camera Access';
      case ConsentPurpose.evaluationDataset:
        return 'Evaluation Dataset';
      case ConsentPurpose.modelImprovement:
        return 'Model Improvement';
    }
  }

  IconData _purposeIcon(ConsentPurpose purpose) {
    switch (purpose) {
      case ConsentPurpose.documentProcessing:
        return Icons.description_outlined;
      case ConsentPurpose.analytics:
        return Icons.bar_chart_outlined;
      case ConsentPurpose.marketingEmails:
        return Icons.contact_mail_outlined;
      case ConsentPurpose.privacyPolicy:
        return Icons.rule_outlined;
      case ConsentPurpose.cameraAccess:
        return Icons.camera_alt_outlined;
      case ConsentPurpose.evaluationDataset:
        return Icons.dataset_outlined;
      case ConsentPurpose.modelImprovement:
        return Icons.build_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = record.isActive;
    final date =
        '${record.timestamp.day}/${record.timestamp.month}/${record.timestamp.year}';

    return CoverWiseActionRow(
      icon: _purposeIcon(record.purpose),
      color: isActive ? const Color(0xFF0F9D84) : const Color(0xFF637083),
      title: _purposeLabel(record.purpose),
      subtitle: isActive
          ? S.settingsConsentGranted(date, record.version)
          : S.settingsConsentRevoked(date),
      trailing: CoverWiseStatusChip(
        icon: isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
        label:
            isActive ? S.settingsConsentActive : S.settingsConsentRevokedLabel,
        color: isActive ? const Color(0xFF0F9D84) : const Color(0xFF637083),
        compact: true,
      ),
      onTap: null,
    );
  }
}
