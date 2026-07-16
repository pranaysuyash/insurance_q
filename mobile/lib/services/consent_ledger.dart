import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../services/app_state_store.dart';

/// Purpose-specific consent types tracked by CoverWise.
enum ConsentPurpose {
  /// Core document processing — OCR, extraction, RAG indexing.
  documentProcessing('document_processing'),

  /// Analytics and usage tracking.
  analytics('analytics'),

  /// Lead capture — storing email/phone for follow-up.
  leadCapture('lead_capture');

  final String value;
  const ConsentPurpose(this.value);

  static ConsentPurpose? fromString(String value) {
    for (final p in values) {
      if (p.value == value) return p;
    }
    return null;
  }
}

/// A single consent record in the ledger.
class ConsentRecord {
  final ConsentPurpose purpose;
  final String version;
  final bool granted;
  final DateTime timestamp;
  final DateTime? revokedAt;

  const ConsentRecord({
    required this.purpose,
    required this.version,
    required this.granted,
    required this.timestamp,
    this.revokedAt,
  });

  bool get isActive => granted && revokedAt == null;
  bool get isRevoked => revokedAt != null;

  Map<String, dynamic> toJson() => {
        'purpose': purpose.value,
        'version': version,
        'granted': granted,
        'timestamp': timestamp.toIso8601String(),
        if (revokedAt != null) 'revoked_at': revokedAt!.toIso8601String(),
      };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    return ConsentRecord(
      purpose: ConsentPurpose.fromString(json['purpose'] ?? '') ??
          ConsentPurpose.documentProcessing,
      version: json['version'] ?? 'unknown',
      granted: json['granted'] ?? false,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'])
          : null,
    );
  }
}

/// Purpose-specific consent ledger stored in Hive.
///
/// Unlike the single `processing_consent_version` key, this ledger tracks
/// consent per-purpose with grant/revoke timestamps for auditability.
class ConsentLedger {
  static const _boxKey = 'consent_ledger_v1';
  Box get _box => Hive.box(AppStateStore.boxName);

  /// Record a consent grant or revoke for a specific purpose.
  Future<void> recordConsent({
    required ConsentPurpose purpose,
    required String version,
    required bool granted,
  }) async {
    final records = _loadRecords();
    records.add(ConsentRecord(
      purpose: purpose,
      version: version,
      granted: granted,
      timestamp: DateTime.now(),
    ));
    await _saveRecords(records);
    debugPrint(
        'ConsentLedger: ${granted ? "granted" : "revoked"} ${purpose.value} v$version');
  }

  /// Revoke consent for a specific purpose.
  Future<void> revokeConsent(ConsentPurpose purpose) async {
    final records = _loadRecords();
    // Find the latest active record for this purpose and mark it revoked.
    ConsentRecord? latestActive;
    int? latestIndex;
    for (var i = records.length - 1; i >= 0; i--) {
      if (records[i].purpose == purpose && records[i].isActive) {
        latestActive = records[i];
        latestIndex = i;
        break;
      }
    }
    if (latestIndex != null) {
      records[latestIndex] = ConsentRecord(
        purpose: latestActive!.purpose,
        version: latestActive.version,
        granted: latestActive.granted,
        timestamp: latestActive.timestamp,
        revokedAt: DateTime.now(),
      );
      await _saveRecords(records);
      debugPrint('ConsentLedger: revoked ${purpose.value}');
    }
  }

  /// Check if consent is currently active for a given purpose.
  bool hasConsent(ConsentPurpose purpose) {
    final records = _loadRecords();
    for (var i = records.length - 1; i >= 0; i--) {
      if (records[i].purpose == purpose) {
        return records[i].isActive;
      }
    }
    return false;
  }

  /// Get the latest consent record for a purpose.
  ConsentRecord? getLatestRecord(ConsentPurpose purpose) {
    final records = _loadRecords();
    for (var i = records.length - 1; i >= 0; i--) {
      if (records[i].purpose == purpose) {
        return records[i];
      }
    }
    return null;
  }

  /// Get all consent records (for settings / audit display).
  List<ConsentRecord> getAllRecords() => _loadRecords();

  /// Clear all consent records (used on clear-data).
  Future<void> clear() async {
    await _box.delete(_boxKey);
    debugPrint('ConsentLedger: cleared all records');
  }

  List<ConsentRecord> _loadRecords() {
    try {
      final raw = _box.get(_boxKey);
      if (raw == null || raw is! String) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => ConsentRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ConsentLedger: failed to load records: $e');
      return [];
    }
  }

  Future<void> _saveRecords(List<ConsentRecord> records) async {
    try {
      await _box.put(_boxKey, jsonEncode(records.map((r) => r.toJson()).toList()));
    } catch (e) {
      debugPrint('ConsentLedger: failed to save records: $e');
    }
  }
}
