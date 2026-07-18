import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/document_service.dart';
import '../services/local_storage_service.dart';
import '../services/session_service.dart';
import '../widgets/shared/coverwise_components.dart';
import '../theme/coverwise_motion.dart';
import 'policy_detail_screen.dart';

/// Processing stages that map to the backend pipeline.
///
/// The backend runs: received → processing (OCR → extraction → classification → indexing) → completed.
/// This screen polls `documentsProvider` and maps `processingState` to visible stages.
enum ProcessingStage {
  received(
      0, 'Received', 'Document saved securely', Icons.upload_file, Colors.grey),
  processing(1, 'Reading text', 'Extracting text from your document',
      Icons.document_scanner, Colors.blue),
  extraction(
      2,
      'Extracting details',
      'Identifying coverage, premiums, and dates',
      Icons.find_in_page_outlined,
      Colors.purple),
  classification(3, 'Classifying', 'Determining policy type and insurer',
      Icons.category, Colors.teal),
  indexing(4, 'Indexing', 'Making your policy searchable', Icons.search,
      Colors.orange),
  complete(
      5, 'Complete', 'Your policy is ready', Icons.check_circle, Colors.green),
  failed(5, 'Failed', 'Something went wrong', Icons.error, Colors.red);

  final int step;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const ProcessingStage(
      this.step, this.label, this.description, this.icon, this.color);
}

/// Maps backend processing state strings to user-visible stages.
///
/// Handles both coarse states from local storage (`received`, `processing`,
/// `completed`) and granular stages from the backend status endpoint
/// (`started`, `validating`, `extracting_text`, `extracting_policy_data`,
/// `creating_embeddings`).
ProcessingStage stageFromState(String? state) {
  switch (state) {
    case 'received':
    case 'pending':
    case 'pending_upload':
    case 'started':
      return ProcessingStage.received;
    case 'processing':
    case 'ocr':
    case 'validating':
    case 'extracting_text':
      return ProcessingStage.processing;
    case 'extracting':
    case 'extraction':
    case 'extracting_policy_data':
      return ProcessingStage.extraction;
    case 'classifying':
    case 'classification':
      return ProcessingStage.classification;
    case 'indexing':
    case 'creating_embeddings':
      return ProcessingStage.indexing;
    case 'completed':
    case 'completed_with_errors':
    case 'ready':
      return ProcessingStage.complete;
    case 'failed':
      return ProcessingStage.failed;
    default:
      return ProcessingStage.received;
  }
}

/// Full-screen processing status view shown after document upload.
///
/// Polls `documentsProvider` every 2 seconds until the document reaches a
/// terminal state (completed or failed), then auto-navigates to the policy
/// detail screen on success.
class ProcessingStatusScreen extends ConsumerStatefulWidget {
  final String documentId;
  final String filename;

  const ProcessingStatusScreen({
    super.key,
    required this.documentId,
    required this.filename,
  });

  @override
  ConsumerState<ProcessingStatusScreen> createState() => _ProcessingStatusScreenState();
}

class _ProcessingStatusScreenState extends ConsumerState<ProcessingStatusScreen> {
  Timer? _pollTimer;
  ProcessingStage _currentStage = ProcessingStage.received;
  String? _errorMessage;
  int _pollCount = 0;
  static const int _maxPolls = 90; // 3 minutes at 2s intervals

  /// Reused across all polls to avoid leaking connections.
  /// Uses the authenticated Dio client so auth tokens are attached.
  late final Dio _dio = DocumentService.authenticatedDio;

  @override
  void initState() {
    super.initState();
    // Start polling immediately
    _pollStatus();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _pollStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dio.close();
    super.dispose();
  }

