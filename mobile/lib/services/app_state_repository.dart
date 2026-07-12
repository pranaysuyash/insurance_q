import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/document_model.dart';
import 'app_state_store.dart';

class AppStateRepository {
  static Box get _box => Hive.box(AppStateStore.boxName);

  static String? getSelectedDocumentId() {
    return _box.get(AppStateStore.selectedDocumentIdKey) as String?;
  }

  static Future<void> setSelectedDocumentId(String? documentId) async {
    if (documentId == null) {
      await _box.delete(AppStateStore.selectedDocumentIdKey);
      await _box.delete(AppStateStore.lastViewedDocumentIdKey);
      return;
    }
    await _box.put(AppStateStore.selectedDocumentIdKey, documentId);
    await _box.put(AppStateStore.lastViewedDocumentIdKey, documentId);
  }

  static String? getLastUploadedDocumentId() {
    return _box.get(AppStateStore.lastUploadedDocumentIdKey) as String?;
  }

  static Future<void> setLastUploadedDocumentId(String? documentId) async {
    if (documentId == null) {
      await _box.delete(AppStateStore.lastUploadedDocumentIdKey);
      return;
    }
    await _box.put(AppStateStore.lastUploadedDocumentIdKey, documentId);
  }

  static String? getLastViewedDocumentId() {
    return _box.get(AppStateStore.lastViewedDocumentIdKey) as String?;
  }

  static Future<void> setLastViewedDocumentId(String? documentId) async {
    if (documentId == null) {
      await _box.delete(AppStateStore.lastViewedDocumentIdKey);
      return;
    }
    await _box.put(AppStateStore.lastViewedDocumentIdKey, documentId);
  }

  static List<String> getRecentQuestions() {
    final raw = _box.get(AppStateStore.recentQuestionsKey);
    if (raw is List) {
      return raw.map((item) => item.toString()).toList();
    }
    return [];
  }

  static Future<void> addRecentQuestion(String question,
      {int limit = 5}) async {
    final recentQuestions = getRecentQuestions();
    if (!recentQuestions.contains(question)) {
      recentQuestions.insert(0, question);
      if (recentQuestions.length > limit) {
        recentQuestions.removeLast();
      }
      await _box.put(AppStateStore.recentQuestionsKey, recentQuestions);
    }
  }

  static List<String> getRecentlyDeletedDocuments() {
    final raw = _box.get(AppStateStore.recentlyDeletedDocsKey);
    if (raw is List) {
      return raw.map((item) => item.toString()).toList();
    }
    return [];
  }

  static Future<void> addRecentlyDeletedDocument(String filename,
      {int limit = 5}) async {
    final deletedDocs = getRecentlyDeletedDocuments();
    if (!deletedDocs.contains(filename)) {
      deletedDocs.insert(0, filename);
      if (deletedDocs.length > limit) {
        deletedDocs.removeLast();
      }
      await _box.put(AppStateStore.recentlyDeletedDocsKey, deletedDocs);
    }
  }

  static Future<void> clearRecentlyDeletedDocuments() async {
    await _box.delete(AppStateStore.recentlyDeletedDocsKey);
  }

  // ---------------------------------------------------------------------------
  // Manual family members
  //
  // Manually added family members (e.g. a dependent who has their own separate
  // policy and isn't named in any uploaded document). Stored as a JSON string
  // list so they survive app restarts and remain available offline.
  // ---------------------------------------------------------------------------

  static List<PolicyHolder> getManualFamilyMembers() {
    final raw = _box.get(AppStateStore.manualFamilyMembersKey);
    if (raw is! String) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((item) =>
              PolicyHolder.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveManualFamilyMembers(
      List<PolicyHolder> members) async {
    final encoded = jsonEncode(
        members.map((member) => member.toJson()).toList());
    await _box.put(AppStateStore.manualFamilyMembersKey, encoded);
  }

  static Future<void> addManualFamilyMember(PolicyHolder member) async {
    final members = getManualFamilyMembers();
    members.add(member);
    await saveManualFamilyMembers(members);
  }

  static Future<void> removeManualFamilyMember(String name,
      {String? relationship}) async {
    final members = getManualFamilyMembers();
    members.removeWhere((m) =>
        m.name == name &&
        (relationship == null || m.relationship == relationship));
    await saveManualFamilyMembers(members);
  }
}
