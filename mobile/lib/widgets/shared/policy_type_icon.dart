import 'package:flutter/material.dart';

import '../../utils/policy_type.dart';

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
    final color = colorForPolicyType(type);
    final primaryIcon = _primaryIcon(type);
    final background = color.withValues(alpha: selected ? 0.20 : 0.12);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
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

  IconData _primaryIcon(PolicyType type) {
    switch (type) {
      case PolicyType.health:
        return Icons.monitor_heart_rounded;
      case PolicyType.auto:
        return Icons.directions_car_filled_rounded;
      case PolicyType.life:
        return Icons.person_rounded;
      case PolicyType.home:
        return Icons.home_rounded;
      case PolicyType.travel:
        return Icons.flight_rounded;
      case PolicyType.other:
        return Icons.inventory_2_rounded;
    }
  }
}
