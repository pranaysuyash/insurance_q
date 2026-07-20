import 'package:flutter/material.dart';
import '../../models/document_model.dart';
import '../shared/coverwise_components.dart';
import '../../services/analytics_service.dart';
import '../../screens/documents_screen.dart';
import '../../screens/qa_screen.dart';
import '../../screens/emergency_screen.dart';
import '../../widgets/policy_comparison_sheet.dart';
import '../../widgets/terminology_dialog.dart';
import '../../theme/coverwise_theme.dart';

class QuickActions extends StatelessWidget {
  final List<InsuranceDocument> documents;
  
  const QuickActions({super.key, required this.documents});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CoverWiseSectionLabel('Quick Actions'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _ActionButton(
              icon: Icons.upload_file,
              label: 'Upload Document',
              color: Theme.of(context).colorScheme.primary,
              onTap: () {
                AnalyticsService.track('dashboard_quick_action_tapped', {'action_type': 'upload'});
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DocumentsScreen(
                      startWithFilePicker: true,
                    ),
                  ));
              },
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _ActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Ask a Question',
              color: Theme.of(context).colorScheme.secondary,
              onTap: () {
                AnalyticsService.track('dashboard_quick_action_tapped', {'action_type': 'ask'});
                Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const QaScreen()));
              },
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _ActionButton(
              icon: Icons.compare_arrows,
              label: 'Compare Policies',
              color: Theme.of(context).colorScheme.tertiary,
              onTap: () {
                AnalyticsService.track('dashboard_quick_action_tapped', {'action_type': 'compare'});
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => PolicyComparisonSheet(documents: documents),
                );
              },
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _ActionButton(
              icon: Icons.help_outline,
              label: 'Insurance Terms',
              color: CoverWiseColors.mint,
              onTap: () {
                AnalyticsService.track('dashboard_quick_action_tapped', {'action_type': 'terms'});
                showDialog(
                  context: context, builder: (_) => const TerminologyDialog());
              },
            )),
          ],
        ),
        const SizedBox(height: 12),
        // Emergency shortcut — one tap from dashboard instead of More → Emergency
        if (documents.isNotEmpty)
          _EmergencyShortcutButton(
            onTap: () {
              AnalyticsService.track('dashboard_emergency_shortcut_tapped');
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EmergencyScreen()));
            },
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoverWiseIconBadge(icon: icon, color: color, size: 42),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent emergency shortcut button — one tap from dashboard.
class _EmergencyShortcutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EmergencyShortcutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Open emergency card',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emergency_outlined,
                  color: scheme.onErrorContainer, size: 22),
              const SizedBox(width: 10),
              Text(
                'Emergency Card',
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search shortcut button — one tap from dashboard to cross-document search.
class SearchShortcutButton extends StatelessWidget {
  final VoidCallback onTap;
  const SearchShortcutButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Search across all policies',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_rounded,
                  color: scheme.onPrimaryContainer, size: 22),
              const SizedBox(width: 10),
              Text(
                'Search Across All Policies',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
