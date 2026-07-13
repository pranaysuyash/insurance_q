import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

/// About screen: app identity, version, description, disclaimer, and legal links.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
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
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${AppConfig.appName} provides information based on your documents to '
            'help you understand them. It does not constitute insurance, '
            'financial, or legal advice. Answers are AI-generated and may '
            'contain errors. Always verify coverage details against your policy '
            'document and with your insurer. Coverage decisions are determined '
            'by your policy and insurer, not by this app.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (AppConfig.hasPrivacyPolicy || AppConfig.hasTermsOfService)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (AppConfig.hasPrivacyPolicy)
                  TextButton.icon(
                    icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                    label: const Text('Privacy Policy'),
                    onPressed: () => _openUrl(AppConfig.privacyPolicyUrl),
                  ),
                if (AppConfig.hasTermsOfService)
                  TextButton.icon(
                    icon: const Icon(Icons.gavel_outlined, size: 18),
                    label: const Text('Terms of Service'),
                    onPressed: () => _openUrl(AppConfig.termsOfServiceUrl),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
