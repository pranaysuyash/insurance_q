import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../utils/document_icons.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Ensure summaries are loaded from local Hive cache even if backend is
    // unreachable. The provider reads from Hive on construction, so this is
    // already offline-first. We also attempt a background refresh so newly
    // processed documents appear without requiring a cold restart.
    _refreshInBackground();
  }

  Future<void> _refreshInBackground() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final summaries = ref.read(policySummariesProvider);
      if (summaries.isNotEmpty) {
        // Already have cached data — try fetching any new backend summaries
        // in the background without blocking the UI.
        for (final s in summaries) {
          if (!mounted) return;
          try {
            await ref
                .read(policySummariesProvider.notifier)
                .fetchFromBackend(s.documentId, s.documentType);
          } catch (_) {
            // Backend unreachable — cached data is fine.
          }
        }
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(policySummariesProvider);

    if (summaries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Emergency Card')),
        body: const EmptyStateWidget(
          icon: Icons.emergency,
          title: 'No policies loaded',
          subtitle:
              'Upload insurance documents to access emergency information',
          color: Color(0xFFC43B55),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency details')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const CoverWisePageHeader(
            title: 'Help at a glance',
            subtitle:
                'Keep policy numbers and insurer contact details ready when time matters.',
            trailing: CoverWiseIconBadge(
              icon: Icons.emergency_outlined,
              color: Colors.red,
              size: 52,
            ),
          ),
          ...summaries.map((summary) => _EmergencyCard(summary: summary)),
        ],
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final PolicySummary summary;
  const _EmergencyCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final icon = iconForDocumentType(summary.documentType);
    final color = colorForDocumentType(summary.documentType);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CoverWiseIconBadge(icon: icon, color: color, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.documentType,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      if (summary.insurer != null)
                        Text(
                          summary.insurer!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                    ],
                  ),
                ),
                if (summary.isExpired)
                  _StatusBadge('EXPIRED', Colors.red)
                else if (summary.isExpiringSoon)
                  _StatusBadge('EXPIRING', Colors.orange)
                else
                  _StatusBadge('ACTIVE', Colors.green),
              ],
            ),
            const Divider(height: 24),
            if (summary.policyNumber != null) ...[
              _InfoRow(
                Icons.badge_outlined,
                'Policy number',
                summary.policyNumber!,
              ),
              const SizedBox(height: 12),
            ],
            if (summary.formattedCoverageAmount != 'Unknown') ...[
              _InfoRow(
                Icons.shield_outlined,
                'Coverage',
                summary.formattedCoverageAmount,
              ),
              const SizedBox(height: 12),
            ],
            if (summary.formattedExpiryDate != 'Unknown') ...[
              _InfoRow(
                Icons.event_outlined,
                'Expires',
                summary.formattedExpiryDate,
              ),
              const SizedBox(height: 12),
            ],
            if (summary.insurerHelpline != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.phone_outlined, size: 20),
                  label: Text('Call insurer • ${summary.insurerHelpline}'),
                  onPressed: () => _callNumber(summary.insurerHelpline!),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
            if (summary.insurerEmail != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.email_outlined, size: 20),
                  label: Text('Email • ${summary.insurerEmail!}'),
                  onPressed: () => _sendEmail(summary.insurerEmail!),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _callNumber(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return CoverWiseStatusChip(
      icon: label.toLowerCase().contains('expired')
          ? Icons.error_rounded
          : label.toLowerCase().contains('left')
              ? Icons.schedule_rounded
              : Icons.check_circle_rounded,
      label: label,
      color: color,
      compact: true,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return CoverWiseMetadataRow(
      icon: icon,
      label: label,
      value: value,
      selectable: true,
    );
  }
}
