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

/// Engine that determines which CTAs to show based on Q&A context and policy state.
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

  /// Build CTAs relevant to the given topic and optional policy summary.
  ///
  /// Returns an empty list when no CTA is applicable.
  static List<CtaDefinition> ctasForTopic({
    required CtaTopic topic,
    required PolicySummary? policy,
    required BuildContext context,
    required VoidCallback onUpgrade,
    required VoidCallback onCompare,
    required VoidCallback onNewsletter,
    required VoidCallback onContactAgent,
  }) {
    final list = <CtaDefinition>[];

    switch (topic) {
      case CtaTopic.coverageGap:
        list.add(CtaDefinition(
          id: 'gap_compare',
          icon: Icons.compare_arrows_rounded,
          iconColor: const Color(0xFFD97706),
          title: 'Compare coverage options',
          body: policy != null
              ? 'Your ${policy.documentType} may have gaps you can fill. See what other plans offer.'
              : 'See how different plans compare on coverage and exclusions.',
          actionLabel: 'Compare plans',
          actionIcon: Icons.open_in_new_rounded,
          onAction: onCompare,
        ));
        list.add(CtaDefinition(
          id: 'gap_agent',
          icon: Icons.support_agent_rounded,
          iconColor: const Color(0xFF087F75),
          title: 'Talk to an insurance advisor',
          body: 'A professional can help you understand coverage gaps and find suitable protection.',
          actionLabel: 'Connect with advisor',
          actionIcon: Icons.arrow_forward_rounded,
          onAction: onContactAgent,
        ));
        break;

      case CtaTopic.renewal:
        list.add(CtaDefinition(
          id: 'renew_reminder',
          icon: Icons.notifications_active_outlined,
          iconColor: const Color(0xFF7C5AC7),
          title: 'Get renewal reminders',
          body: 'Never miss a renewal. We can notify you 30, 15, 7 and 1 day before expiry.',
          actionLabel: 'Set reminders',
          actionIcon: Icons.toggle_on_outlined,
          onAction: onUpgrade,
        ));
        if (policy?.insurer != null) {
          list.add(CtaDefinition(
            id: 'renew_compare',
            icon: Icons.shopping_cart_outlined,
            iconColor: const Color(0xFFD14A61),
            title: 'Compare renewal offers',
            body: 'See if better rates are available before renewing with ${policy!.insurer}.',
            actionLabel: 'View offers',
            actionIcon: Icons.arrow_forward_rounded,
            onAction: onCompare,
          ));
        }
        break;

      case CtaTopic.premium:
        list.add(CtaDefinition(
          id: 'premium_tips',
          icon: Icons.lightbulb_outline_rounded,
          iconColor: const Color(0xFFD97706),
          title: 'Ways to save on premiums',
          body: 'Higher deductibles, bundling policies, or health improvements can reduce your premium.',
          actionLabel: 'Get saving tips',
          actionIcon: Icons.arrow_forward_rounded,
          onAction: onNewsletter,
        ));
        list.add(CtaDefinition(
          id: 'premium_compare',
          icon: Icons.trending_down_rounded,
          iconColor: const Color(0xFF087F75),
          title: 'Compare premium rates',
          body: policy != null
              ? 'See how your current premium compares to similar plans from other insurers.'
              : 'Discover plans that fit your budget.',
          actionLabel: 'Compare rates',
          actionIcon: Icons.open_in_new_rounded,
          onAction: onCompare,
        ));
        break;

      case CtaTopic.exclusions:
        list.add(CtaDefinition(
          id: 'exclusion_understand',
          icon: Icons.psychology_outlined,
          iconColor: const Color(0xFF7C5AC7),
          title: 'Understanding exclusions',
          body: 'Exclusions vary widely between plans. Know what to watch for when choosing coverage.',
          actionLabel: 'Learn more',
          actionIcon: Icons.arrow_forward_rounded,
          onAction: onNewsletter,
        ));
        break;

      case CtaTopic.claimProcess:
        list.add(CtaDefinition(
          id: 'claim_guide',
          icon: Icons.fact_check_outlined,
          iconColor: const Color(0xFF087F75),
          title: 'Prepare for a claim',
          body: 'Keep documents ready. Our claim guide walks through what insurers typically require.',
          actionLabel: 'View claim guide',
          actionIcon: Icons.arrow_forward_rounded,
          onAction: onUpgrade,
        ));
        break;

      case CtaTopic.waitingPeriod:
        list.add(CtaDefinition(
          id: 'waiting_explain',
          icon: Icons.schedule_outlined,
          iconColor: const Color(0xFFD14A61),
          title: 'How waiting periods work',
          body: 'Most health policies have waiting periods for pre-existing conditions. Some waive them for higher premiums.',
          actionLabel: 'Learn about waiting periods',
          actionIcon: Icons.arrow_forward_rounded,
          onAction: onNewsletter,
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
