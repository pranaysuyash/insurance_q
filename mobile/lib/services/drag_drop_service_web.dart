import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Represents a file dropped from the OS.
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

/// Listens for OS-level file drag-and-drop events on the document body.
///
/// Uses `package:web` (modern web interop, same approach as WebFilePicker).
/// The service provides two callbacks:
///   - [onDragChanged]: fires when the user starts/stops dragging over the window
///   - [onFilesDropped]: fires with the list of dropped files
///
/// Call [init] once at app startup and [dispose] on shutdown.
class DragDropService {
  /// Optional: a single callback that fires when the drag-over visual state
  /// should change. Set this before or immediately after [init].
  static void Function(bool isDragging)? onDragChanged;

  /// Fires with the list of dropped files. Each entry includes the file name,
  /// size in bytes, and the raw bytes read via FileReader.
  static void Function(List<DragDropEvent> files)? onFilesDropped;

  /// Whether the user is currently dragging files over the window.
  /// Polled by the drop zone overlay widget to show/hide the visual hint.
  static bool isDragging = false;

  /// One-shot listener registrations (to avoid attaching multiple).
  static bool _initialized = false;

  /// Start listening. Idempotent — safe to call multiple times.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    web.document.body?.addEventListener('dragenter', (web.Event e) {
      e.preventDefault();
      if (!isDragging) {
        isDragging = true;
        onDragChanged?.call(true);
      }
    });

    web.document.body?.addEventListener('dragover', (web.Event e) {
      e.preventDefault();
    });

    web.document.body?.addEventListener('dragleave', (web.Event e) {
      // Only clear if we're leaving the document body (not a child element).
      // dragleave fires for every child element, so we check the related target.
      final related = (e as web.DragEvent).relatedTarget;
      if (related == null || related == web.document.body) {
        if (isDragging) {
          isDragging = false;
          onDragChanged?.call(false);
        }
      }
    });

    web.document.body?.addEventListener('drop', (web.Event e) async {
      e.preventDefault();
      if (isDragging) {
        isDragging = false;
        onDragChanged?.call(false);
      }

      final dt = (e as web.DragEvent).dataTransfer;
      if (dt == null) return;

      final files = dt.files;
      if (files == null || files.length == 0) return;

      final results = <DragDropEvent>[];
      for (var i = 0; i < files.length; i++) {
        final file = files.item(i);
        if (file == null) continue;

        final reader = web.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoadEnd.first;

        final jsBuffer = reader.result;
        if (jsBuffer is! JSArrayBuffer) continue;
        final bytes = (jsBuffer as JSArrayBuffer).toDart.asUint8List();
        results.add(DragDropEvent(
          name: file.name,
          size: bytes.length,
          bytes: bytes,
        ));
      }

      if (results.isNotEmpty) {
        onFilesDropped?.call(results);
      }
    });
  }

  /// Stop listening and reset state.
  static void dispose() {
    // package:web doesn't require explicit cleanup of listeners added via
    // addEventListener — the GC handles them when the page unloads.
    isDragging = false;
    onDragChanged = null;
    onFilesDropped = null;
  }
}
