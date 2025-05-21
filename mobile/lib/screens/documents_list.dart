import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../services/api_service.dart';

class DocumentsList extends StatefulWidget {
  const DocumentsList({Key? key}) : super(key: key);

  @override
  DocumentsListState createState() => DocumentsListState();
}

class DocumentsListState extends State<DocumentsList> {
  final ApiService _apiService = ApiService();
  List<InsuranceDocument> _documents = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final documents = await _apiService.getDocuments();
      setState(() {
        _documents = documents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading documents: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDocument(InsuranceDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${document.filename}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final success = await _apiService.deleteDocument(document.id);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document deleted successfully')),
          );
          loadDocuments();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to delete document';
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error deleting document: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _documents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loadDocuments,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_documents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No documents yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Upload a document to get started',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadDocuments,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '${_documents.length}/5 documents (free storage limit)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _documents.length,
              itemBuilder: (context, index) {
                final doc = _documents[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ExpansionTile(
                    leading: _getDocumentIcon(doc.documentType),
                    title: Text(
                      doc.filename,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Uploaded: ${doc.formattedUploadDate}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMetadataRow('Document ID', doc.id),
                            _buildMetadataRow('Type', doc.documentType ?? 'Unknown'),
                            _buildMetadataRow('Upload Date', doc.formattedUploadDate),
                            _buildMetadataRow('Analysis Date', doc.formattedAnalyzedDate),
                            if (doc.size != null)
                              _buildMetadataRow('Size', doc.formattedFileSize),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.question_answer),
                                  label: const Text('Ask Questions'),
                                  onPressed: () {
                                    // Navigate to QA screen with this document
                                    Navigator.pushNamed(
                                      context,
                                      '/qa',
                                      arguments: doc.id,
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Delete'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  onPressed: () => _deleteDocument(doc),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _getDocumentIcon(String? documentType) {
    if (documentType == null) {
      return const Icon(Icons.description);
    }
    
    switch (documentType.toLowerCase()) {
      case 'health insurance':
        return const Icon(Icons.health_and_safety, color: Colors.red);
      case 'auto insurance':
        return const Icon(Icons.directions_car, color: Colors.blue);
      case 'life insurance':
        return const Icon(Icons.favorite, color: Colors.pink);
      case 'home insurance':
        return const Icon(Icons.home, color: Colors.brown);
      default:
        return const Icon(Icons.description);
    }
  }
} 