import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../providers/document_providers.dart';
import '../theme/coverwise_theme.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../widgets/shared/error_widget.dart';
import 'documents_screen.dart';

class ClaimsAssistantScreen extends ConsumerStatefulWidget {
  const ClaimsAssistantScreen({super.key});

  @override
  ConsumerState<ClaimsAssistantScreen> createState() =>
      _ClaimsAssistantScreenState();
}

class _ClaimsAssistantScreenState extends ConsumerState<ClaimsAssistantScreen> {
  String? _selectedIncident;
  String? _selectedDocumentId;

  static const _incidentTypes = [
    (
      'hospitalization',
      'Hospitalization',
      Icons.local_hospital_outlined,
      Color(0xFFD14A61)
    ),
    ('accident', 'Auto accident', Icons.car_crash_outlined, Color(0xFFD97706)),
    (
      'death',
      'Life insurance claim',
      Icons.favorite_outline_rounded,
      Color(0xFF7C5AC7)
    ),
    (
      'general',
      'Other or general',
      Icons.help_outline_rounded,
      CoverWiseColors.blueDeep
    ),
  ];

  String _incidentDescription(String type) => switch (type) {
        'hospitalization' =>
          'Prepare hospital, treatment and pre-authorization records.',
        'accident' => 'Organize incident, vehicle and repair evidence.',
        'death' => 'Review nominee, identity and insurer requirements.',
        _ => 'Build a general document and contact checklist.',
      };

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(policySummariesProvider);
    final documentsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Claim guide')),
      body: documentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
          message: 'Claim guidance could not load your policy library.',
          icon: Icons.fact_check_outlined,
          onRetry: () => ref.invalidate(documentsProvider),
        ),
        data: (documents) {
          if (documents.isEmpty && summaries.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.fact_check_outlined,
              title: 'No documents uploaded',
              subtitle: 'Choose a policy file to get claim guidance.',
              actionLabel: 'Choose policy file',
              actionIcon: Icons.upload_file_rounded,
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const DocumentsScreen(startWithFilePicker: true),
                ),
              ),
              color: const Color(0xFFD97706),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              const CoverWisePageHeader(
                title: 'What happened?',
                subtitle:
                    'Choose an incident to see a practical preparation guide. CoverWise does not file or manage the claim.',
              ),
              const CoverWiseSectionLabel('Incident type'),
              ..._incidentTypes.map((item) {
                final (type, label, icon, color) = item;
                final isSelected = _selectedIncident == type;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: CoverWiseSelectableRow(
                    icon: icon,
                    color: color,
                    title: label,
                    subtitle: _incidentDescription(type),
                    selected: isSelected,
                    onTap: () => setState(() => _selectedIncident = type),
                  ),
                );
              }),
              if (_selectedIncident != null) ...[
                if (summaries.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const CoverWiseSectionLabel('Related policy (optional)'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedDocumentId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.policy_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Auto-select best match')),
                        ...summaries.map((s) => DropdownMenuItem(
                              value: s.documentId,
                              child: Text(
                                  '${s.documentType} — ${s.insurer ?? "Unknown"}'),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedDocumentId = v),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: CoverWiseInfoPanel(
                      icon: Icons.info_outline_rounded,
                      title: 'General guidance only',
                      body:
                          'No policy summary is available, so this guide cannot include policy-specific contacts or requirements.',
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('View preparation guide'),
                      onPressed: () => _showClaimGuide(),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showClaimGuide() {
    if (_selectedIncident == null) return;
    final guide =
        ref.read(claimGuideProvider((_selectedIncident!, _selectedDocumentId)));
    if (guide == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ClaimGuideSheet(guide: guide),
    );
  }
}

class _ClaimGuideSheet extends StatelessWidget {
  final ClaimGuide guide;
  const _ClaimGuideSheet({required this.guide});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(guide.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Use this as a preparation checklist. Confirm requirements and deadlines directly with your insurer.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            ...guide.steps.map((step) => _StepCard(step: step)),
            if (guide.helpline != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.call_outlined),
                  label: Text('Call ${guide.helpline}'),
                  onPressed: () => _callNumber(guide.helpline!),
                ),
              ),
            ],
            if (guide.email != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: Text(guide.email!),
                  onPressed: () => _sendEmail(guide.email!),
                ),
              ),
            ],
            if (guide.notes != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CoverWiseColors.blueDeep.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: CoverWiseColors.blueDeep.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: CoverWiseColors.blueDeep, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(guide.notes!,
                            style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _callNumber(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
    await launchUrl(Uri.parse('tel:$cleaned'));
  }

  void _sendEmail(String email) async {
    await launchUrl(Uri.parse('mailto:$email'));
  }
}

class _StepCard extends StatelessWidget {
  final ClaimStep step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(step.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(step.description,
                  style: Theme.of(context).textTheme.bodyMedium),
              if (step.documents.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: step.documents
                      .map((d) => Chip(
                            label:
                                Text(d, style: const TextStyle(fontSize: 12)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
              if (step.contactInfo != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.call_outlined,
                        size: 18, color: CoverWiseColors.blueDeep),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        step.contactInfo!,
                        style: const TextStyle(
                            color: CoverWiseColors.blueDeep,
                            fontWeight: FontWeight.w700),
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
