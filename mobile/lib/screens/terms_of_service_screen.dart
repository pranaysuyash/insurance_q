import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/legal_content_section.dart';
import '../services/legal_content_loader.dart';

/// In-app terms of service viewer.
///
/// Loads content from `assets/legal/terms_of_service.md` at runtime
/// via [LegalContentLoader] — the single source of truth.
/// Copy-to-clipboard uses the same parsed sections.
class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
  Future<LegalDocument>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= LegalContentLoader.loadTermsOfService(
      bundle: DefaultAssetBundle.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy terms text',
            onPressed: () async {
              final doc = await _future;
              if (!mounted || doc == null) return;
              Clipboard.setData(ClipboardData(text: doc.toPlainText()));
              // ignore: use_build_context_synchronously — guarded by mounted check above
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Terms of service copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<LegalDocument>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Failed to load terms of service: ${snapshot.error}'),
                ],
              ),
            );
          }

          final doc = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                CoverWiseSurface(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CoverWiseIconBadge(
                              icon: Icons.gavel_outlined,
                              color: CoverWiseColors.blueDeep,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Effective ${doc.effectiveDate}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sections from parsed markdown
                for (final section in doc.sections)
                  LegalContentSection(
                    title: section.title,
                    content: section.content,
                  ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

}
