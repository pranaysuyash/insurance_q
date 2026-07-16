import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/analytics_service.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';

/// Help & Support: a real, self-contained FAQ + contact screen. Uses only
/// information we can actually stand behind (no invented phone numbers or SLAs),
/// per the customer-facing-claims rule — copy stays conditional and honest.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    (
      title: 'How do I ask a question about my policy?',
      body:
          'Open the Q&A tab, pick a document, then tap a suggested question or '
          'type your own. Answers are generated from your uploaded policy text.',
    ),
    (
      title: 'Why does an answer say it is unavailable?',
      body:
          'Q&A needs an internet connection and a synced document. If you are '
          'offline or the document has not finished uploading, the app tells you '
          'and lets you retry.',
    ),
    (
      title: 'Can I use the app offline?',
      body:
          'Yes. Your uploaded documents and question history are stored locally '
          'and available without a connection. Generating new answers and '
          'uploading new documents require a connection.',
    ),
    (
      title: 'How accurate are the answers?',
      body:
          'Answers are based on the text in your policy using retrieval-augmented '
          'generation. Always confirm important details (coverage, exclusions, '
          'claim procedures) against the source document and your insurer.',
    ),
    (
      title: 'How do I delete a document?',
      body:
          'Go to the Documents tab, open the document, and use the delete action. '
          'This removes it from this device.',
    ),
  ];

  Future<void> _launchEmail() async {
    final uri =
        Uri.parse('mailto:support@coverwise.app?subject=CoverWise%20Support');
    AnalyticsService.track('support_intent', {'source_surface': 'help_screen'});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help and support')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const CoverWisePageHeader(
            title: 'How can we help?',
            subtitle:
                'Find answers about documents, policy questions, offline access, and data removal.',
          ),
          const CoverWiseSectionLabel('Frequently asked questions'),
          CoverWiseSurface(
            child: Column(
              children: [
                for (var i = 0; i < _faqs.length; i++) ...[
                  ExpansionTile(
                    leading: const CoverWiseIconBadge(
                      icon: Icons.help_outline_rounded,
                      color: CoverWiseColors.blueDeep,
                      size: 40,
                    ),
                    title: Text(
                      _faqs[i].title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _faqs[i].body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  if (i < _faqs.length - 1) const Divider(),
                ],
              ],
            ),
          ),
          const CoverWiseSectionLabel('Still need help?'),
          CoverWiseSurface(
            child: Column(
              children: [
                CoverWiseActionRow(
                  icon: Icons.mail_outline_rounded,
                  color: CoverWiseColors.blueDeep,
                  title: 'Contact support',
                  subtitle: 'Email the CoverWise team',
                  onTap: _launchEmail,
                ),
                const Divider(),
                CoverWiseActionRow(
                  icon: Icons.info_outline_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                  title: 'App version',
                  subtitle: '${AppConfig.appName} ${AppConfig.appVersion}',
                  onTap: null,
                  trailing: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
