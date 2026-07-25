import 'package:flutter/material.dart';
import '../../models/policy_summary.dart';
import '../../services/preventive_health_service.dart';
import '../../services/analytics_service.dart';
import '../shared/coverwise_components.dart';

class PreventiveTipsSection extends StatefulWidget {
  final List<PolicySummary> summaries;
  const PreventiveTipsSection({super.key, required this.summaries});

  @override
  State<PreventiveTipsSection> createState() => _PreventiveTipsSectionState();
}

class _PreventiveTipsSectionState extends State<PreventiveTipsSection> {
  List<HealthTip> _tips = [];

  @override
  void initState() {
    super.initState();
    _tips = PreventiveHealthService.getAvailableTips(widget.summaries);
  }

  @override
  void didUpdateWidget(PreventiveTipsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summaries != widget.summaries) {
      _tips = PreventiveHealthService.getAvailableTips(widget.summaries);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const CoverWiseSectionLabel('Policy review notes'),
            TextButton(
              onPressed: () async {
                AnalyticsService.track('dashboard_preventive_tips_dismiss_all');
                await PreventiveHealthService.markAllShown(_tips);
                setState(() => _tips = []);
              },
              child: const Text('Dismiss All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._tips.take(3).map((tip) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CoverWiseIconBadge(
                  icon: tip.icon,
                  color: Theme.of(context).colorScheme.tertiary,
                  size: 40,
                ),
                title: Text(tip.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(tip.body,
                    style: const TextStyle(fontSize: 13), maxLines: 2),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss ${tip.title}',
                  onPressed: () async {
                    AnalyticsService.track('dashboard_preventive_tip_dismissed',
                        {'tip_id': tip.id});
                    await PreventiveHealthService.markTipShown(tip.id);
                    setState(() => _tips.remove(tip));
                  },
                ),
              ),
            )),
      ],
    );
  }
}
