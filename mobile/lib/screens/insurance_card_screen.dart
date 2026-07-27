import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../l10n/app_localizations_gen.dart';
import '../theme/coverwise_theme.dart';
import '../utils/document_icons.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../widgets/shared/policy_type_icon.dart';
import 'documents_screen.dart';

/// Policy quick-reference card for details extracted from a user's document.
///
/// Shows a visual card for each policy with:
/// - Policy number, insurer, coverage amount, expiry
/// - One-tap call insurer and share a limited text card
/// - Shareable reference format that is not insurer-issued proof of cover
class InsuranceCardScreen extends ConsumerWidget {
  const InsuranceCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizationsGen.of(context);
    final summaries = ref.watch(policySummariesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.insuranceCardsTitle)),
      body: summaries.isEmpty
          ? EmptyStateWidget(
              icon: Icons.credit_card_off_outlined,
              title: l10n.insuranceCardsEmptyTitle,
              subtitle: l10n.insuranceCardsEmptySubtitle,
              actionLabel: l10n.insuranceCardsChooseFile,
              actionIcon: Icons.upload_file_rounded,
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const DocumentsScreen(startWithFilePicker: true),
                ),
              ),
              color: const Color(0xFF16866B),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                CoverWisePageHeader(
                  title: l10n.insuranceCardsHeaderTitle,
                  subtitle: l10n.insuranceCardsHeaderSubtitle,
                  trailing: CoverWiseIconBadge(
                    icon: Icons.wallet_outlined,
                    color: CoverWiseColors.blueDeep,
                    size: 52,
                  ),
                ),
                ...summaries.map(
                  (summary) => _InsuranceCard(summary: summary),
                ),
              ],
            ),
    );
  }
}

class _InsuranceCard extends StatelessWidget {
  final PolicySummary summary;
  const _InsuranceCard({required this.summary});

  Color _cardColor(BuildContext context) {
    final type = classifyPolicyType(summary.documentType);
    return colorForPolicyType(
      type,
      brightness: Theme.of(context).brightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    final isExpired = summary.isExpired;
    final isExpiring = summary.isExpiringSoon;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: _cardColor(context), width: 5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  PolicyTypeIcon(
                    type: classifyPolicyType(summary.documentType),
                    size: 40,
                    selected: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.documentType,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        if (summary.insurer != null)
                          Text(
                            summary.insurer!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                      ],
                    ),
                  ),
                  if (isExpired || isExpiring)
                    CoverWiseStatusChip(
                      icon: isExpired
                          ? Icons.error_outline_rounded
                          : Icons.schedule_rounded,
                      label: isExpired
                          ? 'Expired'
                          : '${summary.daysUntilExpiry}d left',
                      color: isExpired ? Colors.red : Colors.orange,
                      compact: true,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Policy number
              if (summary.policyNumber != null) ...[
                _CardField(
                  label: l10n.insuranceCardsPolicyNumber,
                  value: summary.policyNumber!,
                ),
                const SizedBox(height: 12),
              ],
              // Coverage and premium row
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  if (summary.formattedCoverageAmount != 'Unknown')
                    _CardField(
                      label: l10n.insuranceCardsCoverage,
                      value: summary.formattedCoverageAmount,
                    ),
                  if (summary.formattedPremium != 'Unknown')
                    _CardField(
                      label: l10n.insuranceCardsPremium,
                      value: summary.formattedPremium,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Dates row
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  if (summary.formattedStartDate != 'Unknown')
                    _CardField(
                      label: l10n.insuranceCardsValidFrom,
                      value: summary.formattedStartDate,
                    ),
                  if (summary.formattedExpiryDate != 'Unknown')
                    _CardField(
                      label: l10n.insuranceCardsValidUntil,
                      value: summary.formattedExpiryDate,
                    ),
                ],
              ),
              if (summary.insurerHelpline != null) ...[
                const SizedBox(height: 16),
                // Action buttons
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stack = constraints.maxWidth < 330;
                    final call = SizedBox(
                      width: stack ? double.infinity : null,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.phone_outlined, size: 18),
                        label: Text(l10n.insuranceCardsCallInsurer),
                        onPressed: () => _callInsurer(context),
                      ),
                    );
                    final share = SizedBox(
                      width: stack ? double.infinity : null,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(l10n.insuranceCardsShareCard),
                        onPressed: () => _shareCard(context),
                      ),
                    );
                    if (stack) {
                      return Column(
                        children: [call, const SizedBox(height: 8), share],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: call),
                        const SizedBox(width: 10),
                        Expanded(child: share),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callInsurer(BuildContext context) async {
    final l10n = AppLocalizationsGen.of(context);
    final rawNumber = summary.insurerHelpline;
    if (rawNumber == null || rawNumber.trim().isEmpty) return;
    final phone = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    bool launched = false;
    try {
      launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      CoverWiseSnackBar.error(context, l10n.insuranceCardsPhoneError);
    }
  }

  Future<void> _shareCard(BuildContext context) async {
    final l10n = AppLocalizationsGen.of(context);
    final lines = <String>[
      l10n.insuranceCardsShareTitle,
      summary.documentType,
      if (summary.insurer != null)
        '${l10n.insuranceCardsInsurerPrefix}${summary.insurer}',
      if (summary.policyNumber != null)
        '${l10n.insuranceCardsPolicyNumberPrefix}${summary.policyNumber}',
      if (summary.formattedCoverageAmount != 'Unknown')
        '${l10n.insuranceCardsCoveragePrefix}${summary.formattedCoverageAmount}',
      if (summary.formattedExpiryDate != 'Unknown')
        '${l10n.insuranceCardsValidUntilPrefix}${summary.formattedExpiryDate}',
      if (summary.insurerHelpline != null)
        '${l10n.insuranceCardsHelplinePrefix}${summary.insurerHelpline}',
      '',
      l10n.insuranceCardsShareFooter,
    ];
    try {
      await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
    } catch (_) {
      if (context.mounted) {
        CoverWiseSnackBar.error(context, l10n.insuranceCardsShareError);
      }
    }
  }
}

class _CardField extends StatelessWidget {
  final String label;
  final String value;
  const _CardField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: .6,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
