import 'package:flutter/material.dart';

/// Canonical motion tokens for CoverWise.
///
/// Motion is presentation-only: state and meaning must remain available through
/// text, iconography, and semantics. All custom motion must resolve its duration
/// through [duration] so the platform Reduce Motion preference is respected.
abstract final class CoverWiseMotion {
  static const instant = Duration.zero;
  static const quick = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 220);
  static const emphasized = Duration(milliseconds: 360);
  static const onboarding = Duration(milliseconds: 420);

  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;

  static bool isReduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration duration(BuildContext context, Duration token) =>
      isReduced(context) ? instant : token;

  static AnimationStyle animationStyle(
    BuildContext context, {
    Duration token = standard,
  }) {
    if (isReduced(context)) return AnimationStyle.noAnimation;
    return AnimationStyle(
      duration: token,
      reverseDuration: token,
      curve: enterCurve,
      reverseCurve: exitCurve,
    );
  }
}

/// Keyed, local state replacement for compact content regions.
///
/// This deliberately uses only opacity. It avoids spatial movement when the
/// relationship between the old and new content does not need to be tracked.
class CoverWiseStateTransition extends StatelessWidget {
  final Widget child;
  final Duration durationToken;
  final AlignmentGeometry alignment;

  const CoverWiseStateTransition({
    super.key,
    required this.child,
    this.durationToken = CoverWiseMotion.standard,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: CoverWiseMotion.duration(context, durationToken),
      reverseDuration: CoverWiseMotion.duration(context, durationToken),
      switchInCurve: CoverWiseMotion.enterCurve,
      switchOutCurve: CoverWiseMotion.exitCurve,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: alignment,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      child: child,
    );
  }
}
