import 'package:flutter/material.dart';

import '../../utils/policy_type.dart';
import '../../theme/coverwise_motion.dart';

/// A compact, recognisable visual for a type of cover.
///
/// The foreground object makes the policy instantly scannable (car, home,
/// person, etc.); the shield badge keeps the insurance meaning clear without
/// relying on a text-heavy card.
class PolicyTypeIcon extends StatelessWidget {
  final PolicyType type;
  final double size;
  final bool selected;

  const PolicyTypeIcon({
    super.key,
    required this.type,
    this.size = 52,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorForPolicyType(
      type,
      brightness: Theme.of(context).brightness,
    );
    final primaryIcon = iconForPolicyType(type);
    final background = color.withValues(alpha: selected ? 0.20 : 0.12);

    return AnimatedContainer(
      duration: CoverWiseMotion.duration(context, CoverWiseMotion.standard),
      curve: CoverWiseMotion.enterCurve,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: selected ? 0.78 : 0.28),
          width: 1.5,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(primaryIcon, color: color, size: size * 0.48),
          Positioned(
            right: size * 0.06,
            bottom: size * 0.04,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_user_rounded,
                color: color,
                size: size * 0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
