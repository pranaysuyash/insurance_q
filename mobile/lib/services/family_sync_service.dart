import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import 'app_state_repository.dart';
import 'document_service.dart';

/// Result status for family member sync operations.
enum FamilySyncCompletion {
  complete,
  partial,
  failed,
}

/// Diagnostic result of a family sync run.
class FamilySyncResult {
  final int pulledCount;
  final int pushedCount;
  final int errorCount;
  final String? errorMessage;
  final FamilySyncCompletion completion;

  const FamilySyncResult({
    this.pulledCount = 0,
    this.pushedCount = 0,
    this.errorCount = 0,
    this.errorMessage,
    this.completion = FamilySyncCompletion.complete,
  });

  bool get isSuccess => completion == FamilySyncCompletion.complete;
}

/// Service that synchronizes manual family members between the local Hive store
/// and the canonical backend (/family/members) API.
///
/// Designed with offline-first resiliency: local operations are immediately
/// persistent in Hive, and sync happens opportunistically in the background
/// without blocking UI rendering.
class FamilySyncService {
  final Dio _dio;

  FamilySyncService([Dio? dio]) : _dio = dio ?? DocumentService.authenticatedDio;

  /// Fetches all family members from the backend and reconciles them
  /// with the local Hive store.
  Future<List<PolicyHolder>> pullMembers() async {
    try {
      final response = await _dio.get('/family/members');
      if (response.statusCode != 200 || response.data is! List) {
        return AppStateRepository.getManualFamilyMembers();
      }

      final serverList = (response.data as List)
          .whereType<Map<String, dynamic>>()
          .map((json) => PolicyHolder.fromJson({
                'id': json['id'],
                'name': json['name'],
                'relationship': json['relationship'],
                'dob': json['date_of_birth'],
                'source': 'manual',
              }))
          .toList();

      final localList = AppStateRepository.getManualFamilyMembers();
      final merged = <String, PolicyHolder>{};

      // Server members are canonical
      for (final s in serverList) {
        final key = s.id ?? '${s.name.toLowerCase()}_${s.relationship.toLowerCase()}';
        merged[key] = s;
      }

      // Preserve any unpushed local members (id == null)
      for (final l in localList) {
        if (l.id == null) {
          final key = '${l.name.toLowerCase()}_${l.relationship.toLowerCase()}';
          if (!merged.containsKey(key)) {
            merged[key] = l;
          }
        }
      }

      final reconciled = merged.values.toList();
      await AppStateRepository.setManualFamilyMembers(reconciled);
      return reconciled;
    } catch (e) {
      debugPrint('FamilySyncService.pullMembers error: $e');
      return AppStateRepository.getManualFamilyMembers();
    }
  }

  /// Pushes a single manual family member to the backend.
  /// If [member.id] is null, calls POST /family/members.
  /// If [member.id] is present, calls PUT /family/members/{id}.
  Future<PolicyHolder?> pushMember(PolicyHolder member) async {
    try {
      final payload = {
        'name': member.name,
        'relationship': member.relationship,
        if (member.dob != null) 'date_of_birth': member.dob,
      };

      if (member.id == null) {
        final response = await _dio.post('/family/members', data: payload);
        if (response.statusCode == 201 || response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final created = PolicyHolder(
            id: data['id']?.toString(),
            name: data['name'] ?? member.name,
            relationship: data['relationship'] ?? member.relationship,
            dob: data['date_of_birth'] ?? member.dob,
            source: 'manual',
          );
          await _updateLocalMember(created);
          return created;
        }
      } else {
        final response = await _dio.put('/family/members/${member.id}', data: payload);
        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final updated = PolicyHolder(
            id: member.id,
            name: data['name'] ?? member.name,
            relationship: data['relationship'] ?? member.relationship,
            dob: data['date_of_birth'] ?? member.dob,
            source: 'manual',
          );
          await _updateLocalMember(updated);
          return updated;
        }
      }
    } catch (e) {
      debugPrint('FamilySyncService.pushMember error: $e');
    }
    return null;
  }

  /// Deletes a family member on the server by ID.
  Future<bool> deleteMember(String backendId) async {
    try {
      final response = await _dio.delete('/family/members/$backendId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('FamilySyncService.deleteMember error: $e');
      return false;
    }
  }

  /// Executes a full bi-directional sync cycle.
  Future<FamilySyncResult> syncAll() async {
    int pulled = 0;
    int pushed = 0;
    int errors = 0;

    try {
      final reconciled = await pullMembers();
      pulled = reconciled.length;

      // Push any members that don't have an ID yet
      for (final m in reconciled) {
        if (m.id == null) {
          final result = await pushMember(m);
          if (result != null && result.id != null) {
            pushed++;
          } else {
            errors++;
          }
        }
      }

      return FamilySyncResult(
        pulledCount: pulled,
        pushedCount: pushed,
        errorCount: errors,
        completion: errors == 0 ? FamilySyncCompletion.complete : FamilySyncCompletion.partial,
      );
    } catch (e) {
      return FamilySyncResult(
        pulledCount: pulled,
        pushedCount: pushed,
        errorCount: errors + 1,
        errorMessage: e.toString(),
        completion: FamilySyncCompletion.failed,
      );
    }
  }

  Future<void> _updateLocalMember(PolicyHolder member) async {
    final list = AppStateRepository.getManualFamilyMembers();
    final updated = <PolicyHolder>[];
    bool matched = false;

    for (final item in list) {
      if ((member.id != null && item.id == member.id) ||
          (item.name.toLowerCase() == member.name.toLowerCase() &&
              item.relationship.toLowerCase() == member.relationship.toLowerCase())) {
        updated.add(member);
        matched = true;
      } else {
        updated.add(item);
      }
    }

    if (!matched) {
      updated.add(member);
    }

    await AppStateRepository.setManualFamilyMembers(updated);
  }
}
