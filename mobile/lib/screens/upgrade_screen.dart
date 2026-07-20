import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/entitlement.dart';
import '../providers/entitlement_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/faq_item.dart';
import '../theme/coverwise_theme.dart';

/// Screen showing subscription plan options (Free / Plus / Family).
///
/// Users can compare features, see pricing, and upgrade directly through
/// RevenueCat. The billing adapter handles the purchase flow and the
/// entitlement provider updates the UI reactively.
class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  bool _annual = true; // default to annual (better value)
  PlanTier? _purchasing;
  bool _purchaseSuccess = false;

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(entitlementProvider);
    final billingAsync = ref.watch(billingInitProvider);
    final billingReady = billingAsync is AsyncData<void>;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your plan'),
        actions: [
          if (entitlement.planTier != PlanTier.free)
            TextButton(
              onPressed: () => _manageSubscription(context),
              child: const Text('Manage'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current plan banner
            _CurrentPlanBanner(entitlement: entitlement),
            const SizedBox(height: 20),

            // Annual/Monthly toggle
            if (billingReady) ...[
              _BillingToggle(
                annual: _annual,
                onChanged: (v) => setState(() => _annual = v),
              ),
              const SizedBox(height: 20),
            ],

            // Plan cards
            ...PlanTier.values.map((tier) => _PlanCard(
                  tier: tier,
                  annual: _annual,
                  isCurrent: entitlement.planTier == tier,
                  isPurchasing: _purchasing == tier,
                  billingReady: billingReady,
                  onStartPurchase: (t) => setState(() => _purchasing = t),
                  onEndPurchase: () => setState(() => _purchasing = null),
                  onSuccess: () => setState(() => _purchaseSuccess = true),
                )),

            // Success message
            if (_purchaseSuccess) ...[
              const SizedBox(height: 16),
              CoverWiseSurface(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Plan upgraded! New features are now available.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Start using'),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Feature comparison table
            const SizedBox(height: 24),
            Text(
              'Compare plans',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _FeatureComparisonTable(currentTier: entitlement.planTier),

            // FAQ
            const SizedBox(height: 24),
            Text(
              'Questions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const FaqItem(
              question: 'Can I switch plans?',
              answer:
                  'Yes. Upgrade or downgrade anytime. Changes take effect immediately and billing is prorated.',
            ),
            const FaqItem(
              question: 'What about my Q&A packs?',
              answer:
                  'Pack questions remain active and are used after your monthly subscription quota is exhausted.',
            ),
            const FaqItem(
              question: 'How do I cancel?',
              answer:
                  'Cancel anytime from your App Store or Play Store subscription settings. You keep access until the end of your billing period.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _manageSubscription(BuildContext context) async {
    final billingAsync = ref.read(billingInitProvider);
    if (billingAsync is! AsyncData) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Billing is not available yet. Please try again later.')),
        );
      }
      return;
    }
    final billing = ref.read(billingAdapterProvider);
    final opened = await billing.manageSubscription();
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open subscription settings')),
      );
    }
  }
}

// ── Current Plan Banner ───────────────────────────────────────────────

class _CurrentPlanBanner extends StatelessWidget {
  final Entitlement entitlement;
  const _CurrentPlanBanner({required this.entitlement});

