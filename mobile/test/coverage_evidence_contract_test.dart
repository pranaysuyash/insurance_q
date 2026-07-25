import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';

void main() {
  group('coverage evidence contract', () {
    test('round-trips provenance without changing stable follow-up id', () {
      final original = CoverageGap(
        category: 'Health Insurance',
        description: 'No health policy was found in the uploaded workspace.',
        severity: 'info',
        evidenceStatus: CoverageEvidenceStatus.notFoundInWorkspace,
        recommendation: 'Upload it or review this with your insurer.',
      );

      final restored = CoverageGap.fromJson(original.toJson());

      expect(
          restored.evidenceStatus, CoverageEvidenceStatus.notFoundInWorkspace);
      expect(restored.gapId, original.gapId);
      expect(restored.recommendation, original.recommendation);
    });

    test('keeps source provenance for an unverified policy question', () {
      final gap = CoverageGap(
        category: 'Maternity Coverage',
        description:
            'Maternity coverage was not verified in the extracted benefits.',
        severity: 'info',
        evidenceStatus: CoverageEvidenceStatus.notVerified,
        sourceDocumentIds: ['doc-123'],
        sourceFieldNames: ['key_benefits'],
        confidence: 0.62,
      );

      final restored = CoverageGap.fromJson(gap.toJson());

      expect(restored.sourceDocumentIds, ['doc-123']);
      expect(restored.sourceFieldNames, ['key_benefits']);
      expect(restored.confidence, 0.62);
      expect(restored.evidenceStatus, CoverageEvidenceStatus.notVerified);
    });

    test('legacy serialized gaps remain readable as unverified', () {
      final restored = CoverageGap.fromJson({
        'category': 'Legacy question',
        'description': 'Older saved insight',
        'severity': 'info',
      });

      expect(restored.evidenceStatus, CoverageEvidenceStatus.notVerified);
      expect(restored.sourceDocumentIds, isEmpty);
    });
  });
}
