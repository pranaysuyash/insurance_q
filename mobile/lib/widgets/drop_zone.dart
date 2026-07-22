import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/drag_drop_service.dart';
import '../theme/coverwise_motion.dart';

/// Wraps [child] with a drag-and-drop zone.
///
/// On web: listens to OS-level file drag events via [DragDropService] and
/// shows a full-area overlay with "Drop files here" when the user drags
/// files over the window. On drop, calls [onFilesDropped] with the parsed
/// list of file bytes.
///
/// On mobile/native: passes through [child] unchanged since the native file
/// picker is the expected UX.
///
/// Example:
/// ```dart
/// DropZone(
///   onFilesDropped: (files) { /* process files */ },
///   child: myUploadWidget,
/// )
/// ```
class DropZone extends StatefulWidget {
  /// Called when files are dropped onto the zone.
  /// Each [DragDropEvent] contains `name`, `size`, and `bytes`.
  final void Function(List<DragDropEvent> files)? onFilesDropped;

  /// The content to wrap. On non-web platforms this is rendered as-is.
  final Widget child;

  /// Optional label shown in the overlay.
  final String dropLabel;

  const DropZone({
    super.key,
    required this.child,
    this.onFilesDropped,
    this.dropLabel = 'Drop files here',
  });

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> with WidgetsBindingObserver {
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      _initService();
    }
  }

  void _initService() {
    DragDropService.onDragChanged = (dragging) {
      if (mounted) {
        setState(() => _isDragging = dragging);
      }
    };
    DragDropService.onFilesDropped = (files) {
      widget.onFilesDropped?.call(files);
    };
    if (!kIsWeb) return;
    // Lazy init — service already started in main.dart or here.
    DragDropService.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (kIsWeb) {
      DragDropService.onDragChanged = null;
      DragDropService.onFilesDropped = null;
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(DropZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb && oldWidget.onFilesDropped != widget.onFilesDropped) {
      DragDropService.onFilesDropped = (files) {
        widget.onFilesDropped?.call(files);
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_isDragging) return widget.child;

    return Stack(
      children: [
        widget.child,
        // Full-area translucent overlay
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: CoverWiseMotion.duration(
                  context, CoverWiseMotion.standard),
              curve: CoverWiseMotion.enterCurve,
              opacity: _isDragging ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2.5,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.dropLabel,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PDF, JPEG, PNG — max 20 MB',
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
              ),
            ),
          ),
        ),
      ],
    );
  }
}
