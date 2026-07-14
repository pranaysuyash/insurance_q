import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final String filePath;
  final String filename;

  const DocumentPreviewScreen({
    super.key,
    required this.filePath,
    required this.filename,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  PdfController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      _controller = PdfController(
        document: PdfDocument.openFile(widget.filePath),
      );
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Could not open document: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filename, overflow: TextOverflow.ellipsis),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _controller == null
                  ? const Center(child: Text('Document not available'))
                  : PdfView(controller: _controller!),
    );
  }
}