import 'dart:convert';

/// A user-maintained insurance claim-log record, tracked locally.
///
/// This is not connected to any insurer system — it's a personal log the user
/// keeps to track what they report having filed, with whom, and the status they
/// record. It is not an insurer feed or a claim decision.
///
/// Audit 6 P0.5: Added [remoteId], [syncState], and [updatedAt] fields to
/// support proper synchronization identity, revisions, and tombstone tracking.
/// - [remoteId]: The server-assigned UUID for this claim. Null when the claim
///   has never been pushed. Never repurposed as a user-visible reference number.
/// - [syncState]: Tracks whether the claim is local-only, pending push, or
///   synced to the server. Replaces the heuristic of checking referenceNumber.
/// - [updatedAt]: The last time this record was modified locally or received
///   from the server. Used for conflict resolution in pull-from-backend.
class ClaimRecord {
  final String id;
  final String documentId;
  final String policyType;
  final String insurer;
  final String incidentType;
  final String description;
  final DateTime filedDate;
  final String? referenceNumber;
  final ClaimStatus status;
  final String? notes;
  final List<String> photoPaths;
  final List<StatusUpdate> statusHistory;

  /// Audit 6 P0.5: Server-assigned UUID. Null when never pushed.
  final String? remoteId;

  /// Audit 6 P0.5: Synchronization state for this claim.
  final ClaimSyncState syncState;

  /// Audit 6 P0.5: Last modification timestamp (local or server).
  /// Used for conflict resolution in pull-from-backend.
  final DateTime updatedAt;

  ClaimRecord({
    required this.id,
    required this.documentId,
    required this.policyType,
    required this.insurer,
    required this.incidentType,
    required this.description,
    required this.filedDate,
    this.referenceNumber,
    this.status = ClaimStatus.filed,
    this.notes,
    this.photoPaths = const [],
    List<StatusUpdate>? statusHistory,
    this.remoteId,
    this.syncState = ClaimSyncState.local,
    DateTime? updatedAt,
  })  : statusHistory = statusHistory ??
            [StatusUpdate(status: ClaimStatus.filed, timestamp: filedDate)],
        updatedAt = updatedAt ?? DateTime.now();

