import 'dart:convert';

class PolicyHolder {
  final String name;
  final String? dob;
  final String relationship;

  /// Where this member came from.
  ///
  /// - `'document'`: auto-detected from an uploaded policy. Cannot be deleted
  ///   directly (remove the document instead).
  /// - `'manual'`: added by the user, e.g. a dependent who has their own
  ///   separate policy and isn't named in any uploaded document. Can be
  ///   edited/deleted by the user.
  ///
  /// Defaults to `'document'` for backward compatibility with members parsed
  /// from existing documents and backend responses.
  final String source;

  PolicyHolder({
    required this.name,
    this.dob,
    required this.relationship,
    this.source = 'document',
  });

  factory PolicyHolder.fromJson(Map<String, dynamic> json) {
    return PolicyHolder(
      name: json['name'] ?? 'Unknown',
      dob: json['dob'],
      relationship: json['relationship'] ?? 'Insured',
      source: json['source'] ?? 'document',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dob': dob,
      'relationship': relationship,
      'source': source,
    };
  }

  bool get isManual => source == 'manual';
}

class InsuranceDocument {
  final String id;
  final String? remoteId;
  final String filename;
  final DateTime uploadedOn;
  final String? documentType;
  final String? insurer;
  final String? status;
  final String syncState;
  final String processingState;
  final String? processingConsentVersion;
  final int schemaVersion;
  final DateTime? processingCompletedAt;
  final int? size;
  final String? localFilePath; // Path to locally stored file
  final List<PolicyHolder>? policyHolders;
  final bool isArchived;
  final DateTime? archivedAt;

  InsuranceDocument({
    required this.id,
    this.remoteId,
    required this.filename,
    required this.uploadedOn,
    this.documentType,
    this.insurer,
    this.status = 'completed',
    this.syncState = 'synced',
    this.processingState = 'ready',
    this.processingConsentVersion,
    this.schemaVersion = 1,
    this.processingCompletedAt,
    this.size,
    this.localFilePath,
    this.policyHolders,
    this.isArchived = false,
    this.archivedAt,
  });

  factory InsuranceDocument.fromJson(Map<String, dynamic> json) {
    // Parse policy holders if available
    List<PolicyHolder>? holders;
    if (json['policy_holders'] != null && json['policy_holders'] is List) {
      holders = (json['policy_holders'] as List)
          .map((holder) => PolicyHolder.fromJson(holder))
          .toList();
    }

    return InsuranceDocument(
      id: json['local_id'] ?? json['id'] ?? '',
      remoteId: json['remote_id'] ?? json['document_id'],
      filename: json['filename'] ?? '',
      uploadedOn: json['upload_date'] != null
          ? DateTime.parse(json['upload_date'])
          : DateTime.now(),
      documentType: json['document_type'],
      insurer: json['insurer'],
      status: json['status'] ?? 'completed',
      syncState: json['sync_state'] ?? 'synced',
      processingState: json['processing_state'] ?? json['status'] ?? 'ready',
      processingConsentVersion: json['processing_consent_version'],
      schemaVersion: json['schema_version'] ?? 1,
      processingCompletedAt: json['processing_completed_at'] != null
          ? DateTime.parse(json['processing_completed_at'])
          : null,
      size: json['size'],
      localFilePath: json['local_file_path'],
      policyHolders: holders,
      isArchived: json['is_archived'] == true,
      archivedAt: json['archived_at'] != null
          ? DateTime.tryParse(json['archived_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'local_id': id,
      'remote_id': remoteId,
      'filename': filename,
      'upload_date': uploadedOn.toIso8601String(),
      'document_type': documentType,
      'insurer': insurer,
      'status': status,
      'sync_state': syncState,
      'processing_state': processingState,
      'processing_consent_version': processingConsentVersion,
      'schema_version': schemaVersion,
      'processing_completed_at': processingCompletedAt?.toIso8601String(),
      'size': size,
      'local_file_path': localFilePath,
      'policy_holders':
          policyHolders?.map((holder) => holder.toJson()).toList(),
      'is_archived': isArchived,
      if (archivedAt != null) 'archived_at': archivedAt!.toIso8601String(),
    };
  }

  // Convenience method to create a JSON string
  String toJsonString() => jsonEncode(toJson());

  // Convenience factory to create from a JSON string
  factory InsuranceDocument.fromJsonString(String jsonString) {
    return InsuranceDocument.fromJson(jsonDecode(jsonString));
  }

  String get formattedUploadDate {
    return '${uploadedOn.day}/${uploadedOn.month}/${uploadedOn.year}';
  }

  String get formattedAnalyzedDate {
    return processingCompletedAt != null
        ? '${processingCompletedAt!.day}/${processingCompletedAt!.month}/${processingCompletedAt!.year}'
        : 'Not analyzed';
  }

  String get formattedFileSize {
    if (size == null) return 'Unknown';

    if (size! < 1024) {
      return '$size B';
    } else if (size! < 1024 * 1024) {
      return '${(size! / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get backendId => remoteId ?? id;

  bool get isSynced => remoteId != null && syncState == 'synced';

  /// Sentinel used by [copyWith] to distinguish "not provided" from
  /// "explicitly set to null". Without this sentinel, callers could never
  /// clear a nullable field because `null ?? existingValue` returns the
  /// existing value.
  static const _copyWithSentinel = Object();

  InsuranceDocument copyWith({
    Object? remoteId = _copyWithSentinel,
    Object? documentType = _copyWithSentinel,
    Object? insurer = _copyWithSentinel,
    Object? status = _copyWithSentinel,
    String? syncState,
    String? processingState,
    Object? processingConsentVersion = _copyWithSentinel,
    Object? processingCompletedAt = _copyWithSentinel,
    bool? isArchived,
    Object? archivedAt = _copyWithSentinel,
    Object? size = _copyWithSentinel,
    Object? localFilePath = _copyWithSentinel,
    Object? policyHolders = _copyWithSentinel,
  }) {
    return InsuranceDocument(
      id: id,
      remoteId: identical(remoteId, _copyWithSentinel)
          ? this.remoteId
          : remoteId as String?,
      filename: filename,
      uploadedOn: uploadedOn,
      documentType: identical(documentType, _copyWithSentinel)
          ? this.documentType
          : documentType as String?,
      insurer: identical(insurer, _copyWithSentinel)
          ? this.insurer
          : insurer as String?,
      status: identical(status, _copyWithSentinel)
          ? this.status
          : status as String?,
      syncState: syncState ?? this.syncState,
      processingState: processingState ?? this.processingState,
      processingConsentVersion:
          identical(processingConsentVersion, _copyWithSentinel)
              ? this.processingConsentVersion
              : processingConsentVersion as String?,
      schemaVersion: schemaVersion,
      processingCompletedAt:
          identical(processingCompletedAt, _copyWithSentinel)
              ? this.processingCompletedAt
              : processingCompletedAt as DateTime?,
      size: identical(size, _copyWithSentinel) ? this.size : size as int?,
      localFilePath: identical(localFilePath, _copyWithSentinel)
          ? this.localFilePath
          : localFilePath as String?,
      policyHolders: identical(policyHolders, _copyWithSentinel)
          ? this.policyHolders
          : policyHolders as List<PolicyHolder>?,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: identical(archivedAt, _copyWithSentinel)
          ? this.archivedAt
          : archivedAt as DateTime?,
    );
  }
}
