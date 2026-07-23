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
  classification(3, 'Categorising', 'Identifying the policy type and insurer',
      Icons.category, Colors.teal),
  indexing(4, 'Finishing up', 'Preparing your policy for questions',
      Icons.search, Colors.orange),
  complete(
      5, 'Complete', 'Your policy is ready', Icons.check_circle, Colors.green),
  partial(5, 'Partially ready', 'Some policy details still need verification',
      Icons.warning_amber_rounded, Colors.orange),
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
    case 'rag_ingestion':
    case 'evidence_extraction':
      return ProcessingStage.indexing;
    case 'completed':
    case 'ready':
      return ProcessingStage.complete;
    case 'completed_no_summary':
    case 'completed_summary_partial':
    case 'completed_text_partial':
    case 'summary_partial':
    case 'indexing_failed':
    case 'partial':
    case 'completed_with_errors':
      return ProcessingStage.partial;
    case 'failed':
    case 'terminal_failed':
    case 'retryable_failed':
      return ProcessingStage.failed;
    default:
      return ProcessingStage.received;
  }
}

/// Extract the set of completed backend stage names from the
/// `processing_details.stages` dict returned by the backend
/// `/documents/{id}/status` endpoint.
///
/// Example input:
/// ```json
/// {"file_storage": {"status": "completed"},
///  "ocr": {"status": "completed"},
///  "policy_extraction": {"status": "completed"}}
/// ```
/// Returns `{"file_storage", "ocr", "policy_extraction"}`.
Set<String> _completedBackendStageNames(Map<String, dynamic>? stages) {
  if (stages == null || stages.isEmpty) return {};
  final completed = <String>{};
  for (final entry in stages.entries) {
    final stageData = entry.value;
    if (stageData is Map) {
      final status = stageData['status']?.toString();
      // Only 'completed' is terminal. The 'queued' status means the
      // stage has been enqueued for async execution (e.g. evidence
      // extraction via job outbox) and is NOT yet done.
      if (status == 'completed') {
        completed.add(entry.key);
      }
    }
  }
  return completed;
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
  ConsumerState<ProcessingStatusScreen> createState() =>
      _ProcessingStatusScreenState();
}

