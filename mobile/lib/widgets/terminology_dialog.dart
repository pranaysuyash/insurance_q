import 'package:flutter/material.dart';
import '../data/insurance_terminology.dart';

class TerminologyDialog extends StatelessWidget {
  const TerminologyDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: const Text('Insurance Terminology'),
            centerTitle: true,
            automaticallyImplyLeading: false,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: insuranceTerminology.length,
              itemBuilder: (context, index) {
                final section = insuranceTerminology[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Text(
                        section.letter,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    ...section.terms.map((term) => ListTile(
                          title: Text(
                            term.term,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                            child: Text(term.definition),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 4),
                        )),
                    if (index < insuranceTerminology.length - 1)
                      const Divider(indent: 16, endIndent: 16),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
