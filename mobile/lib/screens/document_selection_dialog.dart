import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../utils/document_icons.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';

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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a policy',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'CoverWise will ground the next answer in this document.',
            ),
            const SizedBox(height: 16),

            // Document limit indicator
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 18, color: CoverWiseColors.blue),
                const SizedBox(width: 8),
                Text(
                  '${documents.length}/5 documents (free storage limit)',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: CoverWiseColors.blueDeep,
                        fontWeight: FontWeight.w700,
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
                    final details = [
                      doc.documentType ?? 'Policy document',
                      doc.formattedUploadDate,
                      if (doc.size != null) doc.formattedFileSize,
                    ].join(' • ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: CoverWiseSelectableRow(
                        icon: iconForDocumentType(doc.documentType),
                        color: colorForDocumentType(doc.documentType),
                        title: doc.filename,
                        subtitle: details,
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
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
