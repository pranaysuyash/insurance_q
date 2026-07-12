import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Privacy & Security: a real privacy policy covering what data is collected,
/// how it's processed, and user rights. Replace the hosted URL constant below
/// with a real hosted version before app store submission.
class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  /// Replace with your hosted privacy policy URL before submitting to stores.
  static const _hostedPolicyUrl = 'https://coverwise.app/privacy';

  Future<void> _openHostedPolicy() async {
    final uri = Uri.parse(_hostedPolicyUrl);
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
          // Hosted policy link
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

          Text('Data We Collect',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const _PrivacyItem(
            icon: Icons.description,
            title: 'Policy documents',
            body: 'When you upload an insurance policy (PDF or image), the text '
                'is extracted and stored on your device. The text is also sent '
                'to the CoverWise backend to generate answers and summaries.',
          ),
          const _PrivacyItem(
            icon: Icons.question_answer,
            title: 'Your questions',
            body: 'Questions you ask about your policies are sent to the backend '
                'to retrieve relevant answers. Questions and answers are stored '
                'locally on your device for your history.',
          ),
          const _PrivacyItem(
            icon: Icons.phone_android,
            title: 'Device data',
            body: 'A random session ID is generated on your device to enforce '
                'usage limits. No account, email, or personal information is '
                'required to use the app.',
          ),

          const SizedBox(height: 16),
          Text('How Your Data Is Processed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const _PrivacyItem(
            icon: Icons.cloud,
            title: 'Backend processing',
            body: 'Your policy text and questions are processed on CoverWise '
                'servers hosted on AWS (ap-south-1, India). Text is sent to '
                'OpenAI for AI-powered analysis and answer generation.',
          ),
          const _PrivacyItem(
            icon: Icons.hub,
            title: 'Vector database',
            body: 'Policy text is converted to vector embeddings and stored in '
                'a vector database (Qdrant) to enable semantic search. This '
                'allows the app to find relevant policy sections when you ask '
                'a question.',
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
            body: 'Documents uploaded to the backend may be retained in the '
                'vector database to answer your future questions. The backend '
                'does not currently support individual document deletion '
                'requests — this is a known limitation being addressed.',
          ),
          const _PrivacyItem(
            icon: Icons.delete_outline,
            title: 'Your rights',
            body: 'You can delete all local data at any time via Settings. To '
                'request deletion of server-side data, contact '
                'support@coverwise.app.',
          ),

          const SizedBox(height: 16),
          Text('Security',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
