import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../models/policy_summary.dart';
import '../providers/family_providers.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../widgets/shared/coverwise_components.dart';
import '../utils/document_icons.dart';
import '../utils/policy_type.dart';
import '../l10n/app_localizations_gen.dart';
import '../theme/coverwise_theme.dart';
import 'policy_detail_screen.dart';

/// Visual relationship map showing family members and their policy connections.
///
/// Renders a node-link diagram where family members sit in the center
/// and policies radiate outward, with lines showing coverage associations.
/// Tap a member node to see details; tap a policy card to open PolicyDetailScreen.
class FamilyVisualizationScreen extends ConsumerWidget {
  const FamilyVisualizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizationsGen.of(context);
    final documentsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.familyVisTitle)),
      body: documentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading documents: $e'),
        ),
        data: (documents) {
          if (documents.isEmpty) {
            return _EmptyState();
          }
          return _VisualizationBody(documents: documents);
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.familyVisEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.familyVisEmptySubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualizationBody extends ConsumerWidget {
  final List<InsuranceDocument> documents;
  const _VisualizationBody({required this.documents});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizationsGen.of(context);
    final familyAsync = ref.watch(mergedFamilyMembersProvider(documents));
    final summaries = ref.watch(policySummariesProvider);

    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (familyMembers) {
        if (familyMembers.isEmpty) {
          return _EmptyState();
        }

        // Build the relationship map: member name → list of associated policies.
        final memberPolicies = <String, List<_PolicyInfo>>{};
        for (final member in familyMembers.values) {
          final associatedPolicies = <_PolicyInfo>[];
          for (final doc in documents) {
            if (doc.policyHolders != null &&
                doc.policyHolders!.any((h) => h.name == member.name)) {
              final summary = summaries
                  .where((s) => s.documentId == doc.id || s.documentId == doc.remoteId)
                  .firstOrNull;
              associatedPolicies.add(_PolicyInfo(
                document: doc,
                summary: summary,
              ));
            }
          }
          memberPolicies[member.name] = associatedPolicies;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverWisePageHeader(
                title: l10n.familyVisHeader,
                subtitle: l10n.familyVisSubtitle,
                trailing: CoverWiseIconBadge(
                  icon: Icons.account_tree_rounded,
                  color: CoverWiseColors.blueDeep,
                  size: 48,
                ),
              ),
              const SizedBox(height: 8),

              // Summary stats
              _SummaryStats(
                memberCount: familyMembers.length,
                policyCount: documents.length,
              ),
              const SizedBox(height: 20),

              // Relationship cards for each member
              ...familyMembers.values.map((member) {
                final policies = memberPolicies[member.name] ?? [];
                return _MemberRelationshipCard(
                  member: member,
                  policies: policies,
                );
              }),

              // Coverage matrix (members × policies)
              if (documents.length > 1 && familyMembers.length > 1) ...[
                const SizedBox(height: 24),
                const CoverWiseSectionLabel('Coverage matrix'),
                const SizedBox(height: 8),
                _CoverageMatrix(
                  members: familyMembers.values.toList(),
                  documents: documents,
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

/// Summary stats bar at the top.
class _SummaryStats extends StatelessWidget {
  final int memberCount;
  final int policyCount;
  const _SummaryStats({required this.memberCount, required this.policyCount});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.people_rounded,
            label: l10n.familyVisMembers,
            value: '$memberCount',
            color: CoverWiseColors.blueDeep,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.shield_rounded,
            label: l10n.familyVisPolicies,
            value: '$policyCount',
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CoverWiseSurface(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CoverWiseIconBadge(icon: icon, color: color, size: 36),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A card showing a family member and their associated policies.
class _MemberRelationshipCard extends StatelessWidget {
  final PolicyHolder member;
  final List<_PolicyInfo> policies;

  const _MemberRelationshipCard({
    required this.member,
    required this.policies,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    final theme = Theme.of(context);
    final isPrimary = member.relationship == 'Primary Insured';

    return CoverWiseSurface(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: policies.isNotEmpty
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PolicyDetailScreen(
                      documentId: policies.first.document.id,
                    ),
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Member header
              Row(
                children: [
                  CoverWiseIconBadge(
                    icon: isPrimary
                        ? Icons.person_rounded
                        : Icons.person_outline_rounded,
                    color: isPrimary
                        ? CoverWiseColors.blueDeep
                        : theme.colorScheme.tertiary,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          member.relationship,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (policies.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${policies.length} polic${policies.length == 1 ? 'y' : 'ies'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),

              // Policy connections
              if (policies.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...policies.map((policy) => _PolicyConnection(
                      policy: policy,
                      isLast: policy == policies.last,
                    )),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.familyVisNoPolicies(member.name),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
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

/// A single policy connection line with icon and coverage info.
class _PolicyConnection extends StatelessWidget {
  final _PolicyInfo policy;
  final bool isLast;

  const _PolicyConnection({required this.policy, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doc = policy.document;
    final summary = policy.summary;
    final typeName = summary?.documentType ?? doc.documentType ?? 'Insurance';
    final policyType = classifyPolicyType(typeName);
    final coverageText = summary?.formattedCoverageAmount ?? '';
    final insurerText = summary?.insurer ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PolicyDetailScreen(documentId: doc.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // Connection line indicator
            Container(
              width: 24,
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    width: 2,
                    height: 8,
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorForPolicyType(
                        policyType,
                        brightness: theme.brightness,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 8,
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Policy info
            CoverWiseIconBadge(
              icon: iconForPolicyType(policyType),
              color: colorForPolicyType(
                policyType,
                brightness: theme.brightness,
              ),
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (insurerText.isNotEmpty)
                    Text(
                      insurerText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (coverageText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  coverageText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Coverage matrix: rows = members, columns = policies.
/// Shows checkmarks or coverage amounts at intersections.
class _CoverageMatrix extends StatelessWidget {
  final List<PolicyHolder> members;
  final List<InsuranceDocument> documents;

  const _CoverageMatrix({
    required this.members,
    required this.documents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CoverWiseSurface(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: policy names
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Member',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),                  ...documents.map((doc) {
                    return SizedBox(
                      width: 80,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                        _shortName(doc.filename),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const Divider(height: 1),

            // Member rows
            ...members.map((member) {
              return Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  ...documents.map((doc) {
                    final isCovered = doc.policyHolders != null &&
                        doc.policyHolders!
                            .any((h) => h.name == member.name);
                    return SizedBox(
                      width: 80,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: isCovered
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                )
                              : Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.3),
                                ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  String _shortName(String filename) {
    // Remove extension and truncate.
    final name = filename.replaceAll(RegExp(r'\.(pdf|jpg|jpeg|png)$', caseSensitive: false), '');
    return name.length > 12 ? '${name.substring(0, 10)}…' : name;
  }
}

/// Internal model linking a document to its optional summary.
class _PolicyInfo {
  final InsuranceDocument document;
  final PolicySummary? summary;

  const _PolicyInfo({required this.document, this.summary});
}
