import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/policy_summary.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../utils/policy_type.dart';
import 'document_preview_screen.dart';

/// The core value screen: turns a 40-page policy PDF into one page the user
/// can actually understand.
///
/// Displays everything the system extracted: coverage, premium, deductible,
/// key benefits, exclusions, waiting periods, coverage items, and dates.
/// Provides quick actions: ask a question, view claim guide, call/email insurer.
class PolicyDetailScreen extends ConsumerWidget {
  final String documentId;

  const PolicyDetailScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(policySummariesProvider);
    final summary = summaries.where((s) => s.documentId == documentId).firstOrNull;

    if (summary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Policy Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Policy summary not available',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The summary for this policy could not be loaded. '
                  'This can happen if extraction is still in progress or '
                  'has not been run yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.question_answer),
                  label: const Text('Ask a Question Instead'),
                  onPressed: () => Navigator.pushNamed(context, '/qa', arguments: documentId),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final policyType = classifyPolicyType(summary.documentType);

    return Scaffold(
      appBar: AppBar(
        title: Text(canonicalTypeName(policyType)),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'View source document',
            onPressed: () => _openDocumentPreview(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.question_answer),
            tooltip: 'Ask a Question',
            onPressed: () => Navigator.pushNamed(context, '/qa', arguments: documentId),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Policy Summary',
            onPressed: () => _shareSummary(summary),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(summary: summary, policyType: policyType),
          const SizedBox(height: 16),
          _MoneyRow(summary: summary),
          const SizedBox(height: 16),
          _DatesCard(summary: summary),
          const SizedBox(height: 16),
          if (summary.keyBenefits.isNotEmpty) ...[
            _SectionList(
              title: 'What\'s Covered',
              icon: Icons.check_circle,
              iconColor: Colors.green,
              items: summary.keyBenefits,
              itemIcon: Icons.check,
              itemColor: Colors.green,
            ),
            const SizedBox(height: 16),
          ],
          if (summary.exclusions.isNotEmpty) ...[
            _SectionList(
              title: 'What\'s Not Covered',
              icon: Icons.cancel,
              iconColor: Colors.red,
              items: summary.exclusions,
              itemIcon: Icons.close,
              itemColor: Colors.red,
            ),
            const SizedBox(height: 16),
          ],
          if (summary.waitingPeriods.isNotEmpty) ...[
            _SectionList(
              title: 'Waiting Periods',
              icon: Icons.schedule,
              iconColor: Colors.orange,
              items: summary.waitingPeriods,
              itemIcon: Icons.access_time,
              itemColor: Colors.orange,
            ),
            const SizedBox(height: 16),
          ],
          if (summary.coverageItems.isNotEmpty) ...[
            _CoverageItemsCard(items: summary.coverageItems),
            const SizedBox(height: 16),
          ],
          _QuickActions(summary: summary, context: context),
          const SizedBox(height: 32),
          Text(
            'Extracted on ${_formatDate(summary.extractedAt)} from your uploaded policy document. '
            'Always verify important details against the source document and your insurer.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';

  void _openDocumentPreview(BuildContext context, WidgetRef ref) {
    final documents = ref.read(documentsProvider).valueOrNull;
    if (documents == null || documents.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No documents available.')),
      );
      return;
    }

    final doc = documents.where(
      (d) => d.id == documentId || d.remoteId == documentId,
    ).firstOrNull;

    if (doc == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document not found on this device.')),
      );
      return;
    }

    if (doc.localFilePath == null || doc.localFilePath!.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source document is only available on the device where it was uploaded.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPreviewScreen(
          filePath: doc.localFilePath!,
          filename: doc.filename,
          documentId: doc.id,
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final PolicySummary summary;
  final PolicyType policyType;

  const _HeaderCard({required this.summary, required this.policyType});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorForPolicyType(policyType).withValues(alpha: 0.1),
              child: Icon(iconForPolicyType(policyType),
                  size: 28, color: colorForPolicyType(policyType)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    canonicalTypeName(policyType),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (summary.insurer != null)
                    Text(summary.insurer!,
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
                  if (summary.policyNumber != null) ...[
                    const SizedBox(height: 4),
                    Text('Policy: ${summary.policyNumber}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ],
              ),
            ),
            _StatusBadge(summary: summary),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PolicySummary summary;
  const _StatusBadge({required this.summary});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    if (summary.isExpired) {
      label = 'EXPIRED';
      color = Colors.red;
    } else if (summary.isExpiringSoon) {
      label = '${summary.daysUntilExpiry}d LEFT';
      color = Colors.orange;
    } else if (summary.isActive) {
      label = 'ACTIVE';
      color = Colors.green;
    } else {
      label = 'UNKNOWN';
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final PolicySummary summary;
  const _MoneyRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = <_MoneyItem>[
      if (summary.coverageAmount != null)
        _MoneyItem(
          label: 'Sum Insured',
          value: summary.formattedCoverageAmount,
          icon: Icons.shield,
          color: Colors.blue,
        ),
      if (summary.premiumAmount != null)
        _MoneyItem(
          label: 'Premium',
          value: summary.formattedPremium,
          icon: Icons.payments,
          color: Colors.green,
        ),
      if (summary.deductible != null)
        _MoneyItem(
          label: 'Deductible',
          value: '₹${summary.deductible!.toStringAsFixed(0)}',
          icon: Icons.money_off,
          color: Colors.orange,
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      children: items
          .map((item) => Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(item.icon, color: item.color, size: 24),
                        const SizedBox(height: 6),
                        Text(item.value,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(item.label,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _MoneyItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _MoneyItem(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
}

class _DatesCard extends StatelessWidget {
  final PolicySummary summary;
  const _DatesCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.startDate == null && summary.endDate == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.event, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (summary.startDate != null)
                    Text('From: ${summary.formattedStartDate}',
                        style: const TextStyle(fontSize: 14)),
                  if (summary.endDate != null) ...[
                    const SizedBox(height: 4),
                    Text('Until: ${summary.formattedExpiryDate}',
                        style: const TextStyle(fontSize: 14)),
                  ],
                  if (summary.isActive || summary.isExpiringSoon) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${summary.daysUntilExpiry} days remaining',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: summary.isExpiringSoon
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> items;
  final IconData itemIcon;
  final Color itemColor;

  const _SectionList({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.itemIcon,
    required this.itemColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(itemIcon, size: 18, color: itemColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item, style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _CoverageItemsCard extends StatelessWidget {
  final List<CoverageItem> items;
  const _CoverageItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.indigo, size: 22),
                const SizedBox(width: 8),
                const Text('Coverage Details',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.covered ? Icons.check_circle : Icons.cancel,
                        size: 18,
                        color: item.covered ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            if (item.limitText != null)
                              Text(item.limitText!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                            if (item.limit != null && item.limitText == null)
                              Text('Limit: ₹${item.limit!.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                            if (item.notes != null)
                              Text(item.notes!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final PolicySummary summary;
  final BuildContext context;

  const _QuickActions({required this.summary, required this.context});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.question_answer),
          label: const Text('Ask a Question About This Policy'),
          onPressed: () => Navigator.pushNamed(context, '/qa',
              arguments: summary.documentId),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.share),
          label: const Text('Share Policy Summary'),
          onPressed: () => _shareSummary(summary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (summary.insurerHelpline != null)
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.phone),
                  label: const Text('Call Insurer'),
                  onPressed: () => _launchUrl('tel:${summary.insurerHelpline!.replaceAll(RegExp(r'[^0-9+]'), '')}'),
                ),
              ),
            if (summary.insurerHelpline != null && summary.insurerEmail != null)
              const SizedBox(width: 8),
            if (summary.insurerEmail != null)
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.email),
                  label: const Text('Email'),
                  onPressed: () => _launchUrl('mailto:${summary.insurerEmail}'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

/// Builds the shareable text for a policy summary.
/// Extracted as a pure function for testability.
String buildShareSummaryText(PolicySummary summary) {
  final buffer = StringBuffer();
  buffer.writeln('📋 ${summary.documentType}');
  if (summary.insurer != null) buffer.writeln('🏢 ${summary.insurer}');
  if (summary.policyNumber != null) buffer.writeln('🔢 Policy: ${summary.policyNumber}');
  buffer.writeln('');
  if (summary.coverageAmount != null) buffer.writeln('🛡️ Coverage: ${summary.formattedCoverageAmount}');
  if (summary.premiumAmount != null) buffer.writeln('💰 Premium: ${summary.formattedPremium}');
  if (summary.deductible != null) buffer.writeln('📉 Deductible: ₹${summary.deductible!.toStringAsFixed(0)}');
  buffer.writeln('');
  if (summary.startDate != null) buffer.writeln('📅 From: ${summary.formattedStartDate}');
  if (summary.endDate != null) buffer.writeln('📅 Until: ${summary.formattedExpiryDate}');
  if (summary.isActive || summary.isExpiringSoon) {
    buffer.writeln('⏰ ${summary.daysUntilExpiry} days remaining');
  }
  if (summary.keyBenefits.isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('✅ Benefits:');
    for (final b in summary.keyBenefits) {
      buffer.writeln('  • $b');
    }
  }
  if (summary.exclusions.isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('❌ Exclusions:');
    for (final e in summary.exclusions) {
      buffer.writeln('  • $e');
    }
  }
  buffer.writeln('');
  buffer.writeln('Shared via CoverWise — Your Insurance Companion');
  return buffer.toString();
}

void _shareSummary(PolicySummary summary) {
  SharePlus.instance.share(ShareParams(text: buildShareSummaryText(summary)));
}
