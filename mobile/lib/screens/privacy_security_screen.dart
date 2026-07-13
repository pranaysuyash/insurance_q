import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

/// Privacy & Security: visible copy follows the production data architecture.
class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  Future<void> _openHostedPolicy() async {
    final uri = Uri.parse(AppConfig.privacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (AppConfig.hasPrivacyPolicy) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: Icon(Icons.open_in_new,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('View Full Privacy Policy'),
                subtitle: const Text('Opens in your browser'),
                onTap: _openHostedPolicy,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('Data We Collect',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const _PrivacyItem(
            icon: Icons.description,
            title: 'Policy documents',
            body: 'When you upload an insurance policy (PDF or image), it is '
                'stored on your device. When you choose to sync a policy, the '
                'document is sent to CoverWise for summaries and answers.',
          ),
          const _PrivacyItem(
            icon: Icons.question_answer,
            title: 'Your questions',
            body:
                'Questions you ask about your policies are sent to the backend '
                'to retrieve relevant answers. Questions and answers are stored '
                'locally on your device for your history.',
          ),
          const _PrivacyItem(
            icon: Icons.phone_android,
            title: 'Device data',
            body: 'A secure anonymous app identity protects your documents and '
                'enforces usage limits. An account is not required at launch.',
          ),
          const SizedBox(height: 16),
          Text('How Your Data Is Processed',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const _PrivacyItem(
            icon: Icons.cloud,
            title: 'Backend processing',
            body: 'Your policy text and questions are processed by CoverWise. '
                'Synced data is stored in private Supabase Storage and Postgres. '
                'Text may be sent to OpenAI for analysis and answer generation.',
          ),
          const _PrivacyItem(
            icon: Icons.hub,
            title: 'Search index',
            body: 'Policy text is converted to vector embeddings and stored in '
                'CoverWise’s private pgvector search index to find relevant '
                'policy sections when you ask a question.',
          ),
          const _PrivacyItem(
            icon: Icons.block,
            title: 'No data selling',
            body: 'CoverWise does not sell, share, or rent your data to third '
                'parties. Your policy documents are used solely to provide the '
                'app\'s features to you.',
          ),
          const SizedBox(height: 16),
          Text('Data Retention & Deletion',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const _PrivacyItem(
            icon: Icons.timer,
            title: 'Local storage',
            body: 'Documents, summaries, and Q&A history are stored on your '
                'device and persist until you delete them. Use Settings → '
                'Clear local data to remove everything at any time.',
          ),
          const _PrivacyItem(
            icon: Icons.timer_off,
            title: 'Server storage',
            body: 'Synced policies are retained in private storage, metadata, '
                'summaries, and the search index to answer your questions. '
                'Deleting a synced policy removes these server-side records.',
          ),
          _PrivacyItem(
            icon: Icons.delete_outline,
            title: 'Your rights',
            body: AppConfig.hasSupportEmail
                ? 'You can delete all local data at any time via Settings. For '
                    'help with server-side data, contact ${AppConfig.supportEmail}.'
                : 'You can delete all local data at any time via Settings. '
                    'Use the release support channel for server-side data help.',
          ),
          const SizedBox(height: 16),
          Text('Security',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const _PrivacyItem(
            icon: Icons.lock,
            title: 'Encryption',
            body: 'All communication between the app and the backend is '
                'encrypted using HTTPS/TLS. API keys and credentials are '
                'stored as environment variables, not in the app code.',
          ),
          const _PrivacyItem(
            icon: Icons.speed,
            title: 'Rate limits',
            body: 'Usage is limited per session and per device to prevent '
                'abuse and ensure fair availability of the service.',
          ),
          const SizedBox(height: 24),
          Text(
            'CoverWise helps you understand your insurance policies. It does '
            'not provide insurance, financial, or legal advice. Always verify '
            'coverage details with your insurer. Answers are AI-generated and '
            'may contain errors.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PrivacyItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
