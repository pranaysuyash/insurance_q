import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:hive/hive.dart';
import '../models/document_model.dart';
import '../providers/service_providers.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../providers/family_providers.dart';
import '../providers/questions_provider.dart';
import '../services/app_state_repository.dart';
import '../services/app_state_store.dart';
import '../utils/document_icons.dart';
import 'document_preview_screen.dart';

class DocumentsList extends ConsumerWidget {
  final Function(String)? onDocumentSelectedForQA;

  const DocumentsList({super.key, this.onDocumentSelectedForQA});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);

    return documentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading documents: $e',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: () => ref.invalidate(documentsProvider),
                child: const Text('Retry')),
          ],
        ),
      ),
      data: (documents) {
        if (documents.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No documents yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
                SizedBox(height: 8),
                Text('Upload a document to get started',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(documentsProvider),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('${documents.length}/5 documents (free storage limit)',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.blue)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    final processingState = doc.processingState;
                    final isReady = processingState == 'completed' ||
                        processingState == 'ready';
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ExpansionTile(
                        leading: Icon(iconForDocumentType(doc.documentType),
                            color: colorForDocumentType(doc.documentType)),
                        title: Text(doc.filename,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Uploaded: ${doc.formattedUploadDate} • ${_processingLabel(processingState)}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _metadataRow('Local ID', doc.id),
                                if (doc.remoteId != null)
                                  _metadataRow('Backend ID', doc.remoteId!),
                                _metadataRow(
                                    'Type', doc.documentType ?? 'Unknown'),
                                _metadataRow(
                                    'Upload Date', doc.formattedUploadDate),
                                _metadataRow(
                                    'Analysis Date', doc.formattedAnalyzedDate),
                                if (doc.size != null)
                                  _metadataRow('Size', doc.formattedFileSize),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (doc.localFilePath != null)
                                      TextButton.icon(
                                        icon: const Icon(Icons.visibility),
                                        label: const Text('Preview'),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  DocumentPreviewScreen(
                                                filePath: doc.localFilePath!,
                                                filename: doc.filename,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    if (doc.localFilePath != null)
                                      const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.question_answer),
                                      label: Text(isReady
                                          ? 'Ask Questions'
                                          : 'Reading policy'),
                                      onPressed: isReady
                                          ? () {
                                              if (onDocumentSelectedForQA !=
                                                  null) {
                                                onDocumentSelectedForQA!(
                                                    doc.id);
                                              } else {
                                                Navigator.pushNamed(
                                                    context, '/qa',
                                                    arguments: doc.id);
                                              }
                                            }
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.swap_horiz),
                                      label: const Text('Replace'),
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.orange),
                                      onPressed: () =>
                                          _replaceDocument(context, ref, doc),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Delete'),
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.red),
                                      onPressed: () =>
                                          _deleteDocument(context, ref, doc),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _replaceDocument(
      BuildContext context, WidgetRef ref, InsuranceDocument document) async {
    // Import needed
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _DocumentReplaceScreen(document: document),
        ),
      );
    }
  }

  Future<void> _deleteDocument(
      BuildContext context, WidgetRef ref, InsuranceDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content:
            Text('Are you sure you want to delete "${document.filename}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success =
            await ref.read(documentServiceProvider).deleteDocument(document.id);
        if (success) {
          // Cascade: remove derived data and invalidate all dependents
          // so the UI stays consistent (dashboard, QA, summaries, family).
          ref.read(policySummariesProvider.notifier).deleteSummary(document.id);

          // Clear stale selected document pointer if it pointed at this doc
          final selectedId = AppStateRepository.getSelectedDocumentId();
          if (selectedId == document.id) {
            await AppStateRepository.setSelectedDocumentId(null);
            ref.read(selectedDocumentProvider.notifier).state = null;
          }

          // Invalidate the document list (all screens watching rebuild)
          ref.invalidate(documentsProvider);

          // Invalidate family members (auto-detected ones may have come
          // from this document)
          refreshManualFamilyMembers(ref);

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document deleted successfully')),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting document: $e')),
        );
      }
    }
  }

  Widget _metadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _processingLabel(String? state) {
    switch (state) {
      case 'received':
      case 'processing':
        return 'Reading policy';
      case 'pending':
      case 'pending_upload':
        return 'Waiting to sync';
      case 'failed':
        return 'Needs attention';
      case 'completed':
      case 'ready':
        return 'Ready for questions';
      default:
        return 'Saved';
    }
  }
}

/// Dedicated screen for replacing a document with a new file.
class _DocumentReplaceScreen extends ConsumerStatefulWidget {
  final InsuranceDocument document;
  const _DocumentReplaceScreen({required this.document});

  @override
  ConsumerState<_DocumentReplaceScreen> createState() =>
      _DocumentReplaceScreenState();
}

class _DocumentReplaceScreenState extends ConsumerState<_DocumentReplaceScreen> {
  File? _selectedFile;
  bool _isUploading = false;
  String? _error;

  Future<void> _pickReplacement() async {
    final typeGroup = XTypeGroup(
      label: 'Documents',
      uniformTypeIdentifiers: ['com.adobe.pdf', 'public.image'],
      mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null && mounted) {
      setState(() {
        _selectedFile = File(file.path);
        _error = null;
      });
    }
  }

  Future<void> _confirmReplacement() async {
    if (_selectedFile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace Document?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will delete "${widget.document.filename}" and replace it with the new file.'),
            const SizedBox(height: 8),
            const Text(
              "The old document's analysis will be lost. The new document will be processed fresh.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _performReplacement();
    }
  }

  Future<void> _performReplacement() async {
    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final box = Hive.box(AppStateStore.boxName);
      final consentVersion = box.get('processing_consent_version') as String? ?? 'v1';

      final result = await ref.read(documentServiceProvider).replaceDocument(
        widget.document.id,
        _selectedFile!,
        processingConsentVersion: consentVersion,
      );

      if (!mounted) return;

      if (result.containsKey('error')) {
        setState(() {
          _error = result['message']?.toString() ?? 'Replacement failed';
          _isUploading = false;
        });
        return;
      }

      // Refresh document list
      ref.invalidate(documentsProvider);
      ref.invalidate(policySummariesProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document replaced successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Replacement failed: $e';
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Replace Document'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Document',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(widget.document.filename),
                    Text('Uploaded: ${widget.document.formattedUploadDate}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedFile != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(_selectedFile!.path.split('/').last),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedFile = null),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 16),
            ],
            const Spacer(),
            if (_isUploading)
              const Center(child: CircularProgressIndicator())
            else ...[
              ElevatedButton.icon(
                onPressed: _pickReplacement,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Select Replacement File'),
              ),
              if (_selectedFile != null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _confirmReplacement,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Replace Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
