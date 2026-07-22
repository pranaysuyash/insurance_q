import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/document_model.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';

/// Dialog for manually adding a family member/insured person.
///
/// Use case: a dependent (e.g. a child who cannot hold their own policy) who
/// has their own separate policy and isn't named in any of the user's uploaded
/// documents — so they won't be auto-detected.
class AddFamilyMemberDialog extends StatefulWidget {
  const AddFamilyMemberDialog({super.key});

  @override
  State<AddFamilyMemberDialog> createState() => _AddFamilyMemberDialogState();
}

class _AddFamilyMemberDialogState extends State<AddFamilyMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  String _relationship = 'Dependent';
  DateTime? _dob;

  static const _relationships = [
    'Dependent',
    'Spouse',
    'Child',
    'Parent',
    'Sibling',
    'Primary Insured',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final member = PolicyHolder(
      name: _nameController.text.trim(),
      dob: _dob != null
          ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
          : null,
      relationship: _relationship,
      source: 'manual',
    );
    Navigator.of(context).pop(member);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const CoverWiseIconBadge(
        icon: Icons.person_add_alt_1_rounded,
        color: CoverWiseColors.blueDeep,
        size: 48,
      ),
      title: const Text('Add family member'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add someone who is not listed in an uploaded policy. This creates a local family entry only.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(80),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: Icon(Icons.family_restroom_rounded),
                ),
                items: _relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _relationship = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date of birth (optional)',
                  prefixIcon: Icon(Icons.cake_outlined),
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                ),
                onTap: _pickDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add member'),
        ),
      ],
    );
  }
}
