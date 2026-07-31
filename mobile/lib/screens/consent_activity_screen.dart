import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/server_consent_service.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';

/// Account-scoped, append-only privacy choice history.
///
/// This surface reads the server ledger directly. The local cache remains
/// useful for feature gating, but is not presented as a complete account
/// audit trail when the backend cannot be reached.
class ConsentActivityScreen extends StatefulWidget {
  final ServerConsentService? service;

  const ConsentActivityScreen({super.key, this.service});

  @override
  State<ConsentActivityScreen> createState() => _ConsentActivityScreenState();
}

class _ConsentActivityScreenState extends State<ConsentActivityScreen> {
  late final ServerConsentService _service;
  List<ServerConsentRecord>? _records;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ServerConsentService();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final result = await _service.getConsentHistory();
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case ConsentSnapshotLoaded(:final records):
          _records = records;
        case ConsentSnapshotUnavailable():
          _records = null;
        case ConsentSnapshotInvalid():
          _records = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consent activity')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const _ConsentActivitySkeleton();
    if (_records == null) {
      return _ConsentHistoryUnavailable(onRetry: _load);
    }
    if (_records!.isEmpty) return const _EmptyConsentHistory();

    final groups = <String, List<ServerConsentRecord>>{};
    for (final record in _records!) {
      final month = DateFormat.yMMMM().format(record.createdAt.toLocal());
      groups.putIfAbsent(month, () => []).add(record);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        const CoverWisePageHeader(
          title: 'Your privacy choices',
          subtitle:
              'This account-scoped record shows when you allowed or declined specific uses of your data.',
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: CoverWiseInfoPanel(
            icon: Icons.verified_user_outlined,
            title: 'Append-only record',
            body:
                'New choices are added to the ledger. Earlier entries remain visible so you can see what changed and when.',
          ),
        ),
        for (final group in groups.entries) ...[
          _MonthLabel(group.key),
          CoverWiseSurface(
            child: Column(
              children: [
                for (var index = 0; index < group.value.length; index++) ...[
                  _ConsentActivityRow(record: group.value[index]),
                  if (index != group.value.length - 1)
                    const Divider(indent: 68),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_person_outlined,
                size: 20,
                color: CoverWiseColors.blueDeep,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Only choices associated with your signed-in or anonymous CoverWise identity appear here.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthLabel extends StatelessWidget {
  final String label;

  const _MonthLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ConsentActivityRow extends StatelessWidget {
  final ServerConsentRecord record;

  const _ConsentActivityRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final presentation = _ConsentPresentation.from(record);
    final formattedDate =
        DateFormat.yMMMd().add_jm().format(record.createdAt.toLocal());
    final theme = Theme.of(context);

    return Semantics(
      label:
          '${presentation.title}. $formattedDate. Policy ${record.policyVersion}.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverWiseIconBadge(
              icon: presentation.icon,
              color: presentation.color,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentation.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Policy ${record.policyVersion}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Text(
                formattedDate,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentPresentation {
  final String title;
  final IconData icon;
  final Color color;

  const _ConsentPresentation({
    required this.title,
    required this.icon,
    required this.color,
  });

  factory _ConsentPresentation.from(ServerConsentRecord record) {
    final action = record.granted ? 'allowed' : 'declined';
    final color =
        record.granted ? const Color(0xFF087F75) : const Color(0xFFB4233C);
    final defaultIcon = record.granted
        ? Icons.check_circle_outline_rounded
        : Icons.block_rounded;

    return switch (record.consentType) {
      'privacy_policy' => _ConsentPresentation(
          title: record.granted
              ? 'Privacy policy accepted'
              : 'Privacy policy declined',
          icon: record.granted ? Icons.task_alt_rounded : Icons.block_rounded,
          color: color,
        ),
      'document_processing' => _ConsentPresentation(
          title: 'Document processing $action',
          icon: record.granted
              ? Icons.description_outlined
              : Icons.hide_source_rounded,
          color: color,
        ),
      'analytics' => _ConsentPresentation(
          title: 'Analytics $action',
          icon: Icons.analytics_outlined,
          color: color,
        ),
      'marketing_emails' => _ConsentPresentation(
          title: 'Marketing emails $action',
          icon: Icons.mail_outline_rounded,
          color: color,
        ),
      'camera_access' => _ConsentPresentation(
          title: 'Camera access $action',
          icon: record.granted
              ? Icons.photo_camera_outlined
              : Icons.no_photography_outlined,
          color: color,
        ),
      'evaluation_dataset' => _ConsentPresentation(
          title: 'Evaluation data use $action',
          icon: Icons.fact_check_outlined,
          color: color,
        ),
      'model_improvement' => _ConsentPresentation(
          title: 'Model improvement $action',
          icon: Icons.model_training_outlined,
          color: color,
        ),
      _ => _ConsentPresentation(
          title: '${_humanize(record.consentType)} $action',
          icon: defaultIcon,
          color: color,
        ),
    };
  }

  static String _humanize(String raw) {
    final words = raw.split('_').where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return 'Consent';
    final value = words.join(' ');
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _ConsentHistoryUnavailable extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ConsentHistoryUnavailable({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 52,
          color: CoverWiseColors.blueDeep,
        ),
        const SizedBox(height: 20),
        Text(
          'Consent history unavailable',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'CoverWise could not reach the account ledger. Your current on-device settings still apply, but this screen will not show a partial record as complete.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}

class _EmptyConsentHistory extends StatelessWidget {
  const _EmptyConsentHistory();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
      children: [
        const Icon(
          Icons.shield_outlined,
          size: 52,
          color: CoverWiseColors.blueDeep,
        ),
        const SizedBox(height: 20),
        Text(
          'No consent activity yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'When you allow or decline a data use, the choice will appear here with its policy version and time.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
        ),
      ],
    );
  }
}

class _ConsentActivitySkeleton extends StatelessWidget {
  const _ConsentActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(height: 30, width: 220, color: fill),
        ),
        const SizedBox(height: 12),
        Container(height: 18, color: fill),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(height: 18, width: 260, color: fill),
        ),
        const SizedBox(height: 40),
        for (var index = 0; index < 4; index++) ...[
          Row(
            children: [
              Container(width: 40, height: 40, color: fill),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 48, color: fill)),
            ],
          ),
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}
