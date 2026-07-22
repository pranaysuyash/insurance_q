import 'dart:typed_data';

/// Stub implementation used on non-web platforms.
/// Drag-and-drop from the OS is not supported here — the user picks files
/// via the native file selector instead.

class DragDropEvent {
  final String name;
  final int size;
  final Uint8List bytes;

  const DragDropEvent({
    required this.name,
    required this.size,
    required this.bytes,
  });
}

abstract class DragDropService {
  /// Start listening for OS-level file drag-over/drop events.
  /// On non-web this is a no-op.
  static void init() {}

  /// Stop listening.
  static void dispose() {}

  /// Whether the user is currently dragging files over the window.
  static bool get isDragging => false;

  /// Called by the platform layer when drag-over state changes.
  static void Function(bool isDragging)? onDragChanged;

  /// Called when files are dropped.
  static void Function(List<DragDropEvent> files)? onFilesDropped;
}
