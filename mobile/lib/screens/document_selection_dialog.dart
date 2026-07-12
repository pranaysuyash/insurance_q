import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../utils/document_icons.dart';

class DocumentSelectionDialog extends StatelessWidget {
  final List<InsuranceDocument> documents;
  final String? currentDocumentId;
  final Function(String?) onDocumentSelected;

  const DocumentSelectionDialog({
    super.key,
    required this.documents,
    this.currentDocumentId,
    required this.onDocumentSelected,
  });

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
    return Icon(
      iconForDocumentType(documentType),
      color: colorForDocumentType(documentType),
    );
  }
} 