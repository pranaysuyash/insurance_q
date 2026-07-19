import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/field_citation.dart';
import '../widgets/not_yet_extracted_section.dart';

/// The claim-assistance entry point (Trust audit ADR-09 thin
/// slice).
///
/// Per docs/decisions/ADR-2026-07-19-04-...md, the thin slice
/// shows the substrate's `insurer_name` field (the foundation
/// of the claim flow) and a deep-link to a generic insurer
/// claim process page. The per-insurer claim process URL is
/// a per-insurer lookup table in v1; the per-policy checklist
/// (network hospital list, helpline, email) is deferred to a
/// follow-up session that extends the parser pipeline.
///
/// This screen is reached from a button in the policy detail
/// screen's action area. It is a read-only consumer of the
/// substrate; it does not call extractors, does not write
/// to the substrate, and does not invent insurer details.
class ClaimAssistanceScreen extends StatelessWidget {
  final String documentId;
  final List<FieldCitation> citations;

  const ClaimAssistanceScreen({
    super.key,
    required this.documentId,
    required this.citations,
  });

  /// The list of fields the substrate does NOT yet extract.
  /// Per ADR-2026-07-19-04, the deferred work is:
  /// - claim_helpline
  /// - claim_email
  /// - network_hospital_list_url
  /// - claim_document_checklist (per-policy)
  /// - claim_form_draft (per-policy)
  static const List<String> _deferredFields = [
    'Claim helpline phone number',
    'Claim email address',
    'Network hospital list',
    'Per-policy claim document checklist',
    'Per-policy claim form draft',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final insurer = _findCitation(citations, 'insurer_name');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim assistance'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Filing a claim',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'The information below is grounded in your policy document. '
              'For the most accurate, up-to-date claim process, '
              'always confirm with your insurer directly.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (insurer != null)
            _InsurerCard(
              insurerName: insurer.value.display,
              citeString: insurer.citeString,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 24,
              ),
              child: Text(
                'The substrate has not extracted an insurer name for this document yet. '
                'This is the honest state when the parser pipeline has not completed, '
                'or when the document does not contain an extractable insurer name.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 8),
          _GenericClaimProcessCard(insurerName: insurer?.value.display),
          const SizedBox(height: 12),
          NotYetExtractedSection(
            fieldNames: _deferredFields,
            title: 'Not yet extracted for your claim',
            subtitle:
                'These items are not in the system yet. They will be '
                'added in a future update; for now, contact your '
                'insurer directly for the helpline, network hospital '
                'list, and the per-policy claim document checklist.',
          ),
        ],
      ),
    );
  }

  static FieldCitation? _findCitation(
    List<FieldCitation> citations,
    String fieldName,
  ) {
    for (final c in citations) {
      if (c.fieldName == fieldName) return c;
    }
    return null;
  }
}

class _InsurerCard extends StatelessWidget {
  final String insurerName;
  final String citeString;

  const _InsurerCard({
    required this.insurerName,
    required this.citeString,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your insurer',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              insurerName,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6,
              ),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 14,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    citeString,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenericClaimProcessCard extends StatelessWidget {
  final String? insurerName;

  const _GenericClaimProcessCard({required this.insurerName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to file a claim',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._genericSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_genericSteps.indexOf(step) + 1}. ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        step,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openInsurerClaims(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('View insurer claim process'),
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _genericSteps = [
    'Notify your insurer as soon as possible after the event (most insurers require notification within 24-48 hours for cashless claims).',
    'Collect all relevant documents: policy number, hospital bills, discharge summary, diagnosis, prescriptions, investigation reports.',
    'For cashless claims, request pre-authorization at a network hospital; for reimbursement claims, pay upfront and submit documents after discharge.',
    'Submit the claim form and documents to your insurer; track the claim status through the insurer\'s portal or customer service.',
    'Follow up with the insurer if there are delays; escalate to the IRDAI ombudsman if the claim is unreasonably denied.',
  ];

  Future<void> _openInsurerClaims(BuildContext context) async {
    // v1: a generic search URL. v2 will use a per-insurer
    // lookup table that maps insurer_name to a verified claim
    // process URL. The per-insurer table is honest about
    // being a small static table; it is not a claim about a
    // specific policy.
    final insurer = insurerName ?? 'insurance';
    final url = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent("$insurer claim process")}',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the browser. Search for your insurer\'s '
            'claim process online.',
          ),
        ),
      );
    }
  }
}
