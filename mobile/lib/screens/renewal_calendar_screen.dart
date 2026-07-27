import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../l10n/app_localizations_gen.dart';
import '../utils/document_icons.dart';
import '../services/notification_service.dart';
import 'documents_screen.dart';

// ─── View Mode ──────────────────────────────────────────────────────────

enum _ViewMode { list, calendar }

// ─── Helpers ─────────────────────────────────────────────────────────────

/// Returns the first day of the month as a DateTime (time zero).
DateTime _firstOfMonth(DateTime month) =>
    DateTime(month.year, month.month, 1);

/// Returns the number of days in [month].
int _daysInMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0).day;

/// Returns the weekday index (0 = Monday … 6 = Sunday) of a given [date].
int _weekdayIndex(DateTime date) {
  // DateTime.weekday: 1 = Monday … 7 = Sunday
  return date.weekday - 1;
}

/// Short weekday label from DateTime.weekday (1=Monday…7=Sunday).
/// Uses English labels for now; ready for intl DateFormat('E') when M10 ships.
String _weekdayShort(int weekday) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels[weekday - 1];
}

/// Bright, partially-desaturated indicator for date cells. Distinguishable in
/// light and dark modes without relying on luminance alone.
Color _dotColor(PolicySummary s) {
  if (s.isExpired) return const Color(0xFFE53935); // red
  if (s.isExpiringSoon) return const Color(0xFFEF8C1A); // amber
  return const Color(0xFF2E7D32); // green
}

/// Groups policies by their expiry date (date only, no time).
Map<DateTime, List<PolicySummary>> _groupByDate(List<PolicySummary> policies) {
  final map = <DateTime, List<PolicySummary>>{};
  for (final s in policies) {
    if (s.endDate == null) continue;
    // Normalise to date-only key so cells match by day equality.
    final key = DateTime(s.endDate!.year, s.endDate!.month, s.endDate!.day);
    map.putIfAbsent(key, () => []).add(s);
  }
  return map;
}

// ─── Screen ──────────────────────────────────────────────────────────────

class RenewalCalendarScreen extends ConsumerStatefulWidget {
  const RenewalCalendarScreen({super.key});

  @override
  ConsumerState<RenewalCalendarScreen> createState() =>
      _RenewalCalendarScreenState();
}

class _RenewalCalendarScreenState
    extends ConsumerState<RenewalCalendarScreen> {
  _ViewMode _viewMode = _ViewMode.list;
  DateTime _currentMonth = _firstOfMonth(DateTime.now());

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = _firstOfMonth(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    final summaries = ref.watch(policySummariesProvider);
    final hasNoPolicies = summaries.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.renewalTitle),
        actions: [
          if (!hasNoPolicies)
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  _viewMode == _ViewMode.list
                      ? Icons.calendar_month_outlined
                      : Icons.view_list_rounded,
                  key: ValueKey(_viewMode),
                ),
              ),
              tooltip: _viewMode == _ViewMode.list
                  ? 'Switch to calendar'
                  : 'Switch to list',
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == _ViewMode.list
                      ? _ViewMode.calendar
                      : _ViewMode.list;
                });
              },
            ),
        ],
      ),
      body: hasNoPolicies ? _buildEmptyState() : _buildBody(summaries),
    );
  }

  // ─── Empty ─────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final l10n = AppLocalizationsGen.of(context);
    return EmptyStateWidget(
      icon: Icons.event_busy,
      title: l10n.renewalEmptyTitle,
      subtitle: l10n.renewalEmptySubtitle,
      actionLabel: l10n.insuranceCardsChooseFile,
      actionIcon: Icons.upload_file_rounded,
      onAction: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DocumentsScreen(startWithFilePicker: true),
        ),
      ),
      color: const Color(0xFFA94E00),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────

  Widget _buildBody(List<PolicySummary> summaries) {
    final sorted = List<PolicySummary>.from(summaries)..sort((a, b) {
        final aDate = a.endDate ?? DateTime(9999);
        final bDate = b.endDate ?? DateTime(9999);
        return aDate.compareTo(bDate);
      });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _viewMode == _ViewMode.list
          ? _ListViewContent(
              key: const ValueKey('list'),
              summaries: sorted,
            )
          : _CalendarViewContent(
              key: ValueKey('calendar-${_currentMonth.month}-${_currentMonth.year}'),
              summaries: sorted,
              currentMonth: _currentMonth,
              onPreviousMonth: _previousMonth,
              onNextMonth: _nextMonth,
              onGoToToday: _goToToday,
            ),
    );
  }
}

// ─── List View ───────────────────────────────────────────────────────────

