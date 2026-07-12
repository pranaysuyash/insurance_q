import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../widgets/shared/empty_state_widget.dart';

class PolicyComparisonScreen extends ConsumerWidget {
  const PolicyComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(policySummariesProvider);

    if (summaries.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compare Policies')),
        body: EmptyStateWidget(
          icon: Icons.compare_arrows,
          title: 'Need at least 2 policies',
          subtitle: summaries.isEmpty ? 'Upload your first document to compare' : 'Upload another document to compare',
        ),
      );
    }

    final policies = summaries.take(2).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Policies')),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _ComparisonTable(policies: policies),
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final List<PolicySummary> policies;
  const _ComparisonTable({required this.policies});

  @override
  Widget build(BuildContext context) {
    final rows = <_ComparisonRow>[
      _ComparisonRow('Type', (s) => s.documentType),
      _ComparisonRow('Insurer', (s) => s.insurer ?? 'Unknown'),
      _ComparisonRow('Policy Number', (s) => s.policyNumber ?? 'Unknown'),
      _ComparisonRow('Coverage', (s) => s.formattedCoverageAmount),
      _ComparisonRow('Premium', (s) => s.formattedPremium),
      _ComparisonRow('Deductible', (s) => s.deductible != null ? '₹${s.deductible}' : 'Not listed'),
      _ComparisonRow('Start Date', (s) => s.formattedStartDate),
      _ComparisonRow('End Date', (s) => s.formattedExpiryDate),
      _ComparisonRow('Status', (s) => s.isExpired ? 'Expired' : s.isExpiringSoon ? 'Expiring Soon' : 'Active'),
      _ComparisonRow('Helpline', (s) => s.insurerHelpline ?? 'Not listed'),
    ];

    return DataTable(
      columnSpacing: 24,
      columns: [
        const DataColumn(label: Text('Field', style: TextStyle(fontWeight: FontWeight.bold))),
        ...policies.map((p) => DataColumn(
          label: Text(p.documentType, style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
      ],
      rows: rows.map((row) => DataRow(cells: [
        DataCell(Text(row.label, style: const TextStyle(color: Colors.grey))),
        ...policies.map((p) => DataCell(Text(row.getValue(p)))),
      ])).toList(),
    );
  }
}

class _ComparisonRow {
  final String label;
  final String Function(PolicySummary) getter;
  _ComparisonRow(this.label, this.getter);
  String getValue(PolicySummary s) => getter(s);
}