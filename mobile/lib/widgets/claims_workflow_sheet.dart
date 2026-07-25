import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/claim_record.dart';
import '../models/policy_summary.dart';
import '../services/app_state_repository.dart';
import '../providers/policy_providers.dart';
import '../theme/coverwise_theme.dart';
import 'shared/coverwise_components.dart';
import 'shared/coverwise_snackbar.dart';

/// A multi-step bottom sheet for recording a private claim note with photo evidence.
///
/// Steps:
/// 1. Select incident type and related policy
/// 2. Capture or choose photo evidence (optional)
/// 3. Add description and notes
/// 4. Save to the on-device claim log; CoverWise never submits it to an insurer.
class ClaimWizardSheet extends ConsumerStatefulWidget {
  final PolicySummary? preselectedPolicy;

  const ClaimWizardSheet({super.key, this.preselectedPolicy});

  /// Show the claim wizard as a modal bottom sheet.
  static Future<void> show(BuildContext context,
      {PolicySummary? preselectedPolicy}) async {
    final result = await showModalBottomSheet<ClaimRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ClaimWizardSheet(preselectedPolicy: preselectedPolicy),
    );
    if (result != null && context.mounted) {
      await AppStateRepository.addClaimRecord(result);
      if (context.mounted) {
        CoverWiseSnackBar.success(
          context,
          'Claim logged — ${result.incidentType}. Track it in Claim log.',
        );
      }
    }
  }

  @override
  ConsumerState<ClaimWizardSheet> createState() => _ClaimWizardSheetState();
}

