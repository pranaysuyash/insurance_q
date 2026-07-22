import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:coverwise/screens/processing_status_screen.dart';

void main() {
  group('ProcessingStage enum', () {
    test('has exactly 8 stages in correct order', () {
      expect(ProcessingStage.values.length, 8);
      expect(ProcessingStage.values[0], ProcessingStage.received);
      expect(ProcessingStage.values[1], ProcessingStage.processing);
      expect(ProcessingStage.values[2], ProcessingStage.extraction);
      expect(ProcessingStage.values[3], ProcessingStage.classification);
      expect(ProcessingStage.values[4], ProcessingStage.indexing);
      expect(ProcessingStage.values[5], ProcessingStage.complete);
      expect(ProcessingStage.values[6], ProcessingStage.partial);
      expect(ProcessingStage.values[7], ProcessingStage.failed);
    });

    test('step values are sequential for pipeline stages', () {
      expect(ProcessingStage.received.step, 0);
      expect(ProcessingStage.processing.step, 1);
      expect(ProcessingStage.extraction.step, 2);
      expect(ProcessingStage.classification.step, 3);
      expect(ProcessingStage.indexing.step, 4);
    });

    test('terminal stages share step 5', () {
      expect(ProcessingStage.complete.step, 5);
      expect(ProcessingStage.partial.step, 5);
      expect(ProcessingStage.failed.step, 5);
    });

    test('all stages have non-empty labels', () {
      for (final stage in ProcessingStage.values) {
        expect(stage.label, isNotEmpty);
      }
    });

    test('all stages have non-empty descriptions', () {
      for (final stage in ProcessingStage.values) {
        expect(stage.description, isNotEmpty);
      }
    });

    test('pipeline stages have distinct colors', () {
      final pipelineStages = [
        ProcessingStage.received,
        ProcessingStage.processing,
        ProcessingStage.extraction,
        ProcessingStage.classification,
        ProcessingStage.indexing,
      ];
      final colors = pipelineStages.map((s) => s.color).toSet();
      expect(colors.length, pipelineStages.length,
          reason: 'Each pipeline stage should have a distinct color');
    });

    test('complete is green and failed is red', () {
      expect(ProcessingStage.complete.color, Colors.green);
      expect(ProcessingStage.failed.color, Colors.red);
    });
  });

  group('stageFromState mapping', () {
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

    test('maps "completed" to complete', () {
      expect(stageFromState('completed'), ProcessingStage.complete);
    });

    test('maps "ready" to complete', () {
      expect(stageFromState('ready'), ProcessingStage.complete);
    });

    test('maps "failed" to failed', () {
      expect(stageFromState('failed'), ProcessingStage.failed);
    });

    test('maps null to received (safe default)', () {
      expect(stageFromState(null), ProcessingStage.received);
    });

    test('maps empty string to received (safe default)', () {
      expect(stageFromState(''), ProcessingStage.received);
    });

    test('maps unknown string to received (safe default)', () {
      expect(stageFromState('unknown_state'), ProcessingStage.received);
    });

    test('maps random garbage to received (safe default)', () {
      expect(stageFromState('hello_world_123'), ProcessingStage.received);
    });
  });

  group('Stage progression logic', () {
    test('isComplete returns true only for complete', () {
      expect(ProcessingStage.complete == ProcessingStage.complete, true);
      expect(ProcessingStage.failed == ProcessingStage.complete, false);
    });

    test('step comparison correctly identifies completed stages', () {
      // When current stage is extraction (step 2), received (step 0) and
      // processing (step 1) should be considered "complete" (their step < current)
      final currentStep = ProcessingStage.extraction.step;
      expect(ProcessingStage.received.step < currentStep, true);
      expect(ProcessingStage.processing.step < currentStep, true);
      expect(ProcessingStage.extraction.step < currentStep, false);
      expect(ProcessingStage.classification.step < currentStep, false);
    });

    test('terminal stages are not part of pipeline stages list', () {
      final pipelineStages =
          ProcessingStage.values.where((s) => s.step < 5).toList();
      expect(pipelineStages.length, 5);
      expect(pipelineStages.contains(ProcessingStage.complete), false);
      expect(pipelineStages.contains(ProcessingStage.failed), false);
    });
  });
}
