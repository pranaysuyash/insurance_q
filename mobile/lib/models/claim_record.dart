import 'dart:convert';

/// A user-maintained insurance claim-log record, tracked locally.
///
/// This is not connected to any insurer system — it's a personal log the user
/// keeps to track what they report having filed, with whom, and the status they
/// record. It is not an insurer feed or a claim decision.
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
  }) : statusHistory = statusHistory ??
            [StatusUpdate(status: ClaimStatus.filed, timestamp: filedDate)];

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
      status: latestEntry?.status ??
          ClaimStatus.values.firstWhere(
            (s) => s.name == json['status'],
            orElse: () => ClaimStatus.filed,
          ),
      notes: json['notes'],
      photoPaths: json['photo_paths'] != null
          ? List<String>.from(json['photo_paths'] as List)
          : const [],
      statusHistory: statusHistory,
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
        'status': status.name,
        'notes': notes,
        if (photoPaths.isNotEmpty) 'photo_paths': photoPaths,
        if (statusHistory.isNotEmpty)
          'status_history': statusHistory.map((u) => u.toJson()).toList(),
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
    );
  }
}

/// A single status change event in a claim's lifecycle.
class StatusUpdate {
  final ClaimStatus status;
  final DateTime timestamp;

  const StatusUpdate({required this.status, required this.timestamp});

  factory StatusUpdate.fromJson(Map<String, dynamic> json) => StatusUpdate(
        status: ClaimStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ClaimStatus.filed,
        ),
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'status': status.name,
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

extension ClaimStatusX on ClaimStatus {
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