class _ProcessingStatusScreenState
    extends ConsumerState<ProcessingStatusScreen> {
  Timer? _pollTimer;
  ProcessingStage _currentStage = ProcessingStage.received;
  String? _errorMessage;
  int _pollCount = 0;
  static const int _maxPolls = 90; // 3 minutes at 2s intervals

  /// Set of backend stage names (e.g. "file_storage", "ocr") that have
  /// completed, populated from the granular `processing_details.stages`
  /// dict. When non-empty, these drive the stage completion indicators
  /// in the UI, showing which specific pipeline steps are done.
  Set<String> _completedBackendStages = {};

  // ─── Retry state ───────────────────────────────────────────────────
  /// Number of reprocess attempts made so far this session.
  int _retryCount = 0;

  /// Maximum number of manual reprocess attempts allowed per session.
  static const int _maxRetries = 3;

  /// Whether a reprocess request is currently in flight.
  bool _isRetrying = false;

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
    // DocumentService.authenticatedDio is a process-wide shared client. This
    // screen must not close it while other screens or providers may still be
    // using the same interceptor/client instance.
    super.dispose();
  }

  /// Determines the current ProcessingStage from either the rich stages
  /// dict (preferred) or the flat stage string (fallback).
  ///
  /// When the backend returns `processing_details.stages` with per-stage
  /// statuses, this function:
  /// 1. Marks all completed backend stages in `_completedBackendStages`
  /// 2. Finds the first UI stage (by step order) whose backend stage is
  ///    NOT yet completed — that becomes the current stage
  /// 3. If every mapped backend stage is completed, the doc is complete
  ///
  /// Falls back to `stageFromState(flatStage)` when no stages dict exists.
  ProcessingStage _resolveStageFromBackendData(
    Map<String, dynamic>? processingDetails,
    String? flatStage,
  ) {
    // Extract the granular stages dict if present.
    final stagesDict = processingDetails?['stages'] is Map
        ? Map<String, dynamic>.from(processingDetails!['stages'] as Map)
        : null;

    if (stagesDict != null && stagesDict.isNotEmpty) {
      final completed = _completedBackendStageNames(stagesDict);
      _completedBackendStages = completed;

      // Order: received → processing → extraction → classification → indexing
      // Check each UI stage by step ordering to find the first incomplete one.
      const stepOrder = [
        ProcessingStage.received,
        ProcessingStage.processing,
        ProcessingStage.extraction,
        ProcessingStage.classification,
        ProcessingStage.indexing,
      ];

      /// Maps backend stage names to their UI ProcessingStage counterpart.
      /// Multiple backend stages can map to the same UI stage (e.g.
      /// rag_ingestion and evidence_extraction both map to indexing).
      // ignore: no_leading_underscores_for_local_identifiers
      Map<ProcessingStage, List<String>> _backendStageNamesForStep = {
        ProcessingStage.received: ['file_storage'],
        ProcessingStage.processing: ['ocr'],
        ProcessingStage.extraction: ['policy_extraction'],
        ProcessingStage.indexing: ['rag_ingestion', 'evidence_extraction'],
      };

      for (final step in stepOrder) {
        final requiredStages =
            _backendStageNamesForStep[step] ?? <String>[];
        // Skip steps that have no backend counterpart (classification).
        if (requiredStages.isEmpty) continue;
        // Check if ALL backend stages for this step are completed.
        final allDone = requiredStages.every(completed.contains);
        if (!allDone) {
          return step;
        }
      }
      // All mapped stages completed.
      return ProcessingStage.complete;
    }

    // No stages dict — fall back to flat stage string (backward compat).
    return stageFromState(flatStage);
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
      Map<String, dynamic>? processingDetails;

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
          processingDetails =
              data['processing_details'] is Map
                  ? Map<String, dynamic>.from(
                      data['processing_details'] as Map)
                  : null;
          stageString = processingDetails?['stage']?.toString() ??
              data['status']?.toString();
        }
      } catch (_) {
        // Backend unreachable — fall through to local storage.
      }

      // Fall back to local Hive storage if backend didn't return a stage.
      if (stageString == null && processingDetails == null) {
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

      final newStage = _resolveStageFromBackendData(
        processingDetails,
        stageString,
      );

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

      if (newStage == ProcessingStage.partial) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() => _currentStage = newStage);
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
          _currentStage == ProcessingStage.partial ||
          _currentStage == ProcessingStage.complete,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showDismissWarning();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Preparing your policy'),
          automaticallyImplyLeading: _errorMessage != null ||
              _currentStage == ProcessingStage.failed ||
              _currentStage == ProcessingStage.partial,
        ),
        body: SafeArea(
          child: Column(
            children: [
              CoverWisePageHeader(
                title: _currentStage == ProcessingStage.failed
                    ? 'We couldn\'t finish this file'
                    : _currentStage == ProcessingStage.partial
                        ? 'Your policy is partly ready'
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
                    : _currentStage == ProcessingStage.partial
                        ? _buildPartialState(theme)
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
    // Use granular backend stage completion when available.
    // Fall back to step-based comparison for backward compat.
    bool isComplete;
    if (_completedBackendStages.isNotEmpty) {
      // Check if ALL backend stages that map to this UI step are done.
      switch (stage) {
        case ProcessingStage.received:
          isComplete = _completedBackendStages.contains('file_storage');
        case ProcessingStage.processing:
          isComplete = _completedBackendStages.contains('ocr');
        case ProcessingStage.extraction:
          isComplete = _completedBackendStages.contains('policy_extraction');
        case ProcessingStage.indexing:
          isComplete =
              _completedBackendStages.contains('rag_ingestion') ||
              _completedBackendStages.contains('evidence_extraction');
        default:
          isComplete = _currentStage.step > stage.step;
      }
    } else {
      isComplete = _currentStage.step > stage.step;
    }
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
          subtitle: isCurrent
              ? Text(stage.description)
              : (isComplete && stage != ProcessingStage.complete)
                  ? Text(
                      'Ready',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : null,
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
    final canRetry = _retryCount < _maxRetries && !_isRetrying;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (_retryCount > 0) ...[  // Show retry attempt counter
              const SizedBox(height: 8),
              Text(
                'Attempt $_retryCount of $_maxRetries',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Retry button — shown only when retries remain
            if (canRetry)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: _isRetrying
                      ? FilledButton.icon(
                          icon: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                          label: const Text('Retrying...'),
                          onPressed: null,
                        )
                      : FilledButton.icon(
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                            _retryCount > 0
                                ? 'Retry processing (attempt $_retryCount of $_maxRetries)'
                                : 'Retry processing',
                          ),
                          onPressed: () => _retryProcessing(),
                        ),
                ),
              ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Back to documents'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartialState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoverWiseIconBadge(
            icon: Icons.warning_amber_rounded,
            color: theme.colorScheme.tertiary,
            size: 68,
          ),
          const SizedBox(height: 16),
          Text('Policy partly ready',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Some details could not be verified yet. You can review the available policy information and ask questions about the source document.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('View available policy'),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) =>
                    PolicyDetailScreen(documentId: widget.documentId),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDismissWarning() {
    if (_currentStage == ProcessingStage.complete ||
        _currentStage == ProcessingStage.partial ||
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

  /// Re-process a failed document by calling the backend reprocess endpoint.
  /// Resets polling to show fresh progress from the new attempt.
  Future<void> _retryProcessing() async {
    if (_isRetrying || _retryCount >= _maxRetries) return;

    setState(() {
      _isRetrying = true;
      _errorMessage = null;
    });

    try {
      final sessionId = await SessionService.getSessionId();
      final response = await _dio.post(
        '/documents/${widget.documentId}/reprocess',
        options: Options(
          headers: {'X-Session-ID': sessionId},
          validateStatus: (status) =>
              status == 202 || status == 409 || status == 404 || status == 503,
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 202) {
        // Reprocessing accepted — reset state and restart polling.
        setState(() {
          _retryCount++;
          _isRetrying = false;
          _currentStage = ProcessingStage.received;
          _errorMessage = null;
          _pollCount = 0;
          _completedBackendStages = {};
        });

        // Restart polling
        _pollTimer?.cancel();
        _pollStatus();
        _pollTimer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => _pollStatus(),
        );
      } else if (response.statusCode == 409) {
        // Document not in retryable state
        setState(() {
          _isRetrying = false;
          _errorMessage =
              'This document cannot be reprocessed in its current state.';
        });
      } else {
        setState(() {
          _isRetrying = false;
          _errorMessage =
              'Could not start reprocessing. Please try again later.';
        });
      }
    } catch (e) {
      debugPrint('Reprocessing request failed: $e');
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _errorMessage =
              'Could not start reprocessing due to a network error. Please check your connection and try again.';
        });
      }
    }
  }
}
