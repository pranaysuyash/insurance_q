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
import '../widgets/shared/coverwise_snackbar.dart';
import '../widgets/shared/coverwise_scene.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../widgets/document_thumbnail.dart';
import '../l10n/app_localizations_gen.dart';
import '../utils/app_error.dart';
import '../widgets/shared/error_widget.dart';
import 'document_preview_screen.dart';

/// Sort modes for the document list.
enum DocsSortMode {
  dateDesc('date_desc'),
  dateAsc('date_asc'),
  nameAsc('name_asc'),
  nameDesc('name_desc'),
  type('type');

  final String value;
  const DocsSortMode(this.value);

  static DocsSortMode fromString(String? value) {
    return DocsSortMode.values.firstWhere(
      (m) => m.value == value,
      orElse: () => DocsSortMode.dateDesc,
    );
  }
}

/// Applies the active sort mode to the document list.
@visibleForTesting
List<InsuranceDocument> applySort(
    List<InsuranceDocument> docs, DocsSortMode mode) {
  final sorted = List<InsuranceDocument>.from(docs);
  switch (mode) {
    case DocsSortMode.dateDesc:
      sorted.sort((a, b) => b.uploadedOn.compareTo(a.uploadedOn));
    case DocsSortMode.dateAsc:
      sorted.sort((a, b) => a.uploadedOn.compareTo(b.uploadedOn));
    case DocsSortMode.nameAsc:
      sorted.sort((a, b) =>
          a.filename.toLowerCase().compareTo(b.filename.toLowerCase()));
    case DocsSortMode.nameDesc:
      sorted.sort((a, b) =>
          b.filename.toLowerCase().compareTo(a.filename.toLowerCase()));
    case DocsSortMode.type:
      sorted.sort((a, b) {
        final ta = canonicalTypeName(classifyPolicyType(a.documentType));
        final tb = canonicalTypeName(classifyPolicyType(b.documentType));
        final cmp = ta.compareTo(tb);
        return cmp != 0 ? cmp : b.uploadedOn.compareTo(a.uploadedOn);
      });
  }
  return sorted;
}

/// Applies the active type filter to the document list.
@visibleForTesting
List<InsuranceDocument> applyFilter(
    List<InsuranceDocument> docs, String? filterType) {
  if (filterType == null || filterType.isEmpty) return docs;
  return docs.where((d) {
    final t = canonicalTypeName(classifyPolicyType(d.documentType));
    return t.toLowerCase() == filterType.toLowerCase();
  }).toList();
}

/// Collects the distinct document types present in the list (for the filter chips).
@visibleForTesting
List<String> distinctTypes(List<InsuranceDocument> docs) {
  final types = <String>{};
  for (final d in docs) {
    types.add(canonicalTypeName(classifyPolicyType(d.documentType)));
  }
  final list = types.toList()..sort();
  return list;
}

/// A policy can be queried from the server even when its source PDF is not
/// cached on this device. Pending uploads remain ineligible until they have a
/// stable remote identity.
@visibleForTesting
bool canAskQuestions(InsuranceDocument document, {required bool isReady}) {
  return isReady &&
      (document.localFilePath != null || document.remoteId != null);
}

class DocumentsList extends ConsumerStatefulWidget {
  final Function(String)? onDocumentSelectedForQA;

  const DocumentsList({super.key, this.onDocumentSelectedForQA});

  @override
  ConsumerState<DocumentsList> createState() => _DocumentsListState();
}

