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
import '../utils/policy_type.dart';
import '../widgets/document_type_picker.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_scene.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../utils/app_error.dart';
import '../widgets/shared/error_widget.dart';
import 'document_preview_screen.dart';

class DocumentsList extends ConsumerWidget {
  final Function(String)? onDocumentSelectedForQA;

  const DocumentsList({super.key, this.onDocumentSelectedForQA});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);

    return documentsAsync.when(
      loading: () => Center(
        child: Semantics(
          label: 'Loading saved policies',
          child: const CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => AppErrorView(
        message: 'We could not load your saved policies.',
        onRetry: () => ref.invalidate(documentsProvider),
      ),
      data: (documents) {
        if (documents.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.folder_open_outlined,
            title: 'No saved policies yet',
            subtitle:
                'Add a PDF or policy image above to start building your library.',
            scene: CoverWiseSceneKind.firstPolicy,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(documentsProvider),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Semantics(
                  label:
                      '${documents.length} of 5 free policy storage slots used',
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${documents.length} of 5 free policy slots used',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
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
                    final typeColor = colorForDocumentType(doc.documentType);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        leading: CoverWiseIconBadge(
                          icon: iconForDocumentType(doc.documentType),
                          color: typeColor,
                          size: 46,
                        ),
                        title: Text(doc.filename,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${doc.formattedUploadDate} • ${_processingLabel(processingState)}',
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _metadataRow(context, 'Local ID', doc.id),
                                if (doc.remoteId != null)
                                  _metadataRow(
                                      context, 'Backend ID', doc.remoteId!),
                                _metadataRow(context, 'Type',
                                    doc.documentType ?? 'Unknown'),
                                _metadataRow(context, 'Upload Date',
                                    doc.formattedUploadDate),
                                _metadataRow(context, 'Analysis Date',
                                    doc.formattedAnalyzedDate),
                                if (doc.size != null)
                                  _metadataRow(
                                      context, 'Size', doc.formattedFileSize),
                                const SizedBox(height: 16),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 4,
                                  runSpacing: 4,
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
                                    TextButton.icon(
                                      icon: const Icon(Icons.category_outlined),
                                      label: const Text('Change type'),
                                      onPressed: () => _changeDocumentType(context, ref, doc),
                                    ),
                                    if (doc.localFilePath != null)
                                      TextButton.icon(
                                        icon: const Icon(Icons.forum_outlined),
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
                                    // Security audit P0-03 (2026-07-18):
                                    // "Replace" uploads a new server
                                    // document and only removes the old
                                    // local record. The old server
                                    // document remains in Supabase,
                                    // Supabase Storage, and the RAG
                                    // index. Disabling until the
                                    // server-side orphan is handled in
                                    // Security Phase 3.
                                    Tooltip(
                                      message:
                                          'Replace is temporarily disabled. The old document is still on CoverWise servers and will be cleared with the next account sync (see Security Phase 3).',
                                      child: TextButton.icon(
                                        icon: const Icon(
                                            Icons.find_replace_outlined),
                                        label: const Text('Replace'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .tertiary
                                              .withValues(alpha: 0.38),
                                        ),
                                        onPressed: null,
                                      ),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete_outline),
                                      // Security audit P0-02 (2026-07-18):
                                      // the "Delete" action only removes the
                                      // local copy. The old copy on the
                                      // server is not deleted by this
                                      // button (until remote-first deletion
                                      // ships in Security Phase 3). Honest
                                      // copy: "Remove from this device".
                                      label: const Text('Remove from this device'),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            Theme.of(context).colorScheme.error,
                                      ),
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

  Future<void> _changeDocumentType(
      BuildContext context, WidgetRef ref, InsuranceDocument document) async {
    final currentType = classifyPolicyType(document.documentType);
    final newType = await showDocumentTypePicker(context, currentType: currentType);
    if (newType == null || newType == currentType) return;
    // Persist the corrected type locally so the next getDocuments() call
    // reflects the user's choice without waiting for a backend re-classify.
    final updated = InsuranceDocument(
      id: document.id,
      remoteId: document.remoteId,
      filename: document.filename,
      uploadedOn: document.uploadedOn,
      documentType: canonicalTypeName(newType),
      insurer: document.insurer,
      status: document.status,
      syncState: document.syncState,
      processingState: document.processingState,
      processingCompletedAt: document.processingCompletedAt,
      size: document.size,
      localFilePath: document.localFilePath,
      policyHolders: document.policyHolders,
    );
    try {
      await ref.read(documentServiceProvider).updateDocumentType(updated);
      ref.invalidate(documentsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Type changed to ${canonicalTypeName(newType)}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppError.userMessage(e))),
      );
    }
  }

  // Security audit P0-03 (2026-07-18): the Replace button is disabled
  // in the document list, so this handler is currently unreachable from
  // the UI. The handler is preserved for Security Phase 3, which will
  // re-enable Replace once the old server document is atomically
  // deleted server-side. Removing the handler now would lose the
  // navigation contract that _DocumentReplaceScreen relies on.
  // ignore: unused_element
  Future<void> _replaceDocument(
      BuildContext context, WidgetRef ref, InsuranceDocument document) async {
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
        // Security audit P0-02: honest copy. The action removes the
        // local copy only; the server copy remains until remote-first
        // deletion ships in Security Phase 3.
        title: const Text('Remove from this device?'),
        content: Text(
          'This removes "${document.filename}" from this device. '
          'The copy on CoverWise servers is NOT deleted by this action. '
          'You can clear the server copy from your account later.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove from this device')),
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
            // Security audit P0-02: honest copy. The local copy is
            // removed; the server copy is not.
            const SnackBar(
                content: Text(
                    'Removed from this device. The server copy was not affected.')),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppError.contextual(error: e, operation: 'delete_document'))),
        );
      }
    }
  }

  Widget _metadataRow(BuildContext context, String label, String value) {
    final icon = switch (label) {
      'Local ID' || 'Server ID' => Icons.tag_rounded,
      'Type' => Icons.category_outlined,
      'Upload Date' => Icons.upload_file_outlined,
      'Analysis Date' => Icons.manage_search_rounded,
      'Status' => Icons.info_outline_rounded,
      _ => Icons.description_outlined,
    };
    return CoverWiseMetadataRow(
      icon: icon,
      label: label,
      value: value,
    );
  }

  String _processingLabel(String? state) {
    switch (state) {
      case 'received':
      case 'processing':
        return 'Reading policy';
      case 'pending':
      case 'pending_upload':
        return 'Server upload required';
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

class _DocumentReplaceScreenState
    extends ConsumerState<_DocumentReplaceScreen> {
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
            Text(
                'This will delete "${widget.document.filename}" and replace it with the new file.'),
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
      final consentVersion =
          box.get('processing_consent_version') as String? ?? 'v1';

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
          _error = AppError.userMessage(e);
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
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
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
                    tooltip: 'Clear replacement file',
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
