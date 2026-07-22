import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/screens/processing_status_screen.dart';

void main() {
  group('stageFromState — backend granular stages', () {
    test('maps backend "started" to received', () {
      expect(stageFromState('started'), ProcessingStage.received);
    });

    test('maps backend "validating" to processing', () {
      expect(stageFromState('validating'), ProcessingStage.processing);
    });

    test('maps backend "extracting_text" to processing', () {
      expect(stageFromState('extracting_text'), ProcessingStage.processing);
    });

    test('maps backend "extracting_policy_data" to extraction', () {
      expect(
          stageFromState('extracting_policy_data'), ProcessingStage.extraction);
    });

    test('maps backend "creating_embeddings" to indexing', () {
      expect(stageFromState('creating_embeddings'), ProcessingStage.indexing);
    });

    test('maps backend "completed" to complete', () {
      expect(stageFromState('completed'), ProcessingStage.complete);
    });

    test('maps backend "failed" to failed', () {
      expect(stageFromState('failed'), ProcessingStage.failed);
    });

    test('maps terminal partial states to partially ready', () {
      for (final state in [
        'completed_no_summary',
        'completed_summary_partial',
        'completed_text_partial',
        'summary_partial',
        'indexing_failed',
        'partial',
        'completed_with_errors',
      ]) {
        expect(stageFromState(state), ProcessingStage.partial,
            reason: 'Expected $state to remain visibly partial');
      }
    });
  });

  group('stageFromState — local storage coarse states', () {
    test('maps "received" to received', () {
      expect(stageFromState('received'), ProcessingStage.received);
    });

    test('maps "pending" to received', () {
      expect(stageFromState('pending'), ProcessingStage.received);
    });

    test('maps "pending_upload" to received', () {
      expect(stageFromState('pending_upload'), ProcessingStage.received);
    });

    test('maps "processing" to processing', () {
      expect(stageFromState('processing'), ProcessingStage.processing);
    });

    test('maps "ocr" to processing', () {
      expect(stageFromState('ocr'), ProcessingStage.processing);
    });

    test('maps "extracting" to extraction', () {
      expect(stageFromState('extracting'), ProcessingStage.extraction);
    });

    test('maps "extraction" to extraction', () {
      expect(stageFromState('extraction'), ProcessingStage.extraction);
    });

    test('maps "classifying" to classification', () {
      expect(stageFromState('classifying'), ProcessingStage.classification);
    });

    test('maps "classification" to classification', () {
      expect(stageFromState('classification'), ProcessingStage.classification);
    });

    test('maps "indexing" to indexing', () {
      expect(stageFromState('indexing'), ProcessingStage.indexing);
    });

    test('maps "ready" to complete', () {
      expect(stageFromState('ready'), ProcessingStage.complete);
    });
  });

  group('stageFromState — edge cases', () {
    test('maps null to received', () {
      expect(stageFromState(null), ProcessingStage.received);
    });

    test('maps empty string to received', () {
      expect(stageFromState(''), ProcessingStage.received);
    });

    test('maps unknown string to received', () {
      expect(stageFromState('some_unknown_state'), ProcessingStage.received);
    });
  });

  group('ProcessingStage properties', () {
    test('received has step 0', () {
      expect(ProcessingStage.received.step, 0);
    });

    test('processing has step 1', () {
      expect(ProcessingStage.processing.step, 1);
    });

    test('extraction has step 2', () {
      expect(ProcessingStage.extraction.step, 2);
    });

    test('classification has step 3', () {
      expect(ProcessingStage.classification.step, 3);
    });

    test('indexing has step 4', () {
      expect(ProcessingStage.indexing.step, 4);
    });

    test('complete has step 5', () {
      expect(ProcessingStage.complete.step, 5);
    });

    test('failed has step 5', () {
      expect(ProcessingStage.failed.step, 5);
    });

    test('all stages have non-empty labels', () {
      for (final stage in ProcessingStage.values) {
        expect(stage.label.isNotEmpty, true,
            reason: 'Stage ${stage.name} has empty label');
      }
    });

    test('all stages have non-empty descriptions', () {
      for (final stage in ProcessingStage.values) {
        expect(stage.description.isNotEmpty, true,
            reason: 'Stage ${stage.name} has empty description');
      }
    });
  });

  group('Stage progression logic', () {
    test('complete is ahead of all processing stages', () {
      expect(ProcessingStage.complete.step,
          greaterThan(ProcessingStage.indexing.step));
      expect(ProcessingStage.complete.step,
          greaterThan(ProcessingStage.classification.step));
      expect(ProcessingStage.complete.step,
          greaterThan(ProcessingStage.extraction.step));
      expect(ProcessingStage.complete.step,
          greaterThan(ProcessingStage.processing.step));
      expect(ProcessingStage.complete.step,
          greaterThan(ProcessingStage.received.step));
    });

    test('failed is at same step as complete', () {
      expect(
          ProcessingStage.failed.step, equals(ProcessingStage.complete.step));
    });

    test('stages are in correct order', () {
      expect(ProcessingStage.received.step,
          lessThan(ProcessingStage.processing.step));
      expect(ProcessingStage.processing.step,
          lessThan(ProcessingStage.extraction.step));
      expect(ProcessingStage.extraction.step,
          lessThan(ProcessingStage.classification.step));
      expect(ProcessingStage.classification.step,
          lessThan(ProcessingStage.indexing.step));
      expect(ProcessingStage.indexing.step,
          lessThan(ProcessingStage.complete.step));
    });
  });
}
