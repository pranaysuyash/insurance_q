import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/claim_record.dart';
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

  /// Remove navigation pointers that refer to a deleted document.
  ///
  /// A document can have both a local Hive ID and a server ID. Callers should
  /// pass both so a remote-first deletion cannot leave a stale deep-link
  /// pointer after the local record is removed.
  static Future<void> clearDocumentReferences(
      Iterable<String> documentIds) async {
    final ids = documentIds.toSet();
    for (final entry in <String, String?>{
      AppStateStore.selectedDocumentIdKey: getSelectedDocumentId(),
      AppStateStore.lastUploadedDocumentIdKey: getLastUploadedDocumentId(),
      AppStateStore.lastViewedDocumentIdKey: getLastViewedDocumentId(),
    }.entries) {
      if (entry.value != null && ids.contains(entry.value)) {
        await _box.delete(entry.key);
      }
    }
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

  // ---------------------------------------------------------------------------
  // Claim records — locally tracked insurance claims
  // ---------------------------------------------------------------------------

  static List<ClaimRecord> getClaimRecords() {
    final raw = _box.get(AppStateStore.claimRecordsKey);
    if (raw is! String) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((item) => ClaimRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveClaimRecords(List<ClaimRecord> records) async {
    final encoded =
        jsonEncode(records.map((r) => r.toJson()).toList());
    await _box.put(AppStateStore.claimRecordsKey, encoded);
  }

  static Future<void> addClaimRecord(ClaimRecord record) async {
    final records = getClaimRecords();
    records.insert(0, record);
    await saveClaimRecords(records);
  }

  static Future<void> updateClaimRecord(ClaimRecord updated) async {
    final records = getClaimRecords();
    final idx = records.indexWhere((r) => r.id == updated.id);
    if (idx >= 0) {
      records[idx] = updated;
      await saveClaimRecords(records);
    }
  }

  /// Delete photo files associated with a set of file paths.
  ///
  /// Silently ignores missing or non-existent files so partial cleanup
  /// never blocks the user from deleting a claim record.
  static Future<void> deletePhotoFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Individual file deletion failures must never block claim deletion.
      }
    }
  }

  static Future<void> deleteClaimRecord(String id) async {
    final records = getClaimRecords();
    final claim = records.where((r) => r.id == id).firstOrNull;
    if (claim != null && claim.photoPaths.isNotEmpty) {
      await deletePhotoFiles(claim.photoPaths);
    }
    records.removeWhere((r) => r.id == id);
    await saveClaimRecords(records);
  }

  // ---------------------------------------------------------------------------
  // Coverage gap resolution tracking
  //
  // Users can mark coverage gaps as "addressed" with optional notes and a
  // timestamp. This persists locally so the resolution status survives restarts.
  // The gap ID is a stable hash of (category + description + severity).
  // ---------------------------------------------------------------------------

  static Map<String, Map<String, dynamic>> getResolvedGaps() {
    final raw = _box.get(AppStateStore.resolvedGapsKey);
    if (raw is! Map) return {};
    try {
      return raw.map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)));
    } catch (e) {
      return {};
    }
  }

  static Future<void> markGapResolved(String gapId, {String? notes}) async {
    final gaps = getResolvedGaps();
    gaps[gapId] = {
      'resolvedAt': DateTime.now().toIso8601String(),
      'notes': notes,
    };
    await _box.put(AppStateStore.resolvedGapsKey, gaps);
  }

  static Future<void> unresolveGap(String gapId) async {
    final gaps = getResolvedGaps();
    gaps.remove(gapId);
    await _box.put(AppStateStore.resolvedGapsKey, gaps);
  }

  static bool isGapResolved(String gapId) {
    return getResolvedGaps().containsKey(gapId);
  }

  static String? getGapResolutionNotes(String gapId) {
    final info = getResolvedGaps()[gapId];
    return info?['notes'] as String?;
  }

  // ---------------------------------------------------------------------------
  // Theme preference
  // ---------------------------------------------------------------------------

  static String getThemeMode() {
    return _box.get(AppStateStore.themeModeKey, defaultValue: 'system') as String;
  }

  static Future<void> setThemeMode(String mode) async {
    await _box.put(AppStateStore.themeModeKey, mode);
  }

  // ---------------------------------------------------------------------------
  // Locale preference (M10 multi-language support)
  // ---------------------------------------------------------------------------

  /// Returns the stored locale tag ('en', 'hi'), or null to use system default.
  static String? getLocale() {
    return _box.get(AppStateStore.localeKey) as String?;
  }

  static Future<void> setLocale(String? locale) async {
    if (locale == null) {
      await _box.delete(AppStateStore.localeKey);
      return;
    }
    // Validate that the locale is one of our supported values.
    // Runtime check (not assert) so validation works in release builds.
    const validLocales = {'en', 'hi', 'gu', 'mr', 'ta'};
    if (!validLocales.contains(locale)) {
      debugPrint('AppStateRepository.setLocale: unsupported locale "$locale" — ignoring.');
      return;
    }
    await _box.put(AppStateStore.localeKey, locale);
  }
}

