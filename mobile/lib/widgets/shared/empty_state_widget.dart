import 'package:flutter/material.dart';
import '../../theme/coverwise_theme.dart';
import 'coverwise_components.dart';
import 'coverwise_scene.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final Color color;
  final CoverWiseSceneKind? scene;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add_rounded,
    this.color = CoverWiseColors.blue,
    this.scene,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Empty states are often placed in an Expanded list below a page
        // header. Keep the composition centered when it fits, but allow the
        // content to scroll when a short viewport or larger text scale leaves
        // less room than the illustration and copy require.
        final minHeight =
            constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
        final compactLayout =
            constraints.hasBoundedHeight && constraints.maxHeight < 280;
        final sceneHeight = compactLayout ? 96.0 : 176.0;
        final contentPadding = compactLayout ? 8.0 : 24.0;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(contentPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (scene != null)
                      CoverWiseScene(scene: scene!, maxHeight: sceneHeight)
                    else
                      _EmptyStateVisual(
                        icon: icon,
                        color: color,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.45,
                            ),
                      ),
                    ],
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        icon: Icon(actionIcon),
                        label: Text(actionLabel!),
                        onPressed: onAction,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyStateVisual extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _EmptyStateVisual({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: SizedBox(
        width: 132,
        height: 104,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 9,
              top: 19,
              child: _Orb(size: 22, color: CoverWiseColors.mint),
            ),
            Positioned(
              right: 6,
              bottom: 14,
              child: _Orb(size: 16, color: color),
            ),
            Positioned(
              right: 19,
              top: 7,
              child: _Orb(size: 8, color: CoverWiseColors.mint),
            ),
            Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 94,
                height: 78,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: color.withValues(alpha: 0.12)),
                ),
              ),
            ),
            CoverWiseIconBadge(icon: icon, color: color, size: 72),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.24),
      ),
    );
  }
}
