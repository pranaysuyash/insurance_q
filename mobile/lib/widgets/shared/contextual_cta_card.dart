import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../services/lead_generation_service.dart';

/// A contextual call-to-action card that appears after relevant content
/// (e.g., Q&A answers, policy details) to drive lead generation.
///
/// Automatically tracks impression and click analytics.
class CtaCard extends StatefulWidget {
  final CtaDefinition cta;
  final bool dismissible;

  const CtaCard({
    super.key,
    required this.cta,
    this.dismissible = true,
  });

  @override
  State<CtaCard> createState() => _CtaCardState();
}

class _CtaCardState extends State<CtaCard> with SingleTickerProviderStateMixin {
  bool _isVisible = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    // Use the canonical default values from CoverWiseMotion directly
    // (the context-dependent variant reads MediaQuery which is not
    // available during initState in test environments). The values
    // match CoverWiseMotion.standard and CoverWiseMotion.enterCurve.
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();

    // Track impression on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.track('cta_impression', {
        'cta_id': widget.cta.id,
        'cta_title': widget.cta.title,
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleAction() {
    AnalyticsService.track('cta_clicked', {
      'cta_id': widget.cta.id,
      'cta_title': widget.cta.title,
    });
    widget.cta.onAction();
  }

  void _handleDismiss() {
    AnalyticsService.track('cta_dismissed', {
      'cta_id': widget.cta.id,
    });
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() => _isVisible = false);
        widget.cta.onDismiss?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cta = widget.cta;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SizeTransition(
        sizeFactor: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 1,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: cta.iconColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cta.iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(cta.icon, color: cta.iconColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cta.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cta.body,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.dismissible)
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Dismiss',
                            onPressed: _handleDismiss,
                            style: IconButton.styleFrom(
                              foregroundColor:
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      icon: Icon(cta.actionIcon, size: 18),
                      label: Text(cta.actionLabel),
                      onPressed: _handleAction,
                      style: FilledButton.styleFrom(
                        foregroundColor: cta.iconColor,
                        backgroundColor: cta.iconColor.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
