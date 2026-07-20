import 'package:flutter/material.dart';
import '../../data/insurance_terminology.dart';
import '../../widgets/terminology_dialog.dart';
import '../shared/coverwise_components.dart';

class InsuranceTerminologySection extends StatelessWidget {
  const InsuranceTerminologySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const CoverWiseSectionLabel('Insurance Terminology'),
            TextButton(
              onPressed: () => showDialog(
                  context: context, builder: (_) => const TerminologyDialog()),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: quickTerminology.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.term}: ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(item.definition)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
