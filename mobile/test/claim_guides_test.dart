import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/services/policy_extraction_service.dart';
import 'package:coverwise/services/query_service.dart';
import 'package:dio/dio.dart';

class _FakeQueryService extends QueryService {
  _FakeQueryService() : super(Dio());

  @override
  Future<Map<String, dynamic>> queryDocument(String question,
      {String? documentId}) async {
    return {'answer': 'test'};
  }
}

void main() {
  late PolicyExtractionService service;
  late PolicySummary testSummary;

  setUp(() {
    service = PolicyExtractionService(_FakeQueryService());
    testSummary = PolicySummary(
      documentId: 'test-doc',
      documentType: 'Test',
      extractedAt: DateTime(2024, 1, 1),
      insurerHelpline: '1800-123-4567',
      insurerEmail: 'claims@insurer.com',
    );
  });

  group('Home insurance claim guides', () {
    test('fire incident returns fire claim guide', () {
      final guide = service.getClaimGuide('fire', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Fire'));
      expect(guide.steps.length, 4);
      expect(guide.requiredDocuments, contains('Fire brigade report'));
      expect(guide.helpline, '1800-123-4567');
      expect(guide.email, 'claims@insurer.com');
    });

    test('"home" incident returns fire claim guide', () {
      final guide = service.getClaimGuide('home', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Fire'));
    });

    test('burglary incident returns burglary claim guide', () {
      final guide = service.getClaimGuide('burglary', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Burglary'));
      expect(guide.steps.length, 4);
      expect(guide.requiredDocuments, contains('FIR copy'));
      expect(guide.notes, contains('valid FIR'));
    });

    test('theft incident returns burglary claim guide', () {
      final guide = service.getClaimGuide('theft', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Burglary'));
    });

    test('flood incident returns natural disaster claim guide', () {
      final guide = service.getClaimGuide('flood', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Natural Disaster'));
      expect(guide.notes, contains('Flood'));
    });

    test('earthquake incident returns natural disaster claim guide', () {
      final guide = service.getClaimGuide('earthquake', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Natural Disaster'));
    });

    test('natural disaster incident returns natural disaster claim guide', () {
      final guide = service.getClaimGuide('natural disaster', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Natural Disaster'));
    });
  });

  group('Travel insurance claim guides', () {
    test('medical emergency returns travel medical claim guide', () {
      final guide = service.getClaimGuide('medical emergency', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Medical Emergency'));
      expect(guide.steps.length, 4);
      expect(guide.requiredDocuments, contains('Travel itinerary'));
      expect(guide.notes, contains('emergency assistance number'));
    });

    test('baggage loss incident returns baggage claim guide', () {
      final guide = service.getClaimGuide('baggage loss', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Baggage'));
      expect(guide.steps.length, 3);
      expect(guide.requiredDocuments, contains('PIR from airline'));
    });

    test('baggage delay incident returns baggage claim guide', () {
      final guide = service.getClaimGuide('baggage delay', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Baggage'));
    });

    test('baggage incident returns baggage claim guide', () {
      final guide = service.getClaimGuide('baggage', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Baggage'));
    });

    test('trip cancellation returns cancellation claim guide', () {
      final guide = service.getClaimGuide('trip cancellation', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Trip Cancellation'));
      expect(guide.steps.length, 3);
      expect(guide.requiredDocuments, contains('Proof of cancellation reason'));
    });

    test('cancellation returns trip cancellation claim guide', () {
      final guide = service.getClaimGuide('cancellation', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Trip Cancellation'));
    });

    test('flight delay returns flight delay claim guide', () {
      final guide = service.getClaimGuide('flight delay', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Flight Delay'));
      expect(guide.steps.length, 3);
      expect(guide.requiredDocuments, contains('Delay certificate from airline'));
    });

    test('"travel" incident returns travel general claim guide', () {
      final guide = service.getClaimGuide('travel', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('General'));
      expect(guide.steps.length, 3);
    });
  });

  group('Existing claim guides still work', () {
    test('hospitalization returns hospitalization claim guide', () {
      final guide = service.getClaimGuide('hospitalization', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Hospitalization'));
    });

    test('accident returns auto claim guide', () {
      final guide = service.getClaimGuide('accident', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Auto'));
    });

    test('death returns life claim guide', () {
      final guide = service.getClaimGuide('death', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, contains('Death'));
    });

    test('unknown incident type returns generic guide', () {
      final guide = service.getClaimGuide('unknown_type', testSummary);
      expect(guide, isNotNull);
      expect(guide!.title, 'General Insurance Claim');
    });
  });
}
