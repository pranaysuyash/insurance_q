import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// About screen: app identity, version, and a short description. No invented
/// legal entities or claims.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.shield,
              size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            AppConfig.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Version ${AppConfig.appVersion}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Text(
            '${AppConfig.appName} helps you understand your insurance policies. '
            'Upload a policy document and ask questions in plain language — '
            'answers are generated from your policy text.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text('Disclaimer',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${AppConfig.appName} provides information based on your documents to '
            'help you understand them. It does not constitute insurance advice, '
            'and answers should not replace reviewing your policy or contacting '
            'your insurer. Coverage decisions are determined by your policy and '
            'insurer.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
