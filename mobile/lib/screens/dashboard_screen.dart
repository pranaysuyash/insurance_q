import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../models/policy_summary.dart';
import '../providers/family_providers.dart';
import '../providers/policy_providers.dart';
import '../services/app_state_repository.dart';
import '../data/insurance_terminology.dart';
import '../utils/document_icons.dart';
import '../widgets/terminology_dialog.dart';
import '../widgets/policy_comparison_sheet.dart';
import '../widgets/shared/policy_type_icon.dart';
import 'add_family_member_dialog.dart';
import '../providers/document_providers.dart';
import 'qa_screen.dart';
import 'documents_screen.dart';

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
        title: const Text('CoverWise'),
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
                        activePolicies:
                            policySummaries.where((s) => s.isActive).length,
                        expiringCount: policySummaries
                            .where((s) => s.isExpiringSoon)
                            .length,
                      ),
                      const SizedBox(height: 20),
                      // First-time user: prominent upload CTA instead of empty sections
                      if (documents.isEmpty) ...[
                        _FirstUploadCta(
                          onUpload: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DocumentsScreen()),
                          ),
                        ),
                      ] else ...[
                        if (policySummaries.isNotEmpty) ...[
                          _PolicySummaryCards(summaries: policySummaries),
                          const SizedBox(height: 20),
                        ],
                      _DocumentSummary(documents: documents),
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
                      ],
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
}

/// Prominent, visual CTA shown when the user has no documents.
/// This IS the onboarding continuation — the first thing a new user sees
/// after the carousel.
class _FirstUploadCta extends StatelessWidget {
  final VoidCallback onUpload;

  const _FirstUploadCta({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.upload_file, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Upload your first policy',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pick a PDF of your insurance policy. CoverWise reads it and '
            'shows you coverage, exclusions, and benefits — in 30 seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 20),
          // Benefits chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _ctaChip(Icons.bolt, 'Takes 30 seconds'),
              _ctaChip(Icons.cloud_off, 'Works offline'),
              _ctaChip(Icons.lock_outline, 'Private'),
            ],
          ),
          const SizedBox(height: 24),
          // CTA button
          FilledButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Select Policy PDF',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            onPressed: onUpload,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
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
              'Your policy hub',
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
                    style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            if (docCount == 0) ...[
              const SizedBox(height: 4),
              const Text(
                'Add a policy PDF to see coverage, exclusions and renewal dates in one place.',
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
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, '/policy-detail',
            arguments: summary.documentId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PolicyTypeIcon(
                    type: classifyPolicyType(summary.documentType),
                    size: 52,
                    selected: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.documentType,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (summary.insurer != null)
                          Text(
                            summary.insurer!,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
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
                    _MetricChip(Icons.shield, 'Coverage',
                        summary.formattedCoverageAmount),
                    const SizedBox(width: 12),
                  ],
                  if (summary.formattedPremium != 'Unknown') ...[
                    _MetricChip(
                        Icons.payments, 'Premium', summary.formattedPremium),
                    const SizedBox(width: 12),
                  ],
                  if (summary.formattedExpiryDate != 'Unknown')
                    _MetricChip(
                        Icons.event, 'Expires', summary.formattedExpiryDate),
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
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 11)),
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
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _DocumentSummary extends StatelessWidget {
  final List<InsuranceDocument> documents;

  const _DocumentSummary({required this.documents});

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
        _CoverageTypeExplorer(documents: documents),
      ],
    );
  }
}

class _CoverageTypeExplorer extends StatefulWidget {
  final List<InsuranceDocument> documents;

  const _CoverageTypeExplorer({required this.documents});

  @override
  State<_CoverageTypeExplorer> createState() => _CoverageTypeExplorerState();
}

class _CoverageTypeExplorerState extends State<_CoverageTypeExplorer> {
  PolicyType _selectedType = PolicyType.health;

  static const _typeDescriptions = {
    PolicyType.health: 'Hospital care, treatment and medical expenses.',
    PolicyType.auto: 'Car, bike and vehicle protection.',
    PolicyType.life: 'Financial protection for the people you love.',
    PolicyType.home: 'Your home, belongings and property cover.',
    PolicyType.travel: 'Protection for trips away from home.',
    PolicyType.other: 'Other policies kept safely in one place.',
  };

