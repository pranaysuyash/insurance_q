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
import '../services/analytics_service.dart';
import '../services/app_state_store.dart';
import '../services/contact_service.dart';
import '../services/ml_ocr_service.dart';
import '../services/web_file_picker.dart';
import '../theme/coverwise_motion.dart';
import '../widgets/lead_capture_dialog.dart';
import '../widgets/phone_capture_sheet.dart';
import '../widgets/usage_stats_widget.dart';
import '../widgets/shared/coverwise_components.dart';
import 'documents_list.dart';
import 'processing_status_screen.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});
  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
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

  @override
  void initState() {
    super.initState();
    if (AppConfig.bootstrapPolicyDemo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _demoPolicyPreloaded) return;
        _demoPolicyPreloaded = true;
        _pickFile();
      });
    }
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

  Future<void> _pickFile() async {
    setState(() {
      _uploadError = null;
      _ocrResult = null;
    });

    if (AppConfig.bootstrapPolicyDemo) {
      try {
        final file = await _loadBundledDemoPolicyFile();
        if (!mounted) return;
        setState(() {
          _selectedFile = file;
          _selectedWebFile = null;
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
        setState(() {
          _selectedWebFile = picked;
          _selectedFile = null;
          _useOnDeviceOcr = false;
          _showUploadDetails = true;
        });
      }
      return;
    }

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null && mounted) {
      setState(() {
        _selectedFile = File(file.path);
        _selectedWebFile = null;
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

    // Consent: ask once, store permanently. On subsequent uploads, skip the dialog.
    final box = Hive.box(AppStateStore.boxName);
    final storedConsent = box.get('processing_consent_version') as String?;

    String consentVersion;
    if (storedConsent != null) {
      consentVersion = storedConsent;
    } else {
      // First upload - show consent + optional contact capture
      final savedContact = await ContactService.getSavedContact();
      if (!mounted) return;
      final leadInfo = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => LeadCaptureDialog(
          initialEmail: savedContact['email'],
          initialPhone: savedContact['phone'],
          isRequired: false,
        ),
      );

      if (leadInfo == null && mounted) return;

      consentVersion = leadInfo!['processing_consent_version'] as String;
      await box.put('processing_consent_version', consentVersion);

      if (leadInfo['save'] == true) {
        await ContactService.saveContact(
            email: leadInfo['email'],
            phone: leadInfo['phone'],
            saveForFuture: true);
      }
    }

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
            _uploadError = result['message'] ??
                'You have reached the document storage limit.';
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(_uploadError!), backgroundColor: Colors.orange),
          );
          return;
        }

        if (result['error'] == 'pdf_password_required' ||
            result['error'] == 'pdf_password_invalid' ||
            result['error'] == 'pdf_unreadable') {
          setState(() {
            _uploadError = result['message']?.toString() ??
                'This PDF could not be opened.';
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
              ? '$selectedName saved locally; will sync when online'
              : '$selectedName saved locally (offline mode)';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
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

  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _selectedWebFile = null;
      _useOnDeviceOcr = false;
      _ocrResult = null;
      _uploadError = null;
      _showUploadDetails = false;
    });
  }

  Future<void> _refreshDocumentTypes() async {
    setState(() => _isUploading = true);
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Refreshing document types...'),
            duration: Duration(seconds: 2)),
      );
      await ref.read(documentServiceProvider).refreshAllDocumentTypes();
      ref.invalidate(documentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Document types refreshed successfully!'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error refreshing document types: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshDocumentTypes,
              tooltip: 'Refresh Document Types'),
        ],
      ),
      body: Column(
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
          if (_showUploadDetails ||
              _selectedFile != null ||
              _selectedWebFile != null)
            CoverWiseSurface(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Add a policy file',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        if (_selectedFile != null || _selectedWebFile != null)
                          IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _clearSelection,
                              tooltip: 'Clear selection'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedFile == null && _selectedWebFile == null)
                      Center(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('Select Document'),
                          onPressed: _pickFile,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12)),
                        ),
                      ),
                    if (_selectedFile != null || _selectedWebFile != null) ...[
                      Row(
                        children: [
                          CoverWiseIconBadge(
                            icon: Icons.description_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 40,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedWebFile?.name ??
                                  _selectedFile!.path.split('/').last,
                              overflow: TextOverflow.ellipsis,
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
                          title:
                              const Text('Read scanned pages on this device'),
                          subtitle: const Text(
                            'Uses on-device text recognition. Your original file is still uploaded and remains the source of truth.',
                          ),
                          secondary:
                              const Icon(Icons.document_scanner_outlined),
                        ),
                        if (_useOnDeviceOcr)
                          DropdownButtonFormField<OnDeviceOcrScript>(
                            value: _onDeviceOcrScript,
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
                                        const CircularProgressIndicator(),
                                        if (_isReadingOnDevice) ...[
                                          const SizedBox(height: 10),
                                          const Text(
                                              'Reading pages on this device…'),
                                        ],
                                      ],
                                    ),
                                  )
                                : FilledButton.icon(
                                    icon:
                                        const Icon(Icons.cloud_upload_outlined),
                                    label: const Text('Upload Selected File'),
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
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: FilledButton.icon(
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Add policy file'),
                  onPressed: _pickFile,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Saved policies',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(documentsProvider),
                  tooltip: 'Refresh list',
                ),
              ],
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
    );
  }
}
