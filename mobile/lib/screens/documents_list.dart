import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../providers/service_providers.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../providers/family_providers.dart';
import '../providers/questions_provider.dart';
import '../services/app_state_repository.dart';
import '../utils/document_icons.dart';

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
            Text('Error loading documents: $e', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => ref.invalidate(documentsProvider), child: const Text('Retry')),
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
                Text('No documents yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                SizedBox(height: 8),
                Text('Upload a document to get started', style: TextStyle(color: Colors.grey)),
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
                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('${documents.length}/5 documents (free storage limit)',
                      style: const TextStyle(fontSize: 12, color: Colors.blue)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ExpansionTile(
                        leading: Icon(iconForDocumentType(doc.documentType), color: colorForDocumentType(doc.documentType)),
                        title: Text(doc.filename, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Uploaded: ${doc.formattedUploadDate}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _metadataRow('Local ID', doc.id),
                                if (doc.remoteId != null) _metadataRow('Backend ID', doc.remoteId!),
                                _metadataRow('Type', doc.documentType ?? 'Unknown'),
                                _metadataRow('Upload Date', doc.formattedUploadDate),
                                _metadataRow('Analysis Date', doc.formattedAnalyzedDate),
                                if (doc.size != null) _metadataRow('Size', doc.formattedFileSize),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.question_answer),
                                      label: const Text('Ask Questions'),
                                      onPressed: () {
                                        if (onDocumentSelectedForQA != null) {
                                          onDocumentSelectedForQA!(doc.id);
                                        } else {
                                          Navigator.pushNamed(context, '/qa', arguments: doc.id);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Delete'),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      onPressed: () => _deleteDocument(context, ref, doc),
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

  Future<void> _deleteDocument(BuildContext context, WidgetRef ref, InsuranceDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${document.filename}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await ref.read(documentServiceProvider).deleteDocument(document.id);
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
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
