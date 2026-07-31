import 'dart:async';
import 'package:hive/hive.dart';

/// The purpose for which consent was granted or revoked.
enum ConsentPurpose {
  /// Core document processing — OCR, extraction, RAG indexing.
  documentProcessing('document_processing'),

  /// Analytics and usage tracking.
  analytics('analytics'),

  /// Marketing and lead capture emails.
  marketingEmails('marketing_emails'),

  /// Terms of Service and Privacy Policy acceptance.
  ///
  /// Audit 5 P1.2: This purpose tracks which privacy policy version the
  /// user has accepted. It is NOT a data-processing consent — it records
  /// acknowledgment of the policy document itself. Document-processing
  /// consent is tracked separately via [documentProcessing].
  ///
  /// The relationship between these two purposes:
  /// - `privacyPolicy`: "I have read and accept the privacy policy"
  /// - `documentProcessing`: "I authorize CoverWise to process my documents"
  ///
  /// When the privacy policy version changes, the old `documentProcessing`
  /// consent becomes stale (the user consented under an old policy). The
  /// UI must re-prompt for `documentProcessing` consent using the new
  /// policy version, but `privacyPolicy` acceptance is a separate record.
  privacyPolicy('privacy_policy'),

  /// Camera access for page capture.
  cameraAccess('camera_access'),

  /// Consent to store processed documents in evaluation datasets.
  evaluationDataset('evaluation_dataset'),

