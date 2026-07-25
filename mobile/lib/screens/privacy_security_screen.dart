import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/consent_ledger.dart';
import '../services/analytics_service.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';
import 'consent_activity_screen.dart';
import 'privacy_policy_screen.dart';

/// Privacy & Security: visible copy follows the production data architecture.
class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  late bool _analyticsConsent;
  final _ledger = ConsentLedger();

  @override
  void initState() {
    super.initState();
    _analyticsConsent = _ledger.hasConsent(ConsentPurpose.analytics);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPolicyVersion());
  }

  Future<void> _checkPolicyVersion() async {
    if (!mounted) return;
    if (_ledger.isPrivacyPolicyAccepted(AppConfig.privacyPolicyVersion)) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy policy updated'),
        content: const Text(
          'The privacy policy has been updated. Please review and accept '
          'the new version to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              );
            },
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('I accept'),
          ),
        ],
      ),
    );

    if (accepted == true && mounted) {
      await _ledger.recordPolicyAcceptance(
        version: AppConfig.privacyPolicyVersion,
      );
    }
  }

  Future<void> _toggleAnalyticsConsent(bool value) async {
    setState(() => _analyticsConsent = value);
    try {
      await _ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'analytics-v1',
        granted: value,
      );
      // Refresh the analytics service cache so track() respects the new state.
      AnalyticsService.refreshConsentCache();
      if (value) {
        // Re-grant: track a re-enable event for audit.
        AnalyticsService.track('analytics_consent_re_enabled');
      }
    } catch (e) {
      // Revert the switch if persistence fails.
      if (mounted) setState(() => _analyticsConsent = !value);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    if (!mounted) return;
    if (AppConfig.hasPrivacyPolicy) {
      final uri = Uri.parse(AppConfig.privacyPolicyUrl);
      if (await canLaunchUrl(uri)) {
        if (!mounted) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PrivacyPolicyScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and security')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const CoverWisePageHeader(
            title: 'Your data, explained',
            subtitle:
                'See what stays on your device, what is synced for app features, and how to remove it.',
          ),
          // A release requires a hosted policy URL, but development and
          // review builds must still expose the bundled, versioned policy.
          // Hiding this row when no URL is injected would make the fallback
          // unreachable exactly when a reviewer needs to inspect it.
          CoverWiseSurface(
            child: CoverWiseActionRow(
              icon: Icons.privacy_tip_outlined,
              color: CoverWiseColors.blueDeep,
              title: 'View full privacy policy',
              subtitle: AppConfig.hasPrivacyPolicy
                  ? 'Opens in your browser'
                  : 'View in app',
              onTap: _openPrivacyPolicy,
              trailing: AppConfig.hasPrivacyPolicy
                  ? const Icon(Icons.open_in_new_rounded)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          CoverWiseSurface(
            child: CoverWiseActionRow(
              icon: Icons.history_rounded,
              color: CoverWiseColors.blueDeep,
              title: 'View consent activity',
              subtitle:
                  'See the account record of privacy choices and policy versions',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ConsentActivityScreen(),
                ),
              ),
            ),
          ),
          const CoverWiseSectionLabel('Data we collect'),
          const _PrivacyItem(
            icon: Icons.description,
            title: 'Policy documents',
            body: 'When you upload an insurance policy (PDF or image), it is '
                'stored on your device. When you choose to sync a policy, the '
                'document is sent to CoverWise for summaries and answers.',
          ),
          const _PrivacyItem(
            icon: Icons.chat_bubble_outline_rounded,
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
          // Analytics consent toggle — lets users control usage tracking.
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : CoverWiseColors.line,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CoverWiseIconBadge(
                  icon: Icons.analytics_outlined,
                  color: CoverWiseColors.blueDeep,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Analytics',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        'Help improve CoverWise by sharing anonymous usage '
                        'statistics. No personal data or policy content is '
                        'included — only anonymous event counts and '
                        'feature usage patterns.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _analyticsConsent,
                  onChanged: _toggleAnalyticsConsent,
                ),
              ],
            ),
          ),
          const CoverWiseSectionLabel('How your data is processed'),
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
            // Security audit P0-18 (2026-07-18): "No data selling" was
            // imprecise while Supabase and OpenAI process data. The
            // honest version is: CoverWise does not sell, share, or
            // rent your data to third parties. Sub-processors
            // (Supabase for storage, OpenAI for analysis) process
            // data under contract to provide the app's features.
            title: 'No data selling',
            body: 'CoverWise does not sell, share, or rent your data to '
                'third parties. Your policy documents are processed by '
                'CoverWise and by named sub-processors (Supabase for '
                'private storage, OpenAI for analysis) under contract to '
                'provide the app\'s features. No marketing use, no '
                'third-party advertising.',
          ),
          const CoverWiseSectionLabel('Retention and deletion'),
          const _PrivacyItem(
            icon: Icons.timer,
            title: 'Local cache',
            body: 'A protected local cache keeps documents, summaries, and '
                'Q&A history available on this device. Use Settings → '
                'Clear local data to remove the local cache at any time.',
          ),
          const _PrivacyItem(
            icon: Icons.timer_off,
            title: 'Server storage',
            body: 'Synced policies are retained in private storage, '
                'metadata, summaries, and the search index. Deleting a '
                'synced policy requests remote-first deletion; the local '
                'copy is removed only after the server confirms. Failed '
                'deletions remain available so you can retry.',
          ),
          _PrivacyItem(
            icon: Icons.delete_outline,
            title: 'Your rights',
            // Security audit P0-04 + P0-18: account deletion returns
            // 202 + per-stage status. The previous copy implied a
            // single click would remove everything. The honest
            // version is: deletion is best-effort per stage; partial
            // deletions are surfaced honestly.
            body: AppConfig.hasSupportEmail
                ? 'You can delete all local data at any time via Settings. '
                    'For account deletion, use the Delete account action '
                    'in Settings; the backend returns a per-stage status '
                    'and any incomplete stages will be retried. For '
                    'questions, contact ${AppConfig.supportEmail}.'
                : 'You can delete all local data at any time via Settings. '
                    'Use the release support channel for account and '
                    'server-side data requests.',
          ),
          const CoverWiseSectionLabel('Security'),
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
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CoverWiseColors.blueDeep.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: CoverWiseColors.blueDeep.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: CoverWiseColors.blueDeep),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'CoverWise helps you understand your insurance policies. It does not provide insurance, financial, or legal advice. Always verify coverage details with your insurer. Answers are AI-generated and may contain errors.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.45,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
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
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : CoverWiseColors.line,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoverWiseIconBadge(
            icon: icon,
            color: CoverWiseColors.blueDeep,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
