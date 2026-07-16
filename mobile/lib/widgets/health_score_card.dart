import 'package:flutter/material.dart';
import '../providers/health_score_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(HealthScoreCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.healthScore.score != widget.healthScore.score) {
      _animController.reset();
      _scoreAnim = Tween<double>(
        begin: 0,
        end: widget.healthScore.score.toDouble(),
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ));
      _animController.forward();
    }
  }

  void _startAnimation() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(
      begin: 0,
      end: widget.healthScore.score.toDouble(),
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: gauge + label + summary
              Row(
                children: [
                  // Animated circular gauge
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _scoreColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hs.summary,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),

              // Expandable factor breakdown
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: hs.factors.map((f) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FactorRow(factor: f),
                      );
                    }).toList(),
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
            ],
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
    return SizedBox(
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
              color: Colors.grey.shade200,
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
    );
  }
}

/// A single factor row with label, progress bar, and points.
class _FactorRow extends StatelessWidget {
  final HealthScoreFactor factor;

  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    final fraction = factor.maxPoints > 0
        ? factor.points / factor.maxPoints
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                factor.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${factor.points}/${factor.maxPoints}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
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
            backgroundColor: Colors.grey.shade200,
            color: factor.isPositive ? Colors.green : Colors.orange,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          factor.detail,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
