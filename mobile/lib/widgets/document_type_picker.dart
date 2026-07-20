import 'package:flutter/material.dart';
import '../utils/policy_type.dart';

/// Dialog that lets the user manually select a [PolicyType] for a document.
///
/// Used when automatic classification returns "Unknown" or "Other", or when
/// the user wants to correct an incorrect type.
///
/// Returns the selected [PolicyType] when confirmed, or null if dismissed.
Future<PolicyType?> showDocumentTypePicker(
  BuildContext context, {
  PolicyType? currentType,
}) {
  return showDialog<PolicyType>(
    context: context,
    builder: (context) => _DocumentTypePickerDialog(currentType: currentType),
  );
}

class _DocumentTypePickerDialog extends StatefulWidget {
  final PolicyType? currentType;
  const _DocumentTypePickerDialog({this.currentType});

  @override
  State<_DocumentTypePickerDialog> createState() =>
      _DocumentTypePickerDialogState();
}

class _DocumentTypePickerDialogState extends State<_DocumentTypePickerDialog> {
  late PolicyType _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentType ?? PolicyType.other;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('What type of policy is this?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: PolicyType.values.map((type) {
          final isSelected = type == _selected;
          final color = colorForPolicyType(type);
          return RadioListTile<PolicyType>(
            value: type,
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v!),
            title: Row(
              children: [
                Icon(iconForPolicyType(type), size: 20, color: color),
                const SizedBox(width: 10),
                Text(canonicalTypeName(type)),
              ],
            ),
            activeColor: color,
            contentPadding: EdgeInsets.zero,
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
