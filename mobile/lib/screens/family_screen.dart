import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../providers/family_providers.dart';
import '../providers/document_providers.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../widgets/shared/error_widget.dart';
import '../localization/app_localizations.dart';
import '../theme/coverwise_theme.dart';
import '../utils/document_icons.dart';
import '../utils/policy_type.dart';
import 'add_family_member_dialog.dart';
import 'family_member_detail_screen.dart';
import 'family_visualization_screen.dart';
import 'policy_detail_screen.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.familyTitle)),
      body: const FamilyMembersContent(),
    );
  }
}

class FamilyMembersContent extends ConsumerWidget {
  const FamilyMembersContent({super.key});

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    final member = await showDialog<PolicyHolder>(
      context: context,
      builder: (_) => const AddFamilyMemberDialog(),
    );
    if (member != null) {
      await addManualFamilyMember(ref, member);
      if (!context.mounted) return;
      CoverWiseSnackBar.success(context, 'Added ${member.name}.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);

    return documentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        message: S.familyLibraryError,
        icon: Icons.family_restroom_rounded,
        onRetry: () => ref.invalidate(documentsProvider),
      ),
      data: (documents) {
        if (documents.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.family_restroom,
            title: S.familyNoMembersYet,
            subtitle: S.familyEmptySubtitle,
            actionLabel: S.familyAddMember,
            actionIcon: Icons.person_add_alt_1_rounded,
            color: const Color(0xFF16866B),
            onAction: () => _addMember(context, ref),
          );
        }

        return _FamilyList(
            documents: documents, onAdd: () => _addMember(context, ref));
      },
    );
  }
}

class _FamilyList extends ConsumerWidget {
  final List<InsuranceDocument> documents;
  final VoidCallback onAdd;
  const _FamilyList({required this.documents, required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(mergedFamilyMembersProvider(documents));

    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        message: S.familyMembersReadError,
        icon: Icons.family_restroom_rounded,
        onRetry: () => ref.invalidate(mergedFamilyMembersProvider(documents)),
      ),
      data: (policyHolders) {
        if (policyHolders.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.family_restroom,
            title: S.familyNoMembersFound,
            subtitle: S.familyEmptySubtitle,
            actionLabel: S.familyAddMember,
            actionIcon: Icons.person_add_alt_1_rounded,
            color: const Color(0xFF16866B),
            onAction: onAdd,
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(mergedFamilyMembersProvider(documents)),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              CoverWisePageHeader(
                title: S.familyPeopleCovered,
                subtitle: S.familyPeopleSubtitle,
                trailing: CoverWiseIconBadge(
                  icon: Icons.family_restroom_rounded,
                  color: CoverWiseColors.blueDeep,
                  size: 48,
                ),
              ),
              CoverWiseSectionLabel(S.familySectionLabel),
              ...policyHolders.values.map((holder) => _FamilyMemberCard(
                    key: ValueKey(holder.name),
                    holder: holder,
                    documents: documents,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FamilyMemberDetailScreen(
                          member: holder,
                          documents: documents,
                        ),
                      ),
                    ),
                    onDelete: holder.isManual
                        ? () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(S.familyRemoveTitle),
                                content:
                                    Text(S.familyRemoveContent(holder.name)),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(S.cancel),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(S.remove),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await removeManualFamilyMember(ref, holder);
                            }
                          }
                        : null,
                  )),

              // ── Coverage Summary Section ──
              if (policyHolders.length > 1 || documents.length > 1) ...[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: CoverWiseSectionLabel('Coverage summary'),
                ),
                const SizedBox(height: 4),
                _CoverageMatrix(
                  members: policyHolders.values.toList(),
                  documents: documents,
                ),
                const SizedBox(height: 16),
              ],

              // ── Bottom actions ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.account_tree_outlined, size: 18),
                        label: Text(S.familyVisSeeMap),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FamilyVisualizationScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(S.familyAddButton),
                        onPressed: onAdd,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Finds which documents cover a given member by matching the member name
