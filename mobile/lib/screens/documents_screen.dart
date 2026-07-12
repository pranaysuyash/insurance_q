import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../providers/service_providers.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../services/contact_service.dart';
import '../widgets/lead_capture_dialog.dart';
import '../widgets/usage_stats_widget.dart';
import 'documents_list.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});
  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  File? _selectedFile;
  bool _isUploading = false;
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

  Future<File> _loadBundledDemoPolicyFile() async {
    final byteData = await rootBundle.load('assets/demo/policy.pdf');
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(path.join(tempDir.path, 'policy_demo.pdf'));
    final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
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
        setState(() { _selectedFile = file; _showUploadDetails = true; });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() => _uploadError = 'Failed to load bundled policy sample: $e');
        return;
      }
    }

    final typeGroup = XTypeGroup(
      label: 'Documents',
      uniformTypeIdentifiers: ['com.adobe.pdf', 'public.image'],
      mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null && mounted) {
      setState(() { _selectedFile = File(file.path); _showUploadDetails = true; });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;

    final duplicate = await ref.read(documentServiceProvider).checkForDuplicateDocument(_selectedFile!);

    if (duplicate != null && mounted) {
      final shouldProceed = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A similar document already exists:'),
              const SizedBox(height: 8),
              Text(duplicate.filename, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Uploaded on: ${duplicate.formattedUploadDate}'),
              const SizedBox(height: 16),
              const Text(
                'Uploading this document will count against your storage limit. Do you want to replace the existing document or keep both?',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, 'replace'), child: const Text('Replace')),
            ElevatedButton(onPressed: () => Navigator.pop(context, 'keep'), child: const Text('Keep Both')),
          ],
        ),
      );

      if (shouldProceed == 'cancel' || shouldProceed == null) return;

      if (shouldProceed == 'replace' && mounted) {
        setState(() => _isUploading = true);
        final deleted = await ref.read(documentServiceProvider).deleteDocument(duplicate.id);
        if (!deleted && mounted) {
          setState(() { _isUploading = false; _uploadError = 'Failed to delete existing document'; });
          return;
        }
      }
    }

    if (!mounted) return;

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

    if (leadInfo != null && leadInfo['save'] == true) {
      await ContactService.saveContact(email: leadInfo['email'], phone: leadInfo['phone'], saveForFuture: true);
    }

    setState(() { _isUploading = true; _uploadError = null; _ocrResult = null; });

    try {
      final result = await ref.read(documentServiceProvider).uploadDocumentWithLimitCheck(
        _selectedFile!,
        email: leadInfo?['email'],
        phone: leadInfo?['phone'],
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
            _uploadError = result['message'] ?? 'You have reached the document storage limit.';
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_uploadError!), backgroundColor: Colors.orange),
          );
          return;
        }

        setState(() => _ocrResult = result);
        ref.invalidate(documentsProvider);

        // Fetch policy summary from backend (single API call)
        final documentId = result['document_id']?.toString();
        final documentType = result['document_type']?.toString() ?? 'Unknown';
        final isOfflineFlag = result['offline_mode'] == true;
        if (documentId != null && !isOfflineFlag) {
          ref.read(policySummariesProvider.notifier).fetchFromBackend(documentId, documentType);
        }

        final isOfflineModeFlag = isOfflineFlag;
        final isQueuedOnly = result['status'] == 'pending_upload';
        final message = isQueuedOnly
            ? '${_selectedFile?.path.split('/').last ?? 'Document'} saved locally; sync pending'
            : isOfflineModeFlag
                ? '${_selectedFile?.path.split('/').last ?? 'Document'} saved locally (offline mode)'
                : '${_selectedFile?.path.split('/').last ?? 'Document'} uploaded successfully!';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: (isOfflineModeFlag || isQueuedOnly) ? Colors.orange : null),
        );

        setState(() { _selectedFile = null; _showUploadDetails = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _uploadError = e.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _clearSelection() {
    setState(() { _selectedFile = null; _ocrResult = null; _uploadError = null; _showUploadDetails = false; });
  }

  Future<void> _refreshDocumentTypes() async {
    setState(() => _isUploading = true);
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refreshing document types...'), duration: Duration(seconds: 2)),
      );
      await ref.read(documentServiceProvider).refreshAllDocumentTypes();
      ref.invalidate(documentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document types refreshed successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing document types: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Documents'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshDocumentTypes, tooltip: 'Refresh Document Types'),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: UsageStatsWidget(),
          ),
          if (_showUploadDetails || _selectedFile != null)
            Card(
              margin: const EdgeInsets.all(16.0),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Upload New Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_selectedFile != null)
                          IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection, tooltip: 'Clear selection'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedFile == null)
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('Select Document'),
                          onPressed: _pickFile,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                        ),
                      ),
                    if (_selectedFile != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.insert_drive_file, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_selectedFile!.path.split('/').last, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: _isUploading
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                                icon: const Icon(Icons.cloud_upload),
                                label: const Text('Upload Selected File'),
                                onPressed: _uploadFile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                      ),
                    ],
                    if (_uploadError != null) ...[
                      const SizedBox(height: 12),
                      Text('Error: $_uploadError', style: const TextStyle(color: Colors.red)),
                    ],
                    if (_ocrResult != null) ...[
                      const SizedBox(height: 12),
                      const Text('Upload & OCR Successful!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Upload a Document'),
                  onPressed: _pickFile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Your Documents', style: Theme.of(context).textTheme.headlineSmall),
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
