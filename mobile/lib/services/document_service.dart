import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import 'local_storage_service.dart';
import 'session_service.dart';
import 'app_state_repository.dart';
import 'ml_ocr_service.dart';

class DocumentService {
  final Dio _dio;
  final LocalStorageService _localStorageService = LocalStorageService();

  DocumentService(this._dio);

  Future<Map<String, dynamic>> uploadFile(File file,
      {String? email, String? phone, String? pdfPassword}) async {
    try {
      final sessionId = await SessionService.getSessionId();

      try {
        final formData = FormData.fromMap({
          'files': await MultipartFile.fromFile(file.path),
          'processing_mode': 'full',
          if (pdfPassword != null && pdfPassword.trim().isNotEmpty)
            'pdf_password': pdfPassword,
          if (email != null) 'user_email': email,
          if (phone != null) 'user_phone': phone,
          'consent': true,
        });

        final response = await _dio.post(
          '/documents/upload',
          data: formData,
          options: Options(
            headers: {'X-Session-ID': sessionId},
            contentType: 'multipart/form-data',
          ),
        );

        if (response.statusCode == 202 || response.statusCode == 200) {
          final responseData = response.data;
          final documents = responseData['documents'] as List<dynamic>?;
          final firstDoc = (documents != null && documents.isNotEmpty)
              ? documents[0] as Map<String, dynamic>?
              : null;

          String documentType =
              firstDoc?['document_type'] ?? _inferDocumentType(file.path);
          String insurer =
              firstDoc?['insurer'] ?? _inferInsurerInfo(file.path)['insurer'];

          final documentId = firstDoc?['id'] ?? firstDoc?['processing_id'];

          if (firstDoc?['document_type'] != null) {
            documentType = firstDoc!['document_type'];
          }

          final baseDocument = {
            'document_type': documentType,
            'insurer': insurer,
          };

          final savedDocument = await _localStorageService.saveDocument(
            file,
            additionalMetadata: baseDocument,
            remoteId: documentId?.toString(),
            syncState: 'synced',
            processingState: firstDoc?['status']?.toString() ?? 'ready',
            status: firstDoc?['status']?.toString() ?? 'completed',
          );
          await AppStateRepository.setLastUploadedDocumentId(savedDocument.id);

          return {
            ...responseData,
            if (documentId != null) 'document_id': documentId,
            'document_type': documentType,
            'insurer': insurer,
          };
        } else if (response.statusCode == 429) {
          final errorData = response.data;
          return {
            'error': 'rate_limit_exceeded',
            'message': errorData['detail'] ??
                'Upload limit exceeded. Please try again later.',
            'retry_after': errorData['retry_after'],
          };
        } else {
          throw DioException(
            requestOptions: RequestOptions(path: '/documents/upload'),
            response: response,
            type: DioExceptionType.badResponse,
          );
        }
      } catch (e) {
        debugPrint('Backend upload failed, falling back to local storage: $e');

        if (e is DioException && e.response?.statusCode == 429) {
          final errorData = e.response?.data;
          return {
            'error': 'rate_limit_exceeded',
            'message': errorData?['detail'] ??
                'Upload limit exceeded. Please try again later.',
            'retry_after': errorData?['retry_after'],
          };
        }

        if (e is DioException && e.response?.statusCode == 422) {
          final detail = e.response?.data is Map
              ? (e.response?.data as Map)['detail']
              : null;
          if (detail is Map && detail['code'] != null) {
            return {
              'error': detail['code'].toString(),
              'message': detail['message']?.toString() ??
                  'This document could not be opened.',
            };
          }
        }

        final documentType = _inferDocumentType(file.path);
        final insurerInfo = _inferInsurerInfo(file.path);

        final baseDocument = {
          'document_type': documentType,
          'insurer': insurerInfo['insurer'],
        };

        final document = await _localStorageService.saveDocument(
          file,
          additionalMetadata: baseDocument,
          syncState: 'pending_upload',
          processingState: 'pending',
          status: 'pending',
        );
        await AppStateRepository.setLastUploadedDocumentId(document.id);

        return {
          'message': 'File saved locally; sync pending',
          'document_id': document.id,
          'document_type': documentType,
          'insurer': insurerInfo['insurer'],
          'status': 'pending_upload',
          'sync_state': 'pending_upload',
          'offline_mode': true,
        };
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return {'error': e.toString()};
    }
  }

  String _inferDocumentType(String filePath) {
    final fileName = filePath.toLowerCase();
    if (fileName.contains('health') || fileName.contains('medical')) {
      return 'Health Insurance';
    } else if (fileName.contains('auto') ||
        fileName.contains('car') ||
        fileName.contains('vehicle')) {
      return 'Auto Insurance';
    } else if (fileName.contains('home') ||
        fileName.contains('property') ||
        fileName.contains('house')) {
      return 'Home Insurance';
    } else if (fileName.contains('life')) {
      return 'Life Insurance';
    } else {
      return 'Insurance Policy';
    }
  }

  Map<String, dynamic> _inferInsurerInfo(String filePath) {
    final fileName = filePath.toLowerCase();
    const insurers = [
      'Aetna',
      'Anthem',
      'Blue Cross',
      'Blue Shield',
      'Cigna',
      'UnitedHealth',
      'Humana',
      'Kaiser',
      'MetLife',
      'Prudential',
      'State Farm',
      'Allstate',
      'Geico',
      'Progressive',
      'Farmers',
      'Liberty Mutual',
      'Nationwide',
      'Travelers',
      'USAA',
      'New York Life',
      'Northwestern Mutual'
    ];

    for (final company in insurers) {
      if (fileName.contains(company.toLowerCase())) {
        return {'insurer': company};
      }
    }
    return {'insurer': 'Unknown'};
  }

  Future<Map<String, dynamic>> uploadDocument(File file,
      {String? email, String? phone, String? pdfPassword}) {
    return uploadFile(
      file,
      email: email,
      phone: phone,
      pdfPassword: pdfPassword,
    );
  }

  Future<Map<String, dynamic>> uploadWebDocument({
    required String filename,
    required Uint8List bytes,
    String? email,
    String? phone,
    String? pdfPassword,
  }) async {
    try {
      final sessionId = await SessionService.getSessionId();

      try {
        final formData = FormData.fromMap({
          'files': MultipartFile.fromBytes(bytes, filename: filename),
          'processing_mode': 'full',
          if (pdfPassword != null && pdfPassword.trim().isNotEmpty)
            'pdf_password': pdfPassword,
          if (email != null) 'user_email': email,
          if (phone != null) 'user_phone': phone,
          'consent': true,
        });

        final response = await _dio.post(
          '/documents/upload',
          data: formData,
          options: Options(
            headers: {'X-Session-ID': sessionId},
            contentType: 'multipart/form-data',
          ),
        );

        if (response.statusCode == 202 || response.statusCode == 200) {
          final responseData = response.data;
          final documents = responseData['documents'] as List<dynamic>?;
          final firstDoc = (documents != null && documents.isNotEmpty)
              ? documents[0] as Map<String, dynamic>?
              : null;

          String documentType =
              firstDoc?['document_type'] ?? _inferDocumentType(filename);
          String insurer =
              firstDoc?['insurer'] ?? _inferInsurerInfo(filename)['insurer'];
          final documentId = firstDoc?['id'] ?? firstDoc?['processing_id'];

          if (firstDoc?['document_type'] != null) {
            documentType = firstDoc!['document_type'];
          }

          final baseDocument = {
            'document_type': documentType,
            'insurer': insurer,
          };

          final savedDocument = await _localStorageService.saveWebDocument(
            filename,
            bytes,
            additionalMetadata: baseDocument,
            remoteId: documentId?.toString(),
            syncState: 'synced',
            processingState: firstDoc?['status']?.toString() ?? 'ready',
            status: firstDoc?['status']?.toString() ?? 'completed',
          );
          await AppStateRepository.setLastUploadedDocumentId(savedDocument.id);

          return {
            ...responseData,
            if (documentId != null) 'document_id': documentId,
            'document_type': documentType,
            'insurer': insurer,
          };
        } else if (response.statusCode == 429) {
          final errorData = response.data;
          return {
            'error': 'rate_limit_exceeded',
            'message': errorData['detail'] ??
                'Upload limit exceeded. Please try again later.',
            'retry_after': errorData['retry_after'],
          };
        } else {
          throw DioException(
            requestOptions: RequestOptions(path: '/documents/upload'),
            response: response,
            type: DioExceptionType.badResponse,
          );
        }
      } catch (e) {
        debugPrint('Backend upload failed, falling back to local storage: $e');

        if (e is DioException && e.response?.statusCode == 429) {
          final errorData = e.response?.data;
          return {
            'error': 'rate_limit_exceeded',
            'message': errorData?['detail'] ??
                'Upload limit exceeded. Please try again later.',
            'retry_after': errorData?['retry_after'],
          };
        }

        final documentType = _inferDocumentType(filename);
        final insurerInfo = _inferInsurerInfo(filename);
        final baseDocument = {
          'document_type': documentType,
          'insurer': insurerInfo['insurer'],
        };

        final document = await _localStorageService.saveWebDocument(
          filename,
          bytes,
          additionalMetadata: baseDocument,
          syncState: 'pending_upload',
          processingState: 'pending',
          status: 'pending',
        );
        await AppStateRepository.setLastUploadedDocumentId(document.id);

        return {
          'message': 'File saved locally; sync pending',
          'document_id': document.id,
          'document_type': documentType,
          'insurer': insurerInfo['insurer'],
          'status': 'pending_upload',
          'sync_state': 'pending_upload',
          'offline_mode': true,
        };
      }
    } catch (e) {
      debugPrint('Error uploading web file: $e');
      return {'error': e.toString()};
    }
  }

  Future<List<InsuranceDocument>> getDocuments() async {
    try {
      final documents = await _localStorageService.getDocuments();
      final updatedDocuments = <InsuranceDocument>[];

      for (final doc in documents) {
        if (doc.documentType == null || doc.documentType == 'Unknown') {
          final inferredType = await inferDocumentTypeFromContent(doc.id);
          final updatedDoc = InsuranceDocument(
            id: doc.id,
            remoteId: doc.remoteId,
            filename: doc.filename,
            uploadedOn: doc.uploadedOn,
            documentType: inferredType,
            insurer: doc.insurer,
            status: doc.status,
            syncState: doc.syncState,
            processingState: doc.processingState,
            processingCompletedAt: doc.processingCompletedAt,
            size: doc.size,
            localFilePath: doc.localFilePath,
          );
          await _localStorageService.updateDocument(updatedDoc);
          updatedDocuments.add(updatedDoc);
        } else {
          updatedDocuments.add(doc);
        }
      }
      return updatedDocuments;
    } catch (e) {
      debugPrint('Error getting documents: $e');
      rethrow;
    }
  }

  Future<String> inferDocumentTypeFromContent(String documentId) async {
    try {
      debugPrint('Inferring document type for document: $documentId');
      final result = await _queryForType(documentId);
      if (result != null) return result;

      final metadataResult = await _queryForMetadata(documentId);
      if (metadataResult != null) return metadataResult;

      return 'Unknown';
    } catch (e) {
      debugPrint('Error inferring document type: $e');
      return 'Unknown';
    }
  }

  Future<String?> _queryForType(String documentId) async {
    try {
      final sessionId = await SessionService.getSessionId();
      final response = await _dio.post(
        '/query',
        data: {
          'query':
              "What type of insurance policy is this? Please answer with just the type: Health Insurance, Auto Insurance, Home Insurance, Life Insurance, or Other Insurance.",
          'filters': {'document_id': documentId},
        },
        options: Options(
          headers: {'X-Session-ID': sessionId},
          contentType: Headers.jsonContentType,
          validateStatus: (status) => true,
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final answer = response.data['answer']?.toString().toLowerCase() ?? '';
        return _matchTypeFromAnswer(answer);
      }
      return null;
    } catch (e) {
      debugPrint('Error querying document type: $e');
      return null;
    }
  }

  Future<String?> _queryForMetadata(String documentId) async {
    try {
      final sessionId = await SessionService.getSessionId();
      final response = await _dio.post(
        '/query',
        data: {
          'query':
              "What is the name of the insurance company and what type of coverage does this policy provide?",
          'filters': {'document_id': documentId},
        },
        options: Options(
          headers: {'X-Session-ID': sessionId},
          contentType: Headers.jsonContentType,
          validateStatus: (status) => true,
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final answer = response.data['answer']?.toString().toLowerCase() ?? '';
        return _matchTypeFromAnswer(answer);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting document metadata: $e');
      return null;
    }
  }

  String? _matchTypeFromAnswer(String answer) {
    if (answer.contains('health') ||
        answer.contains('medical') ||
        answer.contains('niva bupa') ||
        answer.contains('star health') ||
        answer.contains('apollo munich') ||
        answer.contains('max bupa') ||
        answer.contains('icici lombard') ||
        answer.contains('hdfc ergo') ||
        answer.contains('bajaj allianz') ||
        answer.contains('oriental insurance') ||
        answer.contains('new india assurance') ||
        answer.contains('united india insurance')) {
      return 'Health Insurance';
    }
    if (answer.contains('auto') ||
        answer.contains('car') ||
        answer.contains('vehicle') ||
        answer.contains('motor') ||
        answer.contains('two wheeler') ||
        answer.contains('bike')) {
      return 'Auto Insurance';
    }
    if (answer.contains('home') ||
        answer.contains('property') ||
        answer.contains('house') ||
        answer.contains('fire') ||
        answer.contains('burglary')) {
      return 'Home Insurance';
    }
    if (answer.contains('life') ||
        answer.contains('term') ||
        answer.contains('endowment') ||
        answer.contains('ulip') ||
        answer.contains('pension')) {
      return 'Life Insurance';
    }
    if (answer.contains('travel') || answer.contains('overseas')) {
      return 'Travel Insurance';
    }
    if (answer.contains('insurance')) {
      return 'Insurance Policy';
    }
    return null;
  }

  Future<List<PolicyHolder>> extractPolicyHolders(String documentId) async {
    try {
      final sessionId = await SessionService.getSessionId();
      final result = await _dio.post(
        '/query',
        data: {
          'query':
              "Who are the policy holders and insured individuals in this document? Please provide their names and dates of birth in a structured format.",
          'filters': {'document_id': documentId},
        },
        options: Options(
          headers: {'X-Session-ID': sessionId},
          contentType: Headers.jsonContentType,
          validateStatus: (status) => true,
        ),
      );

      if (result.statusCode == 200 && result.data is Map) {
        final answer = result.data['answer']?.toString() ?? '';
        final holders = _parsePolicyHolders(answer);

        if (holders.isEmpty) {
          debugPrint('No grounded policy holders found for $documentId');
          return [];
        }

        final document = await _localStorageService.getDocumentById(documentId);
        if (document != null) {
          final updatedDoc = InsuranceDocument(
            id: document.id,
            remoteId: document.remoteId,
            filename: document.filename,
            uploadedOn: document.uploadedOn,
            documentType: document.documentType,
            insurer: document.insurer,
            status: document.status,
            syncState: document.syncState,
            processingState: document.processingState,
            processingCompletedAt: document.processingCompletedAt,
            size: document.size,
            localFilePath: document.localFilePath,
            policyHolders: holders,
          );
          await _localStorageService.updateDocument(updatedDoc);
        }
        return holders;
      }
      return [];
    } catch (e) {
      debugPrint('Error extracting policy holders: $e');
      return [];
    }
  }

  List<PolicyHolder> _parsePolicyHolders(String answer) {
    final List<PolicyHolder> holders = [];
    final nameRegex = RegExp(r'([A-Z][a-z]+ [A-Z][a-z]+)');
    final dobRegex = RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})');
    final nameMatches = nameRegex.allMatches(answer);
    final dobMatches = dobRegex.allMatches(answer);

    for (var i = 0; i < nameMatches.length; i++) {
      final name = nameMatches.elementAt(i).group(1);
      final dob =
          i < dobMatches.length ? dobMatches.elementAt(i).group(1) : null;
      if (name != null) {
        holders.add(PolicyHolder(
          name: name,
          dob: dob,
          relationship: i == 0 ? 'Primary Insured' : 'Dependent',
        ));
      }
    }
    return holders;
  }

  Future<bool> deleteDocument(String documentId) async {
    try {
      final document = await _localStorageService.getDocumentById(documentId);
      if (document == null) return false;

      final deleted = await _localStorageService.deleteDocument(documentId);
      if (deleted) {
        await AppStateRepository.addRecentlyDeletedDocument(document.filename);
      }
      return deleted;
    } catch (e) {
      debugPrint('Error deleting document: $e');
      return false;
    }
  }

  Future<InsuranceDocument?> checkForDuplicateDocument(File file) async {
    final filename = file.path.split('/').last;
    return await _localStorageService.findDuplicateDocument(filename);
  }

  Future<InsuranceDocument?> checkForDuplicateDocumentByName(
      String filename) async {
    return await _localStorageService.findDuplicateDocument(filename);
  }

  Future<Map<String, dynamic>> uploadDocumentWithLimitCheck(File file,
      {String? email, String? phone, String? pdfPassword}) async {
    try {
      final documents = await getDocuments();
      if (documents.length >= 5) {
        return {
          'error': 'storage_limit_reached',
          'message':
              'You already have 5 documents stored. Delete one before uploading another.',
          'document_limit': 5,
        };
      }

      // On-device OCR for scanned PDFs: if the PDF has no embedded text,
      // extract it with ML Kit before uploading. This handles scanned/image-
      // only policies without needing doctr on the backend (slim production
      // image). For digital PDFs (the common case), this is a fast no-op.
      final uploadFile = await _preprocessForOcr(file);

      return await uploadDocument(
        uploadFile,
        email: email,
        phone: phone,
        pdfPassword: pdfPassword,
      );
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Pre-processes a file for upload. If it's a PDF with no direct text,
  /// runs on-device ML Kit OCR and returns a text file. Otherwise returns
  /// the original file unchanged.
  Future<File> _preprocessForOcr(File file) async {
    final path = file.path.toLowerCase();
    if (!path.endsWith('.pdf')) return file;

    try {
      // Check if the PDF has direct text
      final result = await MlOcrService.extractTextFromFile(file.path);
      if (result.usedOcr && result.text.isNotEmpty) {
        // The PDF was scanned — write the OCR'd text to a temp file and
        // upload that instead. The backend processes text files fine.
        final tempDir = await Directory.systemTemp.createTemp('coverwise_ocr');
        final textFile = File(
            '${tempDir.path}/${file.uri.pathSegments.last.replaceAll('.pdf', '')}_ocr.txt');
        await textFile.writeAsString(result.text);
        debugPrint(
            'On-device OCR extracted ${result.text.length} chars from scanned PDF');
        return textFile;
      }
    } catch (e) {
      debugPrint('OCR preprocessing skipped: $e');
    }

    return file;
  }

  Future<void> refreshAllDocumentTypes() async {
    try {
      debugPrint('Refreshing document types for all documents...');
      final documents = await _localStorageService.getDocuments();

      for (final doc in documents) {
        debugPrint('Refreshing document type for: ${doc.filename}');
        final newType = await inferDocumentTypeFromContent(doc.id);

        if (newType != doc.documentType) {
          final updatedDoc = InsuranceDocument(
            id: doc.id,
            remoteId: doc.remoteId,
            filename: doc.filename,
            uploadedOn: doc.uploadedOn,
            documentType: newType,
            insurer: doc.insurer,
            status: doc.status,
            syncState: doc.syncState,
            processingState: doc.processingState,
            processingCompletedAt: doc.processingCompletedAt,
            size: doc.size,
            localFilePath: doc.localFilePath,
            policyHolders: doc.policyHolders,
          );
          await _localStorageService.updateDocument(updatedDoc);
        }
      }
      debugPrint('Document type refresh completed');
    } catch (e) {
      debugPrint('Error refreshing document types: $e');
    }
  }
}