class _ListViewContent extends StatelessWidget {
  final List<PolicySummary> summaries;
  const _ListViewContent({super.key, required this.summaries});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    final expired = summaries.where((s) => s.isExpired).toList();
    final expiringSoon = summaries.where((s) => s.isExpiringSoon).toList();
    final active =
        summaries.where((s) => s.isActive && !s.isExpiringSoon).toList();
    final noEndDate = summaries.where((s) => s.endDate == null).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        CoverWisePageHeader(
          title: l10n.renewalHeaderTitle,
          subtitle: l10n.renewalHeaderSubtitle,
          trailing: CoverWiseIconBadge(
            icon: Icons.event_repeat_outlined,
            color: CoverWiseColors.blueDeep,
            size: 52,
          ),
        ),
        _ReminderCard(summaries: summaries),
        const SizedBox(height: 24),
        if (expired.isNotEmpty) ...[
          _SectionHeader(l10n.renewalSectionExpired, Icons.error, Colors.red,
              expired.length),
          const SizedBox(height: 8),
          ...expired.map((s) => _RenewalCard(summary: s, color: Colors.red)),
          const SizedBox(height: 20),
        ],
        if (expiringSoon.isNotEmpty) ...[
          _SectionHeader(l10n.renewalSectionExpiringSoon, Icons.warning,
              Colors.orange, expiringSoon.length),
          const SizedBox(height: 8),
          ...expiringSoon
              .map((s) => _RenewalCard(summary: s, color: Colors.orange)),
          const SizedBox(height: 20),
        ],
        if (active.isNotEmpty) ...[
          _SectionHeader(l10n.renewalSectionActive, Icons.check_circle,
              Colors.green, active.length),
          const SizedBox(height: 8),
          ...active.map((s) => _RenewalCard(summary: s, color: Colors.green)),
        ],
        if (noEndDate.isNotEmpty) ...[
          if (active.isNotEmpty) const SizedBox(height: 20),
          _SectionHeader(l10n.renewalSectionNoDate, Icons.info_outline,
              Colors.blueGrey, noEndDate.length),
          const SizedBox(height: 8),
          _NoEndDateNote(),
          ...noEndDate
              .map((s) => _RenewalCard(summary: s, color: Colors.blueGrey)),
        ],
      ],
    );
  }
}

// ─── Calendar View ───────────────────────────────────────────────────────

class _CalendarViewContent extends StatelessWidget {
  final List<PolicySummary> summaries;
  final DateTime currentMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onGoToToday;

  const _CalendarViewContent({
    super.key,
    required this.summaries,
    required this.currentMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onGoToToday,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policiesByDate = _groupByDate(summaries);
    final noEndDate = summaries.where((s) => s.endDate == null).toList();

    // Build the grid cells.
    final daysInMonth = _daysInMonth(currentMonth);
    final firstWeekday = _weekdayIndex(currentMonth);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    // Build weekday headers using DateFormat for locale-aware day names.
    // Use the intl DateFormat which is already a project dependency.
    // Statically reference day-of-week index 1 (Monday) through 7 (Sunday)
    // to avoid string-based locale assumptions.
    final weekdayLabelTheme = theme.textTheme.labelSmall;
    final weekdayLabels = <Widget>[];
    // DateTime.monday = 1, sunday = 7
    final refDate = DateTime(2024, 9, 30); // A Monday
    for (var i = 0; i < 7; i++) {
      final dow = refDate.add(Duration(days: i));
      final isWeekend = dow.weekday >= 6;
      weekdayLabels.add(
        Expanded(
          child: Center(
            child: Text(
              _weekdayShort(dow.weekday),
              style: weekdayLabelTheme?.copyWith(
                color: isWeekend
                    ? theme.colorScheme.error.withValues(alpha: 0.65)
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),
      );
    }

    // Calendar cells as list of widgets (day numbers + empty fillers).
    final cells = <Widget>[];

    // Leading empty cells for days before the 1st.
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    // Day cells.
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      final policies = policiesByDate[date] ?? const [];
      final isToday = date == todayKey;
      cells.add(_DayCell(
        day: day,
        policies: policies,
        isToday: isToday,
        onTap: policies.isEmpty
            ? null
            : () => _showDayPolicies(context, date, policies),
      ));
    }

    final isCurrentMonth =
        currentMonth.month == DateTime.now().month &&
        currentMonth.year == DateTime.now().year;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        // Month navigation header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: onPreviousMonth,
                tooltip: 'Previous month',
              ),
              Expanded(
                child: Text(
                  _monthLabel(currentMonth),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isCurrentMonth)
                TextButton(
                  onPressed: onGoToToday,
                  child: const Text('Today'),
                )
              else
                const SizedBox(width: 72), // maintain layout balance
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: onNextMonth,
                tooltip: 'Next month',
              ),
            ],
          ),
        ),

