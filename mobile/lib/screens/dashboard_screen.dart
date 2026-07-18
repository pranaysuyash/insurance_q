import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../models/policy_summary.dart';
import '../providers/family_providers.dart';
import '../providers/policy_providers.dart';
import '../providers/health_score_provider.dart';
import '../services/app_state_repository.dart';
import '../data/insurance_terminology.dart';
import '../utils/document_icons.dart';
import '../widgets/terminology_dialog.dart';
import '../widgets/policy_comparison_sheet.dart';
import '../widgets/health_score_card.dart';
import '../widgets/shared/policy_type_icon.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/error_widget.dart';
import '../widgets/shared/coverwise_scene.dart';
import '../theme/coverwise_motion.dart';
import '../services/preventive_health_service.dart';
import 'add_family_member_dialog.dart';
import '../providers/document_providers.dart';
import 'qa_screen.dart';
import 'documents_screen.dart';
import 'emergency_screen.dart';

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
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh policy overview',
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
          loading: () => Center(
            child: Semantics(
              label: 'Loading policy overview',
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => AppErrorView(
            message: 'We could not load your policy overview.',
            onRetry: () {
              ref.invalidate(documentsProvider);
              ref.invalidate(policySummariesProvider);
            },
          ),
          data: (documents) {
            if (documents.isEmpty) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: _FirstUploadCta(
                        onUpload: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DocumentsScreen(
                              startWithFilePicker: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const CoverWisePageHeader(
                        title: 'Your cover, at a glance',
                        subtitle:
                            'See what is protected, what needs attention, and what to do next.',
                      ),
                      _WelcomeCard(
                        docCount: documents.length,
                        activePolicies:
                            policySummaries.where((s) => s.isActive).length,
                        expiringCount: policySummaries
                            .where((s) => s.isExpiringSoon)
                            .length,
                      ),
                      const SizedBox(height: 16),
                      // Insurance Health Score — at-a-glance coverage check
                      HealthScoreCard(
                        healthScore: ref.watch(healthScoreProvider),
                      ),
                      const SizedBox(height: 20),
                      _QuickActions(documents: documents),
                      const SizedBox(height: 20),
                      _SearchShortcutButton(
                        onTap: () => Navigator.pushNamed(context, '/search'),
                      ),
                      const SizedBox(height: 20),
                      if (policySummaries.isNotEmpty) ...[
                        _PolicySummaryCards(summaries: policySummaries),
                        const SizedBox(height: 20),
                      ],
                      _DocumentSummary(documents: documents),
                      const SizedBox(height: 20),
                      _FamilySection(documents: documents),
                      const SizedBox(height: 20),
                      _RecentActivities(
                        documents: documents,
                        recentQuestions: recentQuestions,
                      ),
                      const SizedBox(height: 20),
                      if (policySummaries.isNotEmpty)
                        _PreventiveTipsSection(summaries: policySummaries),
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
}

/// Prominent, visual CTA shown when the user has no documents.
/// This IS the onboarding continuation — the first thing a new user sees
/// after the carousel.
class _FirstUploadCta extends StatelessWidget {
  final VoidCallback onUpload;

  const _FirstUploadCta({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CoverWiseSurface(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          children: [
            const CoverWiseScene(
              scene: CoverWiseSceneKind.firstPolicy,
              maxHeight: 170,
            ),
            const SizedBox(height: 16),
            Text(
              'Turn your first policy into clear answers',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a PDF or policy image. CoverWise organizes the file and '
              'shows the cover, exclusions and dates for you to review.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              label:
                  'Your original policy is always available for you to review. We process it securely on our servers.',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Your original policy is always available. We process it securely to generate summaries.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Choose policy file'),
                onPressed: onUpload,
              ),
            ),
          ],
        ),
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
    final theme = Theme.of(context);
    return CoverWiseSurface(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your policy hub',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$docCount document${docCount == 1 ? "" : "s"} • $activePolicies active ${activePolicies == 1 ? "policy" : "policies"}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (expiringCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_outlined,
                      color: theme.colorScheme.tertiary, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$expiringCount ${expiringCount == 1 ? "policy" : "policies"} expiring soon',
                    style: TextStyle(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            if (docCount == 0) ...[
              const SizedBox(height: 4),
              Text(
                'Add a policy PDF to see coverage, exclusions and renewal dates in one place.',
                style: TextStyle(color: theme.colorScheme.primary),
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
        Text(
          'Your Policies',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (summary.insurer != null)
                          Text(
                            summary.insurer!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = summary.isExpired
        ? ('EXPIRED', scheme.error)
        : summary.isExpiringSoon
            ? ('${summary.daysUntilExpiry}d LEFT', scheme.tertiary)
            : ('ACTIVE', scheme.primary);

    return CoverWiseStatusChip(
      icon: summary.isExpired
          ? Icons.error_rounded
          : summary.isExpiringSoon
              ? Icons.schedule_rounded
              : Icons.check_circle_rounded,
      label: label,
      color: color,
      compact: true,
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
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
          ],
        ),
        Text(value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
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
        Text(
          'Documents by Type',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
    final brightness = Theme.of(context).brightness;
    final selectedColor = colorForPolicyType(
      _selectedType,
      brightness: brightness,
    );

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
                        '${canonicalTypeName(type)}, $count ${count == 1 ? 'policy' : 'policies'}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _selectedType = type),
                      child: AnimatedContainer(
                        duration: CoverWiseMotion.duration(
                          context,
                          CoverWiseMotion.standard,
                        ),
                        curve: CoverWiseMotion.enterCurve,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorForPolicyType(
                                  type,
                                  brightness: brightness,
                                ).withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            PolicyTypeIcon(
                              type: type,
                              selected: isSelected,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              canonicalTypeName(type)
                                  .replaceFirst(' Insurance', ''),
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: colorForPolicyType(
                                  type,
                                  brightness: brightness,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '$count ${count == 1 ? 'policy' : 'policies'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colorForPolicyType(
                                      type,
                                      brightness: brightness,
                                    ).withValues(alpha: 0.82),
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
          duration: CoverWiseMotion.duration(
            context,
            CoverWiseMotion.quick,
          ),
          switchInCurve: CoverWiseMotion.enterCurve,
          switchOutCurve: CoverWiseMotion.exitCurve,
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
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _ActionButton(
              icon: Icons.upload_file,
              label: 'Upload Document',
              color: Colors.blue,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DocumentsScreen(
                      startWithFilePicker: true,
                    ),
                  )),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _ActionButton(
              icon: Icons.chat_bubble_outline_rounded,
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
        const SizedBox(height: 12),
        // Emergency shortcut — one tap from dashboard instead of More → Emergency
        if (documents.isNotEmpty)
          _EmergencyShortcutButton(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EmergencyScreen())),
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
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoverWiseIconBadge(icon: icon, color: color, size: 42),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search shortcut button — one tap from dashboard to cross-document search.
class _SearchShortcutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchShortcutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Search across all policies',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_rounded,
                  color: scheme.onPrimaryContainer, size: 22),
              const SizedBox(width: 10),
              Text(
                'Search Across All Policies',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent emergency shortcut button — one tap from dashboard.
class _EmergencyShortcutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EmergencyShortcutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Open emergency card',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emergency_outlined,
                  color: scheme.onErrorContainer, size: 22),
              const SizedBox(width: 10),
              Text(
                'Emergency Card',
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a detail dialog for a family member.
void _showFamilyMemberDetail(BuildContext context, PolicyHolder holder) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(holder.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (holder.dob != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Date of Birth: ${holder.dob}'),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Relationship: ${holder.relationship}'),
          ),
          Text(
            holder.isManual ? 'Added manually' : 'Detected from policy',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
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
            Text(
              'Family Members & Insured',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showFamilyMemberDetail(context, holder),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              holder.relationship == 'Primary Insured'
                                  ? Icons.person
                                  : Icons.people_alt,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                          trailing: const Icon(Icons.chevron_right_rounded),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      ),
                    )),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Auto-detected from your policies, plus anyone you add manually.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
        Text('Recent Activities',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 12),
        if (docs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Recently uploaded documents',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                )),
          ),
          ...docs.map((doc) => _ActivityItem(
                icon: Icons.upload_file,
                title: doc.filename,
                subtitle:
                    'Uploaded on ${doc.uploadedOn.day}/${doc.uploadedOn.month}/${doc.uploadedOn.year}',
                color: Theme.of(context).colorScheme.primary,
                onTap: () => Navigator.pushNamed(context, '/policy-detail', arguments: doc.id),
              )),
          const SizedBox(height: 8),
        ],
        if (deletedDocs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Recently deleted documents',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                )),
          ),
          ...deletedDocs.take(2).map((filename) => _ActivityItem(
                icon: Icons.delete_outline,
                title: filename,
                subtitle: 'Deleted recently',
                color: Theme.of(context).colorScheme.error,
              )),
          const SizedBox(height: 8),
        ],
        if (recentQuestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Recent questions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                )),
          ),
          ...recentQuestions.take(3).map((question) => _ActivityItem(
                icon: Icons.chat_bubble_outline_rounded,
                title: question,
                subtitle: 'Asked recently',
                color: Theme.of(context).colorScheme.secondary,
                onTap: () => Navigator.pushNamed(context, '/qa'),
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
  final VoidCallback? onTap;

  const _ActivityItem(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: tile,
            )
          : tile,
    );
  }
}

class _PreventiveTipsSection extends StatefulWidget {
  final List<PolicySummary> summaries;
  const _PreventiveTipsSection({required this.summaries});

  @override
  State<_PreventiveTipsSection> createState() => _PreventiveTipsSectionState();
}

class _PreventiveTipsSectionState extends State<_PreventiveTipsSection> {
  List<HealthTip> _tips = [];

  @override
  void initState() {
    super.initState();
    _tips = PreventiveHealthService.getAvailableTips(widget.summaries);
  }

  @override
  void didUpdateWidget(_PreventiveTipsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summaries != widget.summaries) {
      _tips = PreventiveHealthService.getAvailableTips(widget.summaries);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Health Tips',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
            TextButton(
              onPressed: () async {
                await PreventiveHealthService.markAllShown(_tips);
                setState(() => _tips = []);
              },
              child: const Text('Dismiss All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._tips.take(3).map((tip) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CoverWiseIconBadge(
                  icon: tip.icon,
                  color: Theme.of(context).colorScheme.tertiary,
                  size: 40,
                ),
                title: Text(tip.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(tip.body,
                    style: const TextStyle(fontSize: 13), maxLines: 2),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss ${tip.title}',
                  onPressed: () async {
                    await PreventiveHealthService.markTipShown(tip.id);
                    setState(() => _tips.remove(tip));
                  },
                ),
              ),
            )),
      ],
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
            Text('Insurance Terminology',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
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
