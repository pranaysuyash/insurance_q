import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/document_model.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';
import 'session_service.dart';
import 'app_state_repository.dart';
import 'ml_ocr_service.dart';
import '../utils/policy_type.dart';

class DocumentService {
  final Dio _dio;
  final LocalStorageService _localStorageService = LocalStorageService();

  /// The singleton authenticated Dio instance. All API calls should use this
  /// instead of creating ad-hoc Dio instances without auth tokens.
  static Dio? _authenticatedDio;
  static Future<Map<String, int>>? _pendingUploadSyncFuture;

  /// Returns the authenticated Dio instance, creating it lazily if needed.
  /// This ensures all API calls go through the AuthInterceptor.
  static Dio get authenticatedDio {
    if (_authenticatedDio == null) {
      _authenticatedDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: Duration(seconds: AppConfig.connectTimeoutSeconds),
          receiveTimeout: Duration(seconds: AppConfig.receiveTimeoutSeconds),
        ),
      );
      _authenticatedDio!.interceptors.add(AuthInterceptor(_authenticatedDio!));
    }
    return _authenticatedDio!;
  }

  DocumentService(this._dio);

  /// Downloads an owner-authorized source document and attaches it to the
  /// reconciled local metadata record. The signed URL is never persisted.
  Future<InsuranceDocument> cacheRemoteSource(String documentId) async {
    final document = await _localStorageService.getDocumentById(documentId);
    if (document == null || document.remoteId == null) {
      throw StateError('A server-owned document is required');
    }
    final response = await _dio.get(
      '/documents/${Uri.encodeComponent(document.remoteId!)}/source-url',
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw StateError('Source document authorization failed');
    }
    final payload = Map<String, dynamic>.from(response.data as Map);
    final url = payload['url']?.toString();
    if (url == null || url.isEmpty) {
      throw StateError('Source document URL was not returned');
    }
    final download = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(download.data ?? const <int>[]);
    if (bytes.isEmpty || bytes.length > 50 * 1024 * 1024) {
      throw StateError(
          'Downloaded source document is outside the safe size limit');
    }
    final expectedSize = (payload['size'] as num?)?.toInt();
    if (expectedSize != null && expectedSize != bytes.length) {
      throw StateError(
          'Downloaded source document failed integrity validation');
    }
    return _localStorageService.cacheRemoteSource(document, bytes);
  }

  Future<Map<String, dynamic>> uploadFile(File file,
      {String? email,
      String? phone,
      String? pdfPassword,
      String? onDeviceOcrText,
      required String processingConsentVersion}) async {
    try {
      final sessionId = await SessionService.getSessionId();

      try {
        final formData = FormData.fromMap({
          'files': await MultipartFile.fromFile(file.path),
          'processing_mode': 'full',
          'processing_consent': true,
          'processing_consent_version': processingConsentVersion,
          if (pdfPassword != null && pdfPassword.trim().isNotEmpty)
            'pdf_password': pdfPassword,
          if (onDeviceOcrText != null && onDeviceOcrText.trim().isNotEmpty)
            'on_device_ocr_text': onDeviceOcrText,
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
            processingConsentVersion: processingConsentVersion,
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
        debugPrint('Document upload request did not complete.');

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

        if (!_isOfflineTransportFailure(e)) {
          return {
            'error': 'upload_failed',
                'message':
                'We could not save this policy. Please try again before closing the app.',
          };
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
          processingConsentVersion: processingConsentVersion,
          status: 'pending',
        );
        await AppStateRepository.setLastUploadedDocumentId(document.id);

        return {
          'message': 'File saved locally; server upload still required',
          'document_id': document.id,
          'document_type': documentType,
          'insurer': insurerInfo['insurer'],
          'status': 'pending_upload',
          'sync_state': 'pending_upload',
          'offline_mode': true,
        };
      }
    } catch (e) {
      debugPrint('Unexpected document upload failure.');
      return {
        'error': 'upload_failed',
        'message': 'We could not save this policy. Please try again.',
      };
    }
  }

  String _inferDocumentType(String filePath) {
    // Use the same keyword classifier as the rest of the app (single source
    // of truth) instead of a separate, less-complete filename matcher.
    // This covers Indian product names (Mediclaim, Family Floater, etc.)
    // and all six canonical types including Travel and Other.
    return _canonicalTypeName(
      classifyPolicyType(filePath),
    );
  }

  /// Maps a [PolicyType] to the canonical display string used by the backend.
  String _canonicalTypeName(PolicyType type) {
    switch (type) {
      case PolicyType.health:
        return 'Health Insurance';
      case PolicyType.auto:
        return 'Auto Insurance';
      case PolicyType.life:
        return 'Life Insurance';
      case PolicyType.home:
        return 'Home Insurance';
      case PolicyType.travel:
        return 'Travel Insurance';
      case PolicyType.asset:
        return 'Asset Insurance';
      case PolicyType.liability:
        return 'Liability Insurance';
      case PolicyType.marine:
        return 'Marine Insurance';
      case PolicyType.cyber:
        return 'Cyber Insurance';
      case PolicyType.pet:
        return 'Pet Insurance';
      case PolicyType.other:
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
      {String? email,
      String? phone,
      String? pdfPassword,
      String? onDeviceOcrText,
      required String processingConsentVersion}) {
    return uploadFile(
      file,
      email: email,
      phone: phone,
      pdfPassword: pdfPassword,
      onDeviceOcrText: onDeviceOcrText,
      processingConsentVersion: processingConsentVersion,
    );
  }

  /// Reconciles locally persisted uploads without creating a second local
  /// document. Transport failures leave the item pending; missing local
  /// artifacts become an explicit terminal failure requiring user action.
  Future<Map<String, int>> retryPendingUploads() async {
    final existing = _pendingUploadSyncFuture;
    if (existing != null) return existing;

    final operation = _runPendingUploadSync();
    _pendingUploadSyncFuture = operation;
    try {
      return await operation;
    } finally {
      if (identical(_pendingUploadSyncFuture, operation)) {
        _pendingUploadSyncFuture = null;
      }
    }
  }

  Future<Map<String, int>> _runPendingUploadSync() async {
    var synced = 0;
    var pending = 0;
    var failed = 0;
    var skipped = 0;
    final queued = await _localStorageService.getPendingUploads();
    for (final document in queued) {
      final localPath = document.localFilePath;
      if (localPath == null || !await File(localPath).exists()) {
        await _localStorageService.updateDocument(document.copyWith(
          status: 'failed',
          syncState: 'failed',
          processingState: 'failed',
        ));
        failed++;
        continue;
      }
      final outcome = await _retryOnePendingUpload(document, File(localPath));
      switch (outcome) {
        case 'synced':
          synced++;
        case 'pending':
          pending++;
        case 'failed':
          failed++;
        default:
          skipped++;
      }
    }
    return {
      'synced': synced,
      'pending': pending,
      'failed': failed,
      'skipped': skipped,
    };
  }

  Future<String> _retryOnePendingUpload(
      InsuranceDocument document, File file) async {
    try {
      final sessionId = await SessionService.getSessionId();
      final formData = FormData.fromMap({
        'files': await MultipartFile.fromFile(file.path),
        'processing_mode': 'full',
        'processing_consent': true,
        'processing_consent_version':
            document.processingConsentVersion ?? 'legacy-local-save',
      });
      final response = await _dio.post(
        '/documents/upload',
        data: formData,
        options: Options(
          headers: {'X-Session-ID': sessionId},
          contentType: 'multipart/form-data',
        ),
      );
      if (response.statusCode == 429 ||
          response.statusCode == 408 ||
          (response.statusCode != null && response.statusCode! >= 500)) {
        return 'pending';
      }
      if (response.statusCode == 409 &&
          _isUploadInProgressResponse(response.data)) {
        return 'pending';
      }
      if (response.statusCode != 200 && response.statusCode != 202) {
        return 'failed';
      }
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final documents = data['documents'] as List<dynamic>?;
      final first =
          documents != null && documents.isNotEmpty && documents[0] is Map
              ? Map<String, dynamic>.from(documents[0] as Map)
              : <String, dynamic>{};
      final remoteId = first['id'] ?? first['processing_id'];
      if (remoteId == null) return 'failed';
      await _localStorageService.updateDocument(document.copyWith(
        remoteId: remoteId.toString(),
        documentType: first['document_type']?.toString(),
        insurer: first['insurer']?.toString(),
        status: first['status']?.toString() ?? 'received',
        syncState: 'synced',
        processingState: first['status']?.toString() ?? 'received',
      ));
      return 'synced';
    } on DioException catch (error) {
      if (error.response == null ||
          error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'pending';
      }
      final status = error.response?.statusCode;
      if (status == 429 ||
          status == 408 ||
          (status != null && status >= 500) ||
          (status == 409 &&
              _isUploadInProgressResponse(error.response?.data))) {
        return 'pending';
      }
      return 'failed';
    } catch (_) {
      return 'failed';
    }
  }

  bool _isUploadInProgressResponse(Object? data) {
    if (data is! Map) return false;
    final detail = data['detail'];
    if (detail is Map) {
      return detail['code']?.toString() == 'upload_in_progress';
    }
    return false;
  }

  bool _isOfflineTransportFailure(Object error) {
    if (error is! DioException || error.response != null) return false;
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }

  Future<Map<String, dynamic>> uploadWebDocument({
    required String filename,
    required Uint8List bytes,
    String? email,
    String? phone,
    String? pdfPassword,
    String? onDeviceOcrText,
    required String processingConsentVersion,
  }) async {
    try {
      final sessionId = await SessionService.getSessionId();

      try {
        final formData = FormData.fromMap({
          'files': MultipartFile.fromBytes(bytes, filename: filename),
          'processing_mode': 'full',
          'processing_consent': true,
          'processing_consent_version': processingConsentVersion,
          if (pdfPassword != null && pdfPassword.trim().isNotEmpty)
            'pdf_password': pdfPassword,
          if (onDeviceOcrText != null && onDeviceOcrText.trim().isNotEmpty)
            'on_device_ocr_text': onDeviceOcrText,
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
        debugPrint('Web document upload request did not complete.');

        if (e is DioException && e.response?.statusCode == 429) {
          final errorData = e.response?.data;
          return {
            'error': 'rate_limit_exceeded',
            'message': errorData?['detail'] ??
                'Upload limit exceeded. Please try again later.',
            'retry_after': errorData?['retry_after'],
          };
        }

        if (!_isOfflineTransportFailure(e)) {
          return {
            'error': 'upload_failed',
                'message':
                'We could not save this policy. Please try again before closing the app.',
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
          'message': 'File saved locally; server upload still required',
          'document_id': document.id,
          'document_type': documentType,
          'insurer': insurerInfo['insurer'],
          'status': 'pending_upload',
          'sync_state': 'pending_upload',
          'offline_mode': true,
        };
      }
    } catch (e) {
      debugPrint('Unexpected web document upload failure.');
      return {
        'error': 'upload_failed',
        'message': 'We could not save this policy. Please try again.',
      };
    }
  }

  Future<List<InsuranceDocument>> getDocuments() async {
    try {
      var documents = await _localStorageService.getDocuments();
      if (AuthService.hasAccountSession) {
        try {
          documents = await syncAccountDocuments();
        } catch (error) {
          // A remote read failure must not erase the usable local workspace.
          // The next refresh/re-entry retries reconciliation.
          debugPrint('Account document reconciliation unavailable: $error');
        }
      }
      final updatedDocuments = <InsuranceDocument>[];

      for (final doc in documents) {
        // Do not spend a Q&A request while merely rendering the library.
        // Unknown types are resolved only by the explicit user-triggered
        // refreshAllDocumentTypes action, which keeps quota consumption and
        // model work visible and intentional.
        updatedDocuments.add(doc);
      }
      return updatedDocuments;
    } catch (e) {
      debugPrint('Unable to load the local document list.');
      rethrow;
    }
  }

  /// Reconcile the active account's server document list into local metadata.
  ///
  /// The server list is authoritative only after the complete paginated read
  /// succeeds. Pending local uploads are retained, remote-only documents are
  /// materialized without pretending a source file exists, and local records
  /// for confirmed server deletions are removed. A failed request throws so
  /// callers cannot mistake a partial page for a complete reconciliation.
  Future<List<InsuranceDocument>> syncAccountDocuments() async {
    final remoteDocuments = <InsuranceDocument>[];
    var page = 1;
    while (true) {
      final response = await _dio.get(
        '/documents',
        queryParameters: {'page': page, 'limit': 100},
      );
      if (response.statusCode != 200 || response.data is! Map) {
        throw StateError(
            'Account document reconciliation returned an invalid response');
      }
      final payload = Map<String, dynamic>.from(response.data as Map);
      final rows = payload['documents'];
      if (rows is! List) {
        throw StateError('Account document reconciliation omitted documents');
      }
      for (final raw in rows) {
        if (raw is! Map) continue;
        final json = Map<String, dynamic>.from(raw);
        final remoteId = (json['id'] ?? json['document_id'])?.toString();
        if (remoteId == null || remoteId.isEmpty) continue;
        json['remote_id'] = remoteId;
        json['id'] = remoteId;
        remoteDocuments.add(InsuranceDocument.fromJson(json));
      }
      final totalPages = (payload['total_pages'] as num?)?.toInt();
      if (rows.isEmpty || (totalPages != null && page >= totalPages)) break;
      if (totalPages == null && rows.length < 100) break;
      page++;
    }

    final localDocuments = await _localStorageService.getDocuments();
    final remoteIds = remoteDocuments
        .map((document) => document.remoteId ?? document.id)
        .toSet();
    for (final local in localDocuments) {
      // An unsent local upload belongs to the retry queue, not the server
      // snapshot, so it must survive a successful reconciliation.
      if (local.remoteId == null && local.syncState == 'pending_upload') {
        continue;
      }
      if (local.remoteId != null && !remoteIds.contains(local.remoteId)) {
        await _localStorageService.deleteDocument(local.id);
      }
    }
    for (final remote in remoteDocuments) {
      await _localStorageService.upsertRemoteDocument(remote);
    }
    return _localStorageService.getDocuments();
  }

  Future<String> inferDocumentTypeFromContent(String documentId) async {
    try {
      debugPrint('Inferring document type for document: $documentId');
      final backendDocumentId =
          await _localStorageService.getBackendDocumentId(documentId);
      final queryDocumentId = backendDocumentId ?? documentId;
      final result = await _queryForType(queryDocumentId);
      if (result != null) return result;

      final metadataResult = await _queryForMetadata(queryDocumentId);
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
            processingConsentVersion: document.processingConsentVersion,
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

      // Per the 2026-07-19 review: the previous version was
      // local-only. Source files, metadata, summaries, and
      // chunks remained on the server after the user believed
      // the policy was deleted. The fix: call the backend's
      // DELETE /documents/{document_id} endpoint FIRST. If
      // the server-side deletion fails, we do NOT delete
      // locally; the user is told the deletion failed and
      // can retry. Only on server-side success do we delete
      // locally.
      //
      // The backend's response is the canonical state. A 200
      // means the server deleted everything (source, metadata,
      // summary, chunks). A 5xx means we leave the local
      // record in place and surface the error.
      try {
        final response = await authenticatedDio.delete(
          '/documents/${document.backendId}',
          options: Options(
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        if (response.statusCode == 404) {
          // The server has no record of this document. The
          // local record is stale; delete it and return true.
          debugPrint(
            'Server returned 404 for document $documentId; '
            'removing local record only',
          );
        } else if (response.statusCode != 200 && response.statusCode != 204) {
          // Server-side deletion failed (4xx other than 404,
          // e.g. 503 from the backend). Do NOT delete locally;
          // the user can retry. Surface the error.
          debugPrint(
            'Server-side deletion failed for $documentId: '
            '${response.statusCode} ${response.data}',
          );
          throw Exception(
            'Server-side deletion failed (${response.statusCode}). '
            'The document is not deleted. Please retry.',
          );
        }
        // 200/204: server deleted; we delete locally below.
      } on DioException catch (e) {
        // Transport-level failure. Do NOT delete locally; the
        // user can retry.
        debugPrint(
          'Server-side deletion network error for $documentId: '
          '${e.type} ${e.message}',
        );
        throw Exception(
          'Server-side deletion failed (network error). '
          'The document is not deleted. Please retry.',
        );
      }

      // Server confirmed deletion (or 404); safe to delete
      // locally.
      final deleted = await _localStorageService.deleteDocument(documentId);
      if (deleted) {
        await AppStateRepository.addRecentlyDeletedDocument(document.filename);
      }
      return deleted;
    } catch (e) {
      debugPrint('Error deleting document: $e');
      // Preserve the failure contract for the caller. The screen owns the
      // user-facing message and must be able to distinguish a failed remote
      // deletion from a successful local cleanup.
      rethrow;
    }
  }

  /// Archive a document (hide from active list, keep data intact).
  Future<bool> archiveDocument(String documentId) async {
    return _localStorageService.archiveDocument(documentId);
  }

  /// Restore an archived document back to the active list.
  Future<bool> restoreDocument(String documentId) async {
    return _localStorageService.restoreDocument(documentId);
  }

  /// Count how many documents are currently archived.
  Future<int> archivedDocumentCount() async {
    return _localStorageService.archivedDocumentCount();
  }

  /// Count how many active (non-archived) documents exist.
  Future<int> activeDocumentCount() async {
    return _localStorageService.activeDocumentCount();
  }

  /// Replace an existing document with a new file.
  /// Deletes the old document and its summary, then uploads the new file.
  Future<Map<String, dynamic>> replaceDocument(
    String existingDocumentId,
    File newFile, {
    String? pdfPassword,
    String? onDeviceOcrText,
    required String processingConsentVersion,
  }) async {
    try {
      // Get the existing document to preserve some metadata
      final existingDoc =
          await _localStorageService.getDocumentById(existingDocumentId);
      if (existingDoc == null) {
        return {
          'error': 'document_not_found',
          'message': 'The original document could not be found.',
        };
      }

      // Delete the old document's summary from local storage
      // (the backend will re-extract from the new file)
      debugPrint('Replacing document: ${existingDoc.filename}');

      // Upload the new file (this creates a new document)
      final uploadResult = await uploadDocument(
        newFile,
        pdfPassword: pdfPassword,
        onDeviceOcrText: onDeviceOcrText,
        processingConsentVersion: processingConsentVersion,
      );

      if (uploadResult.containsKey('error')) {
        return uploadResult;
      }

      // Delete the old document after successful upload of the new one
      await deleteDocument(existingDocumentId);

      return {
        ...uploadResult,
        'replaced_document_id': existingDocumentId,
        'message': 'Document replaced successfully',
      };
    } catch (e) {
      debugPrint('Error replacing document: $e');
      return {
        'error': 'replace_failed',
        'message': 'Could not replace the document. Please try again.',
      };
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
      {String? email,
      String? phone,
      String? pdfPassword,
      bool useOnDeviceOcr = false,
      OnDeviceOcrScript onDeviceOcrScript = OnDeviceOcrScript.latin,
      required String processingConsentVersion,
      int? documentLimit}) async {
    try {
      final documents = await getDocuments();
      final limit = documentLimit ?? 5; // Default for free tier
      if (documents.length >= limit) {
        return {
          'error': 'storage_limit_reached',
          'message':
              'You already have $limit documents stored. Upgrade your plan or delete one before uploading another.',
          'document_limit': limit,
        };
      }

      // OCR is explicitly chosen by the user for scanned pages. The original
      // source file is always uploaded; OCR text is a labelled sidecar that
      // the backend may use only when the source lacks embedded PDF text.
      final onDeviceOcrText = useOnDeviceOcr
          ? await _extractOnDeviceOcrText(file, onDeviceOcrScript)
          : null;

      return await uploadDocument(
        file,
        email: email,
        phone: phone,
        pdfPassword: pdfPassword,
        onDeviceOcrText: onDeviceOcrText,
        processingConsentVersion: processingConsentVersion,
      );
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Produces an optional, in-memory sidecar for a user-selected scanned
  /// document. It never changes the original file or filename.
  Future<String?> _extractOnDeviceOcrText(
    File file,
    OnDeviceOcrScript script,
  ) async {
    try {
      final result = await MlOcrService.extractTextFromFile(
        file.path,
        script: script,
      );
      if (result.usedOcr && result.text.isNotEmpty) {
        debugPrint(
            'On-device OCR extracted ${result.text.length} chars; original source is retained');
        return result.text;
      }
    } catch (e) {
      debugPrint('On-device OCR assist unavailable: $e');
    }
    return null;
  }

  /// Fetch the real-time processing status from the backend.
  ///
  /// Uses the centralized authenticated Dio client to ensure auth tokens
  /// are attached to the request.
  ///
  /// Returns the full status response including `processing_details.stage`
  /// (e.g. `started`, `validating`, `extracting_text`, `extracting_policy_data`,
  /// `creating_embeddings`, `completed`), or `null` if the backend is
  /// unreachable or the document is not found.
  Future<Map<String, dynamic>?> getDocumentStatus(String documentId) async {
    try {
      final sessionId = await SessionService.getSessionId();
      final response = await authenticatedDio.get(
        '/documents/$documentId/status',
        options: Options(
          headers: {'X-Session-ID': sessionId},
          validateStatus: (status) => status == 200 || status == 404,
        ),
      );
      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      // Network errors during status polling are expected (backend down,
      // document still queued). Only log non-transport failures.
      if (e.type != DioExceptionType.connectionTimeout &&
          e.type != DioExceptionType.connectionError) {
        debugPrint('Backend status fetch failed: ${e.type}');
      }
      return null;
    } catch (e) {
      debugPrint('Backend status fetch unexpected error: $e');
      return null;
    }
  }

  Future<void> updateDocumentType(InsuranceDocument updatedDoc) async {
    await _localStorageService.updateDocument(updatedDoc);
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
            processingConsentVersion: doc.processingConsentVersion,
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
