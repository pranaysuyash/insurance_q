import 'package:flutter_test/flutter_test.dart';

import 'package:coverwise/services/demo_service.dart';
import 'package:coverwise/providers/questions_provider.dart';
import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/models/qa_models.dart';
void main() {
  group('DemoService', () {
    late DemoService demoService;

    setUp(() {
      demoService = DemoService();
    });

    test('returns policy number for policy number query', () {
      final result = demoService.buildLocalPolicyAnswer('What is my policy number?');
      expect(result['answer'], contains('4214i/CPHSR/407834350/00/000'));
    });

    test('returns insurer for insurer query', () {
      final result = demoService.buildLocalPolicyAnswer('Who is the insurer?');
      expect(result['answer'], contains('ICICI Lombard'));
    });

    test('returns coverage amount for sum insured query', () {
      final result = demoService.buildLocalPolicyAnswer('What is the sum insured?');
      expect(result['answer'], contains('25,00,000'));
    });

    test('returns fallback for unknown query', () {
      final result = demoService.buildLocalPolicyAnswer('What is the weather today?');
      expect(result['answer'], contains('more specific question'));
    });

    test('returns sources with every answer', () {
      final result = demoService.buildLocalPolicyAnswer('What is my policy number?');
      expect(result['sources'], isNotEmpty);
    });
  });

  group('QaHistoryNotifier', () {
    test('adds item and maintains order', () {
      final notifier = QaHistoryNotifier();
      final answer = QaAnswer(
        text: 'Test answer',
        sources: [],
        timestamp: DateTime.now(),
        documentId: 'doc1',
        question: 'Test question',
      );

      notifier.addItem('Question 1', answer);
      expect(notifier.state.length, 1);
      expect(notifier.state.first.question, 'Question 1');

      notifier.addItem('Question 2', answer);
      expect(notifier.state.length, 2);
      expect(notifier.state.first.question, 'Question 2');
    });

    test('limits history to 50 items', () {
      final notifier = QaHistoryNotifier();
      final answer = QaAnswer(
        text: 'Test',
        sources: [],
        timestamp: DateTime.now(),
        documentId: 'doc1',
        question: 'Test',
      );

      for (var i = 0; i < 60; i++) {
        notifier.addItem('Question $i', answer);
      }

      expect(notifier.state.length, 50);
    });

    test('clears history', () {
      final notifier = QaHistoryNotifier();
      final answer = QaAnswer(
        text: 'Test',
        sources: [],
        timestamp: DateTime.now(),
        documentId: 'doc1',
        question: 'Test',
      );

      notifier.addItem('Question 1', answer);
      notifier.clearHistory();
      expect(notifier.state, isEmpty);
    });
  });

  group('QaPair serialization', () {
    test('round-trips through JSON', () {
      final source = QaSource(documentId: 'doc1', pageNumber: 1, text: 'Source text', score: 0.95);
      final answer = QaAnswer(
        text: 'Answer text',
        sources: [source],
        timestamp: DateTime(2026, 7, 11, 10, 30),
        documentId: 'doc1',
        question: 'Test question',
        confidence: 0.9,
      );
      final pair = QaPair(question: 'Test question', answer: answer, timestamp: DateTime(2026, 7, 11, 10, 30));

      final json = pair.toJson();
      final restored = QaPair.fromJson(json);

      expect(restored.question, pair.question);
      expect(restored.answer.text, pair.answer.text);
      expect(restored.answer.sources.length, 1);
      expect(restored.answer.sources.first.text, 'Source text');
      expect(restored.answer.sources.first.pageNumber, 1);
    });
  });

  group('InsuranceDocument model', () {
    test('formats file size correctly', () {
      final doc = InsuranceDocument(id: '1', filename: 'test.pdf', uploadedOn: DateTime.now(), size: 500);
      expect(doc.formattedFileSize, '500 B');

      final docKb = InsuranceDocument(id: '2', filename: 'test.pdf', uploadedOn: DateTime.now(), size: 2048);
      expect(docKb.formattedFileSize, '2.0 KB');

      final docMb = InsuranceDocument(id: '3', filename: 'test.pdf', uploadedOn: DateTime.now(), size: 1048576);
      expect(docMb.formattedFileSize, '1.0 MB');
    });

    test('round-trips through JSON string', () {
      final doc = InsuranceDocument(
        id: 'test-id',
        remoteId: 'remote-id',
        filename: 'policy.pdf',
        uploadedOn: DateTime(2026, 7, 11),
        documentType: 'Health Insurance',
        insurer: 'ICICI Lombard',
        size: 1024,
        policyHolders: [
          PolicyHolder(name: 'John Doe', dob: '10-May-1988', relationship: 'SELF'),
        ],
      );

      final jsonStr = doc.toJsonString();
      final restored = InsuranceDocument.fromJsonString(jsonStr);

      expect(restored.id, doc.id);
      expect(restored.filename, doc.filename);
      expect(restored.documentType, doc.documentType);
      expect(restored.policyHolders?.length, 1);
      expect(restored.policyHolders?.first.name, 'John Doe');
    });
  });
}
