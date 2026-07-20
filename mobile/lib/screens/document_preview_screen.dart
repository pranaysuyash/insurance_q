import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../widgets/shared/error_widget.dart';
import '../widgets/shared/loading_widget.dart';

/// Full-featured document preview screen.
///
/// Renders PDFs page-by-page with pinch-to-zoom, page navigation, and a
/// toolbar showing the current page. For image files (PNG/JPG), displays
/// them directly with zoom support via [InteractiveViewer].
///
/// This is the trust-building screen: users can verify extracted data against
/// the source document (motto_v3 §0.11 — customer-facing claims verification).
class DocumentPreviewScreen extends StatefulWidget {
  final String filePath;
  final String filename;
  final String? documentId;
  final int initialPage;

  const DocumentPreviewScreen({
    super.key,
    required this.filePath,
    required this.filename,
    this.documentId,
    this.initialPage = 1,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  PdfController? _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _error;
  bool _isImage = false;

  bool get _isPdf => widget.filePath.toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    final file = File(widget.filePath);
    if (!await file.exists()) {
      setState(() {
        _error = 'File not found on this device.';
        _isLoading = false;
      });
      return;
    }

    if (_isPdf) {
      try {
        // PdfController accepts Future<PdfDocument> — it handles async loading
        // internally and exposes pagesCount once the document is ready.
        _pdfController = PdfController(
          document: PdfDocument.openFile(widget.filePath),
        );
        // Wait a tick for the document to resolve so we can read pagesCount.
        await Future.delayed(Duration.zero);
        if (!mounted) return;
        _totalPages = _pdfController!.pagesCount ?? 0;
        if (widget.initialPage > 1) {
          _goToPage(widget.initialPage);
        }
        setState(() => _isLoading = false);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Could not open PDF: $e';
          _isLoading = false;
        });
      }
    } else {
      // Image file — display with InteractiveViewer
      setState(() {
        _isImage = true;
        _isLoading = false;
      });
    }
  }

  void _goToPage(int page) {
    if (_pdfController == null || page < 1 || page > _totalPages) return;
    _pdfController!.jumpToPage(page);
    setState(() => _currentPage = page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filename, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_isLoading && _error == null && _isPdf)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          if (widget.documentId != null)
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'View extracted summary',
              onPressed: () {
                Navigator.pushReplacementNamed(
                  context,
                  '/policy-detail',
                  arguments: widget.documentId,
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading document preview…')
          : _error != null
              ? _buildErrorState()
              : _isImage
                  ? _buildImageView()
                  : _buildPdfView(),
      bottomNavigationBar:
          !_isLoading && _error == null && _isPdf && _totalPages > 1
              ? _buildPageNavigator()
              : null,
    );
  }

  Widget _buildPdfView() {
    return PdfView(
      controller: _pdfController!,
      scrollDirection: Axis.vertical,
      onPageChanged: (page) {
        setState(() => _currentPage = page);
      },
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) =>
            const LoadingWidget(message: 'Opening policy document…'),
        pageLoaderBuilder: (_) =>
            const LoadingWidget(message: 'Rendering policy page…'),
        errorBuilder: (_, error) => const AppErrorView(
          message: 'This page could not be rendered.',
          icon: Icons.broken_image_outlined,
        ),
      ),
    );
  }

  Widget _buildImageView() {
    final file = File(widget.filePath);
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const AppErrorView(
            message: 'This policy image could not be loaded.',
            icon: Icons.broken_image_outlined,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return AppErrorView(
      message:
          'Document not available\n\n$_error\n\nThe file may have been added on another device or removed from local storage.',
      icon: Icons.folder_off_outlined,
    );
  }

  Widget _buildPageNavigator() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.first_page),
              tooltip: 'First page',
              onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous page',
              onPressed:
                  _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
            ),
            Semantics(
              button: true,
              label:
                  'Page $_currentPage of $_totalPages. Tap to jump to a page.',
              excludeSemantics: true,
              child: InkWell(
                onTap: _showPageJumpDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next page',
              onPressed: _currentPage < _totalPages
                  ? () => _goToPage(_currentPage + 1)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              tooltip: 'Last page',
              onPressed: _currentPage < _totalPages
                  ? () => _goToPage(_totalPages)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showPageJumpDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    String? errorText;

    void validateAndJump() {
      final page = int.tryParse(controller.text);
      if (page != null && page >= 1 && page <= _totalPages) {
        _goToPage(page);
        Navigator.pop(context);
      } else {
        errorText = 'Enter a page number between 1 and $_totalPages';
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Go to page'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Page number (1-$_totalPages)',
              errorText: errorText,
            ),
            autofocus: true,
            onSubmitted: (_) => setDialogState(validateAndJump),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => setDialogState(validateAndJump),
              child: const Text('Go'),
            ),
          ],
        ),
      ),
    );
  }
}
