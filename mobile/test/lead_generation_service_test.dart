import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/services/lead_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CtaDefinition? firstCta(CtaTopic topic) {
    final ctas = LeadGenerationService.ctasForTopic(
      topic: topic,
      policy: PolicySummary(
        documentId: 'policy-1',
        documentType: 'health',
        insurer: 'Example Insurer',
        extractedAt: DateTime(2026, 7, 24),
      ),
      onUpgrade: () {},
    );
    return ctas.isEmpty ? null : ctas.single;
  }

  group('LeadGenerationService', () {
    test('classifies document-review questions without treating them as advice',
        () {
      expect(
        LeadGenerationService.classifyQuestion('What is excluded?'),
        CtaTopic.coverageGap,
      );
      expect(
        LeadGenerationService.classifyQuestion('When does my policy expire?'),
        CtaTopic.renewal,
      );
      expect(
        LeadGenerationService.classifyQuestion('What premium is recorded?'),
        CtaTopic.premium,
      );
    });

    test(
        'active CTAs direct people back to their policy, not to insurance sales',
        () {
      const activeTopics = [
        CtaTopic.coverageGap,
        CtaTopic.renewal,
        CtaTopic.premium,
        CtaTopic.exclusions,
        CtaTopic.claimProcess,
        CtaTopic.waitingPeriod,
      ];
      final prohibited = RegExp(
        r'compare|offer|advisor|rate|save|suitable protection|higher premium',
        caseSensitive: false,
      );

      for (final topic in activeTopics) {
        final cta = firstCta(topic);
        expect(cta, isNotNull, reason: 'Expected CTA for $topic');
        expect(cta!.actionLabel, 'Ask about this policy');
        expect(prohibited.hasMatch('${cta.title} ${cta.body}'), isFalse,
            reason: 'Prohibited sales/advice copy in $topic');
      }
    });

    test('low-signal topics do not create a CTA', () {
      expect(firstCta(CtaTopic.policyNumber), isNull);
      expect(firstCta(CtaTopic.general), isNull);
    });
  });
}