  @override
  Widget build(BuildContext context) {
    final isFree = entitlement.planTier == PlanTier.free;
    final theme = Theme.of(context);

    return CoverWiseSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isFree ? Icons.workspace_premium_rounded : Icons.star_rounded,
              size: 28,
              color: isFree ? const Color(0xFF637083) : CoverWiseColors.blueDeep,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current plan: ${entitlement.planTier.displayName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    entitlement.planTier.tagline,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (!isFree && entitlement.expiresAt != null)
                    Text(
                      'Renews ${entitlement.expiresAt!.day}/${entitlement.expiresAt!.month}/${entitlement.expiresAt!.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Annual/Monthly Toggle ─────────────────────────────────────────────

class _BillingToggle extends StatelessWidget {
  final bool annual;
  final ValueChanged<bool> onChanged;
  const _BillingToggle({required this.annual, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CoverWiseSurface(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !annual
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'Monthly',
                      style: TextStyle(
                        fontWeight: !annual ? FontWeight.w700 : FontWeight.w500,
                        color: !annual
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: annual
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Annual',
                        style: TextStyle(
                          fontWeight: annual ? FontWeight.w700 : FontWeight.w500,
                          color: annual
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      CoverWiseStatusChip(
                        icon: Icons.savings_rounded,
                        label: 'Save up to 44%',
                        color: CoverWiseColors.mint,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Plan Card ─────────────────────────────────────────────────────────

class _PlanCard extends ConsumerWidget {
  final PlanTier tier;
  final bool annual;
  final bool isCurrent;
  final bool isPurchasing;
  final bool billingReady;
  final ValueChanged<PlanTier> onStartPurchase;
  final VoidCallback onEndPurchase;
  final VoidCallback onSuccess;

  const _PlanCard({
    required this.tier,
    required this.annual,
    required this.isCurrent,
    required this.isPurchasing,
    required this.billingReady,
    required this.onStartPurchase,
    required this.onEndPurchase,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limits = planLimits[tier]!;
    final price = annual ? limits.priceYearly : limits.priceMonthly;
    final theme = Theme.of(context);
    final isFamily = tier == PlanTier.family;
    final isPlus = tier == PlanTier.plus;

    final cardColor = isFamily
        ? CoverWiseColors.blueDeep
        : isPlus
            ? CoverWiseColors.blue
            : const Color(0xFF637083);

    return CoverWiseSurface(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    tier == PlanTier.free
                        ? Icons.person_outline_rounded
                        : tier == PlanTier.plus
                            ? Icons.workspace_premium_rounded
                            : Icons.family_restroom_rounded,
                    color: cardColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tier.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (isFamily) ...[
                            const SizedBox(width: 8),
                            CoverWiseStatusChip(
                              icon: Icons.star_rounded,
                              label: 'Best value',
                              color: CoverWiseColors.blueDeep,
                              compact: true,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        tier.tagline,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: cardColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Key features for this tier
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _FeatureChip(label: '${limits.maxPolicies} policies'),
                _FeatureChip(label: '${limits.maxQuestionsPerMonth} Q&A/mo'),
                if (limits.allowComparison) const _FeatureChip(label: 'Compare'),
                if (limits.allowFamilyView) const _FeatureChip(label: 'Family view'),
                if (limits.allowCloudSync) const _FeatureChip(label: 'Cloud sync'),
                if (limits.allowEmergencyAccess)
                  const _FeatureChip(label: 'Emergency'),
                if (limits.allowAnnualReview)
                  const _FeatureChip(label: 'Annual review'),
                if (limits.allowAdvancedSearch)
                  const _FeatureChip(label: 'Advanced search'),
              ],
            ),
            const SizedBox(height: 12),
            // Purchase button
            if (isCurrent)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: null,
                  child: const Text('Current plan'),
                ),
              )
            else if (tier == PlanTier.free)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  child: const Text('Free forever'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isPurchasing || !billingReady
                      ? null
                      : () => _purchase(context, ref),
                  child: isPurchasing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Upgrade to ${tier.displayName}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchase(BuildContext context, WidgetRef ref) async {
    onStartPurchase(tier);
    AnalyticsService.track('plan_purchase_started', {
      'plan_tier': tier.name,
      'billing_cycle': annual ? 'annual' : 'monthly',
    });

    try {
      final billing = ref.read(billingAdapterProvider);
      final result = await billing.purchasePlan(tier, annual: annual);

      if (!context.mounted) return;

      if (result != null) {
        AnalyticsService.track('plan_purchase_completed', {
          'plan_tier': tier.name,
        });
        ref.read(entitlementProvider.notifier).refresh();
        onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upgraded to ${tier.displayName}! Enjoy your new features.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        AnalyticsService.track('plan_purchase_failed', {
          'plan_tier': tier.name,
          'reason': 'user_cancelled',
        });
      }
    } catch (e) {
      if (!context.mounted) return;
      AnalyticsService.track('plan_purchase_failed', {
        'plan_tier': tier.name,
        'reason': 'error',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      onEndPurchase();
    }
  }
}

// ── Feature Chips ─────────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  final String label;
  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── Feature Comparison Table ──────────────────────────────────────────

class _FeatureComparisonTable extends StatelessWidget {
  final PlanTier currentTier;
  const _FeatureComparisonTable({required this.currentTier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final features = [
      ('Policies', (PlanTier t) => '${planLimits[t]!.maxPolicies}'),
      ('Q&A per month', (PlanTier t) => '${planLimits[t]!.maxQuestionsPerMonth}'),
      ('Compare policies', (PlanTier t) => planLimits[t]!.allowComparison ? '✓' : '—'),
      ('Family view', (PlanTier t) => planLimits[t]!.allowFamilyView ? '✓' : '—'),
      ('Cloud sync', (PlanTier t) => planLimits[t]!.allowCloudSync ? '✓' : '—'),
      ('Emergency access', (PlanTier t) => planLimits[t]!.allowEmergencyAccess ? '✓' : '—'),
      ('Annual review', (PlanTier t) => planLimits[t]!.allowAnnualReview ? '✓' : '—'),
      ('Advanced search', (PlanTier t) => planLimits[t]!.allowAdvancedSearch ? '✓' : '—'),
    ];

    return CoverWiseSurface(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text('Feature', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  for (final tier in PlanTier.values)
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          tier.displayName,
                          style: TextStyle(
                            fontWeight: tier == currentTier ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 12,
                            color: tier == currentTier ? theme.colorScheme.primary : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Rows
            for (final (label, getter) in features) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(label, style: const TextStyle(fontSize: 12)),
                    ),
                    for (final tier in PlanTier.values)
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            getter(tier),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: tier == currentTier ? FontWeight.w700 : FontWeight.w500,
                              color: getter(tier) == '✓'
                                  ? CoverWiseColors.mint
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (label != 'Advanced search') const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

// ── FAQ Item ──────────────────────────────────────────────────────────

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    widget.answer,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
