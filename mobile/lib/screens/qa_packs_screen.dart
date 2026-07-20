import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/qa_pack.dart';
import '../providers/entitlement_provider.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/faq_item.dart';
import '../theme/coverwise_theme.dart';
import '../services/analytics_service.dart';
import '../utils/app_error.dart';

/// Screen where users can browse and purchase pay-per-Q&A packs.
///
/// This is the alternative to subscription for occasional users who don't
/// need unlimited questions but want more than the 20 free monthly questions.
/// Packs are consumable — questions are deducted one at a time, FIFO by expiry.
class QaPacksScreen extends ConsumerStatefulWidget {
  const QaPacksScreen({super.key});

  @override
  ConsumerState<QaPacksScreen> createState() => _QaPacksScreenState();
}

class _QaPacksScreenState extends ConsumerState<QaPacksScreen> {
  QaPackType? _purchasing;
  bool _purchaseSuccess = false;

  @override
  Widget build(BuildContext context) {
    final packState = ref.watch(qaPackStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Q&A Packs'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current balance
            _CurrentBalanceCard(packState: packState),
            const SizedBox(height: 20),

            // Available packs
            Text(
              'Buy a pack',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'No subscription needed. Pay once, ask questions.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            ...QaPackType.values.map(
              (pack) => _PackCard(
                pack: pack,
                isPurchasing: _purchasing == pack,
                onSuccess: () => setState(() => _purchaseSuccess = true),
                onStartPurchase: (type) => setState(() => _purchasing = type),
                onEndPurchase: () => setState(() => _purchasing = null),
              ),
            ),
            const SizedBox(height: 20),

            // Active packs
            if (packState.activePacks.isNotEmpty) ...[
              Text(
                'Your packs',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              ...packState.activePacks.map(
                (pack) => _ActivePackTile(pack: pack),
              ),
              const SizedBox(height: 12),
            ],

            // Success message
            if (_purchaseSuccess)
              CoverWiseSurface(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Pack purchased! You can now ask more questions.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Start asking'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // FAQ
            Text(
              'How packs work',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const FaqItem(
              question: 'When are questions deducted?',
              answer: 'A question is deducted each time you submit one. '
                  'Monthly subscription questions are used first, then pack questions.',
            ),
            const FaqItem(
              question: 'Do packs expire?',
              answer: 'Yes, packs are valid for 90 days from purchase. '
                  'Unused questions are lost after expiry.',
            ),
            const FaqItem(
              question: 'Can I have multiple packs?',
              answer: 'Yes! Multiple packs stack. Questions are consumed from '
                  'the earliest-expiring pack first (FIFO).',
            ),
            const FaqItem(
              question: 'What happens if I upgrade to a subscription?',
              answer: 'Your pack questions remain active and are used after '
                  'your monthly subscription quota is exhausted.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows current question balance (subscription + packs).
class _CurrentBalanceCard extends StatelessWidget {
  final QaPackState packState;
  const _CurrentBalanceCard({required this.packState});

  @override
  Widget build(BuildContext context) {
    return CoverWiseSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 24),
                const SizedBox(width: 12),
                Text(
                  '${packState.totalQuestionsRemaining} questions available',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (packState.hasSubscriptionQuestions && packState.hasPackQuestions)
              Text(
                '${packState.subscriptionQuestionsRemaining} from monthly plan · '
                '${packState.packQuestionsRemaining} from packs',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else if (packState.hasPackQuestions)
              Text(
                '${packState.packQuestionsRemaining} from ${packState.activePacks.length} pack(s)',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Text(
                '${packState.subscriptionQuestionsRemaining} from monthly plan',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single purchasable pack card.
class _PackCard extends ConsumerWidget {
  final QaPackType pack;
  final bool isPurchasing;
  final VoidCallback onSuccess;
  final ValueChanged<QaPackType> onStartPurchase;
  final VoidCallback onEndPurchase;

  const _PackCard({
    required this.pack,
    required this.isPurchasing,
    required this.onSuccess,
    required this.onStartPurchase,
    required this.onEndPurchase,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricePerQuestion =
        (double.parse(pack.price.replaceAll(RegExp(r'[^0-9.]'), '')) /
                pack.questionCount)
            .toStringAsFixed(1);

    return CoverWiseSurface(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Pack icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: pack == QaPackType.pro
                    ? CoverWiseColors.blueDeep.withValues(alpha: 0.1)
                    : pack == QaPackType.value
                        ? CoverWiseColors.blue.withValues(alpha: 0.1)
                        : CoverWiseColors.mint.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${pack.questionCount}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: pack == QaPackType.pro
                        ? CoverWiseColors.blueDeep
                        : pack == QaPackType.value
                            ? CoverWiseColors.blue
                            : CoverWiseColors.mint,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Pack details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pack.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (pack == QaPackType.pro) ...[
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
                  const SizedBox(height: 2),
                  Text(
                    '${pack.questionCount} questions · ₹$pricePerQuestion each',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    pack.tagline,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Price + buy button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pack.price,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 32,
                  child: FilledButton(
                    onPressed: isPurchasing
                        ? null
                        : () => _purchasePack(context, ref),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: isPurchasing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Buy'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchasePack(BuildContext context, WidgetRef ref) async {
    onStartPurchase(pack);
    AnalyticsService.track('qa_pack_purchase_started', {
      'pack_type': pack.name,
      'pack_price': pack.price,
      'pack_questions': pack.questionCount,
    });

    try {
      final adapter = ref.read(billingAdapterProvider);
      final result = await adapter.purchaseQaPack(pack);

      if (!context.mounted) return;

      if (result != null) {
        AnalyticsService.track('qa_pack_purchase_completed', {
          'pack_type': pack.name,
        });
        ref.read(entitlementProvider.notifier).refresh();
        onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pack.displayName} pack purchased! ${pack.questionCount} questions added.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        AnalyticsService.track('qa_pack_purchase_failed', {
          'pack_type': pack.name,
          'reason': 'user_cancelled',
        });
      }
    } catch (e) {
      if (!context.mounted) return;
      AnalyticsService.track('qa_pack_purchase_failed', {
        'pack_type': pack.name,
        'reason': 'error',
      });
      final msg = AppError.userMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isEmpty ? 'Purchase was cancelled.' : msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      onEndPurchase();
    }
  }
}

/// Shows an active pack with its remaining questions and expiry.
class _ActivePackTile extends StatelessWidget {
  final QaPack pack;
  const _ActivePackTile({required this.pack});

  @override
  Widget build(BuildContext context) {
    final daysLeft = pack.expiresAt.difference(DateTime.now()).inDays;
    final progress = 1.0 - pack.usagePercent;

    return CoverWiseSurface(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${pack.type.displayName} pack',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${pack.questionsRemaining}/${pack.totalQuestions} left',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                color: daysLeft <= 7 ? Colors.orange : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

