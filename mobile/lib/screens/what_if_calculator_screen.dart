import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../utils/what_if_calculator.dart';

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

  String _formatCurrency(double amount) => WhatIfCalculator.formatCurrency(amount);

  @override
  Widget build(BuildContext context) {
    if (_baseSummary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('What-If Calculator')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calculate, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No policy data available',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
              SizedBox(height: 8),
              Text('Upload a policy first to use the calculator',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Base policy info card
            _buildBasePolicyCard(),
            const SizedBox(height: 20),

            // Coverage slider
            _buildSlider(
              label: 'Coverage Amount',
              value: _coverageMultiplier,
              min: 0.5,
              max: 3.0,
              divisions: 5,
              format: (v) => '${(v * 100).round()}% of base',
              onChanged: (v) => setState(() => _coverageMultiplier = v),
            ),
            const SizedBox(height: 16),

            // Deductible slider
            _buildSlider(
              label: 'Deductible',
              value: _deductibleMultiplier,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              format: (v) => '${(v * 100).round()}% of base',
              onChanged: (v) => setState(() => _deductibleMultiplier = v),
            ),
            const SizedBox(height: 16),

            // Coverage toggles
            const Text('Additional Coverage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Maternity Coverage'),
              value: _includeMaternity,
              onChanged: (v) => setState(() => _includeMaternity = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Daycare Procedures'),
              value: _includeDaycare,
              onChanged: (v) => setState(() => _includeDaycare = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Pre/Post Hospitalization'),
              value: _includePrePostHospital,
              onChanged: (v) => setState(() => _includePrePostHospital = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),

            // Results card
            _buildResultsCard(),
            const SizedBox(height: 20),

            // Disclaimer
            Card(
              color: Colors.orange.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These are rough estimates for planning purposes only. Actual premiums vary by insurer and underwriting.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
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
            Text('Base Policy: ${_baseSummary?.insurer ?? "Unknown"}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoChip('Coverage', _formatCurrency(_baseSummary?.coverageAmount ?? 0)),
                _infoChip('Premium', _formatCurrency(_baseSummary?.premiumAmount ?? 0)),
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
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(format(value),
                    style: const TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.w500)),
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
    final estimatedPremium = calc.estimatePremium(_baseSummary?.premiumAmount ?? 0);
    final estimatedCoverage = calc.estimateCoverage(_baseSummary?.coverageAmount ?? 0);
    final estimatedDeductible = calc.estimateDeductible(_baseSummary?.deductible ?? 10000);
    final premiumDiff = estimatedPremium - (_baseSummary?.premiumAmount ?? 0);
    final coverageDiff = estimatedCoverage - (_baseSummary?.coverageAmount ?? 0);

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
                'Premium', _formatCurrency(estimatedPremium),
                premiumDiff >= 0
                    ? '+${_formatCurrency(premiumDiff)}/yr'
                    : '-${_formatCurrency(-premiumDiff)}/yr'),
            const SizedBox(height: 12),
            _resultRow('Deductible', _formatCurrency(estimatedDeductible), null),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, String? change) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            if (change != null)
              Text(change,
                  style: TextStyle(
                      fontSize: 12,
                      color: change.startsWith('+')
                          ? Colors.red.shade700
                          : Colors.green.shade700)),
          ],
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
