import 'package:flutter/material.dart';
import '../models/document_model.dart';

class DocumentSelectionDialog extends StatelessWidget {
  final List<InsuranceDocument> documents;
  final String? currentDocumentId;
  final Function(String?) onDocumentSelected;

  const DocumentSelectionDialog({
    Key? key,
    required this.documents,
    this.currentDocumentId,
    required this.onDocumentSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Document',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose which document to ask questions about:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            
            // All documents option
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('All Documents'),
              subtitle: const Text('Search across all your policies'),
              selected: currentDocumentId == null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () {
                onDocumentSelected(null);
                Navigator.pop(context);
              },
            ),
            
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            
            // Document limit indicator
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '${documents.length}/5 documents (free storage limit)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // List of specific documents
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: _getDocumentIcon(doc.documentType),
                        title: Text(doc.filename),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Uploaded: ${doc.formattedUploadDate}'),
                            if (doc.documentType != null)
                              Text('Type: ${doc.documentType}'),
                            if (doc.size != null)
                              Text('Size: ${doc.formattedFileSize}'),
                          ],
                        ),
                        trailing: doc.id == currentDocumentId
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        isThreeLine: true,
                        selected: doc.id == currentDocumentId,
                        onTap: () {
                          onDocumentSelected(doc.id);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
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