import 'package:flutter/material.dart';
import '../../models/document_model.dart';
import '../shared/coverwise_components.dart';
import '../shared/policy_type_icon.dart';
import '../../utils/policy_type.dart';
import '../../theme/coverwise_motion.dart';
import '../../services/analytics_service.dart';

class DocumentSummary extends StatelessWidget {
  final List<InsuranceDocument> documents;

  const DocumentSummary({super.key, required this.documents});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CoverWiseSectionLabel('Documents by Type'),
        const SizedBox(height: 12),
        CoverageTypeExplorer(documents: documents),
      ],
    );
  }
}

class CoverageTypeExplorer extends StatefulWidget {
  final List<InsuranceDocument> documents;

  const CoverageTypeExplorer({super.key, required this.documents});

  @override
  State<CoverageTypeExplorer> createState() => _CoverageTypeExplorerState();
}

class _CoverageTypeExplorerState extends State<CoverageTypeExplorer> {
  PolicyType _selectedType = PolicyType.health;

  static const _typeDescriptions = {
    PolicyType.health: 'Hospital care, treatment and medical expenses.',
    PolicyType.auto: 'Car, bike and vehicle protection.',
    PolicyType.life: 'Financial protection for the people you love.',
    PolicyType.home: 'Your home, belongings and property cover.',
    PolicyType.travel: 'Protection for trips away from home.',
    PolicyType.other: 'Other policies kept safely in one place.',
  };

  @override
  Widget build(BuildContext context) {
    final counts = <PolicyType, int>{
      for (final type in PolicyType.values) type: 0,
    };
    for (final document in widget.documents) {
      final type = classifyPolicyType(document.documentType);
      counts[type] = counts[type]! + 1;
    }
    final selectedCount = counts[_selectedType]!;
    final brightness = Theme.of(context).brightness;
    final selectedColor = colorForPolicyType(
      _selectedType,
      brightness: brightness,
    );

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: PolicyType.values.map((type) {
                final isSelected = type == _selectedType;
                final count = counts[type]!;
                return SizedBox(
                  width: itemWidth,
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label:
                        '${canonicalTypeName(type)}, $count ${count == 1 ? 'policy' : 'policies'}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        AnalyticsService.track('dashboard_coverage_type_tapped', {
                          'type_name': type.name,
                          'document_count': count
                        });
                        setState(() => _selectedType = type);
                      },
                      child: AnimatedContainer(
                        duration: CoverWiseMotion.duration(
                          context,
                          CoverWiseMotion.standard,
                        ),
                        curve: CoverWiseMotion.enterCurve,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorForPolicyType(
                                  type,
                                  brightness: brightness,
                                ).withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            PolicyTypeIcon(
                              type: type,
                              selected: isSelected,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              canonicalTypeName(type)
                                  .replaceFirst(' Insurance', ''),
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: colorForPolicyType(
                                  type,
                                  brightness: brightness,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '$count ${count == 1 ? 'policy' : 'policies'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colorForPolicyType(
                                      type,
                                      brightness: brightness,
                                    ).withValues(alpha: 0.82),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: CoverWiseMotion.duration(
            context,
            CoverWiseMotion.quick,
          ),
          switchInCurve: CoverWiseMotion.enterCurve,
          switchOutCurve: CoverWiseMotion.exitCurve,
          child: Container(
            key: ValueKey(_selectedType),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selectedColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                PolicyTypeIcon(type: _selectedType, size: 40, selected: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedCount > 0
                        ? '$selectedCount ${selectedCount == 1 ? 'policy' : 'policies'} in ${canonicalTypeName(_selectedType)}. ${_typeDescriptions[_selectedType]}'
                        : widget.documents.isEmpty
                            ? 'Explore the kinds of cover you can keep here. Add your first policy when you are ready.'
                            : 'No ${canonicalTypeName(_selectedType).toLowerCase()} policy has been added. ${_typeDescriptions[_selectedType]}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
