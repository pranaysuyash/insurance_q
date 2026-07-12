import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../models/policy_summary.dart';
import '../providers/service_providers.dart';
import '../providers/family_providers.dart';
import '../providers/policy_providers.dart';
import '../services/app_state_repository.dart';
import '../data/insurance_terminology.dart';
import '../utils/document_icons.dart';
import '../widgets/terminology_dialog.dart';
import '../widgets/policy_comparison_sheet.dart';
import 'add_family_member_dialog.dart';
import 'qa_screen.dart';
import 'documents_screen.dart';

final documentsProvider = FutureProvider<List<InsuranceDocument>>((ref) async {
  return ref.read(documentServiceProvider).getDocuments();
});

final recentQuestionsProvider = Provider<List<String>>((ref) {
  return AppStateRepository.getRecentQuestions();
});

final documentTypeCountsProvider = Provider.family<int, String>((ref, type) {
  final documents = ref.watch(documentsProvider).valueOrNull ?? [];
  return documents.where((d) => d.documentType?.toLowerCase() == type).length;
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);
    final recentQuestions = ref.watch(recentQuestionsProvider);
    final policySummaries = ref.watch(policySummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(documentsProvider);
              ref.invalidate(policySummariesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(documentsProvider);
          ref.invalidate(policySummariesProvider);
        },
        child: documentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (documents) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _WelcomeCard(
                        docCount: documents.length,
                        activePolicies: policySummaries.where((s) => s.isActive).length,
                        expiringCount: policySummaries.where((s) => s.isExpiringSoon).length,
                      ),
                      const SizedBox(height: 20),
                      if (policySummaries.isNotEmpty) ...[
                        _PolicySummaryCards(summaries: policySummaries),
                        const SizedBox(height: 20),
                      ],
                      _DocumentSummary(
                        documents: documents,
                        documentTypeCount: _buildTypeCounts(documents),
                      ),
                      const SizedBox(height: 20),
                      _QuickActions(documents: documents),
                      const SizedBox(height: 20),
                      if (documents.isNotEmpty)
                        _FamilySection(documents: documents),
                      if (documents.isNotEmpty) const SizedBox(height: 20),
                      _RecentActivities(
                        documents: documents,
                        recentQuestions: recentQuestions,
                      ),
                      const SizedBox(height: 20),
                      _InsuranceTerminologySection(),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Map<String, int> _buildTypeCounts(List<InsuranceDocument> documents) {
    final counts = <String, int>{};
    for (var doc in documents) {
      final type = doc.documentType?.toLowerCase() ?? 'unknown';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }
}

class _WelcomeCard extends StatelessWidget {
  final int docCount;
  final int activePolicies;
  final int expiringCount;

  const _WelcomeCard({
    required this.docCount,
    this.activePolicies = 0,
    this.expiringCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to Your Insurance Hub',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$docCount document${docCount == 1 ? "" : "s"} • $activePolicies active policy${activePolicies == 1 ? "" : "ies"}',
              style: const TextStyle(fontSize: 16),
            ),
            if (expiringCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$expiringCount policy${expiringCount == 1 ? "" : "ies"} expiring soon',
                    style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            if (docCount == 0) ...[
              const SizedBox(height: 4),
              const Text(
                'Upload your first document to get started!',
                style: TextStyle(color: Colors.blue),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PolicySummaryCards extends StatelessWidget {
  final List<PolicySummary> summaries;
  const _PolicySummaryCards({required this.summaries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Policies',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...summaries.map((s) => _PolicyCard(summary: s)),
      ],
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final PolicySummary summary;
  const _PolicyCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final icon = iconForDocumentType(summary.documentType);
    final color = colorForDocumentType(summary.documentType);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.documentType,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (summary.insurer != null)
                        Text(
                          summary.insurer!,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _StatusBadge(summary: summary),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (summary.formattedCoverageAmount != 'Unknown') ...[
                  _MetricChip(Icons.shield, 'Coverage', summary.formattedCoverageAmount),
                  const SizedBox(width: 12),
                ],
                if (summary.formattedPremium != 'Unknown') ...[
                  _MetricChip(Icons.payments, 'Premium', summary.formattedPremium),
                  const SizedBox(width: 12),
                ],
                if (summary.formattedExpiryDate != 'Unknown')
                  _MetricChip(Icons.event, 'Expires', summary.formattedExpiryDate),
              ],
            ),
            if (summary.policyNumber != null) ...[
              const SizedBox(height: 8),
              Text(
                'Policy: ${summary.policyNumber}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
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
    final (label, color) = summary.isExpired
        ? ('EXPIRED', Colors.red)
        : summary.isExpiringSoon
            ? ('${summary.daysUntilExpiry}d LEFT', Colors.orange)
            : ('ACTIVE', Colors.green);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetricChip(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _DocumentSummary extends StatelessWidget {
  final List<InsuranceDocument> documents;
  final Map<String, int> documentTypeCount;

  const _DocumentSummary({
    required this.documents,
    required this.documentTypeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documents by Type',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (documents.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No documents yet. Add your first document!')),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTypeCard('Health Insurance', Icons.health_and_safety, Colors.green, documentTypeCount),
                _buildTypeCard('Auto Insurance', Icons.directions_car, Colors.blue, documentTypeCount),
                _buildTypeCard('Home Insurance', Icons.home, Colors.brown, documentTypeCount),
                _buildTypeCard('Life Insurance', Icons.favorite, Colors.red, documentTypeCount),
                _buildTypeCard('Travel Insurance', Icons.flight, Colors.orange, documentTypeCount),
                _buildTypeCard('Other', Icons.description, Colors.grey, documentTypeCount),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTypeCard(String type, IconData icon, Color color, Map<String, int> counts) {
    final count = counts[type.toLowerCase()] ?? 0;
    final hasDocuments = count > 0;

    return Card(
      elevation: 2,
      color: hasDocuments ? null : Colors.grey.shade100,
      child: SizedBox(
        width: 150,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: hasDocuments ? color : Colors.grey, size: 32),
              const SizedBox(height: 8),
              Text(
                type,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                hasDocuments ? '$count document${count > 1 ? "s" : ""}' : 'No documents',
                style: TextStyle(
                  color: hasDocuments ? Colors.black87 : Colors.grey,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final List<InsuranceDocument> documents;
  const _QuickActions({required this.documents});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ActionButton(
              icon: Icons.upload_file, label: 'Upload Document', color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())),
            )),
            const SizedBox(width: 12),
            Expanded(child: _ActionButton(
              icon: Icons.question_answer, label: 'Ask a Question', color: Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QaScreen())),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ActionButton(
              icon: Icons.compare_arrows, label: 'Compare Policies', color: Colors.orange,
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => PolicyComparisonSheet(documents: documents),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: _ActionButton(
              icon: Icons.help_outline, label: 'Insurance Terms', color: Colors.teal,
              onTap: () => showDialog(context: context, builder: (_) => const TerminologyDialog()),
            )),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon, required this.label, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
            ),
          ],
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Family Members & Insured',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: () async {
                final member = await showDialog<PolicyHolder>(
                  context: context,
                  builder: (_) => const AddFamilyMemberDialog(),
                );
                if (member != null) {
                  await addManualFamilyMember(ref, member);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${member.name}.')),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        familyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No family information detected in your policies')),
            ),
          ),
          data: (policyHolders) {
            if (policyHolders.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No family information detected in your policies')),
                ),
              );
            }
            return Column(
              children: [
                ...policyHolders.values.map((holder) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      child: Icon(
                        holder.relationship == 'Primary Insured' ? Icons.person : Icons.people_alt,
                        color: Colors.blue,
                      ),
                    ),
                    title: Text(holder.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (holder.dob != null) Text('DOB: ${holder.dob}'),
                        Text(holder.relationship),
                      ],
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                )),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Auto-detected from your policies, plus anyone you add manually.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RecentActivities extends StatelessWidget {
  final List<InsuranceDocument> documents;
  final List<String> recentQuestions;

  const _RecentActivities({required this.documents, required this.recentQuestions});

  @override
  Widget build(BuildContext context) {
    final recentDocs = [...documents]
      ..sort((a, b) => b.uploadedOn.compareTo(a.uploadedOn));
    final docs = recentDocs.take(3).toList();
    final deletedDocs = AppStateRepository.getRecentlyDeletedDocuments();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (docs.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Recently uploaded documents', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          ...docs.map((doc) => _ActivityItem(
            icon: Icons.upload_file, title: doc.filename,
            subtitle: 'Uploaded on ${doc.uploadedOn.day}/${doc.uploadedOn.month}/${doc.uploadedOn.year}',
            color: Colors.blue,
          )),
          const SizedBox(height: 8),
        ],
        if (deletedDocs.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Recently deleted documents', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          ...deletedDocs.take(2).map((filename) => _ActivityItem(
            icon: Icons.delete_outline, title: filename,
            subtitle: 'Deleted recently', color: Colors.red,
          )),
          const SizedBox(height: 8),
        ],
        if (recentQuestions.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Recent questions', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          ...recentQuestions.take(3).map((question) => _ActivityItem(
            icon: Icons.question_answer, title: question,
            subtitle: 'Asked recently', color: Colors.purple,
          )),
        ],
        if (docs.isEmpty && recentQuestions.isEmpty && deletedDocs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No recent activities')),
            ),
          ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _ActivityItem({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class _InsuranceTerminologySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Insurance Terminology', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => showDialog(context: context, builder: (_) => const TerminologyDialog()),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: quickTerminology.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.term}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(item.definition)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
