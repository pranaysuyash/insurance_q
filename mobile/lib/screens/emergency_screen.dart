import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../utils/document_icons.dart';

class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(policySummariesProvider);

    if (summaries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Emergency Card')),
        body: const EmptyStateWidget(
          icon: Icons.emergency,
          title: 'No policies loaded',
          subtitle: 'Upload insurance documents to access emergency information',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Card')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: summaries.length,
        itemBuilder: (context, index) {
          final s = summaries[index];
          return _EmergencyCard(summary: s);
        },
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
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.documentType,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (summary.insurer != null)
                        Text(summary.insurer!, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
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
              _InfoRow(Icons.badge, 'Policy Number', summary.policyNumber!),
              const SizedBox(height: 12),
            ],
            if (summary.formattedCoverageAmount != 'Unknown') ...[
              _InfoRow(Icons.shield, 'Coverage', summary.formattedCoverageAmount),
              const SizedBox(height: 12),
            ],
            if (summary.formattedExpiryDate != 'Unknown') ...[
              _InfoRow(Icons.event, 'Expires', summary.formattedExpiryDate),
              const SizedBox(height: 12),
            ],
            if (summary.insurerHelpline != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.phone, size: 20),
                  label: Text('Call ${summary.insurerHelpline}'),
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
                  icon: const Icon(Icons.email, size: 20),
                  label: Text(summary.insurerEmail!),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
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
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
}