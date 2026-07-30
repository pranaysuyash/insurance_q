import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations_gen.dart';
import '../services/app_state_store.dart';
import '../services/app_state_repository.dart';
import '../services/auth_service.dart';
import '../models/identity.dart';
import '../services/analytics_service.dart';
import '../services/contact_service.dart';
import '../services/install_service.dart';
import '../services/hive_workspace_service.dart';
import '../models/document_model.dart';
import '../providers/auth_provider.dart';
import '../providers/document_providers.dart';
import '../providers/entitlement_provider.dart';
import '../providers/family_providers.dart';
import '../config/app_config.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../utils/app_error.dart';

/// Profile / Account Screen — shows device identity, token status, and account health.
///
/// For an info broker, this is about transparency: users can see exactly
/// what data the app holds and how their anonymous identity works.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _DeleteConfirmationDialog extends StatefulWidget {
  @override
  State<_DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  final _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    return AlertDialog(
      title: Text(l10n.profileDeleteTypeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.profileDeleteTypeWarning),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.profileDeleteTypeHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => _canDelete = value == 'DELETE');
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton.tonal(
          onPressed: _canDelete ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            foregroundColor: const Color(0xFFC43D4B),
          ),
          child: Text(l10n.profileDeletePermanently),
        ),
      ],
    );
  }
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  DeletionStatus? _deletionStatus;
  bool _loadingDeletionStatus = false;

  /// I3-P1e: Periodic poller for in-progress account deletions.
  /// When deleteAccount() returns a 202 (async in progress), this timer
  /// checks the backend every 30 seconds until deletion completes or fails.
  Timer? _deletionPoller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _refreshDeletionStatus());
  }

  @override
  void dispose() {
    _deletionPoller?.cancel();
    super.dispose();
  }

  Future<void> _refreshDeletionStatus() async {
    final auth = ref.read(authServiceProvider.notifier);
    if (!mounted || !auth.hasAccountSession) return;
    setState(() => _loadingDeletionStatus = true);
    try {
      final status = await auth.getDeletionStatus();
      if (!mounted) return;
      setState(() => _deletionStatus = status);
      // I3-P1e: Start or stop the periodic poller based on deletion state.
      _updateDeletionPoller(status);
    } catch (_) {
      if (mounted) setState(() => _deletionStatus = null);
    } finally {
      if (mounted) setState(() => _loadingDeletionStatus = false);
    }
  }

  /// I3-P1e: Manage the periodic deletion poller.
  /// Starts polling when deletion is in progress (pending/running/failed);
  /// stops polling when deletion completes or the status becomes non-actionable.
  void _updateDeletionPoller(DeletionStatus status) {
    if (status.isActionable) {
      _deletionPoller ??= Timer.periodic(
        const Duration(seconds: 30),
        (_) => _refreshDeletionStatus(),
      );
    } else {
      _deletionPoller?.cancel();
      _deletionPoller = null;
    }
  }

  String _deletionStatusMessage(AppLocalizationsGen l10n, DeletionStatus status) {
    switch (status.status) {
      case 'pending':
        return l10n.profileDeletionStatusPending;
      case 'running':
        return l10n.profileDeletionStatusRunning;
      case 'failed':
        return l10n.profileDeletionStatusFailed;
      default:
        return '';
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authServiceProvider.notifier).signOut();
    } finally {
      await _clearWorkspaceData();
    }
  }

  Future<void> _clearWorkspaceData() async {
    try {
      if (AppConfig.hasRevenueCatConfig) {
        await ref.read(billingAdapterProvider).clearAccountIdentity();
      }
      ref.read(analyticsServiceProvider.notifier).resetForWorkspace();
      await ContactService.clearSavedContact();
      await HiveWorkspaceService.resetForPrincipal(
        LocalPrincipal(InstallService.getInstallId()),
      );
      debugPrint('Workspace data cleared on sign-out');
    } catch (e) {
      debugPrint('Error clearing workspace data on sign-out: $e');
    }
  }

  static const _inFlightStates = {'received', 'processing', 'pending'};

  Future<void> _confirmDeleteAccount(
      BuildContext context, List<InsuranceDocument> docs) async {
    final l10n = AppLocalizationsGen.of(context);
    final inFlight =
        docs.where((d) => _inFlightStates.contains(d.processingState)).toList();
    if (inFlight.isNotEmpty) {
      CoverWiseSnackBar.warning(
        context,
        l10n.profileInFlightWarning(inFlight.length),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded,
            color: Color(0xFFC43D4B), size: 48),
        title: Text(l10n.profileDeleteConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileDeleteConfirmHeader,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(l10n.profileDeleteItemAccount),
            Text(l10n.profileDeleteItemDocs),
            Text(l10n.profileDeleteItemSummaries),
            Text(l10n.profileDeleteItemHistory),
            const SizedBox(height: 12),
            Text(
              l10n.profileDeleteWarning,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              foregroundColor: const Color(0xFFC43D4B),
            ),
            child: Text(l10n.profileDeleteEverything),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (!context.mounted) return;
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmationDialog(),
    );
    if (doubleConfirmed != true || !mounted) return;

    try {
      if (!mounted) return;
      CoverWiseSnackBar.info(this.context, l10n.profileDeletingAccount);
      final result = await ref.read(authServiceProvider.notifier).deleteAccount();
      if (!mounted) return;
      final String snackMessage;
      if (result.isComplete) {
        snackMessage = l10n.profileDeleteComplete(
            result.deletedDocuments, result.deletedStorageFiles);
      } else if (result.isPartial) {
        snackMessage = l10n.profileDeletePartial(result.failedStages);
      } else {
        snackMessage = l10n.profileDeleteRequested(result.status);
      }
      if (result.isComplete) {
        CoverWiseSnackBar.success(this.context, snackMessage,
            duration: const Duration(seconds: 8));
      } else {
        CoverWiseSnackBar.warning(this.context, snackMessage,
            duration: const Duration(seconds: 8));
      }
      setState(() {});
      // I3-P1e: For async deletions (202), immediately fetch the deletion
      // status so the status banner appears without waiting for the next
      // screen mount or poller tick.
      if (!result.isComplete && mounted) {
        _refreshDeletionStatus();
      }
    } catch (e) {
      if (!mounted) return;
      CoverWiseSnackBar.error(this.context,
          AppError.contextual(error: e, operation: 'account_deletion'),
          operation: 'account deletion');
    }
  }

  Future<void> _exportAccountData(BuildContext context) async {
    final l10n = AppLocalizationsGen.of(context);
    if (!ref.read(authServiceProvider.notifier).hasAccountSession) {
      CoverWiseSnackBar.info(context, l10n.profileCreateAccountFirst);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.ios_share_rounded),
        title: const Text('Export account data?'),
        content: const Text(
          'This export includes account and policy metadata. It may include '
          'short-lived links to your private source files. Share it only with '
          'a destination you trust.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Export'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final export = await ref.read(authServiceProvider.notifier).exportAccount();
      final json = const JsonEncoder.withIndent('  ').convert(export);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          text: json,
          subject: 'CoverWise account export',
        ),
      );
      if (!mounted) return;
      CoverWiseSnackBar.success(
        this.context,
        'Account export is ready to share.',
      );
    } catch (error) {
      if (!mounted) return;
      CoverWiseSnackBar.error(
        this.context,
        AppError.contextual(error: error, operation: 'account_export'),
        operation: 'export account data',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    final accountUser = ref.watch(currentUserProvider);
    final docsAsync = ref.watch(documentsProvider);
    final documents = docsAsync.asData?.value ?? const <InsuranceDocument>[];
    final box = Hive.box(AppStateStore.boxName);
    final phone = box.get(AppStateStore.phoneNumberKey) as String?;
    final themeMode = AppStateRepository.getThemeMode();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          CoverWisePageHeader(
            title: phone ?? l10n.profileDefaultHeader,
            subtitle:
                phone != null ? l10n.profileLinkedHeader : l10n.profileUnlinkedHeader,
            trailing: CoverWiseIconBadge(
              icon: phone != null
                  ? Icons.verified_user_rounded
                  : Icons.person_outline_rounded,
              color: phone != null
                  ? const Color(0xFF0F9D84)
                  : CoverWiseColors.blue,
              size: 54,
            ),
          ),
          CoverWiseSectionLabel(l10n.settingsSectionAccount),
          if (accountUser == null)
            CoverWiseSurface(
              child: ListTile(
                leading: const Icon(Icons.cloud_sync_rounded),
                title: Text(l10n.profileCreateAccount),
                subtitle: Text(l10n.profileRestoreWorkspace),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await Navigator.pushNamed(context, '/account');
                },
              ),
            )
          else
            CoverWiseSurface(
              child: ListTile(
                leading: const Icon(Icons.verified_user_rounded),
                title: Text(accountUser.email ?? l10n.profileSignedInAccount),
                subtitle: Text(l10n.profileWorkspaceLinked),
                trailing: TextButton(
                  onPressed: _signOut,
                  child: Text(l10n.signOut),
                ),
              ),
            ),
          if (accountUser != null && _deletionStatus?.isActionable == true)
            CoverWiseSurface(
              child: ListTile(
                leading: const Icon(Icons.sync_problem_rounded,
                    color: Color(0xFFE58726)),
                title: Text(l10n.profileDeletionStatusTitle),
                subtitle: Text(_deletionStatusMessage(l10n, _deletionStatus!)),
                trailing: _loadingDeletionStatus
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: _refreshDeletionStatus,
                        child: Text(l10n.profileDeletionStatusRefresh),
                      ),
              ),
            ),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Icons.phone_iphone_rounded,
                color: const Color(0xFF0F9D84),
                title: l10n.profilePhoneNumber,
                subtitle: phone ?? l10n.profileNotLinked,
                trailing: phone != null
                    ? TextButton(
                        onPressed: () async {
                          await box.delete(AppStateStore.phoneNumberKey);
                          setState(() {});
                        },
                        child: Text(l10n.remove),
                      )
                    : const SizedBox.shrink(),
                onTap: null,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.ios_share_rounded,
                color: CoverWiseColors.blue,
                title: 'Export account data',
                subtitle: accountUser != null
                    ? 'Download account metadata and available source links'
                    : 'Create an account to export server-held data',
                onTap: () => _exportAccountData(context),
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.key_rounded,
                color: const Color(0xFF7557D3),
                title: l10n.profileSecureSession,
                subtitle: accountUser != null
                    ? l10n.profileAccountSessionActive
                    : l10n.profileAnonymousSessionActive,
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
            ]),
          ),
          CoverWiseSectionLabel(l10n.profileAppSection),
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
                icon: Icons.brightness_auto_rounded,
                color: const Color(0xFFE58726),
                title: l10n.settingsAppearance,
                subtitle: themeMode == 'light'
                    ? 'Light'
                    : themeMode == 'dark'
                        ? 'Dark'
                        : 'System default',
                trailing: const SizedBox.shrink(),
                onTap: null,
),
              ],
            ),
          ),
          CoverWiseSectionLabel(l10n.profileFamilySection),
          CoverWiseSurface(
            child: _FamilySection(documents: documents),
          ),
          CoverWiseSectionLabel(l10n.profilePrivacySection),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Icons.phonelink_lock_rounded,
                color: const Color(0xFF0F9D84),
                title: l10n.profileDeviceFirstStorage,
                subtitle: l10n.profileDeviceFirstSubtitle,
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFC43D4B),
                title: l10n.profileDeleteAccount,
                subtitle: l10n.profileDeleteAccountSubtitle,
                onTap: accountUser != null
                    ? () => _confirmDeleteAccount(context, documents)
                    : () => CoverWiseSnackBar.info(
                        context, l10n.profileCreateAccountFirst),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
            child: Text(
              l10n.profileFooter,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilySection extends ConsumerWidget {
  final List<InsuranceDocument> documents;
  const _FamilySection({required this.documents});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(mergedFamilyMembersProvider(documents));

    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading family: $e'),
      ),
      data: (policyHolders) {
        if (policyHolders.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CoverWiseIconBadge(
                  icon: Icons.family_restroom_rounded,
                  color: const Color(0xFF16866B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No family members detected yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.pushNamed(context, '/family'),
                  child: const Text('Add family member'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            CoverWiseActionRow(
              icon: Icons.family_restroom_rounded,
              color: const Color(0xFF16866B),
              title: 'Family members',
              subtitle: '${policyHolders.length} people across your policies',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pushNamed(context, '/family'),
            ),
          ],
        );
      },
    );
  }
}
