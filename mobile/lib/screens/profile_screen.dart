import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
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
import '../config/app_config.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';
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
  State<_DeleteConfirmationDialog> createState() => _DeleteConfirmationDialogState();
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
      title: const Text('Type DELETE to confirm'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This is your last chance. All data will be permanently erased.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Type DELETE',
              border: OutlineInputBorder(),
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
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: _canDelete ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            foregroundColor: const Color(0xFFC43D4B),
          ),
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
    } finally {
      // Clear services before the workspace is closed and reopened with a new
      // principal key. This also runs if the remote sign-out reports an error.
      await _clearWorkspaceData();
    }
    
    // No need for setState — authStateProvider will trigger rebuild.
  }
  
  /// Clears all local Hive boxes and consent ledger on sign-out.
  /// This ensures workspace isolation when switching accounts.
  Future<void> _clearWorkspaceData() async {
    try {
      // Clear service-owned state while all boxes are still open.
      await AnalyticsService.clear();
      await ContactService.clearSavedContact();
      AnalyticsService.dispose();

      // Delete the cleared files and reopen an empty workspace with a
      // principal that is not the signed-out account. The auth listener in
      // InsuranceApp will replace this with the account key after sign-in.
      await HiveWorkspaceService.resetForPrincipal(
        'local-only-${InstallService.getInstallId()}',
      );
      AnalyticsService.init();
      
      debugPrint('Workspace data cleared on sign-out');
    } catch (e) {
      debugPrint('Error clearing workspace data on sign-out: $e');
    }
  }

  /// Documents whose [processingState] is in-flight (not yet settled).
  static const _inFlightStates = {'received', 'processing', 'pending'};

  Future<void> _confirmDeleteAccount(BuildContext context, List<InsuranceDocument> docs) async {
    // ── Pending-processing guard (§10 item 6) ──
    // Prevent account deletion while documents are still being processed.
    // Processing is fast, so the user can retry in a few seconds.
    //
    // docs is passed from build() via ref.watch(documentsProvider) so the
    // list is always current — no race condition with async provider reads.
    //
    // Capture ScaffoldMessenger early to avoid use_build_context_synchronously
    // lint warnings after async gaps (the messenger is safe across gaps).
    final messenger = ScaffoldMessenger.of(context);
    final inFlight = docs.where((d) => _inFlightStates.contains(d.processingState)).toList();
    if (inFlight.isNotEmpty) {
      final names = inFlight.map((d) => d.filename).join(', ');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${inFlight.length} document${inFlight.length == 1 ? ' is' : 's are'} still processing: $names. '
            'Please wait for processing to complete before deleting your account.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded, color: Color(0xFFC43D4B), size: 48),
        title: const Text('Delete account permanently?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('• Your CoverWise account'),
            Text('• All uploaded policy documents on our servers'),
            Text('• All policy summaries and embeddings'),
            Text('• Your Q&A history on the server'),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone. Local data on this device will be cleared separately via Settings → Clear local data.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              foregroundColor: const Color(0xFFC43D4B),
            ),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Show a second confirmation with typing requirement
    if (!context.mounted) return;
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmationDialog(),
    );
    if (doubleConfirmed != true || !mounted) return;

    // Perform deletion
    try {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Deleting account...')),
      );
      // Per the 2026-07-19 review: the backend returns HTTP 202
      // with a per-stage status. The previous UI only handled
      // HTTP 200 + a single "deleted" message, which lied when
      // a stage failed. The new UI surfaces the per-stage result
      // so the user knows what was deleted, what failed, and
      // what will be retried.
      final result = await AuthService.deleteAccount();
      if (!mounted) return;
      // Build the user-facing message from the per-stage
      // status, not from a single "deleted" claim.
      final statusColor = result.isComplete ? Colors.green : Colors.orange;
      final String snackMessage;
      if (result.isComplete) {
        snackMessage =
            'Account deleted. ${result.deletedDocuments} document(s) and '
            '${result.deletedStorageFiles} storage file(s) removed.';
      } else if (result.isPartial) {
        snackMessage =
            'Account deletion is partially complete. '
            'Failed stages: ${result.failedStages.join(", ")}. '
            'Do not assume server deletion is complete. '
            'Local data on this device was not affected and can be '
            'cleared from the privacy screen.';
      } else {
        snackMessage =
            'Account deletion requested. Status: ${result.status}. '
            'Check the privacy screen for details.';
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(snackMessage),
          backgroundColor: statusColor,
          duration: const Duration(seconds: 8),
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppError.contextual(error: e, operation: 'account_deletion')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reactive auth state — rebuilds automatically when user signs in/out.
    final accountUser = ref.watch(currentUserProvider);
    final docsAsync = ref.watch(documentsProvider);
    final documents = docsAsync.valueOrNull ?? const <InsuranceDocument>[];
    final box = Hive.box(AppStateStore.boxName);
    final phone = box.get(AppStateStore.phoneNumberKey) as String?;
    final themeMode = AppStateRepository.getThemeMode();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          CoverWisePageHeader(
            title: phone ?? 'Your CoverWise profile',
            subtitle: phone != null
                ? 'Linked and ready across your devices.'
                : 'Your policy workspace currently stays on this device.',
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
          const CoverWiseSectionLabel('Account'),
          if (accountUser == null)
            CoverWiseSurface(
              child: ListTile(
                leading: const Icon(Icons.cloud_sync_rounded),
                title: const Text('Create a secure account'),
                subtitle: const Text('Restore this policy workspace across devices'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await Navigator.pushNamed(context, '/account');
                  // No manual setState needed — authStateProvider triggers rebuild.
                },
              ),
            )
          else
            CoverWiseSurface(
              child: ListTile(
                leading: const Icon(Icons.verified_user_rounded),
                title: Text(accountUser.email ?? 'Signed-in account'),
                subtitle: const Text('Workspace is linked to your account'),
                trailing: TextButton(
                  onPressed: _signOut,
                  child: const Text('Sign out'),
                ),
              ),
            ),
          CoverWiseSurface(
            child: Column(children: [
              CoverWiseActionRow(
                icon: Icons.phone_iphone_rounded,
                color: const Color(0xFF0F9D84),
                title: 'Phone number',
                subtitle: phone ?? 'Not linked',
                trailing: phone != null
                    ? TextButton(
                        onPressed: () async {
                          await box.delete(AppStateStore.phoneNumberKey);
                          setState(() {});
                        },
                        child: const Text('Remove'),
                      )
                    : const SizedBox.shrink(),
                onTap: null,
              ),
              const Divider(indent: 74),
              // Security audit P0-07 (2026-07-18): the bearer token is
              // never displayed, copied, or exported. The session state is
              // shown as a single line with no actionable export, rotate,
              // or revoke controls until Security Phase 1 (rotate/revoke)
              // lands. The "rotate" and "revoke" actions the audit
              // recommends are NOT exposed yet — adding them would either
              // need a real backend endpoint or would be lying.
              CoverWiseActionRow(
                icon: Icons.key_rounded,
                color: const Color(0xFF7557D3),
                title: 'Secure session',
                subtitle: accountUser != null
                    ? 'Account session active on this device'
                    : 'Anonymous session active on this device',
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
            ]),
          ),
          const CoverWiseSectionLabel('App'),
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
                icon: Icons.brightness_auto_rounded,
                color: const Color(0xFFE58726),
                title: 'Appearance',
                subtitle: themeMode == 'light'
                    ? 'Light'
                    : themeMode == 'dark'
                        ? 'Dark'
                        : 'System default',
                trailing: const SizedBox.shrink(),
                onTap: null,
              ),
            ]),
          ),
          const CoverWiseSectionLabel('Privacy'),
          CoverWiseSurface(
            child: Column(children: [
              const CoverWiseActionRow(
                icon: Icons.phonelink_lock_rounded,
                color: Color(0xFF0F9D84),
                title: 'Device-first storage',
                subtitle:
                    'Your policy workspace and personal details stay local.',
                trailing: SizedBox.shrink(),
                onTap: null,
              ),
              const Divider(indent: 74),
              CoverWiseActionRow(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFC43D4B),
                title: 'Delete account',
                subtitle: 'Permanently remove account and all server data',
                onTap: accountUser != null
                    ? () => _confirmDeleteAccount(context, documents)
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Create an account first to delete it'),
                          ),
                        ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
            child: Text(
              'CoverWise helps you understand your policies. It does not sell insurance.',
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
