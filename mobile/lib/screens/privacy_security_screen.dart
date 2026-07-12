import 'package:flutter/material.dart';

/// Privacy & Security: a transparent summary of what the app stores locally
/// and what it sends to the backend. Kept strictly factual — this describes the
/// real data behavior (local Hive storage + backend document/query calls) rather
/// than a polished legal policy. Replace with reviewed legal copy before a
/// public store listing.
class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Your data',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const _PrivacyItem(
            icon: Icons.phone_android,
            title: 'Stored on your device',
            body: 'Your documents, question history, and session ID are saved '
                'locally using on-device storage. They remain available offline '
                'and are not removed unless you clear them in Settings.',
          ),
          const _PrivacyItem(
            icon: Icons.cloud_upload_outlined,
            title: 'Sent to the backend',
            body: 'When you ask a question or upload a document, the relevant '
                'content is sent to the CoverWise backend to generate an answer. '
                'This is required for Q&A and document processing.',
          ),
          const _PrivacyItem(
            icon: Icons.lock_outline,
            title: 'Rate limits',
            body: 'Usage is limited per session and per device to keep the '
                'service fair and available. These limits are enforced server-side.',
          ),
          const SizedBox(height: 16),
          Text('Your control',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const _PrivacyItem(
            icon: Icons.delete_outline,
            title: 'Delete your data',
            body: 'Use Settings → Clear local data to remove documents and '
                'history from this device at any time.',
          ),
          const SizedBox(height: 24),
          Text(
            'This is a summary, not a legal document. For production listings, '
            'replace this with a reviewed privacy policy.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
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
