import 'package:flutter/material.dart';

/// An inline-editable field that shows the value with an edit icon.
/// Tapping the edit icon switches to a text field with save/cancel.
/// When a user override is active, shows a "user corrected" badge
/// with option to revert to the original extracted value.
class EditableField extends StatefulWidget {
  final String label;
  final String value;
  final String? originalValue;
  final bool hasOverride;
  final bool isEditable;
  final ValueChanged<String> onSave;
  final VoidCallback? onRevert;
  final String? hintText;

  const EditableField({
    super.key,
    required this.label,
    required this.value,
    this.originalValue,
    this.hasOverride = false,
    this.isEditable = true,
    required this.onSave,
    this.onRevert,
    this.hintText,
  });

  @override
  State<EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<EditableField> {
  bool _editing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(EditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    _controller.text = widget.value;
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    setState(() => _editing = false);
  }

  void _save() {
    final newValue = _controller.text.trim();
    if (newValue.isNotEmpty && newValue != widget.value) {
      // Fire-and-forget: the parent's setState (after Hive write)
      // will rebuild with the new override value.
      widget.onSave(newValue);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_editing) {
      return _buildEditingMode(theme, colorScheme);
    }

    return _buildDisplayMode(theme, colorScheme);
  }

  Widget _buildDisplayMode(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.value.isEmpty ? '—' : widget.value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.value.isEmpty
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
              ),
              if (widget.hasOverride && widget.originalValue != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded,
                        size: 14, color: colorScheme.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      'You corrected this',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.tertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (widget.isEditable) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit ${widget.label}',
            onPressed: _startEditing,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (widget.hasOverride && widget.onRevert != null) ...[
          IconButton(
            icon: const Icon(Icons.undo_rounded, size: 18),
            tooltip: 'Revert to original',
            onPressed: widget.onRevert,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditingMode(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'Enter ${widget.label.toLowerCase()}',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            FilledButton.tonal(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Save'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _cancelEditing,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }
}
