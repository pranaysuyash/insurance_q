import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_mark.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

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
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Column(
              children: [
                CoverWiseMark(
                  size: 84,
                  onDark: Theme.of(context).brightness == Brightness.dark,
                  decorative: true,
                ),
                const SizedBox(height: 18),
                Text(
                  AppConfig.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${AppConfig.appVersion}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${AppConfig.appName} helps you understand insurance documents and ask questions in plain language. Answers are generated from your policy text.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const CoverWiseSectionLabel('Important information'),
          CoverWiseSurface(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CoverWiseIconBadge(
                    icon: Icons.info_outline_rounded,
                    color: CoverWiseColors.blueDeep,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${AppConfig.appName} provides information based on your documents to help you understand them. It does not constitute insurance, financial, or legal advice. Answers are AI-generated and may contain errors. Always verify coverage details against your policy document and with your insurer. Coverage decisions are determined by your policy and insurer, not by this app.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.5,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (AppConfig.hasPrivacyPolicy || AppConfig.hasTermsOfService) ...[
            const CoverWiseSectionLabel('Legal'),
            CoverWiseSurface(
              child: Column(
                children: [
                  CoverWiseActionRow(
                    icon: Icons.privacy_tip_outlined,
                    color: CoverWiseColors.blueDeep,
                    title: 'Privacy policy',
                    subtitle: 'How CoverWise handles your data',
                    trailing: AppConfig.hasPrivacyPolicy
                        ? const Icon(Icons.open_in_new_rounded)
                        : null,
                    onTap: () {
                      if (AppConfig.hasPrivacyPolicy) {
                        _openUrl(AppConfig.privacyPolicyUrl);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(),
                  CoverWiseActionRow(
                    icon: Icons.gavel_outlined,
                    color: Theme.of(context).colorScheme.tertiary,
                    title: 'Terms of service',
                    subtitle: 'Terms for using CoverWise',
                    trailing: AppConfig.hasTermsOfService
                        ? const Icon(Icons.open_in_new_rounded)
                        : null,
                    onTap: () {
                      if (AppConfig.hasTermsOfService) {
                        _openUrl(AppConfig.termsOfServiceUrl);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsOfServiceScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