class _DocumentsListState extends ConsumerState<DocumentsList> {
  late DocsSortMode _sortMode;
  String? _filterType;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    final box = Hive.box(AppStateStore.boxName);
    _sortMode = DocsSortMode.fromString(
        box.get(AppStateStore.docsSortModeKey) as String?);
    _filterType = box.get(AppStateStore.docsFilterTypeKey) as String?;
  }

  Future<void> _saveSortMode(DocsSortMode mode) async {
    setState(() => _sortMode = mode);
    final box = Hive.box(AppStateStore.boxName);
    await box.put(AppStateStore.docsSortModeKey, mode.value);
  }

  Future<void> _saveFilterType(String? type) async {
    setState(() => _filterType = type);
    final box = Hive.box(AppStateStore.boxName);
    await box.put(AppStateStore.docsFilterTypeKey, type);
  }

  Future<void> _downloadAndPreview(
      BuildContext context, WidgetRef ref, InsuranceDocument document) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cached = await ref
          .read(documentServiceProvider)
          .cacheRemoteSource(document.id);
      ref.invalidate(documentsProvider);
      if (cached.localFilePath == null) return;
      if (!mounted) return;
      await Navigator.push(
        context, // ignore: use_build_context_synchronously
        MaterialPageRoute(
          builder: (_) => DocumentPreviewScreen(
            filePath: cached.localFilePath!,
            filename: cached.filename,
            documentId: cached.remoteId,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content:
              Text('We could not download the source document. Please retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
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

        // Separate active vs archived, apply sort + filter
        final activeDocs = documents.where((d) => !d.isArchived).toList();
        final archivedDocs = _showArchived
            ? documents.where((d) => d.isArchived).toList()
            : <InsuranceDocument>[];
        final displayDocs = _showArchived
            ? [...activeDocs, ...archivedDocs]
            : activeDocs;
        final filtered = applyFilter(displayDocs, _filterType);
        final sorted = applySort(filtered, _sortMode);
        final totalSlots = 5;
        final usedSlots = activeDocs.length;
        final remainingSlots = totalSlots - usedSlots;
        final showLimitWarning = usedSlots >= totalSlots - 1;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(documentsProvider),
          child: Column(
            children: [
              // Slot count + limit warning
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      label: l10n.docsSlotsUsed(usedSlots),
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
                              _filterType != null
                                  ? l10n.docsFilterResultCount(
                                      filtered.length, documents.length)
                                  : l10n.docsSlotsUsed(usedSlots),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showLimitWarning && usedSlots > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: remainingSlots == 0
                              ? Theme.of(context)
                                  .colorScheme
                                  .errorContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              remainingSlots == 0
                                  ? Icons.block
                                  : Icons.info_outline_rounded,
                              size: 14,
                              color: remainingSlots == 0
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context)
                                      .colorScheme
                                      .onTertiaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              remainingSlots == 0
                                  ? l10n.docsLimitWarning
                                  : l10n.docsLimitRemaining(remainingSlots),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: remainingSlots == 0
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context)
                                        .colorScheme
                                        .onTertiaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_showArchived && archivedDocs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '${archivedDocs.length} archived polic${archivedDocs.length == 1 ? 'y' : 'ies'}',
                              style: TextStyle(
                                fontSize: 11,
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
              ),
              // Sort / Filter bar
              _SortFilterBar(
                sortMode: _sortMode,
                filterType: _filterType,
                availableTypes: distinctTypes(documents),
                onSortChanged: _saveSortMode,
                onFilterChanged: _saveFilterType,
                showArchived: _showArchived,
                onShowArchivedChanged: (selected) {
                  setState(() => _showArchived = selected);
                },
              ),
              // Document list
              Expanded(
                child: sorted.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.filter_list_off_rounded,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              const SizedBox(height: 12),
                              Text(
                                'No policies match this filter',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _saveFilterType(null),
                                child: const Text('Clear filter'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: sorted.length,
                        itemBuilder: (context, index) {
                          final doc = sorted[index];
                          final processingState = doc.processingState;
                          final isReady = processingState == 'completed' ||
                              processingState == 'ready';
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              leading: DocumentThumbnail(
                                localFilePath: doc.localFilePath,
                                documentType: doc.documentType,
                                size: 46,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(doc.filename,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  if (doc.isArchived)
                                    Container(
                                      margin:
                                          const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.archive_outlined,
                                              size: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant),
                                          const SizedBox(width: 2),
                                          Text(
                                            l10n.docsArchived,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  InkWell(
                                    onTap: () =>
                                        _renameDocument(context, ref, doc),
                                    borderRadius: BorderRadius.circular(16),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child:
                                          Icon(Icons.edit_outlined, size: 16),
                                    ),
                                  ),
                                ],
                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _metadataRow(context, 'Local ID', doc.id),
                                      if (doc.remoteId != null)
                                        _metadataRow(context, 'Backend ID',
                                            doc.remoteId!),
                                      _metadataRow(context, 'Type',
                                          doc.documentType ?? 'Unknown'),
                                      _metadataRow(context, 'Upload Date',
                                          doc.formattedUploadDate),
                                      _metadataRow(context, 'Analysis Date',
                                          doc.formattedAnalyzedDate),
                                      if (doc.size != null)
                                        _metadataRow(context, 'Size',
                                            doc.formattedFileSize),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        alignment: WrapAlignment.end,
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: [
                                          if (doc.localFilePath != null)
                                            TextButton.icon(
                                              icon:
                                                  const Icon(Icons.visibility),
                                              label: Text(l10n.docsPreview),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        DocumentPreviewScreen(
                                                      filePath:
                                                          doc.localFilePath!,
                                                      filename: doc.filename,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          if (doc.localFilePath == null &&
                                              doc.remoteId != null)
                                            TextButton.icon(
                                              icon: const Icon(
                                                  Icons.download_outlined),
                                              label:
                                                  Text(l10n.docsDownloadSource),
                                              onPressed: () =>
                                                  _downloadAndPreview(
                                                      context, ref, doc),
                                            ),
                                          if (doc.syncState == 'pending_upload')
                                            TextButton.icon(
                                              icon: const Icon(
                                                  Icons.cloud_upload_outlined),
                                              label: Text(l10n.docsRetryUpload),
                                              onPressed: () =>
                                                  _retryUpload(context, ref),
                                            ),
                                          TextButton.icon(
                                            icon: const Icon(
                                                Icons.category_outlined),
                                            label: Text(l10n.docsChangeType),
                                            onPressed: () =>
                                                _changeDocumentType(
                                                    context, ref, doc),
                                          ),
                                          if (canAskQuestions(doc,
                                              isReady: isReady))
                                            TextButton.icon(
                                              icon: const Icon(
                                                  Icons.forum_outlined),
                                              label: Text(isReady
                                                  ? l10n.docsAskQuestions
                                                  : l10n.docsReadingPolicy),
                                              onPressed: isReady
                                                  ? () {
                                                      if (widget
                                                              .onDocumentSelectedForQA !=
                                                          null) {
                                                        widget.onDocumentSelectedForQA!(
                                                            doc.id);
                                                      } else {
                                                        Navigator.pushNamed(
                                                            context, '/qa',
                                                            arguments: doc.id);
                                                      }
                                                    }
                                                  : null,
                                            ),
                                          Tooltip(
                                            message:
                                                'Replace is temporarily disabled. The old document is still on CoverWise servers and will be cleared with the next account sync (see Security Phase 3).',
                                            child: TextButton.icon(
                                              icon: const Icon(
                                                  Icons.find_replace_outlined),
                                              label: Text(l10n.docsReplace),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .tertiary
                                                        .withValues(
                                                            alpha: 0.38),
                                              ),
                                              onPressed: null,
                                            ),
                                          ),
                                          if (doc.isArchived)
                                            TextButton.icon(
                                              icon: const Icon(
                                                  Icons.unarchive_outlined),
                                              label: Text(l10n.docsRestore),
                                              onPressed: () =>
                                                  _restoreDocument(
                                                      context, ref, doc),
                                            )
                                          else
                                            TextButton.icon(
                                              icon: const Icon(
                                                  Icons.archive_outlined),
                                              label: Text(l10n.docsArchive),
                                              onPressed: () =>
                                                  _archiveDocument(
                                                      context, ref, doc),
                                            ),
                                          TextButton.icon(
                                            icon: const Icon(
                                                Icons.delete_outline),
                                            label: Text(l10n.docsDeletePolicy),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                            onPressed: () => _deleteDocument(
                                                context, ref, doc),
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

  Future<void> _renameDocument(
      BuildContext context, WidgetRef ref, InsuranceDocument document) async {
    final l10n = AppLocalizationsGen.of(context);
    final controller = TextEditingController(text: document.filename);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.docsRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.docsRenameHint,
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (controller.text.trim().isNotEmpty) Navigator.pop(ctx, true);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(ctx, true),
            child: Text(l10n.docsRenameSave),
          ),
        ],
      ),
    );
    final newName = controller.text.trim();
    controller.dispose();

    if (confirmed != true || !mounted) return;

    if (newName.isEmpty || newName == document.filename) return;

    final updated = InsuranceDocument(
      id: document.id,
      remoteId: document.remoteId,
      filename: newName,
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
      policyHolders: document.policyHolders,
    );
    Object? error;
    try {
      await ref.read(documentServiceProvider).updateDocumentType(updated);
      ref.invalidate(documentsProvider);
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    if (error != null) {
      // ignore: use_build_context_synchronously
      CoverWiseSnackBar.error(context, AppError.userMessage(error),
          operation: 'rename policy');
    } else {
      // ignore: use_build_context_synchronously
      CoverWiseSnackBar.success(context, l10n.docsRenameSuccess);
    }
  }

  Future<void> _changeDocumentType(
      BuildContext context, WidgetRef ref, InsuranceDocument document) async {
    final l10n = AppLocalizationsGen.of(context);
    final currentType = classifyPolicyType(document.documentType);
    final newType =
        await showDocumentTypePicker(context, currentType: currentType);
    if (newType == null || newType == currentType) return;
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
      processingConsentVersion: document.processingConsentVersion,
      processingCompletedAt: document.processingCompletedAt,
      size: document.size,
      localFilePath: document.localFilePath,
      policyHolders: document.policyHolders,
    );
    Object? error;
    try {
      await ref.read(documentServiceProvider).updateDocumentType(updated);
      ref.invalidate(documentsProvider);
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    if (error != null) {
      // ignore: use_build_context_synchronously
      CoverWiseSnackBar.error(context, AppError.userMessage(error),
          operation: 'change document type');
    } else {
      CoverWiseSnackBar.success(
          context, // ignore: use_build_context_synchronously
          '${l10n.docsTypeChanged} ${canonicalTypeName(newType)}');
    }
  }

  Future<void> _archiveDocument(
      BuildContext context, WidgetRef ref, InsuranceDocument document) async {
    final l10n = AppLocalizationsGen.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.docsArchiveConfirmTitle),
        content: Text(l10n.docsArchiveConfirmContent(document.filename)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.docsArchive)),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final archived = await ref
          .read(documentServiceProvider)
          .archiveDocument(document.id);
      if (archived) {
        ref.invalidate(documentsProvider);
        if (mounted) {
          // ignore: use_build_context_synchronously
          CoverWiseSnackBar.success(context, l10n.docsArchivedSuccess);
        }
      }
    }
  }

  Future<void> _restoreDocument(
      BuildContext context, WidgetRef ref, InsuranceDocument document) async {
    final l10n = AppLocalizationsGen.of(context);
    final success = await ref
        .read(documentServiceProvider)
        .restoreDocument(document.id);
    if (success) {
      ref.invalidate(documentsProvider);
    }
    if (mounted) {
      // ignore: use_build_context_synchronously
      CoverWiseSnackBar.success(context, l10n.docsRestored);
    }
  }

  Future<void> _deleteDocument(
      BuildContext context, WidgetRef ref, InsuranceDocument document) async {
    final l10n = AppLocalizationsGen.of(context);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.docsDeletePolicyTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.docsDeletePolicyContent(document.filename)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.docsDeletePermanentWarning,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text(l10n.cancel)),
          TextButton.icon(
            icon: const Icon(Icons.archive_outlined, size: 18),
            onPressed: () => Navigator.pop(context, 'archive'),
            label: Text(l10n.docsArchive),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              child: Text(
                l10n.docsDeletePolicy,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              )),
        ],
      ),
    );

    if (action == 'archive') {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await _archiveDocument(context, ref, document);
      return;
    }

    if (action == 'delete') {
      bool? didDelete;
      Object? deleteError;
      try {
        didDelete =
            await ref.read(documentServiceProvider).deleteDocument(document.id);
        if (didDelete == true) {
          final documentIds = {document.id, document.backendId};
          for (final documentId in documentIds) {
            await ref
                .read(policySummariesProvider.notifier)
                .deleteSummary(documentId);
          }

          final selectedId = AppStateRepository.getSelectedDocumentId();
          await AppStateRepository.clearDocumentReferences(documentIds);
          if (selectedId != null && documentIds.contains(selectedId)) {
            ref.read(selectedDocumentProvider.notifier).setState(null);
          }

          ref.invalidate(documentsProvider);
          refreshManualFamilyMembers(ref);
        }
      } catch (e) {
        deleteError = e;
      }
      if (!mounted) return;
      if (deleteError != null) {
        // ignore: use_build_context_synchronously
        CoverWiseSnackBar.error(context,
            AppError.contextual(error: deleteError, operation: 'delete_document'),
            operation: 'delete policy');
      } else if (didDelete == true) {
        // ignore: use_build_context_synchronously
        CoverWiseSnackBar.info(context, l10n.docsDeleted);
      }
    }
  }

  Future<void> _retryUpload(BuildContext context, WidgetRef ref) async {
    Object? retryError;
    Map<String, dynamic>? result;
    try {
      result =
          await ref.read(documentServiceProvider).retryPendingUploads();
      ref.invalidate(documentsProvider);
    } catch (e) {
      retryError = e;
    }
    if (!mounted) return;
    if (retryError != null) {
      // ignore: use_build_context_synchronously
      CoverWiseSnackBar.error(context, AppError.userMessage(retryError),
          operation: 'retry policy upload');
    } else if ((result!['synced'] ?? 0) > 0) {
      // ignore: use_build_context_synchronously
      CoverWiseSnackBar.success(context, 'Policy upload resumed.');
    } else if ((result['pending'] ?? 0) > 0) {
      // ignore: use_build_context_synchronously
      CoverWiseSnackBar.info(context,
          'The connection is still unavailable. We will retry again.');
    } else if ((result['failed'] ?? 0) > 0) {
      CoverWiseSnackBar.error(
          context, // ignore: use_build_context_synchronously
          'This policy needs attention before it can be uploaded.',
          operation: 'retry policy upload');
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
    final l10n = AppLocalizationsGen.of(context);
    switch (state) {
      case 'received':
      case 'processing':
        return l10n.docsReadingPolicy;
      case 'pending':
      case 'pending_upload':
        return l10n.docsUploadRequired;
      case 'failed':
        return l10n.docsNeedsAttention;
      case 'completed':
      case 'ready':
        return l10n.docsReadyForQuestions;
      default:
        return l10n.docsSaved;
    }
  }
}

/// Compact sort / filter bar with horizontal chips.
class _SortFilterBar extends StatelessWidget {
  final DocsSortMode sortMode;
  final String? filterType;
  final List<String> availableTypes;
  final ValueChanged<DocsSortMode> onSortChanged;
  final ValueChanged<String?> onFilterChanged;
  final bool showArchived;
  final ValueChanged<bool> onShowArchivedChanged;

  const _SortFilterBar({
    required this.sortMode,
    required this.filterType,
    required this.availableTypes,
    required this.onSortChanged,
    required this.onFilterChanged,
    required this.showArchived,
    required this.onShowArchivedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // Sort chip
            _SortFilterChip(
              icon: Icons.sort,
              label: l10n.docsSortLabel,
              isActive: sortMode != DocsSortMode.dateDesc,
              onTap: () => _showSortPicker(context),
            ),
            const SizedBox(width: 6),
            // "Show archived" toggle chip
            FilterChip(
              avatar: const Icon(Icons.archive_outlined, size: 14),
              label: Text(
                  l10n.docsShowArchived, style: const TextStyle(fontSize: 12)),
              selected: showArchived,
              onSelected: onShowArchivedChanged,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
            // "All" filter chip to clear type filter
            FilterChip(
              label:
                  Text(l10n.docsFilterAll, style: const TextStyle(fontSize: 12)),
              selected: filterType == null,
              onSelected: (selected) {
                onFilterChanged(null);
              },
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            // Type filter chips (one per distinct type)
            for (final type in availableTypes) ...[
              const SizedBox(width: 6),
              FilterChip(
                label: Text(type, style: const TextStyle(fontSize: 12)),
                selected: filterType == type,
                onSelected: (selected) {
                  onFilterChanged(selected ? type : null);
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSortPicker(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.docsSortLabel,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            _sortOption(ctx, DocsSortMode.dateDesc, l10n.docsSortDateNewest),
            _sortOption(ctx, DocsSortMode.dateAsc, l10n.docsSortDateOldest),
            _sortOption(ctx, DocsSortMode.nameAsc, l10n.docsSortNameAZ),
            _sortOption(ctx, DocsSortMode.nameDesc, l10n.docsSortNameZA),
            _sortOption(ctx, DocsSortMode.type, l10n.docsSortType),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sortOption(BuildContext ctx, DocsSortMode mode, String label) {
    final isSelected = sortMode == mode;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(ctx).colorScheme.primary : null,
      ),
      title: Text(label),
      onTap: () {
        onSortChanged(mode);
        Navigator.pop(ctx);
      },
    );
  }
}

/// Small action chip used by the sort / filter bar.
class _SortFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SortFilterChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isActive
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
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
    final l10n = AppLocalizationsGen.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.docsReplaceDocumentTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.docsReplaceWillDelete(widget.document.filename)),
            const SizedBox(height: 8),
            Text(
              l10n.docsReplaceAnalysisLost,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.docsReplace),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      await _performReplacement();
    }
  }

  Future<void> _performReplacement() async {
    final l10n = AppLocalizationsGen.of(context);
    setState(() {
      _isUploading = true;
      _error = null;
    });

    Object? replaceError;
    try {
      final box = Hive.box(AppStateStore.boxName);
      final consentVersion =
          box.get('processing_consent_version') as String? ?? 'v1';

      final result = await ref.read(documentServiceProvider).replaceDocument(
            widget.document.id,
            _selectedFile!,
            processingConsentVersion: consentVersion,
          );

      if (result.containsKey('error')) {
        setState(() {
          _error = result['message']?.toString() ?? 'Replacement failed';
          _isUploading = false;
        });
        return;
      }

      ref.invalidate(documentsProvider);
      ref.invalidate(policySummariesProvider);
    } catch (e) {
      replaceError = e;
    }
    if (!mounted) return;
    if (replaceError != null) {
      setState(() {
        _error = AppError.userMessage(replaceError!);
        _isUploading = false;
      });
    } else {
      // ignore: use_build_context_synchronously
      CoverWiseSnackBar.success(context, l10n.docsReplaceSuccess);
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.docsReplaceDocument),
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
                    Text(l10n.docsCurrentDocument,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(widget.document.filename),
                    Text(
                        l10n.docsUploadedDate(widget.document.formattedUploadDate),
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
                    tooltip: l10n.docsClearReplacement,
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
                label: Text(l10n.docsSelectReplacement),
              ),
              if (_selectedFile != null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _confirmReplacement,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(l10n.docsReplaceDocument),
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
