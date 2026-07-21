import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import 'upgrade_screen.dart';

/// Compatibility entry point used when a free-plan limit is reached.
///
/// Pricing, plan features and purchase actions intentionally remain owned by
/// [UpgradeScreen]. This wrapper contributes only the reason the user arrived,
/// preventing limit messaging from becoming a second monetization surface.
class PaywallScreen extends StatelessWidget {
  final PaywallLimitType limitType;

  const PaywallScreen({super.key, required this.limitType});

  static Future<void> show(
    BuildContext context, {
    required PaywallLimitType limitType,
    int capValue = 0,
    int userActionsRemaining = 0,
  }) async {
    AnalyticsService.track('free_tier_limit_hit', {
      'limit_type': limitType.name,
    });
    AnalyticsService.track('paywall_viewed', {
      'cap_type': limitType.name,
      'cap_value': capValue,
      'user_actions_remaining': userActionsRemaining,
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
    return UpgradeScreen(entryMessage: limitType.message);
  }
}

enum PaywallLimitType {
  documents(
    'You have reached the policy limit for your current plan. '
    'Compare available plans to add another policy.',
  ),
  queries(
    'You have reached the question limit for your current plan. '
    'Compare available plans or question packs to continue.',
  );

  final String message;
  const PaywallLimitType(this.message);
}