class _ClaimWizardSheetState extends ConsumerState<ClaimWizardSheet> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1: incident + policy
  String _incidentType = 'Hospitalization';
  String? _selectedDocId;

  // Step 2: photo evidence
  final List<String> _photoPaths = [];
  final ImagePicker _picker = ImagePicker();

  // Step 3: description + notes
  final _descController = TextEditingController();
  final _notesController = TextEditingController();

  bool _saving = false;

  static const _incidentTypes = [
    ('Hospitalization', Icons.local_hospital_outlined, Color(0xFFD14A61)),
    ('Auto Accident', Icons.car_crash_outlined, Color(0xFFD97706)),
    ('Life Claim', Icons.favorite_outline_rounded, Color(0xFF7C5AC7)),
    ('Property Damage', Icons.home_outlined, Color(0xFFD97706)),
    ('Theft', Icons.lock_open_rounded, Color(0xFF7C5AC7)),
    ('Other', Icons.help_outline_rounded, CoverWiseColors.blueDeep),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedPolicy != null) {
      _selectedDocId = widget.preselectedPolicy!.documentId;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _descController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? picked;
      if (source == ImageSource.camera) {
        picked = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 80,
        );
      } else {
        picked = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 80,
        );
      }

      if (picked == null) return;

      // Copy to app's documents directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final claimsDir = Directory('${appDir.path}/claim_photos');
      if (!await claimsDir.exists()) {
        await claimsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath =
          '${claimsDir.path}/claim_${_selectedDocId ?? 'new'}_$timestamp.jpg';
      await File(picked.path).copy(destPath);

      if (mounted) {
        setState(() => _photoPaths.add(destPath));
      }
    } catch (e) {
      if (mounted) {
        CoverWiseSnackBar.error(context, 'Could not select photo: $e');
      }
    }
  }

  Future<void> _saveClaim() async {
    if (_descController.text.trim().isEmpty) return;

    setState(() => _saving = true);

    PolicySummary? selectedSummary;
    if (_selectedDocId != null) {
      final summaries = ref.read(policySummariesProvider);
      selectedSummary =
          summaries.where((s) => s.documentId == _selectedDocId).firstOrNull;
    }

    final claim = ClaimRecord(
      id: const Uuid().v4(),
      documentId: _selectedDocId ?? '',
      policyType: selectedSummary?.documentType ?? 'Unknown',
      insurer: selectedSummary?.insurer ?? 'Unknown',
      incidentType: _incidentType,
      description: _descController.text.trim(),
      filedDate: DateTime.now(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      photoPaths: List.unmodifiable(_photoPaths),
    );

    setState(() => _saving = false);
    if (mounted) Navigator.of(context).pop(claim);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          children: [
            // Step indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Row(
                children: List.generate(3, (i) {
                  final isActive = i == _currentStep;
                  final isPast = i < _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isPast
                            ? Theme.of(context).colorScheme.primary
                            : isActive
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.5)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Step labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('Details', style: _stepLabelStyle(_currentStep == 0)),
                  Text('Photos (optional)',
                      style: _stepLabelStyle(_currentStep == 1)),
                  Text('Review', style: _stepLabelStyle(_currentStep == 2)),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentStep = i),
                physics: _saving
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                children: [
                  _buildDetailsStep(),
                  _buildPhotosStep(),
                  _buildReviewStep(),
                ],
              ),
            ),

            // Bottom actions
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  TextStyle _stepLabelStyle(bool isCurrent) {
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: 12,
      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
      color: isCurrent
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
    );
  }

  // ───────────── Step 1: Incident Details ─────────────

  Widget _buildDetailsStep() {
    final summaries = ref.watch(policySummariesProvider);
    final theme = Theme.of(context);

    return ListView(
      key: const ValueKey('incident_type_list'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      children: [
        Text(
          'What happened?',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the type of incident and optionally link it to a policy.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        const CoverWiseInfoPanel(
          icon: Icons.info_outline_rounded,
          title: 'Private claim note',
          body:
              'This records information on this device only. It does not file, submit, or update a claim with an insurer.',
        ),
        const SizedBox(height: 20),
        const CoverWiseSectionLabel('Incident type'),
        const SizedBox(height: 6),
        ..._incidentTypes.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _IncidentTypeTile(
              label: item.$1,
              icon: item.$2,
              color: item.$3,
              selected: _incidentType == item.$1,
              onTap: () => setState(() => _incidentType = item.$1),
            ),
          ),
        ),
        if (summaries.isNotEmpty) ...[
          const SizedBox(height: 16),
          const CoverWiseSectionLabel('Related policy (optional)'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            initialValue: _selectedDocId,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.policy_outlined),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('None selected')),
              ...summaries.map(
                (s) => DropdownMenuItem(
                  value: s.documentId,
                  child: Text(
                    '${s.documentType} — ${s.insurer ?? "Unknown"}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedDocId = v),
          ),
        ],
      ],
    );
  }

  // ───────────── Step 2: Photo Evidence ─────────────

  Widget _buildPhotosStep() {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      children: [
        Text(
          'Photo evidence',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Add photos of damage, receipts, or relevant documents. These are stored on-device.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),

        // Photo grid
        if (_photoPaths.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_photoPaths.length, (i) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_photoPaths[i]),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _photoPaths.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
        ],

        // Add photos row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_photoPaths.isEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Photos are optional. They stay on this device and can help you organize information before you contact your insurer.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ───────────── Step 3: Review & Save ─────────────

  Widget _buildReviewStep() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      children: [
        Text(
          'Review & save',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Describe what happened. This stays on your device.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),

        // Summary of previous steps
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow(context, Icons.warning_amber_rounded, 'Incident',
                    _incidentType),
                if (_selectedDocId != null)
                  _summaryRow(
                      context, Icons.policy_outlined, 'Policy', 'Linked'),
                _summaryRow(context, Icons.camera_alt_outlined, 'Photos',
                    '${_photoPaths.length} attached'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _descController,
          decoration: const InputDecoration(
            labelText: 'What happened? *',
            hintText: 'E.g. Car hit pole on Marine Drive, 22 July 2026',
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: Icon(Icons.description_outlined),
            ),
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Additional notes (optional)',
            hintText: 'Repair estimate, claim reference from insurer...',
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: Icon(Icons.edit_note_rounded),
            ),
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _summaryRow(
      BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label: ',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ───────────── Bottom Bar ─────────────

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: _saving ? null : _back,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              label: const Text('Back'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          const Spacer(),
          if (_currentStep < 2)
            FilledButton(
              onPressed: _next,
              child: const Text('Continue'),
            )
          else
            FilledButton(
              onPressed: (_descController.text.trim().isEmpty || _saving)
                  ? null
                  : _saveClaim,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save to claim log'),
            ),
        ],
      ),
    );
  }
}

/// Tappable incident type tile used in step 1.
class _IncidentTypeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _IncidentTypeTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}
