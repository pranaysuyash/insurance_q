import 'package:flutter/material.dart';

import '../../theme/coverwise_theme.dart';
import 'coverwise_components.dart';

enum CoverWiseSceneKind { firstPolicy }

extension CoverWiseSceneSpec on CoverWiseSceneKind {
  String get assetPath => switch (this) {
        CoverWiseSceneKind.firstPolicy => 'assets/scenes/first-policy.png',
      };

  IconData get fallbackIcon => switch (this) {
        CoverWiseSceneKind.firstPolicy => Icons.folder_open_rounded,
      };

  Color get fallbackColor => switch (this) {
        CoverWiseSceneKind.firstPolicy => CoverWiseColors.blue,
      };
}

/// Typed access to explanatory art.
///
/// Product meaning must remain in adjacent text. Scenes are decorative by
/// default and collapse at large text sizes so they never displace the action.
class CoverWiseScene extends StatelessWidget {
  final CoverWiseSceneKind scene;
  final double maxHeight;
  final bool decorative;
  final String? semanticLabel;

  const CoverWiseScene({
    super.key,
    required this.scene,
    this.maxHeight = 190,
    this.decorative = true,
    this.semanticLabel,
  }) : assert(decorative || semanticLabel != null);

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final responsiveHeight = textScale > 2
        ? maxHeight * 0.54
        : textScale > 1.5
            ? maxHeight * 0.72
            : maxHeight;
    final cacheWidth =
        (responsiveHeight * MediaQuery.devicePixelRatioOf(context)).round();

    return Semantics(
      image: !decorative,
      label: decorative ? null : semanticLabel,
      excludeSemantics: decorative,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: responsiveHeight),
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              scene.assetPath,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: scene.fallbackColor.withValues(alpha: 0.08),
                child: Center(
                  child: CoverWiseIconBadge(
                    icon: scene.fallbackIcon,
                    color: scene.fallbackColor,
                    size: 72,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