/// against each document's policyHolders list.
List<InsuranceDocument> _policiesForMember(
    PolicyHolder member, List<InsuranceDocument> docs) {
  return docs.where((doc) {
    if (doc.policyHolders == null) return false;
    return doc.policyHolders!.any((h) => h.name == member.name);
  }).toList();
}

class _FamilyMemberCard extends StatefulWidget {
  final PolicyHolder holder;
  final List<InsuranceDocument> documents;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _FamilyMemberCard({
    super.key,
    required this.holder,
    required this.documents,
    this.onTap,
    this.onDelete,
  });

  @override
  State<_FamilyMemberCard> createState() => _FamilyMemberCardState();
}

class _FamilyMemberCardState extends State<_FamilyMemberCard> {
  bool _expanded = false;

  List<InsuranceDocument> get _policies =>
      _policiesForMember(widget.holder, widget.documents);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = widget.holder.relationship == 'Primary Insured';
    final policies = _policies;
    final count = policies.length;

    return CoverWiseSurface(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // ── Main member header ──
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CoverWiseIconBadge(
                        icon: isPrimary
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                        color: isPrimary
                            ? CoverWiseColors.blueDeep
                            : theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.holder.name,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  widget.holder.relationship,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                _SourceBadge(
                                    isManual: widget.holder.isManual),
                                if (count > 0) _PolicyCountBadge(count: count),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.person_remove_outlined),
                          tooltip: S.familyRemoveTooltip(widget.holder.name),
                          onPressed: widget.onDelete,
                        ),
                    ],
                  ),
                  if (widget.holder.dob != null) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Icon(Icons.cake_outlined,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          S.familyDateOfBirth(widget.holder.dob!),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Expand/collapse toggle for policy assignments ──
          if (count > 0) ...[
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _expanded
                          ? 'Hide policy assignments'
                          : 'View $count polic${count == 1 ? 'y' : 'ies'} covering ${widget.holder.name}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded: inline policy list ──
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _PolicyAssignmentList(
                policies: policies,
                holder: widget.holder,
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline list of policies covering a specific member.
class _PolicyAssignmentList extends StatelessWidget {
  final List<InsuranceDocument> policies;
  final PolicyHolder holder;

  const _PolicyAssignmentList({
    required this.policies,
    required this.holder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Covered by:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...policies.map((doc) => _PolicyAssignmentTile(
                document: doc,
                holder: holder,
              )),
        ],
      ),
    );
  }
}

/// A single policy tile within a member's assignment list.
class _PolicyAssignmentTile extends StatelessWidget {
  final InsuranceDocument document;
  final PolicyHolder holder;

  const _PolicyAssignmentTile({
    required this.document,
    required this.holder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeName = document.documentType ?? 'Insurance Policy';
    final policyType = classifyPolicyType(typeName);
    final icon = iconForPolicyType(policyType);
    final color = colorForPolicyType(policyType, brightness: theme.brightness);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PolicyDetailScreen(documentId: document.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CoverWiseIconBadge(icon: icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (document.insurer != null)
                    Text(
                      document.insurer!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

// ─── Coverage Summary Matrix ───

/// A compact coverage matrix showing which members are covered by which policies.
/// Rows = members, columns = policies, checkmarks at intersections.
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: policy short names
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
                ),
                ...documents.map((doc) {
                  return SizedBox(
                    width: 72,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        children: [
                          // Policy type icon
                          Icon(
                            iconForPolicyType(
                              classifyPolicyType(
                                  doc.documentType ?? 'Insurance Policy'),
                            ),
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _shortName(doc.filename),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ],
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
                      width: 72,
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
    final name = filename.replaceAll(
        RegExp(r'\.(pdf|jpg|jpeg|png)$', caseSensitive: false), '');
    return name.length > 10 ? '${name.substring(0, 8)}…' : name;
  }
}

// ─── Shared badges ───

class _PolicyCountBadge extends StatelessWidget {
  final int count;
  const _PolicyCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count polic${count == 1 ? 'y' : 'ies'}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final bool isManual;
  const _SourceBadge({required this.isManual});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isManual ? theme.colorScheme.tertiary : CoverWiseColors.blueDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        isManual ? S.familyManualBadge : S.familyFromDocumentBadge,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
