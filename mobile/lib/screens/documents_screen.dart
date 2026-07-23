import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../providers/service_providers.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../providers/entitlement_provider.dart';
import '../services/analytics_service.dart';
import '../services/app_state_store.dart';
import '../services/consent_ledger.dart';
import '../services/consent_sync_service.dart';
import '../services/contact_service.dart';
import '../services/ml_ocr_service.dart';
import '../services/web_file_picker.dart';
import '../services/drag_drop_service.dart';
import '../widgets/drop_zone.dart';
import 'paywall_screen.dart';
import '../theme/coverwise_motion.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../localization/app_localizations.dart';
import '../utils/app_error.dart';
import '../widgets/lead_capture_dialog.dart';
import '../widgets/phone_capture_sheet.dart';
import '../widgets/usage_stats_widget.dart';
import '../widgets/shared/coverwise_components.dart';
import 'documents_list.dart';
import 'processing_status_screen.dart';
import '../models/batch_upload_entry.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  /// When true, the file picker opens automatically on mount.
  /// Used by onboarding and dashboard CTAs to skip the intermediate
  /// "tap to open file picker" step — reduces upload taps from 4 to 2.
  final bool startWithFilePicker;

  /// Supplies a deterministic selected-file state for widget tests.
  @visibleForTesting
  final String? initialFileName;

  const DocumentsScreen({
    super.key,
    this.startWithFilePicker = false,
    this.initialFileName,
  });
  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  // ── Single-file state (kept for backward compat with onboarding/CTA flow)
  File? _selectedFile;
  WebPickedFile? _selectedWebFile;
  bool _isUploading = false;
  bool _isReadingOnDevice = false;
  bool _useOnDeviceOcr = false;
  OnDeviceOcrScript _onDeviceOcrScript = OnDeviceOcrScript.latin;
  String? _uploadError;
  Map<String, dynamic>? _ocrResult;
  bool _showUploadDetails = false;
  bool _demoPolicyPreloaded = false;
  int? _selectedFileSize;
  String? _pdfPassword;

  // ── Batch upload state (P3-05)
  final List<BatchUploadEntry> _batchEntries = [];
  bool _batchUploading = false;
  int _batchCompleted = 0;
  int _batchFailed = 0;

  Future<void> _syncProcessingConsent() async {
    try {
      // The local ledger remains the immediate offline gate. This generic
      // principal-scoped bridge also retries onboarding privacy/analytics
      // decisions, not only document-processing consent.
      await ConsentSyncService().syncAll();
    } catch (error) {
      debugPrint('server consent sync deferred: ${error.runtimeType}');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialFileName != null && !_demoPolicyPreloaded) {
        _demoPolicyPreloaded = true;
        setState(() {
          _selectedWebFile = WebPickedFile(
            name: widget.initialFileName!,
            bytes: Uint8List(0),
          );
          _selectedFile = null;
          _useOnDeviceOcr = false;
          _showUploadDetails = true;
        });
        return;
      }
      // Auto-open file picker when launched from onboarding/dashboard CTA.
      if (widget.startWithFilePicker && !_demoPolicyPreloaded) {
        _demoPolicyPreloaded = true;
        _pickFile();
        return;
      }
      if (AppConfig.bootstrapPolicyDemo && !_demoPolicyPreloaded) {
        _demoPolicyPreloaded = true;
        _pickFile();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<File> _loadBundledDemoPolicyFile() async {
    final byteData = await rootBundle.load('assets/demo/policy.pdf');
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(path.join(tempDir.path, 'policy_demo.pdf'));
    final bytes = byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile;
  }

  /// Supported file types and their extensions.
  static const Set<String> _supportedExtensions = {
    'pdf',
    'jpg',
    'jpeg',
    'png',
  };

  Future<void> _pickFile() async {
    setState(() {
      _uploadError = null;
      _ocrResult = null;
    });

    if (AppConfig.bootstrapPolicyDemo) {
      try {
        final file = await _loadBundledDemoPolicyFile();
        if (!mounted) return;
        final size = await file.length();
        if (!mounted) return;
        setState(() {
          _selectedFile = file;
          _selectedWebFile = null;
          _selectedFileSize = size;
          _useOnDeviceOcr = false;
          _showUploadDetails = true;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(
            () => _uploadError = 'Failed to load bundled policy sample: $e');
        return;
      }
    }

    final typeGroup = XTypeGroup(
      label: 'Documents',
      uniformTypeIdentifiers: ['com.adobe.pdf', 'public.image'],
      mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
    );

    if (kIsWeb) {
      final picked = await WebFilePicker.pickFile();
      if (picked != null && mounted) {
        // Validate web file type by extension.
        final ext = picked.name.split('.').last.toLowerCase();
        if (!_supportedExtensions.contains(ext)) {
          setState(() => _uploadError = S.fileTypeUnsupported);
          return;
        }
        if (picked.bytes.length > AppConfig.maxUploadFileSizeBytes) {
          setState(() => _uploadError =
              'This file is too large (${_formatFileSize(picked.bytes.length)}). ${S.fileTypeMaxSize}.');
          return;
        }
        setState(() {
          _selectedWebFile = picked;
          _selectedFile = null;
          _selectedFileSize = picked.bytes.length;
          _useOnDeviceOcr = false;
          _showUploadDetails = true;
        });
      }
      return;
    }

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null && mounted) {
      // Validate file type before proceeding.
      final ext = file.path.split('.').last.toLowerCase();
      if (!_supportedExtensions.contains(ext)) {
        if (!mounted) return;
        setState(() => _uploadError = S.fileTypeUnsupported);
        return;
      }

      // Validate file size before proceeding.
      final size = await File(file.path).length();
      if (!mounted) return;
      if (size > AppConfig.maxUploadFileSizeBytes) {
        setState(() => _uploadError =
            'This file is too large (${_formatFileSize(size)}). ${S.fileTypeMaxSize}.');
        return;
      }

      setState(() {
        _selectedFile = File(file.path);
        _selectedWebFile = null;
        _selectedFileSize = size;
        final selectedPath = file.path.toLowerCase();
        _useOnDeviceOcr = selectedPath.endsWith('.png') ||
            selectedPath.endsWith('.jpg') ||
            selectedPath.endsWith('.jpeg');
        _showUploadDetails = true;
      });
    }
  }

  Future<void> _uploadFile() async {
    final selectedFile = _selectedFile;
    final selectedWebFile = _selectedWebFile;
    if (selectedFile == null && selectedWebFile == null) return;

    final currentPolicyCount =
        ref.read(documentsProvider).asData?.value.length ?? 0;
    final entitlementReason = ref
        .read(entitlementProvider.notifier)
        .checkAction('upload_policy', currentPolicyCount: currentPolicyCount);
    if (entitlementReason != null) {
      if (!mounted) return;
      PaywallScreen.show(context, limitType: PaywallLimitType.documents);
      return;
    }

    final duplicate = selectedFile != null
        ? await ref
            .read(documentServiceProvider)
            .checkForDuplicateDocument(selectedFile)
        : selectedWebFile != null
            ? await ref
                .read(documentServiceProvider)
                .checkForDuplicateDocumentByName(selectedWebFile.name)
            : null;

    if (duplicate != null && mounted) {
      final shouldProceed = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('This policy is already saved'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'An identical or matching policy is already on this device:'),
              const SizedBox(height: 8),
              Text(duplicate.filename,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Uploaded on: ${duplicate.formattedUploadDate}'),
              const SizedBox(height: 16),
              const Text(
                'CoverWise avoids creating duplicate policy records. You can use the saved policy or replace it after deleting the old copy.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, 'use_existing'),
                child: const Text('Use Saved Policy')),
          ],
        ),
      );

      if (shouldProceed == null || shouldProceed == 'cancel') return;
      if (shouldProceed == 'use_existing') {
        ref.invalidate(documentsProvider);
        return;
      }
    }

    if (!mounted) return;

    // Consent: ask once per device, stored permanently.
    final consentVersion = await _ensureConsent();
    if (consentVersion == null) return;

    await _syncProcessingConsent();
    if (!mounted) return;

    setState(() {
      _isUploading = true;
      _isReadingOnDevice = !kIsWeb && _useOnDeviceOcr;
      _uploadError = null;
      _ocrResult = null;
    });

    AnalyticsService.track('first_upload_started', {
      'file_type': selectedFile?.path.split('.').last ?? 'unknown',
    });

    try {
      final result = selectedWebFile != null
          ? await ref.read(documentServiceProvider).uploadWebDocument(
                filename: selectedWebFile.name,
                bytes: Uint8List.fromList(selectedWebFile.bytes),
                onDeviceOcrText: null,
                processingConsentVersion: consentVersion,
              )
          : await ref
              .read(documentServiceProvider)
              .uploadDocumentWithLimitCheck(
                selectedFile!,
                useOnDeviceOcr: _useOnDeviceOcr,
                onDeviceOcrScript: _onDeviceOcrScript,
                processingConsentVersion: consentVersion,
                pdfPassword: _pdfPassword,
                documentLimit: ref.read(entitlementProvider).limits.maxPolicies,
              );

      if (mounted) {
        if (result['error'] == 'rate_limit_exceeded') {
          await showDialog(
            context: context,
            builder: (context) => RateLimitDialog(
              message: result['message'] ?? 'Upload limit exceeded',
              retryAfter: result['retry_after'],
            ),
          );
          setState(() => _uploadError = result['message']);
          return;
        }

        if (result['error'] == 'storage_limit_reached') {
          setState(() {
            _isUploading = false;
          });
          // Show the paywall instead of a bare snackbar
          if (!mounted) return;
          PaywallScreen.show(context, limitType: PaywallLimitType.documents);
          return;
        }

        if (result['error'] == 'pdf_password_required' ||
            result['error'] == 'pdf_password_invalid') {
          setState(() => _isUploading = false);
          if (!mounted) return;

          // Show password input dialog and retry
          final password = await showDialog<String>(
            context: context,
            builder: (context) => _PdfPasswordDialog(
              isRetry: result['error'] == 'pdf_password_invalid',
            ),
          );

          if (password != null && password.isNotEmpty && mounted) {
            // Retry upload with the password
            _pdfPassword = password;
            _uploadFile();
          }
          return;
        }

        if (result['error'] == 'pdf_unreadable') {
          setState(() {
            _uploadError = result['message']?.toString() ??
                'This PDF could not be opened. It may be corrupted.';
            _isUploading = false;
          });
          return;
        }

        if (result['error'] != null) {
          setState(() {
            _uploadError = result['message']?.toString() ??
                'We could not save this policy securely. Please try again.';
          });
          return;
        }

        setState(() => _ocrResult = result);
        ref.invalidate(documentsProvider);

        AnalyticsService.track('document_processing_succeeded', {
          'file_type': selectedFile?.path.split('.').last ?? 'unknown',
          'status': result['status']?.toString() ?? 'unknown',
        });

        // A received policy is durable but not yet ready for a summary/Q&A.
        final documentId = result['document_id']?.toString();
        final documentType = result['document_type']?.toString() ?? 'Unknown';
        final isOfflineFlag = result['offline_mode'] == true;
        final serverStatus = result['status']?.toString() ?? '';
        final isProcessing =
            serverStatus == 'received' || serverStatus == 'processing';

        if (documentId != null &&
            !isOfflineFlag &&
            serverStatus == 'completed') {
          ref
              .read(policySummariesProvider.notifier)
              .fetchFromBackend(documentId, documentType);
        }

        final isQueuedOnly = serverStatus == 'pending_upload';
        final selectedName = selectedWebFile?.name ??
            selectedFile?.path.split('/').last ??
            'Document';

        setState(() {
          _selectedFile = null;
          _selectedWebFile = null;
          _showUploadDetails = false;
        });

        if (!mounted) return;

        // Navigate to the policy detail screen if processing completed -
        // this IS the first value moment. The user sees their summary immediately.
        if (documentId != null &&
            !isOfflineFlag &&
            serverStatus == 'completed') {
          AnalyticsService.track('first_value_delivered', {
            'document_id': documentId.substring(0, 8),
          });
          // Push to policy detail - the "aha" moment
          Navigator.pushNamed(context, '/policy-detail', arguments: documentId);
          // After the user sees their policy, offer phone backup (progressive)
          PhoneCaptureSheet.maybeShow(context);
        } else if (isProcessing && documentId != null) {
          // Navigate to the processing status screen with stage indicators
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProcessingStatusScreen(
                documentId: documentId,
                filename: selectedName,
              ),
            ),
          );
          PhoneCaptureSheet.maybeShow(context);
        } else {
          // Offline/queued - honest message
          final message = isQueuedOnly
              ? '$selectedName saved locally. ${S.docsUploadRequired}.'
              : '$selectedName saved locally (offline mode)';
          CoverWiseSnackBar.warning(context, message);
          PhoneCaptureSheet.maybeShow(context);
        }
      }
    } catch (e) {
      AnalyticsService.track('document_processing_failed', {
        'error_class': e.runtimeType.toString(),
      });
      if (mounted) {
        setState(() => _uploadError =
            'We could not save this policy securely. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
      if (mounted) setState(() => _isReadingOnDevice = false);
    }
  }

  /// Validates a dropped file's extension and size, then routes it through
  /// the existing upload pipeline (single file for one, batch for multiple).
  Future<void> _handleDroppedFiles(List<DragDropEvent> files) async {
    if (files.isEmpty) return;

    if (files.length == 1) {
      final file = files.first;
      final ext = file.name.split('.').last.toLowerCase();
      if (!_supportedExtensions.contains(ext)) {
        if (!mounted) return;
        setState(() => _uploadError = S.fileTypeUnsupported);
        return;
      }
      if (file.size > AppConfig.maxUploadFileSizeBytes) {
        if (!mounted) return;
        setState(() => _uploadError =
            'This file is too large (${_formatFileSize(file.size)}). ${S.fileTypeMaxSize}.');
        return;
      }
      setState(() {
        _selectedWebFile = WebPickedFile(name: file.name, bytes: file.bytes);
        _selectedFile = null;
        _selectedFileSize = file.size;
        _useOnDeviceOcr = false;
        _showUploadDetails = true;
      });
      // Single dropped files go through the same upload review step.
      return;
    }

    // Multiple files: use the batch upload path.
    final entries = <BatchUploadEntry>[];
    for (final file in files) {
      final ext = file.name.split('.').last.toLowerCase();
      if (!_supportedExtensions.contains(ext)) {
        entries.add(BatchUploadEntry(
          fileName: file.name,
          fileSizeBytes: file.size,
          isWebFile: true,
          state: BatchUploadState.skipped,
          errorMessage: S.batchFileUnsupported,
        ));
        continue;
      }
      if (file.size > AppConfig.maxUploadFileSizeBytes) {
        entries.add(BatchUploadEntry(
          fileName: file.name,
          fileSizeBytes: file.size,
          isWebFile: true,
          state: BatchUploadState.skipped,
          errorMessage: S.batchFileTooLargeMB(AppConfig.maxUploadFileSizeMB),
        ));
        continue;
      }
      entries.add(BatchUploadEntry(
        fileName: file.name,
        fileSizeBytes: file.size,
        isWebFile: true,
        webFileBytes: file.bytes,
        webFileName: file.name,
      ));
    }

    if (entries.isEmpty) return;
    setState(() {
      _batchEntries
        ..clear()
        ..addAll(entries);
      _batchCompleted = 0;
      _batchFailed = 0;
    });
    // Trigger batch upload immediately for dropped files.
    _uploadBatch();
  }

  String _formatFileSize(int bytes) {
    if (bytes > 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _selectedWebFile = null;
      _selectedFileSize = null;
      _useOnDeviceOcr = false;
      _ocrResult = null;
      _uploadError = null;
      _showUploadDetails = false;
    });
  }

  void _clearBatch() {
    setState(() {
      _batchEntries.clear();
      _batchCompleted = 0;
      _batchFailed = 0;
      _batchUploading = false;
    });
  }

  /// Obtain or establish document-processing consent.
  ///
  /// Returns the consent version string, or `null` if the user cancelled.
  /// Shared between single-file upload and batch upload to avoid duplication.
  Future<String?> _ensureConsent() async {
    final box = Hive.box(AppStateStore.boxName);
    final storedConsent = box.get('processing_consent_version') as String?;

    if (storedConsent != null) {
      final ledger = ConsentLedger();
      if (!ledger.hasConsent(ConsentPurpose.documentProcessing)) {
        await ledger.recordConsent(
          purpose: ConsentPurpose.documentProcessing,
          version: storedConsent,
          granted: true,
        );
      }
      return storedConsent;
    }

    // First upload — show consent + optional contact capture.
    final savedContact = await ContactService.getSavedContact();
    if (!mounted) return null;
    final leadInfo = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => LeadCaptureDialog(
        initialEmail: savedContact['email'],
        initialPhone: savedContact['phone'],
        isRequired: false,
      ),
    );
    if (leadInfo == null) return null;

    final version = leadInfo['processing_consent_version'] as String;
    await box.put('processing_consent_version', version);

    if (leadInfo['save'] == true) {
      await ContactService.saveContact(
        email: leadInfo['email'],
        phone: leadInfo['phone'],
        saveForFuture: true,
      );
    }

    return version;
  }

  /// Open multi-file picker and validate each selected file.
  Future<void> _pickFiles() async {
    setState(() {
      _uploadError = null;
      _ocrResult = null;
    });

    final typeGroup = XTypeGroup(
      label: 'Documents',
      uniformTypeIdentifiers: ['com.adobe.pdf', 'public.image'],
      mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
    );

    if (kIsWeb) {
      final picked = await WebFilePicker.pickFiles();
      if (picked == null || picked.isEmpty || !mounted) return;

      final entries = <BatchUploadEntry>[];
      for (final file in picked) {
        final ext = file.name.split('.').last.toLowerCase();
        if (!_supportedExtensions.contains(ext)) {
          entries.add(BatchUploadEntry(
            fileName: file.name,
            fileSizeBytes: file.bytes.length,
            isWebFile: true,
            state: BatchUploadState.skipped,
            errorMessage: S.batchFileUnsupported,
          ));
          continue;
        }
        if (file.bytes.length > AppConfig.maxUploadFileSizeBytes) {
          entries.add(BatchUploadEntry(
            fileName: file.name,
            fileSizeBytes: file.bytes.length,
            isWebFile: true,
            state: BatchUploadState.skipped,
            errorMessage: S.batchFileTooLargeMB(AppConfig.maxUploadFileSizeMB),
          ));
          continue;
        }
        entries.add(BatchUploadEntry(
          fileName: file.name,
          fileSizeBytes: file.bytes.length,
          isWebFile: true,
          webFileBytes: file.bytes,
          webFileName: file.name,
        ));
      }

      if (entries.isEmpty) return;
      setState(() {
        _batchEntries
          ..clear()
          ..addAll(entries);
        _batchCompleted = 0;
        _batchFailed = 0;
      });
      return;
    }

    // Native: use openFiles() for multi-select.
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);
    if (files.isEmpty || !mounted) return;

    final entries = <BatchUploadEntry>[];
    for (final xFile in files) {
      final ext = xFile.path.split('.').last.toLowerCase();
      if (!_supportedExtensions.contains(ext)) {
        entries.add(BatchUploadEntry(
          fileName: xFile.path.split('/').last,
          fileSizeBytes: 0,
          state: BatchUploadState.skipped,
          errorMessage: S.batchFileUnsupported,
        ));
        continue;
      }
      try {
        final size = await File(xFile.path).length();
        if (!mounted) return;
        if (size > AppConfig.maxUploadFileSizeBytes) {
          entries.add(BatchUploadEntry(
            fileName: xFile.path.split('/').last,
            fileSizeBytes: size,
            state: BatchUploadState.skipped,
            errorMessage: S.batchFileTooLargeMB(AppConfig.maxUploadFileSizeMB),
          ));
          continue;
        }
        entries.add(BatchUploadEntry(
          fileName: xFile.path.split('/').last,
          fileSizeBytes: size,
          localFilePath: xFile.path,
        ));
      } catch (e) {
        entries.add(BatchUploadEntry(
          fileName: xFile.path.split('/').last,
          fileSizeBytes: 0,
          state: BatchUploadState.failed,
          errorMessage: e.toString(),
        ));
      }
    }

    if (entries.isEmpty) return;
    setState(() {
      _batchEntries
        ..clear()
        ..addAll(entries);
      _batchCompleted = 0;
      _batchFailed = 0;
    });
  }

  /// Upload all batch entries sequentially, updating per-file status.
  Future<void> _uploadBatch() async {
    if (_batchEntries.isEmpty) return;
    final pending = _batchEntries
        .where((e) => e.state == BatchUploadState.pending)
        .toList();
    if (pending.isEmpty) return;

    // Entitlement check: prompt paywall immediately if already at limit.
    final currentPolicyCount =
        ref.read(documentsProvider).asData?.value.length ?? 0;
    final limit = ref.read(entitlementProvider).limits.maxPolicies;
    if (currentPolicyCount >= limit) {
      if (mounted) {
        PaywallScreen.show(context, limitType: PaywallLimitType.documents);
      }
      return;
    }

    // Consent: ask once for the entire batch.
    final consentVersion = await _ensureConsent();
    if (consentVersion == null) return;

    await _syncProcessingConsent();

    setState(() {
      _batchUploading = true;
      _batchCompleted = 0;
      _batchFailed = 0;
    });

    AnalyticsService.track('batch_upload_started', {
      'file_count': pending.length,
    });

    for (final entry in pending) {
      if (!mounted) return;

      // Check entitlement before each upload in case limit was reached.
      final nowCount =
          ref.read(documentsProvider).asData?.value.length ?? 0;
      if (nowCount >= limit) {
        entry.state = BatchUploadState.skipped;
        entry.errorMessage = 'Plan limit reached';
        _batchFailed++;
        if (mounted) setState(() {});
        continue;
      }

      setState(() => entry.state = BatchUploadState.uploading);

      // Duplicate check before uploading (non-fatal; proceed on any error).
      final isDuplicate = entry.localFilePath != null
          ? await ref
              .read(documentServiceProvider)
              .checkForDuplicateDocument(File(entry.localFilePath!))
          : entry.isWebFile
              ? await ref
                  .read(documentServiceProvider)
                  .checkForDuplicateDocumentByName(
                      entry.webFileName ?? entry.fileName)
              : null;
      if (!mounted) return;
      if (isDuplicate != null) {
        entry.state = BatchUploadState.skipped;
        entry.errorMessage = S.batchDuplicateSkipped;
        continue;
      }

      try {
        Map<String, dynamic> result;
        if (entry.isWebFile && entry.webFileBytes != null) {
          result = await ref.read(documentServiceProvider).uploadWebDocument(
                filename: entry.webFileName ?? entry.fileName,
                bytes: Uint8List.fromList(entry.webFileBytes!),
                processingConsentVersion: consentVersion,
              );
        } else if (entry.localFilePath != null) {
          result =
              await ref.read(documentServiceProvider).uploadDocumentWithLimitCheck(
                File(entry.localFilePath!),
                processingConsentVersion: consentVersion,
                documentLimit: limit,
              );
        } else {
          entry.state = BatchUploadState.failed;
          entry.errorMessage = 'File not found';
          _batchFailed++;
          if (mounted) setState(() {});
          continue;
        }

        if (!mounted) return;
        if (result['error'] != null) {
          entry.state = BatchUploadState.failed;
          entry.errorMessage =
              result['message']?.toString() ?? result['error'].toString();
          _batchFailed++;
        } else {
          entry.state = BatchUploadState.completed;
          entry.result = result;
          _batchCompleted++;
          if (mounted) ref.invalidate(documentsProvider);
        }
      } catch (e) {
        entry.state = BatchUploadState.failed;
        entry.errorMessage = 'Upload failed';
        _batchFailed++;
      }

      if (mounted) setState(() {});
    }

    AnalyticsService.track('batch_upload_completed', {
      'completed': _batchCompleted,
      'failed': _batchFailed,
      'total': pending.length,
    });

    if (mounted) {
      setState(() => _batchUploading = false);
      ref.invalidate(documentsProvider);

      if (_batchFailed == 0) {
        CoverWiseSnackBar.success(
          context,
          S.batchCompletedCount(_batchCompleted),
        );
      } else {
        CoverWiseSnackBar.warning(
          context,
          S.batchFailedCount(_batchFailed, _batchEntries.length),
        );
      }
    }
  }

  /// Retry only the failed entries in the current batch.
  void _retryFailedBatch() {
    setState(() {
      for (final entry in _batchEntries) {
        if (entry.state == BatchUploadState.failed) {
          entry.state = BatchUploadState.pending;
          entry.errorMessage = null;
          entry.result = null;
        }
      }
      _batchFailed = 0;
    });
    _uploadBatch();
  }

  Future<void> _refreshDocumentTypes() async {
    setState(() => _isUploading = true);
    try {
      if (!mounted) return;
      CoverWiseSnackBar.info(context, S.docsRefreshingTypes);
      await ref.read(documentServiceProvider).refreshAllDocumentTypes();
      ref.invalidate(documentsProvider);
      if (!mounted) return;
      CoverWiseSnackBar.success(
        context,
        S.docsTypesRefreshed,
      );
    } catch (e) {
      if (!mounted) return;
      CoverWiseSnackBar.error(
        context,
        AppError.userMessage(e),
        operation: 'refresh document types',
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsProvider);
    final hasDocuments =
        documentsAsync.whenOrNull(data: (docs) => docs.isNotEmpty) ?? false;
    final hasSelection = _selectedFile != null || _selectedWebFile != null;
    final showExpandedUpload = _showUploadDetails && hasSelection;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshDocumentTypes,
              tooltip: 'Refresh Document Types'),
        ],
      ),
      body: DropZone(
        onFilesDropped: _handleDroppedFiles,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CoverWisePageHeader(
            title: 'Your policy library',
            subtitle:
                'Keep policy files together, then open one to review or ask a question.',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: UsageStatsWidget(),
          ),
          // Upload section: batch progress when batch is active, single-file when selected, CTAs otherwise.
          if (_batchEntries.isNotEmpty)
            _BatchUploadProgress(
              entries: _batchEntries,
              isUploading: _batchUploading,
              completed: _batchCompleted,
              failed: _batchFailed,
              onUpload: _uploadBatch,
              onRetryFailed: _retryFailedBatch,
              onClear: _clearBatch,
              onAddMore: _pickFiles,
              formatFileSize: _formatFileSize,
            )
          else if (showExpandedUpload)
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                child: CoverWiseSurface(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Add a policy file',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _clearSelection,
                                tooltip: 'Clear selection'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_selectedFile != null ||
                            _selectedWebFile != null) ...[
                          Row(
                            children: [
                              CoverWiseIconBadge(
                                icon: Icons.description_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 40,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedWebFile?.name ??
                                          _selectedFile?.path.split('/').last ??
                                          'Policy',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (_selectedFileSize != null)
                                      Text(
                                        _formatFileSize(_selectedFileSize!),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (!kIsWeb) ...[
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _useOnDeviceOcr,
                              onChanged: _isUploading
                                  ? null
                                  : (value) =>
                                      setState(() => _useOnDeviceOcr = value),
                              title: const Text(
                                  'Read scanned pages on this device'),
                              subtitle: const Text(
                                'Uses on-device text recognition. Your original file is still uploaded and remains the source of truth.',
                              ),
                              secondary:
                                  const Icon(Icons.document_scanner_outlined),
                            ),
                            if (_useOnDeviceOcr)
                              DropdownButtonFormField<OnDeviceOcrScript>(
                                initialValue: _onDeviceOcrScript,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Document language',
                                  border: OutlineInputBorder(),
                                ),
                                items: OnDeviceOcrScript.values
                                    .map(
                                      (script) => DropdownMenuItem(
                                        value: script,
                                        child: Text(script.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _isUploading
                                    ? null
                                    : (script) {
                                        if (script != null) {
                                          setState(
                                            () => _onDeviceOcrScript = script,
                                          );
                                        }
                                      },
                              ),
                            const SizedBox(height: 8),
                          ],
                          Center(
                            child: CoverWiseStateTransition(
                              child: KeyedSubtree(
                                key: ValueKey(
                                  _isUploading
                                      ? _isReadingOnDevice
                                          ? 'reading-on-device'
                                          : 'uploading'
                                      : 'ready-to-upload',
                                ),
                                child: _isUploading
                                    ? Semantics(
                                        liveRegion: true,
                                        label: _isReadingOnDevice
                                            ? 'Reading policy pages on this device'
                                            : 'Uploading policy file',
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const LinearProgressIndicator(),
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _isReadingOnDevice
                                                      ? Icons
                                                          .document_scanner_outlined
                                                      : Icons
                                                          .cloud_upload_outlined,
                                                  size: 16,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _isReadingOnDevice
                                                      ? 'Reading pages on this device…'
                                                      : 'Uploading to CoverWise…',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      )
                                    : FilledButton.icon(
                                        icon: const Icon(
                                            Icons.cloud_upload_outlined),
                                        label:
                                            const Text('Upload Selected File'),
                                        onPressed: _uploadFile,
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 12),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                        if (_uploadError != null) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _uploadError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (_ocrResult != null) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: const Text(
                              'Upload and document reading completed',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (!hasDocuments)
            // Empty state: prominent upload CTAs
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Add policy file'),
                      onPressed: _pickFile,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.playlist_add_rounded, size: 18),
                      label: Text(S.batchPickMultiple),
                      onPressed: _pickFiles,
                    ),
                    const SizedBox(height: 12),
                    const _FileTypeHint(),
                  ],
                ),
              ),
            )
          else
            // Documents exist: compact buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add new policy'),
                      onPressed: _pickFile,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.playlist_add_rounded, size: 18),
                      label: Text(S.batchPickMultiple),
                      onPressed: _pickFiles,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          CoverWiseSectionLabel(
            'Saved policies',
            trailing: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(documentsProvider),
              tooltip: 'Refresh saved policies',
            ),
          ),
          Expanded(
            child: DocumentsList(
              onDocumentSelectedForQA: (documentId) {
                Navigator.pushNamed(context, '/qa', arguments: documentId);
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Compact hint showing supported file types and size limit.
class _FileTypeHint extends StatelessWidget {
  const _FileTypeHint();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        _HintChip(
          icon: Icons.picture_as_pdf_outlined,
          label: 'PDF',
        ),
        _HintChip(
          icon: Icons.image_outlined,
          label: 'JPEG',
        ),
        _HintChip(
          icon: Icons.image_outlined,
          label: 'PNG',
        ),
        _HintChip(
          icon: Icons.sd_card_outlined,
          label: 'Max 20 MB',
        ),
      ],
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HintChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Batch Upload Progress Widget (P3-05) ─────────────────────────────────

class _BatchUploadProgress extends StatelessWidget {
  final List<BatchUploadEntry> entries;
  final bool isUploading;
  final int completed;
  final int failed;
  final VoidCallback onUpload;
  final VoidCallback onRetryFailed;
  final VoidCallback onClear;
  final VoidCallback onAddMore;
  final String Function(int) formatFileSize;

  const _BatchUploadProgress({
    required this.entries,
    required this.isUploading,
    required this.completed,
    required this.failed,
    required this.onUpload,
    required this.onRetryFailed,
    required this.onClear,
    required this.onAddMore,
    required this.formatFileSize,
  });

  int get _pendingCount =>
      entries.where((e) => e.state == BatchUploadState.pending).length;

  bool get _allDone =>
      entries.every((e) => e.isTerminal);
  double get _progress => entries.isEmpty
      ? 0
      : (completed + failed +
              entries.where((e) => e.state == BatchUploadState.skipped).length) /
          entries.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Flexible(
      fit: FlexFit.loose,
      child: SingleChildScrollView(
        child: CoverWiseSurface(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.playlist_add_check_rounded,
                        size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
isUploading
                             ? S.batchUploadingProgress(completed + failed, entries.length)
                            : _allDone
                                ? (failed == 0
                                    ? S.batchCompleted
                                    : S.batchSomeFailed)
                            : '${entries.length} files selected',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: isUploading ? null : onClear,
                      tooltip: S.batchDone,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Overall progress bar
                if (isUploading)
                  Column(
                    children: [
                      LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                      const SizedBox(height: 4),
                      Text(
                        '${completed + failed} / ${entries.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                if (isUploading) const SizedBox(height: 12),

                // Per-file list
                ...entries.map((entry) => _BatchFileTile(
                  entry: entry,
                  formatFileSize: formatFileSize,
                )),

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    if (!isUploading && !_allDone)
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                          label: Text(S.batchUploadingPendingCount(_pendingCount)),
                          onPressed: onUpload,
                        ),
                      ),
                    if (!isUploading && _allDone && failed > 0) ...[
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(S.batchRetryFailed),
                          onPressed: onRetryFailed,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (!isUploading && _allDone)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(S.batchAddMore),
                          onPressed: onAddMore,
                        ),
                      ),
                    if (isUploading)
                      Expanded(
                        child: Center(
                          child: Text(
                            S.batchUploadingProgress(completed + failed, entries.length),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single file row in the batch upload progress list.
class _BatchFileTile extends StatelessWidget {
  final BatchUploadEntry entry;
  final String Function(int) formatFileSize;

  const _BatchFileTile({
    required this.entry,
    required this.formatFileSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    IconData icon;
    Color iconColor;
    Widget? trailing;

    switch (entry.state) {
      case BatchUploadState.pending:
        icon = Icons.description_outlined;
        iconColor = cs.onSurfaceVariant;
        break;
      case BatchUploadState.uploading:
      case BatchUploadState.ocrProcessing:
        icon = Icons.cloud_upload_outlined;
        iconColor = cs.primary;
        trailing = const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case BatchUploadState.completed:
        icon = Icons.check_circle_outline;
        iconColor = Colors.green;
        break;
      case BatchUploadState.failed:
        icon = Icons.error_outline;
        iconColor = cs.error;
        break;
      case BatchUploadState.skipped:
        icon = Icons.block;
        iconColor = cs.onSurfaceVariant.withValues(alpha: 0.5);
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(icon, size: 20, color: iconColor),
        title: Text(
          entry.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          entry.statusLabel + (entry.fileSizeBytes > 0 ? ' · ${formatFileSize(entry.fileSizeBytes)}' : ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: entry.state == BatchUploadState.failed
                ? cs.error
                : cs.onSurfaceVariant,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}

/// Password input dialog for locked/encrypted PDFs.
///
/// Shown when the backend returns `pdf_password_required` (no password given)
/// or `pdf_password_invalid` (wrong password). Lets the user enter the
/// password inline and retries the upload.
class _PdfPasswordDialog extends StatefulWidget {
  final bool isRetry;

  const _PdfPasswordDialog({this.isRetry = false});

  @override
  State<_PdfPasswordDialog> createState() => _PdfPasswordDialogState();
}

class _PdfPasswordDialogState extends State<_PdfPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Password Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isRetry
                ? 'That password did not work. Please try again.'
                : 'This PDF is password-protected. Enter the password to read it.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'PDF Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              Navigator.pop(context, _controller.text);
            }
          },
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
