import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../utils/document_icons.dart';
import '../services/notification_service.dart';

class RenewalCalendarScreen extends ConsumerWidget {
  const RenewalCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(policySummariesProvider);

    if (summaries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Renewal Calendar')),
        body: const EmptyStateWidget(
          icon: Icons.event_busy,
          title: 'No policies tracked',
          subtitle: 'Upload documents to track renewal dates',
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
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Get reminders 30, 15, 7 and 1 day before a policy expires.',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final granted =
                          await NotificationService.requestPermissions();
                      if (granted) {
                        await NotificationService.scheduleRenewalReminders(
                          summaries,
                        );
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(granted
                              ? 'Renewal reminders are on.'
                              : 'Notifications are off. You can enable them in Settings.'),
                        ),
                      );
                    },
                    child: const Text('Turn on'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
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
                      style: TextStyle(
                          color: Colors.blueGrey.shade700, fontSize: 13),
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
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            title: Text(summary.documentType,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                '${summary.insurer ?? "Unknown"} • Expires: ${summary.formattedExpiryDate}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trailingLabel,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (summary.policyNumber != null)
                  Text(summary.policyNumber!,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          if (showRenewCta)
            _RenewNowButton(summary: summary, color: color),
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
            summary.isExpired ? Icons.replay : Icons.autorenew,
            size: 18,
          ),
          label: Text(summary.isExpired ? 'Renew Now' : 'Start Renewal'),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Renew ${summary.documentType}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Contact ${summary.insurer ?? "your insurer"} to start the renewal process.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              if (summary.insurerHelpline != null) ...[
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    child: const Icon(Icons.phone, color: Colors.green),
                  ),
                  title: const Text('Call Helpline'),
                  subtitle: Text(summary.insurerHelpline!),
                  onTap: () => _callHelpline(ctx),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (summary.insurerEmail != null) ...[
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: const Icon(Icons.email, color: Colors.blue),
                  ),
                  title: const Text('Send Email'),
                  subtitle: Text(summary.insurerEmail!),
                  onTap: () => _sendEmail(ctx),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }

  void _sendEmail(BuildContext context) async {
    Navigator.of(context).pop();
    final uri = Uri(
      scheme: 'mailto',
      path: summary.insurerEmail,
      queryParameters: {
        'subject': 'Policy Renewal - ${summary.policyNumber ?? summary.documentType}',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email client')),
      );
    }
  }

  void _showNoContactInfo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Contact info not found for ${summary.insurer ?? "this insurer"}. Check your policy document or call the insurer directly.',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View Policy',
          onPressed: () {
            Navigator.of(context).pushNamed(
              '/policy-detail',
              arguments: summary.documentId,
            );
          },
        ),
      ),
    );
  }
}