        // Day-of-week headers (locale-aware, built above)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(children: weekdayLabels),
        ),

        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GridView.count(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.85,
            children: cells,
          ),
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _LegendDot(color: const Color(0xFF2E7D32), label: 'Active'),
              _LegendDot(color: const Color(0xFFEF8C1A), label: 'Expiring soon'),
              _LegendDot(color: const Color(0xFFE53935), label: 'Expired'),
              _LegendDot(color: theme.colorScheme.onSurfaceVariant, label: 'Today', isSquare: true),
            ],
          ),
        ),

        // No-end-date policies note
        if (noEndDate.isNotEmpty) ...[
          const SizedBox(height: 16),
          _NoEndDateNote(),
          const SizedBox(height: 8),
          ...noEndDate.map((s) => _RenewalCard(summary: s, color: Colors.blueGrey)),
        ],

        // Reminder card at the bottom of calendar view too
        const SizedBox(height: 16),
        _ReminderCard(summaries: summaries),
        const SizedBox(height: 24),
      ],
    );
  }

  String _monthLabel(DateTime month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }

  void _showDayPolicies(
    BuildContext context,
    DateTime date,
    List<PolicySummary> policies,
  ) {
    final l10n = AppLocalizationsGen.of(context);
    final theme = Theme.of(context);
    final dateStr = '${date.day} ${_monthLabel(date).split(' ')[0]} ${date.year}';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.renewalExpiringPolicies(dateStr),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.renewalExpiringCount(policies.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ...policies.map((s) => _DayPolicyTile(summary: s)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Day Cell ────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int day;
  final List<PolicySummary> policies;
  final bool isToday;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.policies,
    required this.isToday,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPolicies = policies.isNotEmpty;

    // Sort policies for dot order: expired first (worst case), then expiring, then active.
    final sortedBySeverity = List<PolicySummary>.from(policies)
      ..sort((a, b) {
        final aScore = a.isExpired ? 0 : a.isExpiringSoon ? 1 : 2;
        final bScore = b.isExpired ? 0 : b.isExpiringSoon ? 1 : 2;
        return aScore.compareTo(bScore);
      });

    return Semantics(
      button: hasPolicies,
      label: hasPolicies
          ? '$day — ${policies.length} polic${policies.length == 1 ? 'y' : 'ies'} expiring'
          : 'Day $day',
      child: Material(
        color: isToday
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isToday
              ? BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.40),
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasPolicies ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              if (hasPolicies) ...[
                const SizedBox(height: 3),
                // Show up to 3 colour dots + count if > 3
                Wrap(
                  spacing: 2,
                  runSpacing: 1,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < sortedBySeverity.length && i < 3; i++)
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _dotColor(sortedBySeverity[i]),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (sortedBySeverity.length > 3)
                      Text(
                        '+${sortedBySeverity.length - 3}',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Day Policy Tile (bottom sheet) ────────────────────────────────────

class _DayPolicyTile extends StatelessWidget {
  final PolicySummary summary;
  const _DayPolicyTile({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    final color = _dotColor(summary);
    final icon = iconForDocumentType(summary.documentType);
    final statusLabel = summary.isExpired
        ? l10n.renewalSectionExpired
        : summary.isExpiringSoon
            ? l10n.renewalSectionExpiringSoon
            : l10n.renewalSectionActive;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CoverWiseIconBadge(icon: icon, color: color, size: 40),
        title: Text(
          summary.documentType,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${summary.insurer ?? l10n.renewalInsurerNotFound} • $statusLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          final nav = Navigator.of(context);
          nav.pop(); // close sheet
          nav.pushNamed(
            '/policy-detail',
            arguments: summary.documentId,
          );
        },
      ),
    );
  }
}

// ─── Legend Dot ──────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSquare;

  const _LegendDot({
    required this.color,
    required this.label,
    this.isSquare = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: isSquare ? BorderRadius.circular(2) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ─── No-End-Date Note ────────────────────────────────────────────────────

class _NoEndDateNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.blueGrey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: Colors.blueGrey, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.renewalNoDateInfo,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  const _SectionHeader(this.title, this.icon, this.color, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          CoverWiseIconBadge(icon: icon, color: color, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final List<PolicySummary> summaries;
  const _ReminderCard({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CoverWiseIconBadge(
              icon: Icons.notifications_active_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l10n.renewalReminderText),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final granted =
                    await NotificationService.requestPermissions();
                if (granted) {
                  await NotificationService.scheduleRenewalReminders(
                    summaries,
                  );
                }
                if (!context.mounted) return;
                if (granted) {
                  CoverWiseSnackBar.success(context, l10n.renewalRemindersOn);
                } else {
                  CoverWiseSnackBar.warning(
                      context, l10n.renewalNotificationsOff);
                }
              },
              child: Text(l10n.enable),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenewalCard extends StatelessWidget {
  final PolicySummary summary;
  final Color color;
  const _RenewalCard({required this.summary, required this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    final icon = iconForDocumentType(summary.documentType);
    final days = summary.daysUntilExpiry;
    final hasNoEndDate = summary.endDate == null;
    final trailingLabel = hasNoEndDate
        ? 'N/A'
        : summary.isExpired
            ? 'EXPIRED'
            : '$days days';
    final showRenewCta = summary.isExpired || summary.isExpiringSoon;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          ListTile(
            leading: CoverWiseIconBadge(icon: icon, color: color),
            title: Text(
              summary.documentType,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.insurer ?? l10n.renewalInsurerNotFound}\n${l10n.renewalExpires(summary.formattedExpiryDate)}',
                ),
                if (largeText) ...[
                  const SizedBox(height: 8),
                  CoverWiseStatusChip(
                    icon: hasNoEndDate
                        ? Icons.help_outline_rounded
                        : summary.isExpired
                            ? Icons.error_rounded
                            : Icons.schedule_rounded,
                    label: trailingLabel,
                    color: color,
                    compact: true,
                  ),
                ],
              ],
            ),
            isThreeLine: true,
            trailing: largeText
                ? null
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CoverWiseStatusChip(
                        icon: hasNoEndDate
                            ? Icons.help_outline_rounded
                            : summary.isExpired
                                ? Icons.error_rounded
                                : Icons.schedule_rounded,
                        label: trailingLabel,
                        color: color,
                        compact: true,
                      ),
                      if (summary.policyNumber != null)
                        Text(
                          summary.policyNumber!,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          if (showRenewCta) _RenewNowButton(summary: summary, color: color),
        ],
      ),
    );
  }
}

class _RenewNowButton extends StatelessWidget {
  final PolicySummary summary;
  final Color color;
  const _RenewNowButton({required this.summary, required this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    final hasContact =
        summary.insurerHelpline != null || summary.insurerEmail != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: hasContact
              ? () => _showRenewalContactSheet(context)
              : () => _showNoContactInfo(context),
          icon: Icon(
            summary.isExpired ? Icons.replay_rounded : Icons.autorenew_rounded,
            size: 18,
          ),
          label: Text(
            summary.isExpired ? l10n.renewalContactToRenew : l10n.renewalStartRenewal,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }

  void _showRenewalContactSheet(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.renewalRenewTitle(summary.documentType),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.renewalContactInsurer(summary.insurer ?? 'your insurer'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              if (summary.insurerHelpline != null) ...[
                CoverWiseActionRow(
                  icon: Icons.phone_outlined,
                  color: Colors.green,
                  title: l10n.renewalCallHelpline,
                  subtitle: summary.insurerHelpline!,
                  onTap: () => _callHelpline(ctx),
                ),
                const SizedBox(height: 8),
              ],
              if (summary.insurerEmail != null) ...[
                CoverWiseActionRow(
                  icon: Icons.email_outlined,
                  color: CoverWiseColors.blueDeep,
                  title: l10n.renewalSendEmail,
                  subtitle: summary.insurerEmail!,
                  onTap: () => _sendEmail(ctx),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _callHelpline(BuildContext context) async {
    final l10n = AppLocalizationsGen.of(context);
    Navigator.of(context).pop();
    final cleaned = summary.insurerHelpline!.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      CoverWiseSnackBar.error(context, l10n.renewalPhoneDialerError);
    }
  }

  void _sendEmail(BuildContext context) async {
    final l10n = AppLocalizationsGen.of(context);
    Navigator.of(context).pop();
    final uri = Uri(
      scheme: 'mailto',
      path: summary.insurerEmail,
      queryParameters: {
        'subject':
            'Policy Renewal - ${summary.policyNumber ?? summary.documentType}',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      CoverWiseSnackBar.error(context, l10n.renewalEmailClientError);
    }
  }

  void _showNoContactInfo(BuildContext context) {
    final l10n = AppLocalizationsGen.of(context);
    CoverWiseSnackBar.warning(
      context,
      l10n.renewalContactInfoNotFound(summary.insurer ?? 'this insurer'),
      actionLabel: l10n.viewPolicy,
      onAction: () {
        Navigator.of(context).pushNamed(
          '/policy-detail',
          arguments: summary.documentId,
        );
      },
    );
  }
}
