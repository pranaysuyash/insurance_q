import 'package:flutter/material.dart';
import 'dart:convert';

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
  });

  factory InsuranceDocument.fromJson(Map<String, dynamic> json) {
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