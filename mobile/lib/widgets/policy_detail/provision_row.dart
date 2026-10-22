import 'package:flutter/material.dart';

class ProvisionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? tooltip;

  const ProvisionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          tooltip != null
              ? Tooltip(
                  message: tooltip!,
                  triggerMode: TooltipTriggerMode.longPress,
                  child: Text(
                    '$label: ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Text(
                  '$label: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
