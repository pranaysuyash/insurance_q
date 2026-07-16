import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../theme/coverwise_theme.dart';
import '../utils/document_icons.dart';
import 'shared/coverwise_components.dart';

class PolicyComparisonSheet extends StatelessWidget {
  final List<InsuranceDocument> documents;

  const PolicyComparisonSheet({super.key, required this.documents});

  @override
  Widget build(BuildContext context) {
    final policies = documents.take(2).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const CoverWiseIconBadge(
                  icon: Icons.compare_arrows_rounded,
                  color: CoverWiseColors.blueDeep,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Compare policies',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.4,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              policies.length < 2
                  ? 'You currently have one policy in the library. Add another policy to compare coverage, dates, and document details side by side.'
                  : 'Compare the two most recent policies in your library.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 16),
            if (policies.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const CoverWiseIconBadge(
                        icon: Icons.file_copy_outlined,
                        color: CoverWiseColors.blueDeep,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No policies available to compare yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (policies.length == 1)
                _buildComparisonCard(
                  context: context,
                  title: 'Current Policy',
                  document: policies.first,
                  accent: Colors.orange,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackCards = constraints.maxWidth < 560 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.2;
                    final first = _buildComparisonCard(
                      context: context,
                      title: 'Policy A',
                      document: policies[0],
                      accent: Colors.orange,
                    );
                    final second = _buildComparisonCard(
                      context: context,
                      title: 'Policy B',
                      document: policies[1],
                      accent: Colors.teal,
                    );
                    if (stackCards) {
                      return Column(
                        children: [first, const SizedBox(height: 12), second],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: first),
                        const SizedBox(width: 12),
                        Expanded(child: second),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 12),
              if (policies.length < 2)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.add_to_photos_outlined,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Comparison mode is ready. Upload a second policy to compare both in one view.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    height: 1.4,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard({
    required BuildContext context,
    required String title,
    required InsuranceDocument document,
    required Color accent,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CoverWiseIconBadge(
                  icon: iconForDocumentType(document.documentType),
                  color: accent,
                  size: 38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              document.filename,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _detail(context, 'Type', document.documentType ?? 'Unknown'),
            _detail(context, 'Uploaded', document.formattedUploadDate),
            _detail(context, 'Analyzed', document.formattedAnalyzedDate),
            _detail(context, 'Size', document.formattedFileSize),
            _detail(
              context,
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

  Widget _detail(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
