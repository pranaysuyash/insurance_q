import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../utils/document_icons.dart';
import '../services/notification_service.dart';
import 'documents_screen.dart';

class RenewalCalendarScreen extends ConsumerWidget {
  const RenewalCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(policySummariesProvider);

    if (summaries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Renewal Calendar')),
        body: EmptyStateWidget(
          icon: Icons.event_busy,
          title: 'No policies tracked',
          subtitle: 'Choose a policy file to track renewal dates.',
          actionLabel: 'Choose policy file',
          actionIcon: Icons.upload_file_rounded,
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const DocumentsScreen(startWithFilePicker: true),
            ),
          ),
          color: const Color(0xFFA94E00),
        ),
      );
    }

    final sorted = [...summaries]..sort((a, b) {
        final aDate = a.endDate ?? DateTime(9999);
        final bDate = b.endDate ?? DateTime(9999);
        return aDate.compareTo(bDate);
      });

    final expired = sorted.where((s) => s.isExpired).toList();
    final expiringSoon = sorted.where((s) => s.isExpiringSoon).toList();
    final active =
        sorted.where((s) => s.isActive && !s.isExpiringSoon).toList();
    final noEndDate = sorted.where((s) => s.endDate == null).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Renewal Calendar')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const CoverWisePageHeader(
            title: 'Never miss a renewal',
            subtitle:
                'See what needs attention first and keep insurer contact details close.',
            trailing: CoverWiseIconBadge(
              icon: Icons.event_repeat_outlined,
              color: CoverWiseColors.blueDeep,
              size: 52,
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CoverWiseIconBadge(
                    icon: Icons.notifications_active_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Get reminders 30, 15, 7 and 1 day before a policy expires.',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      final granted =
                          await NotificationService.requestPermissions();
                      if (granted) {
                        await NotificationService.scheduleRenewalReminders(
                          summaries,
                        );
                      }
                      if (!context.mounted) return;
                      if (granted) {
                        CoverWiseSnackBar.success(context, 'Renewal reminders are on.');
                      } else {
                        CoverWiseSnackBar.warning(context, 'Notifications are off. You can enable them in Settings.');
                      }
                    },
                    child: const Text('Enable'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (expired.isNotEmpty) ...[
            _SectionHeader('Expired', Icons.error, Colors.red, expired.length),
            const SizedBox(height: 8),
            ...expired.map((s) => _RenewalCard(summary: s, color: Colors.red)),
            const SizedBox(height: 20),
          ],
          if (expiringSoon.isNotEmpty) ...[
            _SectionHeader('Expiring Soon', Icons.warning, Colors.orange,
                expiringSoon.length),
            const SizedBox(height: 8),
            ...expiringSoon
                .map((s) => _RenewalCard(summary: s, color: Colors.orange)),
            const SizedBox(height: 20),
          ],
          if (active.isNotEmpty) ...[
            _SectionHeader(
                'Active', Icons.check_circle, Colors.green, active.length),
            const SizedBox(height: 8),
            ...active.map((s) => _RenewalCard(summary: s, color: Colors.green)),
          ],
          if (noEndDate.isNotEmpty) ...[
            if (active.isNotEmpty) const SizedBox(height: 20),
            _SectionHeader('Expiry Date Not Found', Icons.info_outline,
                Colors.blueGrey, noEndDate.length),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blueGrey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Expiry date not found in your policy — check your policy document',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            ...noEndDate
                .map((s) => _RenewalCard(summary: s, color: Colors.blueGrey)),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  const _SectionHeader(this.title, this.icon, this.color, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          CoverWiseIconBadge(icon: icon, color: color, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _RenewalCard extends StatelessWidget {
  final PolicySummary summary;
  final Color color;
  const _RenewalCard({required this.summary, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = iconForDocumentType(summary.documentType);
    final days = summary.daysUntilExpiry;
    final hasNoEndDate = summary.endDate == null;
    final trailingLabel = hasNoEndDate
        ? 'N/A'
        : summary.isExpired
            ? 'EXPIRED'
            : '$days days';
    final showRenewCta = summary.isExpired || summary.isExpiringSoon;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          ListTile(
            leading: CoverWiseIconBadge(icon: icon, color: color),
            title: Text(
              summary.documentType,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.insurer ?? "Insurer not found"}\nExpires ${summary.formattedExpiryDate}',
                ),
                if (largeText) ...[
                  const SizedBox(height: 8),
                  CoverWiseStatusChip(
                    icon: hasNoEndDate
                        ? Icons.help_outline_rounded
                        : summary.isExpired
                            ? Icons.error_rounded
                            : Icons.schedule_rounded,
                    label: trailingLabel,
                    color: color,
                    compact: true,
                  ),
                ],
              ],
            ),
            isThreeLine: true,
            trailing: largeText
                ? null
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CoverWiseStatusChip(
                        icon: hasNoEndDate
                            ? Icons.help_outline_rounded
                            : summary.isExpired
                                ? Icons.error_rounded
                                : Icons.schedule_rounded,
                        label: trailingLabel,
                        color: color,
                        compact: true,
                      ),
                      if (summary.policyNumber != null)
                        Text(
                          summary.policyNumber!,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          if (showRenewCta) _RenewNowButton(summary: summary, color: color),
        ],
      ),
    );
  }
}

class _RenewNowButton extends StatelessWidget {
  final PolicySummary summary;
  final Color color;
  const _RenewNowButton({required this.summary, required this.color});

  @override
  Widget build(BuildContext context) {
    final hasContact =
        summary.insurerHelpline != null || summary.insurerEmail != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: hasContact
              ? () => _showRenewalContactSheet(context)
              : () => _showNoContactInfo(context),
          icon: Icon(
            summary.isExpired ? Icons.replay_rounded : Icons.autorenew_rounded,
            size: 18,
          ),
          label: Text(
            summary.isExpired ? 'Contact insurer to renew' : 'Start renewal',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }

  void _showRenewalContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Renew ${summary.documentType}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Contact ${summary.insurer ?? "your insurer"} to start the renewal process.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              if (summary.insurerHelpline != null) ...[
                CoverWiseActionRow(
                  icon: Icons.phone_outlined,
                  color: Colors.green,
                  title: 'Call helpline',
                  subtitle: summary.insurerHelpline!,
                  onTap: () => _callHelpline(ctx),
                ),
                const SizedBox(height: 8),
              ],
              if (summary.insurerEmail != null) ...[
                CoverWiseActionRow(
                  icon: Icons.email_outlined,
                  color: CoverWiseColors.blueDeep,
                  title: 'Send email',
                  subtitle: summary.insurerEmail!,
                  onTap: () => _sendEmail(ctx),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _callHelpline(BuildContext context) async {
    Navigator.of(context).pop();
    final cleaned = summary.insurerHelpline!.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      CoverWiseSnackBar.error(context, 'Could not open phone dialer');
    }
  }

  void _sendEmail(BuildContext context) async {
    Navigator.of(context).pop();
    final uri = Uri(
      scheme: 'mailto',
      path: summary.insurerEmail,
      queryParameters: {
        'subject':
            'Policy Renewal - ${summary.policyNumber ?? summary.documentType}',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      CoverWiseSnackBar.error(context, 'Could not open email client');
    }
  }

  void _showNoContactInfo(BuildContext context) {
    CoverWiseSnackBar.warning(
      context,
      'Contact info not found for ${summary.insurer ?? "this insurer"}. Check your policy document or call the insurer directly.',
      actionLabel: 'View Policy',
      onAction: () {
        Navigator.of(context).pushNamed(
          '/policy-detail',
          arguments: summary.documentId,
        );
      },
    );
  }
}
