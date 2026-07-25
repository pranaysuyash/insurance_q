import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import '../services/app_state_store.dart';
import '../services/app_state_repository.dart';
import '../services/auth_service.dart';
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
import '../localization/app_localizations.dart';
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
    return AlertDialog(
      title: Text(S.profileDeleteTypeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.profileDeleteTypeWarning),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: S.profileDeleteTypeHint,
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
          child: Text(S.cancel),
        ),
        FilledButton.tonal(
          onPressed: _canDelete ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            foregroundColor: const Color(0xFFC43D4B),
          ),
          child: Text(S.profileDeletePermanently),
        ),
      ],
    );
  }
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  DeletionStatus? _deletionStatus;
  bool _loadingDeletionStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _refreshDeletionStatus());
  }

  Future<void> _refreshDeletionStatus() async {
    if (!mounted || !AuthService.hasAccountSession) return;
    setState(() => _loadingDeletionStatus = true);
    try {
      final status = await AuthService.getDeletionStatus();
      if (mounted) setState(() => _deletionStatus = status);
    } catch (_) {
      if (mounted) setState(() => _deletionStatus = null);
    } finally {
      if (mounted) setState(() => _loadingDeletionStatus = false);
    }
  }

  String _deletionStatusMessage(DeletionStatus status) {
    switch (status.status) {
      case 'pending':
        return S.profileDeletionStatusPending;
      case 'running':
        return S.profileDeletionStatusRunning;
      case 'failed':
        return S.profileDeletionStatusFailed;
      default:
        return '';
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
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
        'local-only-${InstallService.getInstallId()}',
      );
      debugPrint('Workspace data cleared on sign-out');
    } catch (e) {
      debugPrint('Error clearing workspace data on sign-out: $e');
    }
  }

  static const _inFlightStates = {'received', 'processing', 'pending'};

  Future<void> _confirmDeleteAccount(
      BuildContext context, List<InsuranceDocument> docs) async {
    final inFlight =
        docs.where((d) => _inFlightStates.contains(d.processingState)).toList();
    if (inFlight.isNotEmpty) {
      final names = inFlight.map((d) => d.filename).join(', ');
      CoverWiseSnackBar.warning(
        context,
        S.profileInFlightWarning(inFlight.length, names),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded,
            color: Color(0xFFC43D4B), size: 48),
        title: Text(S.profileDeleteConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.profileDeleteConfirmHeader,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(S.profileDeleteItemAccount),
            Text(S.profileDeleteItemDocs),
            Text(S.profileDeleteItemSummaries),
            Text(S.profileDeleteItemHistory),
            const SizedBox(height: 12),
            Text(
              S.profileDeleteWarning,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              foregroundColor: const Color(0xFFC43D4B),
            ),
            child: Text(S.profileDeleteEverything),
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
      CoverWiseSnackBar.info(this.context, S.profileDeletingAccount);
      final result = await AuthService.deleteAccount();
      if (!mounted) return;
      final String snackMessage;
      if (result.isComplete) {
        snackMessage = S.profileDeleteComplete(
            result.deletedDocuments, result.deletedStorageFiles);
      } else if (result.isPartial) {
        snackMessage = S.profileDeletePartial(result.failedStages);
      } else {
        snackMessage = S.profileDeleteRequested(result.status);
      }
      if (result.isComplete) {
        CoverWiseSnackBar.success(this.context, snackMessage,
            duration: const Duration(seconds: 8));
      } else {
        CoverWiseSnackBar.warning(this.context, snackMessage,
            duration: const Duration(seconds: 8));
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      CoverWiseSnackBar.error(this.context,
          AppError.contextual(error: e, operation: 'account_deletion'),
          operation: 'account deletion');
    }
  }

  Future<void> _exportAccountData(BuildContext context) async {
    if (!AuthService.hasAccountSession) {
      CoverWiseSnackBar.info(context, S.profileCreateAccountFirst);
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
            child: Text(S.cancel),
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
      final export = await AuthService.exportAccount();
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
    final accountUser = ref.watch(currentUserProvider);
    final docsAsync = ref.watch(documentsProvider);
    final documents = docsAsync.asData?.value ?? const <InsuranceDocument>[];
    final box = Hive.box(AppStateStore.boxName);
    final phone = box.get(AppStateStore.phoneNumberKey) as String?;
    final themeMode = AppStateRepository.getThemeMode();

    return Scaffold(
      appBar: AppBar(title: Text(S.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          CoverWisePageHeader(
            title: phone ?? S.profileDefaultHeader,
            subtitle:
                phone != null ? S.profileLinkedHeader : S.profileUnlinkedHeader,
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
          CoverWiseSectionLabel(S.settingsSectionAccount),
          if (accountUser == null)
            CoverWiseSurface(
              child: ListTile(
                leading: const Icon(Icons.cloud_sync_rounded),
                title: Text(S.profileCreateAccount),
                subtitle: Text(S.profileRestoreWorkspace),
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
                title: Text(accountUser.email ?? S.profileSignedInAccount),
                subtitle: Text(S.profileWorkspaceLinked),
                trailing: TextButton(
                  onPressed: _signOut,
                  child: Text(S.signOut),
                ),
              ),
            ),
          if (accountUser != null && _deletionStatus?.isActionable == true)
            CoverWiseSurface(
              child: ListTile(
                leading: const Icon(Icons.sync_problem_rounded,
                    color: Color(0xFFE58726)),
                title: Text(S.profileDeletionStatusTitle),
                subtitle: Text(_deletionStatusMessage(_deletionStatus!)),
                trailing: _loadingDeletionStatus
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: _refreshDeletionStatus,
                        child: Text(S.profileDeletionStatusRefresh),
                      ),
              ),
            ),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Icons.phone_iphone_rounded,
                color: const Color(0xFF0F9D84),
                title: S.profilePhoneNumber,
                subtitle: phone ?? S.profileNotLinked,
                trailing: phone != null
                    ? TextButton(
                        onPressed: () async {
                          await box.delete(AppStateStore.phoneNumberKey);
                          setState(() {});
                        },
                        child: Text(S.remove),
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
                title: S.profileSecureSession,
                subtitle: accountUser != null
                    ? S.profileAccountSessionActive
                    : S.profileAnonymousSessionActive,
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
            ]),
          ),
          CoverWiseSectionLabel(S.profileAppSection),
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
                icon: Icons.brightness_auto_rounded,
                color: const Color(0xFFE58726),
                title: S.settingsAppearance,
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
          CoverWiseSectionLabel(S.profileFamilySection),
          CoverWiseSurface(
            child: _FamilySection(documents: documents),
          ),
          CoverWiseSectionLabel(S.profilePrivacySection),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Icons.phonelink_lock_rounded,
                color: const Color(0xFF0F9D84),
                title: S.profileDeviceFirstStorage,
                subtitle: S.profileDeviceFirstSubtitle,
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFC43D4B),
                title: S.profileDeleteAccount,
                subtitle: S.profileDeleteAccountSubtitle,
                onTap: accountUser != null
                    ? () => _confirmDeleteAccount(context, documents)
                    : () => CoverWiseSnackBar.info(
                        context, S.profileCreateAccountFirst),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
            child: Text(
              S.profileFooter,
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
