import 'dart:async';
import 'package:hive/hive.dart';

/// The purpose for which consent was granted or revoked.
enum ConsentPurpose {
  /// Core document processing — OCR, extraction, RAG indexing.
  documentProcessing('document_processing'),

  /// Analytics and usage tracking.
  analytics('analytics'),

  /// Lead capture — storing email/phone for follow-up.
  leadCapture('lead_capture'),

  /// Terms of Service acceptance during onboarding.
  termsAccepted('terms_accepted');

  final String value;
  const ConsentPurpose(this.value);

  static ConsentPurpose? fromString(String value) {
    for (final p in values) {
      if (p.value == value) return p;
    }
    return null;
  }
}

/// A single consent record stored in the ledger.
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

  /// Whether this consent record is currently active (granted and not revoked).
  bool get isActive => granted && !isRevoked;

  /// Whether this consent has been revoked.
  bool get isRevoked => revokedAt != null;

  Map<String, dynamic> toJson() => {
        'purpose': purpose.value,
        'version': version,
        'granted': granted,
        'timestamp': timestamp.toIso8601String(),
        'revoked_at': revokedAt?.toIso8601String(),
      };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    final purpose =
        ConsentPurpose.fromString(json['purpose'] ?? '') ??
            ConsentPurpose.documentProcessing;
    return ConsentRecord(
      purpose: purpose,
      version: json['version'] as String? ?? 'unknown',
      granted: json['granted'] as bool? ?? false,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'] as String)
          : null,
    );
  }
}

/// Append-only ledger of consent grants and revocations.
///
/// Stored in a Hive box named `consent_ledger`. Each record is a JSON map
/// appended to the box's values list. The latest record for a given
/// [ConsentPurpose] determines the current consent state.
class ConsentLedger {
  static const String _boxName = 'consent_ledger';

  Box<dynamic>? get _box {
    try {
      return Hive.box<dynamic>(_boxName);
    } catch (_) {
      return null;
    }
  }

  /// Record a consent grant or revocation.
  Future<void> recordConsent({
    required ConsentPurpose purpose,
    required String version,
    required bool granted,
  }) async {
    final record = ConsentRecord(
      purpose: purpose,
      version: version,
      granted: granted,
      timestamp: DateTime.now(),
    );
    await _box?.add(record.toJson());
  }

  /// Revoke consent for a given purpose by marking the latest active record
  /// as revoked.
  Future<void> revokeConsent(ConsentPurpose purpose) async {
    final latest = getLatestRecord(purpose);
    if (latest == null || latest.isRevoked) return;

    final revokedRecord = ConsentRecord(
      purpose: latest.purpose,
      version: latest.version,
      granted: false,
      timestamp: latest.timestamp,
      revokedAt: DateTime.now(),
    );
    await _box?.add(revokedRecord.toJson());
  }

  /// Check if consent is currently granted for a given purpose.
  ///
  /// Looks at the latest record for this purpose. If no record exists
  /// or the latest is revoked, returns `false` (default deny).
  bool hasConsent(ConsentPurpose purpose) {
    final record = getLatestRecord(purpose);
    return record?.isActive ?? false;
  }

  /// Get the latest consent record for a given purpose.
  ConsentRecord? getLatestRecord(ConsentPurpose purpose) {
    if (_box == null) return null;

    ConsentRecord? latest;
    for (final value in _box!.values) {
      try {
        final record =
            ConsentRecord.fromJson(Map<String, dynamic>.from(value));
        if (record.purpose == purpose) {
          if (latest == null || record.timestamp.isAfter(latest.timestamp)) {
            latest = record;
          }
        }
      } catch (_) {
        // Skip malformed records.
      }
    }
    return latest;
  }

  /// Get all consent records, optionally filtered by purpose.
  List<ConsentRecord> getAllRecords({ConsentPurpose? purpose}) {
    if (_box == null) return [];

    final records = <ConsentRecord>[];
    for (final value in _box!.values) {
      try {
        final record =
            ConsentRecord.fromJson(Map<String, dynamic>.from(value));
        if (purpose == null || record.purpose == purpose) {
          records.add(record);
        }
      } catch (_) {
        // Skip malformed records.
      }
    }
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  /// Clear all consent records.
  Future<void> clear() async {
    await _box?.clear();
  }
}
