import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/legal_content_section.dart';
import '../services/legal_content_loader.dart';

/// In-app privacy policy viewer.
///
/// Loads content from `assets/legal/privacy_policy.md` at runtime
/// via [LegalContentLoader] — the single source of truth.
/// Copy-to-clipboard uses the same parsed sections.
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  Future<LegalDocument>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= LegalContentLoader.loadPrivacyPolicy(
      bundle: DefaultAssetBundle.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy policy text',
            onPressed: () async {
              final doc = await _future;
              if (!mounted || doc == null) return;
              Clipboard.setData(ClipboardData(text: doc.toPlainText()));
              // ignore: use_build_context_synchronously — guarded by mounted check above
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy copied to clipboard')),
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
                  Text('Failed to load privacy policy: ${snapshot.error}'),
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
                              icon: Icons.privacy_tip_outlined,
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
