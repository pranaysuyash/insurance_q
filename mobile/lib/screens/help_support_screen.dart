import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/analytics_service.dart';

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
    final uri = Uri.parse('mailto:support@coverwise.app?subject=CoverWise%20Support');
    AnalyticsService.track('support_intent', {'source_surface': 'help_screen'});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Frequently asked questions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ..._faqs.map((f) => ExpansionTile(
                leading: const Icon(Icons.help_outline),
                title: Text(f.title),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [Text(f.body)],
              )),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact support'),
            subtitle: const Text('Email the CoverWise team'),
            onTap: _launchEmail,
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('App version'),
            subtitle: Text('${AppConfig.appName} ${AppConfig.appVersion}'),
          ),
        ],
      ),
    );
  }
}
