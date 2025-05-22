import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import '../services/api_service.dart'; // Assuming ApiService and DuplicateDocumentInfo are here or exported
import 'documents_list.dart'; // For DocumentsListState and potentially DocumentsList widget

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  File? _selectedFile;
  bool _isUploading = false;
  String? _uploadError;
  Map<String, dynamic>? _ocrResult; // Consider creating a typed model for this
  final ApiService _apiService = ApiService();
  final GlobalKey<DocumentsListState> _documentsListKey =
      GlobalKey<DocumentsListState>();
  bool _showUploadDetails = false;

  Future<void> _pickFile() async {
    setState(() {
      _uploadError = null;
      _ocrResult = null;
      // _selectedFile = null; // Reset selected file when picking a new one
    });

    final typeGroup = XTypeGroup(
      label: 'Documents',
      extensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      setState(() {
        _selectedFile = File(file.path);
        _showUploadDetails = true; // Show details once a file is picked
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;

    // Check for duplicate documents first
    // This assumes checkForDuplicateDocument returns a class with 'filename' and 'formattedUploadDate'
    final duplicate =
        await _apiService.checkForDuplicateDocument(_selectedFile!);

    if (duplicate != null && mounted) {
      final shouldProceed = await showDialog<String?>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A similar document already exists:'),
              const SizedBox(height: 8),
              Text(
                duplicate.filename, // Assumes DuplicateDocumentInfo has filename
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                  'Uploaded on: ${duplicate.formattedUploadDate}'), // Assumes DuplicateDocumentInfo has formattedUploadDate
              const SizedBox(height: 16),
              const Text(
                'Uploading this document will count against your storage limit. Do you want to replace the existing document or keep both?',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              child: const Text('Replace'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'keep'), // 'keep' or null for keep both
              child: const Text('Keep Both'),
            ),
          ],
        ),
      );

      if (shouldProceed == 'cancel' || shouldProceed == null && mounted) { // if dialog dismissed
        return;
      }

      if (shouldProceed == 'replace' && mounted) {
        setState(() {
          _isUploading = true;
        });
        
        // Assumes deleteDocument takes the ID from DuplicateDocumentInfo
        final deleted = await _apiService.deleteDocument(duplicate.id); 
        if (!deleted && mounted) {
          setState(() {
            _isUploading = false;
            _uploadError = 'Failed to delete existing document';
          });
          return;
        }
      }
      // If "Keep Both" was selected (shouldProceed is 'keep'), continue with upload
    }
    
    if (!mounted) return; // Check if the widget is still in the tree

    setState(() {
      _isUploading = true;
      _uploadError = null;
      _ocrResult = null;
    });

    try {
      final result =
          await _apiService.uploadDocumentWithLimitCheck(_selectedFile!);
      if (mounted) {
        setState(() {
          _ocrResult = result;
           // _selectedFile = null; // Clear selection after successful upload
           // _showUploadDetails = false; // Hide details section
        });
        _refreshDocumentsList(); // Refresh the list after successful upload
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedFile?.path.split('/').last ?? 'Document'} uploaded successfully!')),
        );
         setState(() { // Reset UI for next upload
            _selectedFile = null;
            _showUploadDetails = false;
          });

      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _ocrResult = null;
      _uploadError = null;
      _showUploadDetails = false;
    });
  }

  void _refreshDocumentsList() {
    _documentsListKey.currentState?.loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Added Scaffold for better structure and SnackBar support
      appBar: AppBar(
        title: const Text('Manage Documents'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showUploadDetails || _selectedFile != null)
            Card(
              margin: const EdgeInsets.all(16.0),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Upload New Document',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_selectedFile != null)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _clearSelection,
                            tooltip: 'Clear selection',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedFile == null)
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('Select Document'),
                          onPressed: _pickFile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),
                    if (_selectedFile != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.insert_drive_file, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFile!.path.split('/').last,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: _isUploading
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                                icon: const Icon(Icons.cloud_upload),
                                label: const Text('Upload Selected File'),
                                onPressed: _uploadFile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                      ),
                    ],
                    if (_uploadError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Error: $_uploadError',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    if (_ocrResult != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Upload & OCR Successful!',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      // Optionally display some OCR results or a success message
                    ],
                  ],
                ),
              ),
            )
          else // Show button to initiate upload if nothing is selected
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Upload a Document'),
                    onPressed: _pickFile, // This will set _showUploadDetails to true
                     style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        textStyle: const TextStyle(fontSize: 16)
                      ),
                  ),
                ),
             ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(
                  'Your Documents',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshDocumentsList,
                  tooltip: 'Refresh list',
                ),
              ],
            ),
          ),
          Expanded(
            child: DocumentsList(
              key: _documentsListKey,
              // Optionally pass a callback to handle document selection for QA
              onDocumentSelectedForQA: (documentId) {
                Navigator.pushNamed(context, '/qa', arguments: documentId);
              },
            ),
          ),
        ],
      ),
    );
  }
} 