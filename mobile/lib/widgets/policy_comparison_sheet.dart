import 'package:flutter/material.dart';
import '../models/document_model.dart';

class PolicyComparisonSheet extends StatelessWidget {
  final List<InsuranceDocument> documents;

  const PolicyComparisonSheet({super.key, required this.documents});

  @override
  Widget build(BuildContext context) {
    final policies = documents.take(2).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Policy Comparison',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              policies.length < 2
                  ? 'You currently have one policy in the library. Add another policy to compare coverage, dates, and document details side by side.'
                  : 'Compare the two most recent policies in your library.',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            if (policies.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No policies available to compare yet.'),
                ),
              )
            else ...[
              if (policies.length == 1)
                _buildComparisonCard(
                  title: 'Current Policy',
                  document: policies.first,
                  accent: Colors.orange,
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildComparisonCard(
                        title: 'Policy A',
                        document: policies[0],
                        accent: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildComparisonCard(
                        title: 'Policy B',
                        document: policies[1],
                        accent: Colors.teal,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (policies.length < 2)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Text(
                    'Comparison mode is ready, but there is only one policy uploaded right now. Upload a second policy to compare both in one view.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required InsuranceDocument document,
    required Color accent,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              document.filename,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _detail('Type', document.documentType ?? 'Unknown'),
            _detail('Uploaded', document.formattedUploadDate),
            _detail('Analyzed', document.formattedAnalyzedDate),
            _detail('Size', document.formattedFileSize),
            _detail(
              'Status',
              document.policyHolders?.isNotEmpty == true
                  ? 'Coverage details available'
                  : 'No extracted family details',
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
