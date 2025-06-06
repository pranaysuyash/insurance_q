import 'dart:convert';

class PolicyHolder {
  final String name;
  final String? dob;
  final String relationship;

  PolicyHolder({
    required this.name,
    this.dob,
    required this.relationship,
  });

  factory PolicyHolder.fromJson(Map<String, dynamic> json) {
    return PolicyHolder(
      name: json['name'] ?? 'Unknown',
      dob: json['dob'],
      relationship: json['relationship'] ?? 'Insured',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dob': dob,
      'relationship': relationship,
    };
  }
}

class InsuranceDocument {
  final String id;
  final String filename;
  final DateTime uploadedOn;
  final String? documentType;
  final String? insurer;
  final String? status;
  final DateTime? processingCompletedAt;
  final int? size;
  final String? localFilePath; // Path to locally stored file
  final List<PolicyHolder>? policyHolders; // New field for policy holders

  InsuranceDocument({
    required this.id,
    required this.filename,
    required this.uploadedOn,
    this.documentType,
    this.insurer,
    this.status = 'completed',
    this.processingCompletedAt,
    this.size,
    this.localFilePath,
    this.policyHolders,
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
      id: json['id'] ?? '',
      filename: json['filename'] ?? '',
      uploadedOn: json['upload_date'] != null 
          ? DateTime.parse(json['upload_date']) 
          : DateTime.now(),
      documentType: json['document_type'],
      insurer: json['insurer'],
      status: json['status'] ?? 'completed',
      processingCompletedAt: json['processing_completed_at'] != null 
          ? DateTime.parse(json['processing_completed_at']) 
          : null,
      size: json['size'],
      localFilePath: json['local_file_path'],
      policyHolders: holders,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'upload_date': uploadedOn.toIso8601String(),
      'document_type': documentType,
      'insurer': insurer,
      'status': status,
      'processing_completed_at': processingCompletedAt?.toIso8601String(),
      'size': size,
      'local_file_path': localFilePath,
      'policy_holders': policyHolders?.map((holder) => holder.toJson()).toList(),
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
} 