  /// Consent to use documents for model improvements.
  modelImprovement('model_improvement');

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

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'purpose': purpose.value,
      'version': version,
      'granted': granted,
      'timestamp': timestamp.toIso8601String(),
    };
    if (revokedAt != null) {
      map['revoked_at'] = revokedAt!.toIso8601String();
    }
    return map;
  }

  /// Construct from a persisted JSON map.
  ///
  /// P0.15: Unknown or missing purposes are rejected rather than silently
  /// defaulting to [ConsentPurpose.documentProcessing]. Malformed timestamps
  /// also throw to prevent corrupt records from becoming authoritative.
  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    final purposeStr = json['purpose'] as String?;
    if (purposeStr == null || purposeStr.isEmpty) {
      throw FormatException('ConsentRecord: missing purpose field');
    }
    final purpose = ConsentPurpose.fromString(purposeStr);
    if (purpose == null) {
      throw FormatException(
        'ConsentRecord: unknown purpose "$purposeStr"',
      );
    }
    final timestampStr = json['timestamp'] as String?;
    if (timestampStr == null || timestampStr.isEmpty) {
      throw FormatException('ConsentRecord: missing timestamp field');
    }
    final timestamp = DateTime.tryParse(timestampStr);
    if (timestamp == null) {
      throw FormatException(
        'ConsentRecord: invalid timestamp "$timestampStr"',
      );
    }
    return ConsentRecord(
      purpose: purpose,
      version: json['version'] as String? ?? 'unknown',
      granted: json['granted'] as bool? ?? false,
      timestamp: timestamp,
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
///
/// Audit 5 P1.1: Consent is coarse — boolean per [ConsentPurpose] with no
/// document-level, field-level, or retention-period scoping. This is
/// intentional for the MVP launch boundary:
///
/// **Architectural boundary:**
/// - The backend server enforces document-level and field-level access
///   controls independently (the client cannot be the authority).
/// - The consent ledger is a local pre-flight gate: "has the user
///   granted permission for this category of data egress?" — not the
///   authoritative policy store.
/// - Finer-grained scoping (per-document consent, per-field redaction,
///   per-retention TTL) requires a backend API contract change and a
///   new ADR before the client can implement it.
///
/// **What would need to change for per-document consent:**
/// 1. Backend defines a `document_consent` table with (user_id, document_id,
///    purpose, granted, expires_at, policy_version).
/// 2. An ADR records the scoping contract and the client's role.
/// 3. The client adds a DocumentConsentGate that reads from the backend
///    (with local cache for offline) before each data-egress boundary.
/// 4. The ConsentLedger retains coarse purpose-level consent as a local
///    fallback when the backend is unreachable.
///
/// **Why the client cannot be the authority for fine-grained consent:**
/// - The client can be tampered with; the server cannot trust client-side
///   consent claims for data-access decisions.
/// - Offline consent grants must still be verifiable by the server before
///   processing begins.
/// - Cross-device consent synchronization requires server-side state.
///
/// Until then, this coarse per-purpose ledger is the correct design:
/// it gates every data-egress boundary (upload, analytics, marketing)
/// with a single boolean per purpose, and the backend independently
/// verifies consent at processing time.
class ConsentLedger {
  static const String _boxName = 'consent_ledger';

  /// Audit 5 P1.3: A broadcast stream that emits after every consent
  /// mutation (grant or revocation). Consumers can listen to react to
  /// consent changes without manual polling via [refreshConsentCache].
  static final StreamController<List<ConsentRecord>> _consentChangesController =
      StreamController<List<ConsentRecord>>.broadcast();

  /// Stream of consent state snapshots. Emits the full record list after
  /// every [recordConsent] or [revokeConsent] call.
  static Stream<List<ConsentRecord>> get consentChanges =>
      _consentChangesController.stream;

  Box<dynamic>? get _box {
    try {
      return Hive.box<dynamic>(_boxName);
    } catch (_) {
      return null;
    }
  }

  /// The underlying Hive box, or null when the workspace is not open.
  Box<dynamic> get _requiredBox {
    final box = _box;
    if (box == null) {
      throw StateError(
        'ConsentLedger: Hive box "$_boxName" is not open. '
        'Consent records cannot be written before workspace activation.',
      );
    }
    return box;
  }

  /// Record a consent grant or revocation.
  ///
  /// P0.14: Throws [StateError] when the Hive box is unavailable so that
  /// callers cannot silently believe consent was recorded when it was not.
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
    await _requiredBox.add(record.toJson());
    _emitConsentChange();
  }

  /// Revoke consent for a given purpose by marking the latest active record
  /// as revoked.
  Future<void> revokeConsent(ConsentPurpose purpose) async {
    final latest = getLatestRecord(purpose);
    if (latest == null || latest.isRevoked) return;

    final revokedAt = DateTime.now();
    final revokedRecord = ConsentRecord(
      purpose: latest.purpose,
      version: latest.version,
      granted: false,
      timestamp: revokedAt,
      revokedAt: revokedAt,
    );
    await _requiredBox.add(revokedRecord.toJson());
    _emitConsentChange();
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
          // Ledger insertion order is authoritative when records share a
          // timestamp (which is common in fast grant/revoke/re-grant flows).
          if (latest == null || !record.timestamp.isBefore(latest.timestamp)) {
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

  /// Whether the current privacy policy version has been accepted.
  ///
  /// Compares the accepted version in the ledger against [expectedVersion].
  /// Returns `true` only when the latest `privacyPolicy` record matches
  /// [expectedVersion] and is active (not revoked).
  bool isPrivacyPolicyAccepted(String expectedVersion) {
    final record = getLatestRecord(ConsentPurpose.privacyPolicy);
    return record?.isActive == true && record?.version == expectedVersion;
  }

  /// Record acceptance of the current privacy policy version.
  Future<void> recordPolicyAcceptance({
    required String version,
    bool granted = true,
  }) async {
    await recordConsent(
      purpose: ConsentPurpose.privacyPolicy,
      version: version,
      granted: granted,
    );
  }

  /// Clear all consent records.
  ///
  /// P0.14: Uses [_requiredBox] so the operation fails visibly when the
  /// Hive box is unavailable, consistent with [recordConsent].
  Future<void> clear() async {
    await _requiredBox.clear();
    _emitConsentChange();
  }

  /// Audit 5 P1.3: Emit current consent state to all stream listeners.
  void _emitConsentChange() {
    if (!_consentChangesController.isClosed) {
      _consentChangesController.add(getAllRecords());
    }
  }
}
