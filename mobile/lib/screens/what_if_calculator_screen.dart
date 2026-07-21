import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../utils/what_if_calculator.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/empty_state_widget.dart';
import 'documents_screen.dart';

/// What-If Calculator — lets users explore how changing coverage parameters
/// affects premiums and out-of-pocket costs.
class WhatIfCalculatorScreen extends ConsumerStatefulWidget {
  final PolicySummary? initialSummary;

  const WhatIfCalculatorScreen({super.key, this.initialSummary});

  @override
  ConsumerState<WhatIfCalculatorScreen> createState() =>
      _WhatIfCalculatorScreenState();
}

class _WhatIfCalculatorScreenState
    extends ConsumerState<WhatIfCalculatorScreen> {
  PolicySummary? _baseSummary;
  double _coverageMultiplier = 1.0;
  double _deductibleMultiplier = 1.0;
  bool _includeMaternity = true;
  bool _includeDaycare = true;
  bool _includePrePostHospital = true;

  @override
  void initState() {
    super.initState();
    _baseSummary =
        widget.initialSummary ?? ref.read(policySummariesProvider).firstOrNull;
  }

  WhatIfCalculator _buildCalculator() => WhatIfCalculator(
        coverageMultiplier: _coverageMultiplier,
        deductibleMultiplier: _deductibleMultiplier,
        includeMaternity: _includeMaternity,
        includeDaycare: _includeDaycare,
        includePrePostHospital: _includePrePostHospital,
      );

  String _formatCurrency(double amount) =>
      WhatIfCalculator.formatCurrency(amount);

  @override
  Widget build(BuildContext context) {
    if (_baseSummary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('What-If Calculator')),
        body: EmptyStateWidget(
          icon: Icons.calculate_outlined,
          title: 'No policy data available',
          subtitle: 'Choose a policy file to explore planning estimates.',
          actionLabel: 'Choose policy file',
          actionIcon: Icons.upload_file_rounded,
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const DocumentsScreen(startWithFilePicker: true),
            ),
          ),
          color: const Color(0xFF6A4BA8),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('What-If Calculator'),
        actions: [
          TextButton(
            onPressed: _resetDefaults,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CoverWisePageHeader(
              title: 'Explore a scenario',
              subtitle:
                  'Adjust policy inputs to see rough planning estimates. Your saved policy is not changed.',
            ),
            // Base policy info card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildBasePolicyCard(),
            ),
            const SizedBox(height: 20),

            // Coverage slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSlider(
                label: 'Coverage amount',
                value: _coverageMultiplier,
                min: 0.5,
                max: 3.0,
                divisions: 5,
                format: (v) => '${(v * 100).round()}% of base',
                onChanged: (v) => setState(() => _coverageMultiplier = v),
              ),
            ),
            const SizedBox(height: 16),

            // Deductible slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSlider(
                label: 'Deductible',
                value: _deductibleMultiplier,
                min: 0.5,
                max: 2.0,
                divisions: 6,
                format: (v) => '${(v * 100).round()}% of base',
                onChanged: (v) => setState(() => _deductibleMultiplier = v),
              ),
            ),
            const SizedBox(height: 16),

            // Coverage toggles
            const CoverWiseSectionLabel('Optional benefits'),
            const SizedBox(height: 8),
            CoverWiseSurface(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.pregnant_woman_outlined),
                    title: const Text('Maternity coverage'),
                    value: _includeMaternity,
                    onChanged: (v) => setState(() => _includeMaternity = v),
                  ),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.medical_services_outlined),
                    title: const Text('Daycare procedures'),
                    value: _includeDaycare,
                    onChanged: (v) => setState(() => _includeDaycare = v),
                  ),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.local_hospital_outlined),
                    title: const Text('Pre/post hospitalization'),
                    value: _includePrePostHospital,
                    onChanged: (v) =>
                        setState(() => _includePrePostHospital = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Results card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildResultsCard(),
            ),
            const SizedBox(height: 20),

            // Disclaimer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color:
                              Theme.of(context).colorScheme.onTertiaryContainer,
                          size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'These are rough estimates for planning purposes only. Actual premiums vary by insurer and underwriting.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer,
                          ),
                        ),
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

  Widget _buildBasePolicyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CoverWiseIconBadge(
                  icon: Icons.policy_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Base policy: ${_baseSummary?.insurer ?? "Unknown"}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 28,
              runSpacing: 10,
              children: [
                _infoChip('Coverage',
                    _formatCurrency(_baseSummary?.coverageAmount ?? 0)),
                _infoChip('Premium',
                    _formatCurrency(_baseSummary?.premiumAmount ?? 0)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(format(value),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final calc = _buildCalculator();
    final estimatedPremium =
        calc.estimatePremium(_baseSummary?.premiumAmount ?? 0);
    final estimatedCoverage =
        calc.estimateCoverage(_baseSummary?.coverageAmount ?? 0);
    final estimatedDeductible =
        calc.estimateDeductible(_baseSummary?.deductible ?? 10000);
    final premiumDiff = estimatedPremium - (_baseSummary?.premiumAmount ?? 0);
    final coverageDiff =
        estimatedCoverage - (_baseSummary?.coverageAmount ?? 0);

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estimated Results',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _resultRow('Coverage', _formatCurrency(estimatedCoverage),
                coverageDiff >= 0 ? '+${_formatCurrency(coverageDiff)}' : null),
            const SizedBox(height: 12),
            _resultRow(
                'Premium',
                _formatCurrency(estimatedPremium),
                premiumDiff >= 0
                    ? '+${_formatCurrency(premiumDiff)}/yr'
                    : '-${_formatCurrency(-premiumDiff)}/yr'),
            const SizedBox(height: 12),
            _resultRow(
                'Deductible', _formatCurrency(estimatedDeductible), null),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, String? change) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                textAlign: TextAlign.end,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (change != null)
                Text(
                  change,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    color: change.startsWith('+')
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.tertiary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _resetDefaults() {
    setState(() {
      _coverageMultiplier = 1.0;
      _deductibleMultiplier = 1.0;
      _includeMaternity = true;
      _includeDaycare = true;
      _includePrePostHospital = true;
    });
  }
}
