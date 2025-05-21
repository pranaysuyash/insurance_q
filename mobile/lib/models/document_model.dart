class InsuranceDocument {
  final String id;
  final String filename;
  final DateTime uploadedOn;
  final DateTime? analyzedOn;
  final String? documentType;
  final int? pageCount;
  final int? fileSize; // in bytes
  
  InsuranceDocument({
    required this.id,
    required this.filename,
    required this.uploadedOn,
    this.analyzedOn,
    this.documentType,
    this.pageCount,
    this.fileSize,
  });
  
  factory InsuranceDocument.fromJson(Map<String, dynamic> json) {
    return InsuranceDocument(
      id: json['id'] ?? '',
      filename: json['filename'] ?? '',
      uploadedOn: json['upload_date'] != null 
          ? DateTime.parse(json['upload_date']) 
          : DateTime.now(),
      analyzedOn: json['analyzed_on'] != null 
          ? DateTime.parse(json['analyzed_on']) 
          : null,
      documentType: json['type'],
      pageCount: json['page_count'],
      fileSize: json['file_size'],
    );
  }
  
  String get formattedUploadDate {
    return '${uploadedOn.day}/${uploadedOn.month}/${uploadedOn.year}';
  }
  
  String get formattedAnalyzedDate {
    return analyzedOn != null 
        ? '${analyzedOn!.day}/${analyzedOn!.month}/${analyzedOn!.year}'
        : 'Not analyzed';
  }
  
  String get formattedFileSize {
    if (fileSize == null) return 'Unknown';
    
    if (fileSize! < 1024) {
      return '$fileSize B';
    } else if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
} 