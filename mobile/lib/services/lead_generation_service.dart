import 'package:flutter/material.dart';
import '../models/policy_summary.dart';

/// A contextual call-to-action card definition.
class CtaDefinition {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;

  const CtaDefinition({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.onDismiss,
  });
}

/// Topics that a user's question may relate to.
enum CtaTopic {
  coverageGap,
  renewal,
  premium,
  exclusions,
  claimProcess,
  waitingPeriod,
  policyNumber,
  general,
}

/// Engine that determines which document-review CTAs to show from Q&A context.
///
/// Rules are evaluated in priority order. The first match wins to avoid
/// overwhelming the user with multiple CTAs per surface.
class LeadGenerationService {
  /// Matches a question text to a [CtaTopic].
  static CtaTopic classifyQuestion(String question) {
    final lower = question.toLowerCase();
    if (lower.contains('gap') ||
        lower.contains('not covered') ||
        lower.contains('excluded') ||
        lower.contains('limit') ||
        lower.contains('shortfall') ||
        lower.contains('missing')) {
      return CtaTopic.coverageGap;
    }
    if (lower.contains('renew') ||
        lower.contains('expir') ||
        lower.contains('valid until') ||
        lower.contains('end date') ||
        lower.contains('lapse')) {
      return CtaTopic.renewal;
    }
    if (lower.contains('premium') ||
        lower.contains('price') ||
        lower.contains('cost') ||
        lower.contains('emi') ||
        lower.contains('installment')) {
      return CtaTopic.premium;
    }
    if (lower.contains('exclusion') ||
        lower.contains('not cover') ||
        lower.contains('wont cover') ||
        lower.contains('exception')) {
      return CtaTopic.exclusions;
    }
    if (lower.contains('claim') ||
        lower.contains('file') ||
        lower.contains('submit') ||
        lower.contains('process') ||
        lower.contains('intimate') ||
        lower.contains('cashless')) {
      return CtaTopic.claimProcess;
    }
    if (lower.contains('wait') ||
        lower.contains('cooling') ||
        lower.contains('survival') ||
        lower.contains('lock-in')) {
      return CtaTopic.waitingPeriod;
    }
    if (lower.contains('policy number') ||
        lower.contains('id') ||
        lower.contains('document number')) {
      return CtaTopic.policyNumber;
    }
    return CtaTopic.general;
  }

  /// Build document-review CTAs relevant to the given topic and policy.
  ///
  /// CoverWise does not compare insurance products, quote prices, recommend
  /// cover, or broker an adviser relationship. Every active CTA therefore
  /// returns the user to an evidence-backed question about their own policy.
  /// Returns an empty list when no CTA is applicable.
  static List<CtaDefinition> ctasForTopic({
    required CtaTopic topic,
    required PolicySummary? policy,
    required VoidCallback onUpgrade,
  }) {
    final list = <CtaDefinition>[];

    switch (topic) {
      case CtaTopic.coverageGap:
        list.add(CtaDefinition(
          id: 'coverage_review',
          icon: Icons.find_in_page_outlined,
          iconColor: const Color(0xFFD97706),
          title: 'Review your policy wording',
          body: policy != null
              ? 'Ask what ${policy.documentType} records or does not verify in your uploaded policy.'
              : 'Ask what your uploaded policy records or does not verify.',
          actionLabel: 'Ask about this policy',
          actionIcon: Icons.question_answer_outlined,
          onAction: onUpgrade,
        ));
        break;

      case CtaTopic.renewal:
        list.add(CtaDefinition(
          id: 'renewal_review',
          icon: Icons.notifications_active_outlined,
          iconColor: const Color(0xFF7C5AC7),
          title: 'Review the recorded policy date',
          body:
              'Confirm the expiry date in your source policy, then choose reminders on this device if useful.',
          actionLabel: 'Ask about this policy',
          actionIcon: Icons.question_answer_outlined,
          onAction: onUpgrade,
        ));
        break;

      case CtaTopic.premium:
        list.add(CtaDefinition(
          id: 'premium_review',
          icon: Icons.receipt_long_outlined,
          iconColor: const Color(0xFFD97706),
          body: policy != null
              ? 'Ask what premium information was extracted from this ${policy.documentType}.'
              : 'Ask what premium information was extracted from your policy.',
          title: 'Review premium details',
          actionLabel: 'Ask about this policy',
          actionIcon: Icons.question_answer_outlined,
          onAction: onUpgrade,
        ));
        break;

      case CtaTopic.exclusions:
        list.add(CtaDefinition(
          id: 'exclusion_understand',
          icon: Icons.psychology_outlined,
          iconColor: const Color(0xFF7C5AC7),
          title: 'Review exclusions in your policy',
          body:
              'Ask which exclusions were found in your uploaded policy wording and verify important details with the insurer.',
          actionLabel: 'Ask about this policy',
          actionIcon: Icons.question_answer_outlined,
          onAction: onUpgrade,
        ));
        break;

      case CtaTopic.claimProcess:
        list.add(CtaDefinition(
          id: 'claim_guide',
          icon: Icons.fact_check_outlined,
          iconColor: const Color(0xFF087F75),
          title: 'Review claim-related policy wording',
          body:
              'Ask what your uploaded policy says. Claim decisions and requirements remain with the insurer.',
          actionLabel: 'Ask about this policy',
          actionIcon: Icons.question_answer_outlined,
          onAction: onUpgrade,
        ));
        break;

      case CtaTopic.waitingPeriod:
        list.add(CtaDefinition(
          id: 'waiting_explain',
          icon: Icons.schedule_outlined,
          iconColor: const Color(0xFFD14A61),
          title: 'Review waiting periods in your policy',
          body:
              'Ask what waiting-period wording was found in your uploaded policy and confirm important details with the insurer.',
          actionLabel: 'Ask about this policy',
          actionIcon: Icons.question_answer_outlined,
          onAction: onUpgrade,
        ));
        break;

      case CtaTopic.policyNumber:
      case CtaTopic.general:
        // General or policy-number questions are low-signal for CTAs.
        // Return empty — no CTA to avoid bothering the user.
        break;
    }

    return list;
  }
}
