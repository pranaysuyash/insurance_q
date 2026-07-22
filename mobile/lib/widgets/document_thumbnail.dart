import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../services/document_thumbnail_cache.dart';
import '../utils/document_icons.dart';
import 'shared/coverwise_components.dart';

/// Renders a thumbnail preview for an insurance document.
///
/// For image files (JPG/PNG), renders a downscaled preview cached via
/// [DocumentThumbnailCache]. For PDFs, shows a stylised PDF document icon.
/// Falls back to [CoverWiseIconBadge] with the document type icon when no
/// local file is available or the thumbnail cannot be generated.
class DocumentThumbnail extends StatefulWidget {
  final String? localFilePath;
  final String? documentType;
  final double size;

  const DocumentThumbnail({
    super.key,
    this.localFilePath,
    this.documentType,
    this.size = 46,
  });

  @override
  State<DocumentThumbnail> createState() => _DocumentThumbnailState();
}

class _DocumentThumbnailState extends State<DocumentThumbnail> {
  ui.Image? _thumbnail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(DocumentThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localFilePath != widget.localFilePath) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final filePath = widget.localFilePath;
    if (filePath == null) {
      setState(() { _isLoading = false; });
      return;
    }

    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.pdf') {
      // PDFs use a document icon — no native rendering needed for thumbnails.
      setState(() { _isLoading = false; });
      return;
    }

    if (ext != '.jpg' && ext != '.jpeg' && ext != '.png') {
      setState(() { _isLoading = false; });
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      setState(() { _isLoading = false; });
      return;
    }

    // Check disk cache first
    final cache = DocumentThumbnailCache();
    var bytes = await cache.get(filePath);

    if (bytes == null) {
      // Read file and cache it
      bytes = await file.readAsBytes();
      await cache.set(filePath, bytes);
    }

    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: widget.size.toInt() * 3,
      );
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _thumbnail = frame.image;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Image thumbnail decode failed: $e');
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnail != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 0.15),
        child: RawImage(
          image: _thumbnail!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      );
    }

    if (_isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: SizedBox(
            width: widget.size * 0.35,
            height: widget.size * 0.35,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Fallback: document type icon badge
    return CoverWiseIconBadge(
      icon: iconForDocumentType(widget.documentType),
      color: colorForDocumentType(widget.documentType),
      size: widget.size,
    );
  }
}
