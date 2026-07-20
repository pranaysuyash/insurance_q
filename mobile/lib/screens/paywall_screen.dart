import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/analytics_service.dart';
import 'upgrade_screen.dart';

/// Paywall shown when a free-tier user hits a limit.
///
/// Phase 1: No actual payment — the "Upgrade" button shows "coming soon."
/// This measures demand for paid features via analytics before building
/// payment integration.
///
/// Phase 2: Replace "coming soon" with Razorpay checkout.
///
/// Usage: `PaywallScreen.show(context, limitType: PaywallLimitType.documents)`.
class PaywallScreen extends StatelessWidget {
  final PaywallLimitType limitType;

  const PaywallScreen({super.key, required this.limitType});

  static Future<void> show(BuildContext context,
      {required PaywallLimitType limitType}) async {
    AnalyticsService.track('free_tier_limit_hit', {
      'limit_type': limitType.name,
    });
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(limitType: limitType),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Pro'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // Limit message
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.lock_outline, size: 40, color: Colors.orange.shade700),
                  const SizedBox(height: 12),
                  Text(
                    _limitMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Pro features list
            const Text(
              'CoverWise Pro includes:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._proFeatures.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.title,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                            Text(f.description,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 32),
            // Pricing teaser
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Text(
                    '₹499 / year',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  Text(
                    'or ₹99 / month',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Launch offer: ₹299 lifetime for first 100 members',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // CTA — route to the existing UpgradeScreen (RevenueCat-powered)
            FilledButton(
              onPressed: () {
                AnalyticsService.track('upgrade_tapped', {
                  'limit_type': limitType.name,
                });
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UpgradeScreen(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Notify Me When Available',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
            const SizedBox(height: 24),
            Text(
              '${AppConfig.appName} will always be free for basic use. Pro adds '
              'unlimited policies, priority answers, and advanced tools.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String get _limitMessage {
    switch (limitType) {
      case PaywallLimitType.documents:
        return 'You\'ve reached the free limit of 5 policies. '
            'Upgrade to add unlimited policies.';
      case PaywallLimitType.queries:
        return 'You\'ve reached your daily question limit. '
            'Upgrade for unlimited questions and faster answers.';
    }
  }

  List<_ProFeature> get _proFeatures => const [
        _ProFeature(
            title: 'Unlimited Policies',
            description: 'No limit on the number of insurance documents'),
        _ProFeature(
            title: 'Priority Q&A',
            description: 'Unlimited questions with faster, prioritized answers'),
        _ProFeature(
            title: 'Coverage Gap Alerts',
            description: 'Get notified when a coverage gap is detected'),
        _ProFeature(
            title: 'Export to PDF',
            description: 'Share your policy summary with family or your CA'),
        _ProFeature(
            title: 'Family Plans',
            description: 'Manage coverage for up to 6 family members'),
      ];
}

enum PaywallLimitType { documents, queries }

class _ProFeature {
  final String title;
  final String description;
  const _ProFeature({required this.title, required this.description});
}
