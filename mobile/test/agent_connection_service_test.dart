import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:coverwise/services/agent_connection_service.dart';

import 'helpers/hive_test_helper.dart';

void main() {
  late AgentConnectionService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HiveTestHelper.setUp();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  setUp(() {
    service = AgentConnectionService();
  });

  tearDown(() async {
    await Hive.box<dynamic>('agent_requests').clear();
  });

  group('AgentConnectionService — submitRequest', () {
    test('returns true on valid submission', () async {
      final result = await service.submitRequest(
        name: 'Pranay Suyash',
        phone: '9876543210',
        description: 'I need help understanding my coverage gaps.',
      );
      expect(result, isTrue);
    });

    test('rejects empty name', () async {
      final result = await service.submitRequest(
        name: '',
        phone: '9876543210',
        description: 'Help',
      );
      expect(result, isFalse);
    });

    test('rejects short phone number', () async {
      final result = await service.submitRequest(
        name: 'Test User',
        phone: '12345',
        description: 'Help',
      );
      expect(result, isFalse);
    });

    test('rejects empty phone', () async {
      final result = await service.submitRequest(
        name: 'Test User',
        phone: '',
        description: 'Help',
      );
      expect(result, isFalse);
    });

    test('accepts phone with +91 prefix', () async {
      final result = await service.submitRequest(
        name: 'Test User',
        phone: '+919876543210',
        description: 'Help',
      );
      expect(result, isTrue);
    });

    test('accepts preferred date and time slot', () async {
      final result = await service.submitRequest(
        name: 'Scheduled User',
        phone: '9876543210',
        description: 'Call me Tuesday morning',
        preferredDate: DateTime(2026, 7, 28),
        preferredTime: 'Morning (9-12)',
      );
      expect(result, isTrue);

      final requests = service.getRequests();
      expect(requests.length, equals(1));
      expect(requests[0].preferredDate, equals(DateTime(2026, 7, 28)));
      expect(requests[0].preferredTime, equals('Morning (9-12)'));
    });

    test('scheduling fields default to null', () async {
      await service.submitRequest(
        name: 'No Schedule',
        phone: '9876543210',
        description: 'Call any time',
      );

      final requests = service.getRequests();
      expect(requests[0].preferredDate, isNull);
      expect(requests[0].preferredTime, isNull);
    });
  });

  group('AgentConnectionService — getRequests', () {
    test('returns empty list when no requests exist', () {
      final requests = service.getRequests();
      expect(requests, isEmpty);
    });

    test('returns stored requests newest first', () async {
      await service.submitRequest(
        name: 'User A',
        phone: '1111111111',
        description: 'First',
      );
      await Future.delayed(const Duration(milliseconds: 10));
      await service.submitRequest(
        name: 'User B',
        phone: '2222222222',
        description: 'Second',
      );

      final requests = service.getRequests();
      expect(requests.length, equals(2));
      expect(requests[0].name, equals('User B'));
      expect(requests[1].name, equals('User A'));
    });

    test('includes policy context when provided', () async {
      await service.submitRequest(
        name: 'Test User',
        phone: '9876543210',
        description: 'Help with my policy',
        insurer: 'ICICI Lombard',
        documentType: 'Health Insurance',
        documentId: 'doc-123',
      );

      final requests = service.getRequests();
      expect(requests.length, equals(1));
      expect(requests[0].insurer, equals('ICICI Lombard'));
      expect(requests[0].documentType, equals('Health Insurance'));
      expect(requests[0].documentId, equals('doc-123'));
    });
  });

  group('AgentConnectionService — requestCount', () {
    test('starts at zero', () {
      expect(service.requestCount, equals(0));
    });

    test('increments after each submission', () async {
      await service.submitRequest(
        name: 'User A', phone: '1111111111', description: 'A',
      );
      expect(service.requestCount, equals(1));

      await service.submitRequest(
        name: 'User B', phone: '2222222222', description: 'B',
      );
      expect(service.requestCount, equals(2));
    });
  });

  group('AgentConnectionService — markContacted', () {
    test('sets contacted flag on matching request', () async {
      await service.submitRequest(
        name: 'Test User',
        phone: '9876543210',
        description: 'Help',
      );

      final requests = service.getRequests();
      expect(requests[0].contacted, isFalse);

      await service.markContacted(requests[0].id);

      final updated = service.getRequests();
      expect(updated[0].contacted, isTrue);
    });
  });

  group('AgentConnectionService — clear', () {
    test('removes all requests', () async {
      await service.submitRequest(
        name: 'User A', phone: '1111111111', description: 'A',
      );
      await service.submitRequest(
        name: 'User B', phone: '2222222222', description: 'B',
      );
      expect(service.requestCount, equals(2));

      await service.clear();

      expect(service.requestCount, equals(0));
      expect(service.getRequests(), isEmpty);
    });
  });

  group('AgentRequest model — serialization', () {
    test('toJson / fromJson roundtrip preserves all fields', () {
      final original = AgentRequest(
        id: 'req-1',
        name: 'Pranay Suyash',
        phone: '+919876543210',
        description: 'I need help understanding my policy exclusions.',
        insurer: 'ICICI Lombard',
        documentType: 'Health Insurance',
        documentId: 'doc-123',
        createdAt: DateTime(2026, 7, 22, 10, 30),
        contacted: true,
        preferredDate: DateTime(2026, 7, 28),
        preferredTime: 'Morning (9-12)',
      );

      final json = original.toJson();
      final restored = AgentRequest.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.phone, equals(original.phone));
      expect(restored.description, equals(original.description));
      expect(restored.insurer, equals(original.insurer));
      expect(restored.documentType, equals(original.documentType));
      expect(restored.documentId, equals(original.documentId));
      expect(restored.createdAt, equals(original.createdAt));
      expect(restored.contacted, equals(original.contacted));
      expect(restored.preferredDate, equals(original.preferredDate));
      expect(restored.preferredTime, equals(original.preferredTime));
    });

    test('toJson omits scheduling fields when null', () {
      final request = AgentRequest(
        id: 'req-1',
        name: 'Test User',
        phone: '9876543210',
        description: 'Help',
        createdAt: DateTime(2026, 7, 22),
      );

      final json = request.toJson();
      expect(json.containsKey('preferred_date'), isFalse);
      expect(json.containsKey('preferred_time'), isFalse);
    });

    test('fromJson restores scheduling fields when present', () {
      final json = <String, dynamic>{
        'id': 'req-1',
        'name': 'Test User',
        'phone': '9876543210',
        'description': 'Help',
        'created_at': '2026-07-22T10:30:00.000',
        'preferred_date': '2026-07-28T00:00:00.000',
        'preferred_time': 'Afternoon (12-5)',
      };

      final request = AgentRequest.fromJson(json);
      expect(request.preferredDate, equals(DateTime(2026, 7, 28)));
      expect(request.preferredTime, equals('Afternoon (12-5)'));
    });

    test('fromJson handles missing scheduling fields gracefully', () {
      final json = <String, dynamic>{
        'id': 'req-1',
        'name': 'Test User',
        'phone': '9876543210',
        'description': 'Help',
        'created_at': '2026-07-22T10:30:00.000',
      };

      final request = AgentRequest.fromJson(json);
      expect(request.preferredDate, isNull);
      expect(request.preferredTime, isNull);
    });

    test('fromJson handles missing optional fields gracefully', () {
      final json = <String, dynamic>{
        'id': 'req-1',
        'name': 'Test User',
        'phone': '9876543210',
        'description': 'Help',
        'created_at': '2026-07-22T10:30:00.000',
      };

      final request = AgentRequest.fromJson(json);
      expect(request.id, equals('req-1'));
      expect(request.name, equals('Test User'));
      expect(request.insurer, isNull);
      expect(request.documentType, isNull);
      expect(request.documentId, isNull);
      expect(request.contacted, isFalse);
    });

    test('fromJson handles empty/malformed created_at', () {
      final json = <String, dynamic>{
        'id': 'req-1',
        'name': 'Test User',
        'phone': '9876543210',
        'description': 'Help',
        'created_at': 'not-a-date',
      };

      final request = AgentRequest.fromJson(json);
      expect(request.createdAt, isNotNull);
      // Should fall back to a recent timestamp
      expect(
        request.createdAt.isAfter(DateTime(2026, 1, 1)),
        isTrue,
      );
    });
  });
}