  Future<void> _pollStatus() async {
    if (!mounted) return;
    _pollCount++;

    if (_pollCount > _maxPolls) {
      _pollTimer?.cancel();
      if (mounted) {
        setState(() {
          _errorMessage =
              'Processing is taking longer than expected. You can close this screen and check back later.';
        });
      }
      return;
    }

    try {
      // Try backend status endpoint first for real granular stage data.
      // Fall back to local Hive storage if the backend is unreachable.
      String? stageString;
      
      try {
        final sessionId = await SessionService.getSessionId();
        final response = await _dio.get(
          '/documents/${widget.documentId}/status',
          options: Options(
            headers: {'X-Session-ID': sessionId},
            validateStatus: (status) => status == 200 || status == 404,
          ),
        );
        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data as Map<String, dynamic>;
          stageString = data['processing_details']?['stage']?.toString()
              ?? data['status']?.toString();
        }
      } catch (_) {
        // Backend unreachable — fall through to local storage.
      }

      // Fall back to local Hive storage if backend didn't return a stage.
      if (stageString == null) {
        final storage = LocalStorageService();
        final doc = await storage.getDocumentById(widget.documentId);
        if (!mounted) return;

        if (doc == null) {
          // Document not found locally — might still be processing on server.
          // Keep polling; the server-side status may not be reflected locally yet.
          return;
        }

        stageString = doc.processingState;
      }

      final newStage = stageFromState(stageString);

      if (newStage == ProcessingStage.complete) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() => _currentStage = newStage);
          await Future<void>.delayed(
            CoverWiseMotion.duration(context, CoverWiseMotion.emphasized),
          );
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) =>
                    PolicyDetailScreen(documentId: widget.documentId),
              ),
            );
          }
        }
        return;
      }

      if (newStage == ProcessingStage.failed) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() {
            _currentStage = newStage;
            _errorMessage =
                'Document processing did not complete. Please try re-uploading.';
          });
        }
        return;
      }

      if (mounted && newStage != _currentStage) {
        setState(() => _currentStage = newStage);
      }
    } catch (e) {
      debugPrint('Processing status poll error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: _errorMessage != null ||
          _currentStage == ProcessingStage.failed ||
          _currentStage == ProcessingStage.complete,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showDismissWarning();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Preparing your policy'),
          automaticallyImplyLeading:
              _errorMessage != null || _currentStage == ProcessingStage.failed,
        ),
        body: SafeArea(
          child: Column(
            children: [
              CoverWisePageHeader(
                title: _currentStage == ProcessingStage.failed
                    ? 'We couldn\'t finish this file'
                    : 'Turning pages into answers',
                subtitle: _errorMessage ?? _currentStage.description,
                trailing: CoverWiseIconBadge(
                  icon: _currentStage == ProcessingStage.failed
                      ? Icons.error_outline_rounded
                      : _currentStage.icon,
                  color: _currentStage.color,
                  size: 52,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Semantics(
                  label: 'File being processed: ${widget.filename}',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.filename,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _errorMessage != null
                    ? _buildErrorState(theme)
                    : _buildStageProgress(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageProgress(ThemeData theme) {
    final stages = ProcessingStage.values.where((s) => s.step < 5).toList();

    return Column(children: [
      Semantics(
          liveRegion: true,
          label: '${_currentStage.label}. ${_currentStage.description}',
          excludeSemantics: true,
          child: Column(children: [
            if (_currentStage != ProcessingStage.complete &&
                _currentStage != ProcessingStage.failed)
              CoverWiseIconBadge(
                icon: _currentStage.icon,
                color: _currentStage.color,
                size: 68,
              ),
            if (_currentStage == ProcessingStage.complete)
              CoverWiseIconBadge(
                icon: Icons.check_circle_rounded,
                color: ProcessingStage.complete.color,
                size: 68,
              ),
            const SizedBox(height: 16),
            Text(
              _currentStage.label,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: _currentStage.color,
              ),
            ),
          ])),
      const SizedBox(height: 20),
      Expanded(
        child: CoverWiseSurface(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: stages.length,
            separatorBuilder: (_, __) => const Divider(indent: 58),
            itemBuilder: (context, index) => _buildStageTile(stages[index]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildStageTile(ProcessingStage stage) {
    final isCurrent = stage == _currentStage;
    final isComplete = _currentStage.step > stage.step;
    final isFailed = _currentStage == ProcessingStage.failed;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: CoverWiseMotion.duration(
        context,
        CoverWiseMotion.standard,
      ),
      curve: CoverWiseMotion.enterCurve,
      decoration: BoxDecoration(
        color: isCurrent
            ? stage.color.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Semantics(
        label:
            '${stage.label}. ${isComplete ? 'Complete' : isCurrent ? 'In progress' : isFailed ? 'Not completed' : 'Pending'}',
        excludeSemantics: true,
        child: ListTile(
          minTileHeight: 64,
          leading: _buildStageIcon(stage,
              isCurrent: isCurrent, isComplete: isComplete),
          title: Text(
            stage.label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: isComplete
                  ? theme.colorScheme.onSurfaceVariant
                  : isCurrent
                      ? stage.color
                      : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          subtitle: isCurrent ? Text(stage.description) : null,
          trailing: isComplete
              ? Icon(Icons.check_circle, size: 20, color: stage.color)
              : isFailed
                  ? Icon(Icons.error, size: 20, color: stage.color)
                  : isCurrent
                      ? CoverWiseMotion.isReduced(context)
                          ? Icon(Icons.timelapse_rounded,
                              size: 20, color: stage.color)
                          : SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(stage.color),
                              ),
                            )
                      : Icon(
                          Icons.circle_outlined,
                          size: 20,
                          color: theme.colorScheme.outlineVariant,
                        ),
        ),
      ),
    );
  }

  Widget _buildStageIcon(ProcessingStage stage,
      {required bool isCurrent, required bool isComplete}) {
    return CoverWiseIconBadge(
      icon: isComplete ? Icons.check_rounded : stage.icon,
      color: isComplete || isCurrent
          ? stage.color
          : Theme.of(context).colorScheme.onSurfaceVariant,
      size: 40,
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoverWiseIconBadge(
            icon: Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            size: 68,
          ),
          const SizedBox(height: 16),
          Text('Processing failed',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to documents'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showDismissWarning() {
    if (_currentStage == ProcessingStage.complete ||
        _currentStage == ProcessingStage.failed) {
      Navigator.of(context).pop();
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Still processing?'),
        content: const Text(
          'Your document is still being processed. You can close this screen — '
          'processing continues in the background. You can check the document list for updates.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Stay')),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
