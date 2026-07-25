import 'package:flutter/material.dart';
import '../../services/agent_connection_service.dart';
import 'coverwise_snackbar.dart';

/// A bottom sheet that lets users request a connection with an insurance advisor.
///
/// Collects: name, phone, what they need help with. Optionally attaches
/// policy context (insurer, document type) if provided.
///
/// The request is stored locally in the [AgentConnectionService] for now.
/// A future version will sync requests to a backend for lead routing.
class AgentRequestSheet extends StatefulWidget {
  /// Optional policy context to attach to the request.
  final String? insurer;
  final String? documentType;
  final String? documentId;

  const AgentRequestSheet({
    super.key,
    this.insurer,
    this.documentType,
    this.documentId,
  });

  /// Show the agent request sheet as a modal bottom sheet.
  static Future<bool?> show(
    BuildContext context, {
    String? insurer,
    String? documentType,
    String? documentId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AgentRequestSheet(
        insurer: insurer,
        documentType: documentType,
        documentId: documentId,
      ),
    );
  }

  @override
  State<AgentRequestSheet> createState() => _AgentRequestSheetState();
}

class _AgentRequestSheetState extends State<AgentRequestSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _service = AgentConnectionService();
  bool _isLoading = false;
  String? _nameError;
  String? _phoneError;

  /// Scheduling state.
  DateTime? _selectedDate;
  String? _selectedTimeSlot;

  static const _timeSlots = [
    ('Morning', '9 AM – 12 PM'),
    ('Afternoon', '12 PM – 5 PM'),
    ('Evening', '5 PM – 8 PM'),
  ];

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isFormValid =>
      _nameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _nameError == null &&
      _phoneError == null;

  void _validateName(String value) {
    setState(() {
      _nameError = value.trim().isEmpty ? 'Please enter your name.' : null;
    });
  }

  void _validatePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    setState(() {
      _phoneError = digits.length >= 10
          ? null
          : 'Please enter a valid 10-digit phone number.';
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty || phone.isEmpty) return;

    setState(() => _isLoading = true);

    final success = await _service.submitRequest(
      name: name,
      phone: phone,
      description: description.isNotEmpty ? description : 'Interested in speaking with an advisor',
      insurer: widget.insurer,
      documentType: widget.documentType,
      documentId: widget.documentId,
      preferredDate: _selectedDate,
      preferredTime: _selectedTimeSlot,
    );

    if (!mounted) return;

    if (success) {
      CoverWiseSnackBar.success(
        context,
        'Request submitted! An advisor will reach out to you.',
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      setState(() => _isLoading = false);
      CoverWiseSnackBar.error(
        context,
        'Could not submit your request. Please try again.',
        operation: 'submit request',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Title + icon
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF087F75).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.support_agent_rounded,
                    color: Color(0xFF087F75)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Talk to an advisor',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Or get answers right now from CoverWise',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'CoverWise helps you understand your policies. For personalized advice from an independent advisor, share your details below and they will reach out.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          // Instant chat CTA — get answers right now from CoverWise
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Ask CoverWise now'),
              onPressed: () {
                Navigator.pop(context);
                // Navigate to Q&A — the caller can set initialDocumentId
                // if they passed documentId to the sheet.
                Navigator.of(context).pushNamed(
                  '/qa',
                  arguments: widget.documentId,
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Divider with label
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or request a callback',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name field
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Your full name',
              labelText: 'Name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: const OutlineInputBorder(),
              errorText: _nameError,
            ),
            textInputAction: TextInputAction.next,
            onChanged: _validateName,
          ),
          const SizedBox(height: 12),
          // Phone field
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              hintText: '98765 43210',
              labelText: 'Phone number',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: const OutlineInputBorder(),
              errorText: _phoneError,
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            onChanged: _validatePhone,
          ),
          const SizedBox(height: 12),
          // What they need help with
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: 'What do you need help with? (optional)',
              labelText: 'What brings you here?',
              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          // Scheduling section
          Text(
            'Preferred callback time (optional)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // Date picker
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Choose a date',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _selectedDate != null
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_selectedDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _selectedDate = null),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Time slot chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _timeSlots.map((slot) {
              final isSelected = _selectedTimeSlot == slot.$1;
              return ChoiceChip(
                label: Text(
                  '${slot.$1} (${slot.$2})',
                  style: TextStyle(fontSize: 13),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedTimeSlot = selected ? slot.$1 : null);
                },
              );
            }).toList(),
          ),
          // Policy context (read-only)
          if (widget.insurer != null || widget.documentType != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (widget.insurer != null) widget.insurer,
                        if (widget.documentType != null) widget.documentType,
                      ].join(' — '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Submit button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(_isLoading ? 'Submitting…' : 'Submit request'),
              onPressed: _isLoading || !_isFormValid ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF087F75),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This request shares your name and phone number with partner advisors. '
            'Review the Privacy Policy for how policy data is processed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
