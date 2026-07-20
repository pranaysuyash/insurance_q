import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/legal_content_section.dart';

/// In-app privacy policy viewer.
///
/// Displays the privacy policy content directly in the app so users
/// can review data practices without leaving the app. This is shown
/// during onboarding and from the Privacy & Security screen.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
            onPressed: () => _copyPolicy(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                                'CoverWise Privacy Policy',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Effective July 20, 2026',
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

            // Policy content — uses shared LegalContentSection widget
            LegalContentSection(
              title: 'Introduction',
              content: 'CoverWise ("we," "our," or "us") helps you understand your insurance policies '
                  'by extracting key information and answering your questions in plain language. '
                  'This Privacy Policy explains what data we collect, how we use it, and your rights.\n\n'
                  'We are an **information broker** — we help you understand your policies. '
                  'We do not sell insurance, provide financial advice, or act as an insurer.',
            ),
            LegalContentSection(
              title: 'What We Collect',
              content: '**Data You Provide:**\n'
                  '• Policy documents (PDFs and images you upload)\n'
                  '• Your questions about policies\n'
                  '• Account information (email, optional)\n\n'
                  '**Data We Generate:**\n'
                  '• Policy summaries from extracted information\n'
                  '• Search indexes for finding relevant sections\n'
                  '• Anonymous usage analytics (opt-in)\n\n'
                  '**We Do NOT Collect:**\n'
                  '• Financial information or payment details\n'
                  '• Health information beyond policy documents\n'
                  '• Location data\n'
                  '• Contact lists',
            ),
            LegalContentSection(
              title: 'How We Use Your Data',
              content: '**Policy Processing:** Documents stored in encrypted Supabase Storage\n\n'
                  '**Q&A Answers:** Questions processed temporarily, not stored server-side\n\n'
                  '**Search Functionality:** Vector embeddings in private pgvector index\n\n'
                  '**App Improvement:** Anonymous event counts (opt-in, 30-day retention)',
            ),
            LegalContentSection(
              title: 'Data Retention',
              content: '**Local Data:** Stored on your device until you delete it\n\n'
                  '**Server Data:** Retained until account deletion (best-effort)\n\n'
                  '**Analytics:** Automatically purged after 30 days\n\n'
                  '**Account Data:** Deleted within 30 days of deletion request',
            ),
            LegalContentSection(
              title: 'Your Rights',
              content: '**Access:** View all data in the app\n\n'
                  '**Correction:** Edit extracted information directly\n\n'
                  '**Deletion:** Delete local data anytime; request account deletion\n\n'
                  '**Consent:** Toggle analytics consent in Settings → Privacy',
            ),
            LegalContentSection(
              title: 'Security',
              content: '• All communication encrypted via HTTPS/TLS\n'
                  '• API keys stored as environment variables\n'
                  '• Rate limiting prevents abuse\n'
                  '• Anonymous device identity protects documents',
            ),
            LegalContentSection(
              title: 'Contact',
              content: 'For privacy questions or data requests:\n'
                  '• Email: support@coverwise.app\n'
                  '• In-app: Settings → Help & Support',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _copyPolicy(BuildContext context) {
    final policyText = '''
CoverWise Privacy Policy (Effective July 20, 2026)

Introduction
CoverWise helps you understand your insurance policies. We are an information broker — we do not sell insurance or provide financial advice.

What We Collect
• Policy documents you upload
• Your questions about policies
• Account information (optional)
• Anonymous usage analytics (opt-in)

We Do NOT Collect
• Financial information or payment details
• Health information beyond policy documents
• Location data
• Contact lists

Data Retention
• Local data: Until you delete it
• Server data: Until account deletion
• Analytics: 30 days automatic purge

Your Rights
• Access: View all data in the app
• Correction: Edit extracted information
• Deletion: Delete anytime
• Consent: Toggle analytics in Settings

Security
• HTTPS/TLS encryption
• Environment variable API keys
• Rate limiting

Contact: support@coverwise.app
''';

    Clipboard.setData(ClipboardData(text: policyText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy policy copied to clipboard')),
    );
  }
}