  @override
  Widget build(BuildContext context) {
    final counts = <PolicyType, int>{
      for (final type in PolicyType.values) type: 0,
    };
    for (final document in widget.documents) {
      final type = classifyPolicyType(document.documentType);
      counts[type] = counts[type]! + 1;
    }
    final selectedCount = counts[_selectedType]!;
    final selectedColor = colorForPolicyType(_selectedType);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: PolicyType.values.map((type) {
                final isSelected = type == _selectedType;
                final count = counts[type]!;
                return SizedBox(
                  width: itemWidth,
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label:
                        '${canonicalTypeName(type)}, $count policy${count == 1 ? '' : 'ies'}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _selectedType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorForPolicyType(type).withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            AnimatedScale(
                              duration: const Duration(milliseconds: 220),
                              scale: isSelected ? 1.07 : 1,
                              child: PolicyTypeIcon(
                                type: type,
                                selected: isSelected,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              canonicalTypeName(type)
                                  .replaceFirst(' Insurance', ''),
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: colorForPolicyType(type),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '$count ${count == 1 ? 'policy' : 'policies'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colorForPolicyType(type)
                                        .withValues(alpha: 0.82),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Container(
            key: ValueKey(_selectedType),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selectedColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                PolicyTypeIcon(type: _selectedType, size: 40, selected: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCount > 0
                        ? '$selectedCount ${selectedCount == 1 ? 'policy' : 'policies'} in ${canonicalTypeName(_selectedType)}. ${_typeDescriptions[_selectedType]}'
                        : widget.documents.isEmpty
                            ? 'Explore the kinds of cover you can keep here. Add your first policy when you are ready.'
                            : 'No ${canonicalTypeName(_selectedType).toLowerCase()} policy has been added. ${_typeDescriptions[_selectedType]}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
            Expanded(
                child: _ActionButton(
              icon: Icons.upload_file,
              label: 'Upload Document',
              color: Colors.blue,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DocumentsScreen())),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _ActionButton(
              icon: Icons.question_answer,
              label: 'Ask a Question',
              color: Colors.purple,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const QaScreen())),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _ActionButton(
              icon: Icons.compare_arrows,
              label: 'Compare Policies',
              color: Colors.orange,
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => PolicyComparisonSheet(documents: documents),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _ActionButton(
              icon: Icons.help_outline,
              label: 'Insurance Terms',
              color: Colors.teal,
              onTap: () => showDialog(
                  context: context, builder: (_) => const TerminologyDialog()),
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
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
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
              style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold),
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
              child: Center(
                  child:
                      Text('No family information detected in your policies')),
            ),
          ),
          data: (policyHolders) {
            if (policyHolders.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: Text(
                          'No family information detected in your policies')),
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
                            holder.relationship == 'Primary Insured'
                                ? Icons.person
                                : Icons.people_alt,
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    )),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Auto-detected from your policies, plus anyone you add manually.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

  const _RecentActivities(
      {required this.documents, required this.recentQuestions});

  @override
  Widget build(BuildContext context) {
    final recentDocs = [...documents]
      ..sort((a, b) => b.uploadedOn.compareTo(a.uploadedOn));
    final docs = recentDocs.take(3).toList();
    final deletedDocs = AppStateRepository.getRecentlyDeletedDocuments();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activities',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (docs.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Recently uploaded documents',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          ...docs.map((doc) => _ActivityItem(
                icon: Icons.upload_file,
                title: doc.filename,
                subtitle:
                    'Uploaded on ${doc.uploadedOn.day}/${doc.uploadedOn.month}/${doc.uploadedOn.year}',
                color: Colors.blue,
              )),
          const SizedBox(height: 8),
        ],
        if (deletedDocs.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Recently deleted documents',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          ...deletedDocs.take(2).map((filename) => _ActivityItem(
                icon: Icons.delete_outline,
                title: filename,
                subtitle: 'Deleted recently',
                color: Colors.red,
              )),
          const SizedBox(height: 8),
        ],
        if (recentQuestions.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('Recent questions',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          ...recentQuestions.take(3).map((question) => _ActivityItem(
                icon: Icons.question_answer,
                title: question,
                subtitle: 'Asked recently',
                color: Colors.purple,
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

  const _ActivityItem(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color});

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
            const Text('Insurance Terminology',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => showDialog(
                  context: context, builder: (_) => const TerminologyDialog()),
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
                      Text('${item.term}: ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
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
