import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../utils/document_icons.dart';

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
    final active = sorted.where((s) => s.isActive && !s.isExpiringSoon).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Renewal Calendar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (expired.isNotEmpty) ...[
            _SectionHeader('Expired', Icons.error, Colors.red, expired.length),
            const SizedBox(height: 8),
            ...expired.map((s) => _RenewalCard(summary: s, color: Colors.red)),
            const SizedBox(height: 20),
          ],
          if (expiringSoon.isNotEmpty) ...[
            _SectionHeader('Expiring Soon', Icons.warning, Colors.orange, expiringSoon.length),
            const SizedBox(height: 8),
            ...expiringSoon.map((s) => _RenewalCard(summary: s, color: Colors.orange)),
            const SizedBox(height: 20),
          ],
          if (active.isNotEmpty) ...[
            _SectionHeader('Active', Icons.check_circle, Colors.green, active.length),
            const SizedBox(height: 8),
            ...active.map((s) => _RenewalCard(summary: s, color: Colors.green)),
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
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(summary.documentType, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${summary.insurer ?? "Unknown"} • Expires: ${summary.formattedExpiryDate}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              summary.isExpired ? 'EXPIRED' : '$days days',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (summary.policyNumber != null)
              Text(summary.policyNumber!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}