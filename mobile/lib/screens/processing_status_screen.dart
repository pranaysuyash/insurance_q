import 'dart:async';
import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import 'policy_detail_screen.dart';

/// Processing stages that map to the backend pipeline.
///
/// The backend runs: received → processing (OCR → extraction → classification → indexing) → completed.
/// This screen polls `documentsProvider` and maps `processingState` to visible stages.
enum ProcessingStage {
  received(0, 'Received', 'Document saved securely', Icons.upload_file, Colors.grey),
  processing(1, 'Reading text', 'Extracting text from your document', Icons.document_scanner, Colors.blue),
  extraction(2, 'Extracting details', 'Identifying coverage, premiums, and dates', Icons.psychology, Colors.purple),
  classification(3, 'Classifying', 'Determining policy type and insurer', Icons.category, Colors.teal),
  indexing(4, 'Indexing', 'Making your policy searchable', Icons.search, Colors.orange),
  complete(5, 'Complete', 'Your policy is ready', Icons.check_circle, Colors.green),
  failed(5, 'Failed', 'Something went wrong', Icons.error, Colors.red);

  final int step;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const ProcessingStage(this.step, this.label, this.description, this.icon, this.color);
}

/// Maps backend processing state strings to user-visible stages.
ProcessingStage stageFromState(String? state) {
  switch (state) {
    case 'received':
    case 'pending':
    case 'pending_upload':
      return ProcessingStage.received;
    case 'processing':
    case 'ocr':
      return ProcessingStage.processing;
    case 'extracting':
    case 'extraction':
      return ProcessingStage.extraction;
    case 'classifying':
    case 'classification':
      return ProcessingStage.classification;
    case 'indexing':
      return ProcessingStage.indexing;
    case 'completed':
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
class ProcessingStatusScreen extends StatefulWidget {
  final String documentId;
  final String filename;

  const ProcessingStatusScreen({
    super.key,
    required this.documentId,
    required this.filename,
  });

  @override
  State<ProcessingStatusScreen> createState() => _ProcessingStatusScreenState();
}

class _ProcessingStatusScreenState extends State<ProcessingStatusScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  late AnimationController _pulseController;
  ProcessingStage _currentStage = ProcessingStage.received;
  String? _errorMessage;
  int _pollCount = 0;
  static const int _maxPolls = 90; // 3 minutes at 2s intervals

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    // Start polling immediately
    _pollStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pollStatus() async {
    if (!mounted) return;
    _pollCount++;

    if (_pollCount > _maxPolls) {
      _pollTimer?.cancel();
      if (mounted) {
        setState(() {
          _errorMessage = 'Processing is taking longer than expected. You can close this screen and check back later.';
        });
      }
      return;
    }

    try {
      // Read directly from local storage without invalidating the shared
      // documentsProvider — this avoids triggering rebuilds across the entire
      // app (dashboard, documents list, QA, etc.) on every 2-second tick.
      final storage = LocalStorageService();
      final doc = await storage.getDocumentById(widget.documentId);
      if (!mounted) return;

      if (doc == null) {
        // Document not found locally — might still be processing on server.
        // Keep polling; the server-side status may not be reflected locally yet.
        return;
      }

      final newStage = stageFromState(doc.processingState);

      if (newStage == ProcessingStage.complete) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() => _currentStage = newStage);
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PolicyDetailScreen(documentId: widget.documentId),
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
            _errorMessage = 'Document processing did not complete. Please try re-uploading.';
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
      canPop: _errorMessage != null || _currentStage == ProcessingStage.failed || _currentStage == ProcessingStage.complete,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showDismissWarning();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Processing'),
          automaticallyImplyLeading: _errorMessage != null || _currentStage == ProcessingStage.failed,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                Text(
                  widget.filename,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  _currentStage.description,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: _errorMessage != null
                      ? _buildErrorState(theme)
                      : _buildStageProgress(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageProgress(ThemeData theme) {
    final stages = ProcessingStage.values.where((s) => s.step < 5).toList();

    return Column(
      children: [
        if (_currentStage != ProcessingStage.complete && _currentStage != ProcessingStage.failed)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Opacity(
                opacity: 0.6 + (_pulseController.value * 0.4),
                child: child,
              );
            },
            child: SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(_currentStage.color),
              ),
            ),
          ),
        if (_currentStage == ProcessingStage.complete)
          Icon(Icons.check_circle, size: 64, color: ProcessingStage.complete.color),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.builder(
            itemCount: stages.length,
            itemBuilder: (context, index) => _buildStageTile(stages[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildStageTile(ProcessingStage stage) {
    final isCurrent = stage == _currentStage;
    final isComplete = _currentStage.step > stage.step;
    final isFailed = _currentStage == ProcessingStage.failed && stage == _currentStage;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isCurrent ? stage.color.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: _buildStageIcon(stage, isCurrent: isCurrent, isComplete: isComplete),
        title: Text(
          stage.label,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isComplete ? Colors.grey.shade500 : isCurrent ? stage.color : Colors.grey.shade400,
          ),
        ),
        trailing: isComplete
            ? Icon(Icons.check_circle, size: 20, color: stage.color)
            : isFailed
                ? Icon(Icons.error, size: 20, color: stage.color)
                : isCurrent
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(stage.color),
                        ),
                      )
                    : Icon(Icons.circle_outlined, size: 20, color: Colors.grey.shade300),
      ),
    );
  }

  Widget _buildStageIcon(ProcessingStage stage, {required bool isCurrent, required bool isComplete}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isComplete
            ? stage.color.withValues(alpha: 0.1)
            : isCurrent
                ? stage.color.withValues(alpha: 0.15)
                : Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isComplete ? Icons.check : stage.icon,
        size: 20,
        color: isComplete ? stage.color : isCurrent ? stage.color : Colors.grey.shade400,
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text('Processing failed', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_errorMessage!, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showDismissWarning() {
    if (_currentStage == ProcessingStage.complete || _currentStage == ProcessingStage.failed) {
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Stay')),
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
