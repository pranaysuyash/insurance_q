import 'package:flutter/material.dart';
import '../providers/health_score_provider.dart';
import '../theme/coverwise_theme.dart';
import '../theme/coverwise_motion.dart';
import 'shared/coverwise_components.dart';
import '../services/analytics_service.dart';

/// At-a-glance "are we covered?" card shown on the dashboard.
///
/// Displays a circular score gauge (0–100), a human-readable label,
/// and an expandable breakdown of the four scoring factors.
class HealthScoreCard extends StatefulWidget {
  final InsuranceHealthScore healthScore;

  const HealthScoreCard({super.key, required this.healthScore});

  @override
  State<HealthScoreCard> createState() => _HealthScoreCardState();
}

class _HealthScoreCardState extends State<HealthScoreCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animController;
  late Animation<double> _scoreAnim;
  bool _motionInitialized = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: CoverWiseMotion.emphasized,
    );
    _scoreAnim = _scoreTween(0, widget.healthScore.score);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = CoverWiseMotion.isReduced(context);
    if (_motionInitialized && reduceMotion == _reduceMotion) return;
    _motionInitialized = true;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _animController
        ..stop()
        ..value = 1;
    } else {
      _animController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(HealthScoreCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.healthScore.score != widget.healthScore.score) {
      _scoreAnim = _scoreTween(
        oldWidget.healthScore.score,
        widget.healthScore.score,
      );
      if (_reduceMotion) {
        _animController.value = 1;
      } else {
        _animController.forward(from: 0);
      }
    }
  }

  Animation<double> _scoreTween(int begin, int end) {
    return Tween<double>(
      begin: begin.toDouble(),
      end: end.toDouble(),
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: CoverWiseMotion.enterCurve,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color get _scoreColor {
    final s = widget.healthScore.score;
    if (s >= 80) return Colors.green;
    if (s >= 60) return Colors.blue;
    if (s >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hs = widget.healthScore;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Card(
      child: Semantics(
        button: true,
        expanded: _expanded,
        label: 'Coverage health details',
        hint: _expanded ? 'Collapse score details' : 'Show score details',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (!_expanded) {
              AnalyticsService.track('dashboard_health_score_expanded', {'current_score': widget.healthScore.score});
            }
            setState(() => _expanded = !_expanded);
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CoverWiseIconBadge(
                      icon: Icons.health_and_safety_outlined,
                      color: CoverWiseColors.blueDeep,
                      size: 38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Coverage health',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _expanded ? 'Hide details' : 'See details',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Animated circular gauge
                    if (reduceMotion)
                      _ScoreGauge(score: hs.score, color: _scoreColor)
                    else
                      AnimatedBuilder(
                        animation: _scoreAnim,
                        builder: (context, _) => _ScoreGauge(
                          score: _scoreAnim.value.round(),
                          color: _scoreColor,
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hs.label,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _scoreColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hs.summary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                            maxLines: _expanded ? null : 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Expandable factor breakdown
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        const Divider(),
                        const SizedBox(height: 14),
                        ...hs.factors.map((f) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _FactorRow(factor: f),
                          );
                        }),
                      ],
                    ),
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: CoverWiseMotion.duration(
                    context,
                    CoverWiseMotion.standard,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular gauge that animates from 0 to [score].
class _ScoreGauge extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreGauge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$score out of 100',
      excludeSemantics: true,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background ring
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 8,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            // Score arc
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 8,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
            // Score number
            Text(
              '$score',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single factor row with label, progress bar, and points.
class _FactorRow extends StatelessWidget {
  final HealthScoreFactor factor;

  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    final fraction =
        factor.maxPoints > 0 ? factor.points / factor.maxPoints : 0.0;

    final theme = Theme.of(context);
    return Semantics(
      label:
          '${factor.title}: ${factor.points} of ${factor.maxPoints} points. ${factor.detail}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  factor.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${factor.points}/${factor.maxPoints}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: factor.isPositive ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            factor.detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
