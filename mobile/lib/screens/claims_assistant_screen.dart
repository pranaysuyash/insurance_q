import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../providers/document_providers.dart';
import '../widgets/shared/empty_state_widget.dart';

class ClaimsAssistantScreen extends ConsumerStatefulWidget {
  const ClaimsAssistantScreen({super.key});

  @override
  ConsumerState<ClaimsAssistantScreen> createState() => _ClaimsAssistantScreenState();
}

class _ClaimsAssistantScreenState extends ConsumerState<ClaimsAssistantScreen> {
  String? _selectedIncident;
  String? _selectedDocumentId;

  static const _incidentTypes = [
    ('hospitalization', 'Hospitalization', Icons.local_hospital, Colors.red),
    ('accident', 'Auto Accident', Icons.car_crash, Colors.orange),
    ('death', 'Life Insurance Claim', Icons.favorite, Colors.purple),
    ('general', 'Other / General', Icons.help_outline, Colors.blue),
  ];

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(policySummariesProvider);
    final documentsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Claims Assistant')),
      body: documentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (documents) {
          if (documents.isEmpty && summaries.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.assignment_turned_in,
              title: 'No documents uploaded',
              subtitle: 'Upload insurance documents to get claim guidance',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('What happened?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Select the type of incident to get step-by-step claim guidance.',
                style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ..._incidentTypes.map((item) {
                final (type, label, icon, color) = item;
                final isSelected = _selectedIncident == type;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: isSelected ? 3 : 1,
                    color: isSelected ? color.withValues(alpha: 0.05) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected ? BorderSide(color: color, width: 2) : BorderSide.none,
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: isSelected ? Icon(Icons.check_circle, color: color) : null,
                      onTap: () => setState(() => _selectedIncident = type),
                    ),
                  ),
                );
              }),
              if (_selectedIncident != null) ...[
                if (summaries.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Select policy (optional):', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _selectedDocumentId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Auto-select best match')),
                      ...summaries.map((s) => DropdownMenuItem(
                        value: s.documentId,
                        child: Text('${s.documentType} - ${s.insurer ?? "Unknown"}'),
                      )),
                    ],
                    onChanged: (v) => setState(() => _selectedDocumentId = v),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No policy summaries available — you will get a general guide without policy-specific helpline or email details.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                FilledButton.icon(
                  icon: const Icon(Icons.assignment),
                  label: const Text('Get Claim Guide'),
                  onPressed: () => _showClaimGuide(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
    final guide = ref.read(claimGuideProvider((_selectedIncident!, _selectedDocumentId)));
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(guide.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...guide.steps.map((step) => _StepCard(step: step)),
            if (guide.helpline != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.phone),
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
                  icon: const Icon(Icons.email),
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
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(guide.notes!, style: const TextStyle(fontSize: 13))),
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
              Text(step.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(step.description, style: const TextStyle(color: Colors.black87)),
              if (step.documents.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: step.documents.map((d) => Chip(
                    label: Text(d, style: const TextStyle(fontSize: 12)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
              if (step.contactInfo != null) ...[
                const SizedBox(height: 8),
                Text('📞 ${step.contactInfo}', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}