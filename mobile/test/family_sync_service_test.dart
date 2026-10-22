import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/app_state_repository.dart';
import 'package:coverwise/services/family_sync_service.dart';
import 'package:coverwise/models/document_model.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('family-sync-test-');
    Hive.init(hiveDirectory.path);
    await Hive.openBox(AppStateStore.boxName);
  });

  setUp(() async {
    await Hive.box(AppStateStore.boxName).clear();
  });

  tearDownAll(() async {
    await hiveDirectory.delete(recursive: true);
  });

  group('FamilySyncService', () {
    test('pullMembers reconciles remote members with local store', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/family/members' && options.method == 'GET') {
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: [
                {
                  'id': 'uuid-1',
                  'name': 'Priya Sharma',
                  'relationship': 'Spouse',
                  'date_of_birth': '1992-05-15',
                },
                {
                  'id': 'uuid-2',
                  'name': 'Aarav Sharma',
                  'relationship': 'Child',
                  'date_of_birth': '2018-09-20',
                },
              ],
            ));
          }
          return handler.next(options);
        },
      ));

      final service = FamilySyncService(dio);
      final members = await service.pullMembers();

      expect(members.length, 2);
      expect(members[0].name, 'Priya Sharma');
      expect(members[0].id, 'uuid-1');
      expect(members[1].name, 'Aarav Sharma');

      final localMembers = AppStateRepository.getManualFamilyMembers();
      expect(localMembers.length, 2);
      expect(localMembers[0].name, 'Priya Sharma');
    });

    test('pushMember creates member on backend and updates local store with ID',
        () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/family/members' && options.method == 'POST') {
            final data = options.data as Map<String, dynamic>;
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'id': 'server-gen-uuid',
                'name': data['name'],
                'relationship': data['relationship'],
                'date_of_birth': data['date_of_birth'],
              },
            ));
          }
          return handler.next(options);
        },
      ));

      final service = FamilySyncService(dio);
      final newMember = PolicyHolder(
        name: 'Rohan Sharma',
        relationship: 'Brother',
        dob: '1995-01-01',
        source: 'manual',
      );

      final pushed = await service.pushMember(newMember);
      expect(pushed, isNotNull);
      expect(pushed!.id, 'server-gen-uuid');

      final local = AppStateRepository.getManualFamilyMembers();
      expect(local.length, 1);
      expect(local.first.id, 'server-gen-uuid');
      expect(local.first.name, 'Rohan Sharma');
    });
  });
}
