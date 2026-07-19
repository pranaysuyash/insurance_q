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
          // CRITICAL: legal disclaimer. This is a regulated
          // financial product; the user must know that this
          // screen is not financial or legal advice, and that
          // the policy and the insurer's own claims process
          // are the authoritative sources.
          const _LegalDisclaimerCard(),
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
              'The information below is taken from your policy document. '
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "We don't have your insurer's name yet.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For now, contact your insurer directly using the '
                    'phone number or email on your policy document.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _GenericClaimProcessCard
                        ._openInsurerClaims(context, insurerName: null),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          _GenericClaimProcessCard(insurerName: insurer?.value.display),
          const SizedBox(height: 12),
          // IRDAI escalation deserves its own section, not buried
          // as the last item in a 5-step list.
          const _IRDIAEscalationCard(),
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
              'Filing a claim in 5 steps',
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
              onPressed: () => _GenericClaimProcessCard
                  ._openInsurerClaims(context, insurerName: insurerName),
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
    'Follow up with the insurer if there are delays in processing.',
  ];

  /// Per-insurer claim process URL lookup. v1 is a small static
  /// table for the most common Indian insurers. v2 will add
  /// more entries; v3 will use a CMS or per-insurer API.
  /// The fallback is a Google search (v1's old behavior) — the
  /// per-insurer table is an honest small static table, not a
  /// claim about a specific policy.
  static const Map<String, String> _insurerClaimUrls = {
    'HDFC ERGO': 'https://www.hdfcergo.com/health-insurance/claims',
    'ICICI Lombard': 'https://www.icicilombard.com/claims',
    'Bajaj Allianz': 'https://www.bajajallianz.com/Customer-Services/Claims-Services.htm',
    'Tata AIG': 'https://www.tataaig.com/claims',
    'New India Assurance': 'https://www.newindia.co.in/claims',
    'Oriental Insurance': 'https://www.orientalinsurance.org.in/claims',
    'National Insurance': 'https://www.nationalinsuranceindia.com/claims.htm',
    'United India': 'https://www.uiic.in/claims',
    'Reliance General': 'https://www.reliancegeneral.co.in/insurance/Claims/Pages/Claims.aspx',
    'IFFCO Tokio': 'https://www.iffcotokio.co.in/claims',
    'SBI General': 'https://www.sbigeneral.in/claims',
    'Star Health': 'https://www.starhealth.in/claims',
    'ManipalCigna': 'https://www.manipalcigna.com/claims',
    'Niva Bupa': 'https://www.nivabupa.com/claims',
    'Aditya Birla Health': 'https://www.adityabirlacapital.com/healthinsurance/claims',
    'Care Health': 'https://www.careinsurance.com/claims',
    'Digit': 'https://www.godigit.com/claims',
    'Acko': 'https://www.acko.com/claims',
    'Zuno': 'https://www.zuno.com/claims',
    'Future Generali': 'https://www.futuregenerali.in/claims',
    'Cholamandalam': 'https://www.cholainsurance.com/claims',
    'Edelweiss': 'https://www.edelweissinsurance.com/claims',
    'Kotak General': 'https://www.kotakgeneral.com/claims',
    'Liberty General': 'https://www.libertyinsurance.in/claims',
    'Universal Sompo': 'https://www.universalsompo.com/claims',
    'Bharti AXA': 'https://www.bharti-axagi.co.in/claims',
    'Royal Sundaram': 'https://www.royalsundaram.in/claims',
    'Shriram General': 'https://www.shriramgi.com/claims',
    'Magma HDI': 'https://www.magmahdi.com/claims',
  };

  static Future<void> _openInsurerClaims(
    BuildContext context, {
    required String? insurerName,
  }) async {
    // 1. Per-insurer direct URL if we have one.
    if (insurerName != null && _insurerClaimUrls.containsKey(insurerName)) {
      final url = Uri.parse(_insurerClaimUrls[insurerName]!);
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        // Fall through to the Google search.
      }
    }
    // 2. Google search fallback (v1 behavior).
    final insurer = insurerName ?? 'insurance';
    final url = Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeComponent("$insurer claim process")}',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open the browser. Search for your insurer\'s '
            'claim process online.',
          ),
        ),
      );
    }
  }
}

/// CRITICAL: the legal disclaimer card. This is a regulated
/// financial product; the user must know that this screen is
/// not financial or legal advice, and that the policy and the
/// insurer's own claims process are the authoritative sources.
class _LegalDisclaimerCard extends StatelessWidget {
  const _LegalDisclaimerCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This is general information, not financial or legal advice. '
              'Your policy document and your insurer are the authoritative sources '
              'for any claim decision.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// IRDAI escalation. Deserves its own section, not buried as
/// the last item in a 5-step list. The IRDAI ombudsman is the
/// user's last-resort channel for an unreasonably denied claim.
class _IRDIAEscalationCard extends StatelessWidget {
  const _IRDIAEscalationCard();

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
            Row(
              children: [
                Icon(
                  Icons.gavel_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'If your claim is unreasonably denied',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You can escalate to the IRDAI (Insurance Regulatory and '
              'Development Authority of India) Bima Bharosa portal or the '
              'Insurance Ombudsman. Both are free, and IRDAI typically '
              'responds within 30 days.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openBimaBharosa(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open IRDAI Bima Bharosa'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBimaBharosa(BuildContext context) async {
    final url = Uri.parse('https://bimabharosa.irdai.gov.in/');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the browser. Visit bimabharosa.irdai.gov.in'),
        ),
      );
    }
  }
}
