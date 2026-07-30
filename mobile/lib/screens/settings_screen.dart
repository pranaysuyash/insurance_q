import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations_gen.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../providers/family_providers.dart';
import '../providers/entitlement_provider.dart';
import '../providers/questions_provider.dart';
import '../services/app_state_store.dart';
import '../services/app_state_repository.dart';
import '../services/consent_ledger.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/hive_workspace_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/phone_capture_sheet.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../widgets/shared/operation_usage_card.dart';
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

  // ── M10: Language picker ──────────────────────────────────────────

  String _localeLabel(String? locale) {
    switch (locale) {
      case 'hi':
        return 'हिन्दी';
      case 'gu':
        return 'ગુજરાતી';
      case 'mr':
        return 'मराठी';
      case 'ta':
        return 'தமிழ்';
      case 'en':
        return 'English';
      default:
        return 'English';
    }
  }

  void _showLanguagePicker() async {
    final current = AppStateRepository.getLocale();
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Language / भाषा'),
        children: [
          _localeOption(ctx, 'en', 'English', current),
          _localeOption(ctx, 'hi', 'हिन्दी', current),
          _localeOption(ctx, 'gu', 'ગુજરાતી', current),
          _localeOption(ctx, 'mr', 'मराठी', current),
          _localeOption(ctx, 'ta', 'தமிழ்', current),
        ],
      ),
    );
    if (selected != null && selected != current) {
      await AppStateRepository.setLocale(selected);
      // Trigger MaterialApp rebuild by toggling the locale counter.
      ref.read(localeTagProvider.notifier).setState(selected);
      if (mounted) setState(() {});
    }
  }

  Widget _localeOption(
      BuildContext ctx, String value, String label, String? current) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, value),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (value == current) const Icon(Icons.check, color: Colors.blue),
        ],
      ),
    );
  }

  Future<void> _confirmClearData() async {
    final l10n = AppLocalizationsGen.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsClearDataTitle),
        content: Text(l10n.settingsClearDataContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      // 1. Clear all Hive workspace boxes and cache
      await HiveWorkspaceService.clearLocalWorkspace();

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
      await ref.read(authServiceProvider.notifier).clearToken();

      if (!mounted) return;
      CoverWiseSnackBar.success(context, l10n.settingsClearDataSuccess);
    } catch (e) {
      if (!mounted) return;
      CoverWiseSnackBar.error(
          context, AppError.contextual(error: e, operation: 'clear_data'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    final box = Hive.box(AppStateStore.boxName);
    final phone = box.get(AppStateStore.phoneNumberKey) as String?;
    final accountUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          CoverWisePageHeader(
            title: l10n.settingsHeaderTitle,
            subtitle: l10n.settingsHeaderSubtitle,
          ),
          CoverWiseSectionLabel(l10n.settingsSectionPlan),
          Consumer(
            builder: (context, ref, _) {
              final l10n = AppLocalizationsGen.of(context);
              final entitlement = ref.watch(entitlementProvider);
              return CoverWiseSurface(
                child: Column(children: [
                  CoverWiseActionRow(
                    icon: Icons.workspace_premium_rounded,
                    color: entitlement.planTier == PlanTier.free
                        ? const Color(0xFF637083)
                        : const Color(0xFF7557D3),
                    title:
                        l10n.settingsCurrentPlan(entitlement.planTier.displayName),
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
                            ? l10n.upgrade
                            : l10n.manage,
                      ),
                    ),
                    onTap: null,
                  ),
                  const Divider(indent: 74),
                  CoverWiseActionRow(
                    icon: Icons.shopping_bag_outlined,
                    color: const Color(0xFFE58726),
                    title: l10n.settingsQaPacks,
                    subtitle: entitlement.hasPackQuestionsRemaining
                        ? l10n.settingsQuestionsInPacks(
                            entitlement.packQuestionsRemaining)
                        : l10n.settingsBuyQuestions,
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
                      title: l10n.settingsRenews,
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
          // M18: Operation cost breakdown — shows per-operation Q&A usage
          Consumer(
            builder: (context, ref, _) {
              final entitlement = ref.watch(entitlementProvider);
              return OperationUsageCard(entitlement: entitlement);
            },
          ),
          const SizedBox(height: 8),
          CoverWiseSectionLabel(l10n.settingsSectionAccount),
          CoverWiseSurface(
            child: Column(children: [
              if (accountUser != null) ...[
                CoverWiseActionRow(
                  icon: Icons.email_outlined,
                  color: const Color(0xFF0F9D84),
                  title: accountUser.email ?? l10n.settingsSignedIn,
                  subtitle: l10n.settingsSupabaseAccount,
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
                    ? l10n.settingsAccountLinked
                    : l10n.settingsLinkYourPhone,
                subtitle: phone != null
                    ? l10n.settingsConnectedAs(phone)
                    : l10n.settingsBackupSubtitle,
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
                  child: Text(phone != null ? l10n.remove : l10n.add),
                ),
                onTap: null,
              ),
            ]),
          ),
          CoverWiseSectionLabel(l10n.settingsSectionExperience),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Theme.of(context).brightness == Brightness.dark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: const Color(0xFF7557D3),
                title: l10n.settingsAppearance,
                subtitle: _themeModeLabel(AppStateRepository.getThemeMode()),
                onTap: _showThemePicker,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.notifications_active_outlined,
                color: const Color(0xFFE58726),
                title: l10n.settingsNotifications,
                subtitle: l10n.settingsNotificationsSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationPreferencesScreen(),
                  ),
                ),
              ),
              const Divider(indent: 74),
              // M10: Language picker — choose between English and Hindi
              CoverWiseActionRow(
                icon: Icons.translate_rounded,
                color: const Color(0xFF0F9D84),
                title: l10n.settingsLanguage,
                subtitle: l10n.settingsLanguageSubtitle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _localeLabel(AppStateRepository.getLocale()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
                onTap: _showLanguagePicker,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.auto_awesome_outlined,
                color: const Color(0xFF7557D3),
                title: l10n.settingsSmartSuggestions,
                subtitle: l10n.settingsSmartSuggestionsSubtitle,
                trailing: CoverWiseSoonBadge(),
                onTap: null,
              ),
            ]),
          ),
          CoverWiseSectionLabel(l10n.settingsSectionAppDetails),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Icons.info_outline_rounded,
                color: CoverWiseColors.blue,
                title: l10n.version,
                subtitle: '${AppConfig.appName} ${AppConfig.appVersion}',
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.dns_outlined,
                color: const Color(0xFF637083),
                title: l10n.settingsServiceEndpoint,
                subtitle: _resolvedBaseUrl ?? AppConfig.baseUrl,
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
            ]),
          ),
          CoverWiseSectionLabel(l10n.settingsSectionPrivacy),
          const _ConsentLedgerSection(),
          CoverWiseSectionLabel(l10n.settingsSectionDeviceData),
          CoverWiseSurface(
            child: CoverWiseActionRow(
              icon: Icons.delete_outline_rounded,
              color: const Color(0xFFC43D4B),
              title: l10n.settingsClearDataAction,
              subtitle: l10n.settingsClearDataSubtitle,
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
    final l10n = AppLocalizationsGen.of(context);
    // Watch the entitlement provider to trigger rebuilds after consent changes.
    ref.watch(entitlementProvider);
    final ledger = ConsentLedger();
    final records = ledger.getAllRecords();

    if (records.isEmpty) {
      return CoverWiseSurface(
        child: CoverWiseActionRow(
          icon: Icons.shield_outlined,
          color: const Color(0xFF0F9D84),
          title: l10n.settingsNoConsentRecords,
          subtitle: l10n.settingsConsentRecorded,
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

  String _purposeLabel(ConsentPurpose purpose, AppLocalizationsGen l10n) {
    switch (purpose) {
      case ConsentPurpose.documentProcessing:
        return l10n.settingsConsentPolicyProcessing;
      case ConsentPurpose.analytics:
        return l10n.settingsConsentAnalytics;
      case ConsentPurpose.marketingEmails:
        return 'Marketing Emails';
      case ConsentPurpose.privacyPolicy:
        return l10n.settingsConsentTermsAccepted;
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
    final l10n = AppLocalizationsGen.of(context);
    final isActive = record.isActive;
    final date =
        '${record.timestamp.day}/${record.timestamp.month}/${record.timestamp.year}';

    return CoverWiseActionRow(
      icon: _purposeIcon(record.purpose),
      color: isActive ? const Color(0xFF0F9D84) : const Color(0xFF637083),
      title: _purposeLabel(record.purpose, l10n),
      subtitle: isActive
          ? l10n.settingsConsentGranted(date, record.version)
          : l10n.settingsConsentRevoked(date),
      trailing: CoverWiseStatusChip(
        icon: isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
        label:
            isActive ? l10n.settingsConsentActive : l10n.settingsConsentRevokedLabel,
        color: isActive ? const Color(0xFF0F9D84) : const Color(0xFF637083),
        compact: true,
      ),
      onTap: null,
    );
  }
}