  factory ClaimRecord.fromJson(Map<String, dynamic> json) {
    final statusHistoryRaw = json['status_history'];
    final statusHistory = statusHistoryRaw is List
        ? statusHistoryRaw
            .map((item) => StatusUpdate.fromJson(item as Map<String, dynamic>))
            .toList()
        : <StatusUpdate>[];

    // Infer the current status from the most recent history entry.
    final latestEntry = statusHistory.isNotEmpty
        ? statusHistory.reduce(
            (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
          )
        : null;

    // Audit 6 P0.5: Parse remoteId, syncState, and updatedAt.
    // For backward compatibility with old Hive data that lacks these fields:
    // - remoteId defaults to null (never pushed)
    // - syncState defaults to local (never pushed)
    // - updatedAt defaults to filedDate so old records don't appear newer
    //   than server versions during merge
    final updatedAtStr = json['updated_at'] as String?;
    final filedDate = json['filed_date'] != null
        ? DateTime.parse(json['filed_date'])
        : DateTime.now();

    return ClaimRecord(
      id: json['id'] ?? '',
      documentId: json['document_id'] ?? '',
      policyType: json['policy_type'] ?? 'Unknown',
      insurer: json['insurer'] ?? 'Unknown',
      incidentType: json['incident_type'] ?? 'Other',
      description: json['description'] ?? '',
      filedDate: json['filed_date'] != null
          ? DateTime.parse(json['filed_date'])
          : DateTime.now(),
      referenceNumber: json['reference_number'],
      // 7-P0.8: Use wire mapping to parse backend status values.
      // The backend sends 'in_review' (snake_case), not 'inReview' (camelCase).
      status: latestEntry?.status ??
          ClaimStatusX.fromWire(json['status'] as String?),
      notes: json['notes'],
      photoPaths: json['photo_paths'] != null
          ? List<String>.from(json['photo_paths'] as List)
          : const [],
      statusHistory: statusHistory,
      remoteId: json['remote_id'] as String?,
      syncState: ClaimSyncStateX.fromWire(json['sync_state'] as String?),
      updatedAt: updatedAtStr != null
          ? (DateTime.tryParse(updatedAtStr) ?? filedDate)
          : filedDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'document_id': documentId,
        'policy_type': policyType,
        'insurer': insurer,
        'incident_type': incidentType,
        'description': description,
        'filed_date': filedDate.toIso8601String(),
        'reference_number': referenceNumber,
        // 7-P0.8: Use wireValue for backend compatibility.
        // Backend sends/accepts 'in_review' (snake_case), not 'inReview'.
        'status': status.wireValue,
        'notes': notes,
        if (photoPaths.isNotEmpty) 'photo_paths': photoPaths,
        if (statusHistory.isNotEmpty)
          'status_history': statusHistory.map((u) => u.toJson()).toList(),
        // Audit 6 P0.5: Serialize new sync identity fields.
        'remote_id': remoteId,
        'sync_state': syncState.wireValue,
        'updated_at': updatedAt.toIso8601String(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory ClaimRecord.fromJsonString(String s) =>
      ClaimRecord.fromJson(jsonDecode(s));

  ClaimRecord copyWith({
    String? id,
    String? documentId,
    String? policyType,
    String? insurer,
    String? incidentType,
    String? description,
    DateTime? filedDate,
    String? referenceNumber,
    ClaimStatus? status,
    String? notes,
    List<String>? photoPaths,
    List<StatusUpdate>? statusHistory,
    String? remoteId,
    ClaimSyncState? syncState,
    DateTime? updatedAt,
  }) =>
      ClaimRecord(
        id: id ?? this.id,
        documentId: documentId ?? this.documentId,
        policyType: policyType ?? this.policyType,
        insurer: insurer ?? this.insurer,
        incidentType: incidentType ?? this.incidentType,
        description: description ?? this.description,
        filedDate: filedDate ?? this.filedDate,
        referenceNumber: referenceNumber ?? this.referenceNumber,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        photoPaths: photoPaths ?? this.photoPaths,
        statusHistory: statusHistory ?? this.statusHistory,
        remoteId: remoteId ?? this.remoteId,
        syncState: syncState ?? this.syncState,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Appends a user-reported status update and returns a new record.
  ClaimRecord withStatusUpdate(ClaimStatus newStatus) {
    final updatedHistory = [
      ...statusHistory,
      StatusUpdate(status: newStatus, timestamp: DateTime.now()),
    ];
    return ClaimRecord(
      id: id,
      documentId: documentId,
      policyType: policyType,
      insurer: insurer,
      incidentType: incidentType,
      description: description,
      filedDate: filedDate,
      referenceNumber: referenceNumber,
      status: newStatus,
      notes: notes,
      photoPaths: photoPaths,
      statusHistory: updatedHistory,
      remoteId: remoteId,
      // A local status edit marks the claim as needing re-sync,
      // but only if it was previously synced or pending.
      syncState: syncState == ClaimSyncState.local
          ? ClaimSyncState.local
          : ClaimSyncState.modified,
      updatedAt: DateTime.now(),
    );
  }
}

/// A single status change event in a claim's lifecycle.
class StatusUpdate {
  final ClaimStatus status;
  final DateTime timestamp;

  const StatusUpdate({required this.status, required this.timestamp});

  factory StatusUpdate.fromJson(Map<String, dynamic> json) => StatusUpdate(
        // 7-P0.8: Use wire mapping for backend status values.
        status: ClaimStatusX.fromWire(json['status'] as String?),
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        // 7-P0.8: Use wireValue for backend compatibility.
        'status': status.wireValue,
        'timestamp': timestamp.toIso8601String(),
      };
}

enum ClaimStatus {
  filed,
  inReview,
  approved,
  rejected,
  paid,
}

/// 7-P0.8: Wire mapping between Dart enum names and the backend's
/// snake_case API values. Never use enum source names as API contracts —
/// `inReview.name` produces `inReview`, but the backend sends `in_review`.
extension ClaimStatusX on ClaimStatus {
  /// The snake_case value sent to / received from the backend API.
  String get wireValue => switch (this) {
    ClaimStatus.filed => 'filed',
    ClaimStatus.inReview => 'in_review',
    ClaimStatus.approved => 'approved',
    ClaimStatus.rejected => 'rejected',
    ClaimStatus.paid => 'paid',
  };

  /// Parse a wire-format string from the backend into a [ClaimStatus].
  /// Falls back to [ClaimStatus.filed] for unknown values.
  static ClaimStatus fromWire(String? value) {
    if (value == null) return ClaimStatus.filed;
    for (final s in ClaimStatus.values) {
      if (s.wireValue == value) return s;
    }
    return ClaimStatus.filed;
  }

  String get label {
    switch (this) {
      case ClaimStatus.filed:
        return 'Self-recorded: filed';
      case ClaimStatus.inReview:
        return 'Self-recorded: in review';
      case ClaimStatus.approved:
        return 'Self-recorded: approved';
      case ClaimStatus.rejected:
        return 'Self-recorded: rejected';
      case ClaimStatus.paid:
        return 'Self-recorded: paid';
    }
  }
}

/// Audit 6 P0.5: Synchronization state for a [ClaimRecord].
///
/// Replaces the heuristic of checking `referenceNumber != null` to
/// determine whether a claim has been pushed to the server. Each state
/// has a clear semantic meaning:
/// - [local]: Never pushed. Safe to delete locally.
/// - [pending]: Push requested, awaiting server confirmation.
/// - [synced]: Server confirmed receipt. Server may have assigned a [remoteId].
/// - [modified]: Local edit after last sync. Needs re-push.
enum ClaimSyncState {
  /// Never pushed to the server.
  local,

  /// Push in progress or queued.
  pending,

  /// Server confirmed receipt.
  synced,

  /// Locally modified after last sync; needs re-push.
  modified,
}

extension ClaimSyncStateX on ClaimSyncState {
  String get wireValue => switch (this) {
    ClaimSyncState.local => 'local',
    ClaimSyncState.pending => 'pending',
    ClaimSyncState.synced => 'synced',
    ClaimSyncState.modified => 'modified',
  };

  static ClaimSyncState fromWire(String? value) {
    if (value == null) return ClaimSyncState.local;
    for (final s in ClaimSyncState.values) {
      if (s.wireValue == value) return s;
    }
    return ClaimSyncState.local;
  }
}
