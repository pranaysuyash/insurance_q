import 'dart:convert';

/// A user-initiated insurance claim record, tracked locally.
///
/// This is not connected to any insurer system — it's a personal log the user
/// keeps to track what claims they've filed, with whom, and what the status is.
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
  });

  factory ClaimRecord.fromJson(Map<String, dynamic> json) => ClaimRecord(
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
        status: ClaimStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ClaimStatus.filed,
        ),
        notes: json['notes'],
      );

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
      };

  String toJsonString() => jsonEncode(toJson());

  factory ClaimRecord.fromJsonString(String s) =>
      ClaimRecord.fromJson(jsonDecode(s));

  ClaimRecord copyWith({
    String? referenceNumber,
    ClaimStatus? status,
    String? notes,
  }) =>
      ClaimRecord(
        id: id,
        documentId: documentId,
        policyType: policyType,
        insurer: insurer,
        incidentType: incidentType,
        description: description,
        filedDate: filedDate,
        referenceNumber: referenceNumber ?? this.referenceNumber,
        status: status ?? this.status,
        notes: notes ?? this.notes,
      );
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
        return 'Filed';
      case ClaimStatus.inReview:
        return 'In Review';
      case ClaimStatus.approved:
        return 'Approved';
      case ClaimStatus.rejected:
        return 'Rejected';
      case ClaimStatus.paid:
        return 'Paid';
    }
  }
}
