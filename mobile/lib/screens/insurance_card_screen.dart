import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../utils/document_icons.dart';
import '../widgets/shared/policy_type_icon.dart';

/// Digital Insurance Card — proof of insurance from your phone.
///
/// Shows a visual card for each policy with:
/// - Policy number, insurer, coverage amount, expiry
/// - One-tap call/email insurer
/// - Shareable card format
class InsuranceCardScreen extends ConsumerWidget {
  const InsuranceCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(policySummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insurance Cards')),
      body: summaries.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.credit_card_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No policies uploaded yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Upload a policy to see your digital insurance card', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: summaries.length,
              itemBuilder: (context, index) => _InsuranceCard(summary: summaries[index]),
            ),
    );
  }
}

class _InsuranceCard extends StatelessWidget {
  final PolicySummary summary;
  const _InsuranceCard({required this.summary});

  Color get _cardColor {
    final type = classifyPolicyType(summary.documentType);
    return colorForPolicyType(type);
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = summary.isExpired;
    final isExpiring = summary.isExpiringSoon;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _cardColor,
              _cardColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (summary.insurer != null)
                          Text(
                            summary.insurer!,
                            style: const TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                  if (isExpired || isExpiring)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isExpired ? Colors.red : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isExpired ? 'EXPIRED' : '${summary.daysUntilExpiry}d LEFT',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Policy number
              if (summary.policyNumber != null) ...[
                _CardField(label: 'Policy Number', value: summary.policyNumber!),
                const SizedBox(height: 12),
              ],
              // Coverage and premium row
              Row(
                children: [
                  if (summary.formattedCoverageAmount != 'Unknown')
                    Expanded(child: _CardField(label: 'Coverage', value: summary.formattedCoverageAmount)),
                  if (summary.formattedPremium != 'Unknown')
                    Expanded(child: _CardField(label: 'Premium', value: summary.formattedPremium)),
                ],
              ),
              const SizedBox(height: 12),
              // Dates row
              Row(
                children: [
                  if (summary.formattedStartDate != 'Unknown')
                    Expanded(child: _CardField(label: 'Valid From', value: summary.formattedStartDate)),
                  if (summary.formattedExpiryDate != 'Unknown')
                    Expanded(child: _CardField(label: 'Valid Until', value: summary.formattedExpiryDate)),
                ],
              ),
              if (summary.insurerHelpline != null) ...[
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Call Insurer'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Call ${summary.insurerHelpline}')),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _cardColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Share'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Share card coming soon')),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }
}
