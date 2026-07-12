import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../models/policy_summary.dart';
import '../services/policy_extraction_service.dart';
import 'service_providers.dart';

final policyExtractionServiceProvider = Provider<PolicyExtractionService>((ref) {
  return PolicyExtractionService(ref.watch(queryServiceProvider));
});

final policySummariesProvider = StateNotifierProvider<PolicySummariesNotifier, List<PolicySummary>>((ref) {
  return PolicySummariesNotifier(ref.watch(policyExtractionServiceProvider));
});

class PolicySummariesNotifier extends StateNotifier<List<PolicySummary>> {
  final PolicyExtractionService _service;

  PolicySummariesNotifier(this._service) : super([]) {
    _loadSummaries();
  }

  void _loadSummaries() {
    var summaries = _service.getAllSummaries();

    // In demo mode, inject demo data if no summaries exist
    if (summaries.isEmpty && AppConfig.bootstrapPolicyDemo) {
      for (final demo in demoPolicySummaries) {
        _service.saveSummary(demo);
      }
      summaries = _service.getAllSummaries();
    }

    state = summaries;
  }

  Future<PolicySummary?> extractForDocument(String documentId, String documentType) async {
    final summary = await _service.extractSummary(documentId, documentType);
    if (summary != null) {
      _loadSummaries();
    }
    return summary;
  }

  Future<void> fetchFromBackend(String documentId, String documentType) async {
    final summary = await _service.extractSummary(documentId, documentType);
    if (summary != null) {
      _loadSummaries();
    }
  }

  Future<void> deleteSummary(String documentId) async {
    await _service.deleteSummary(documentId);
    _loadSummaries();
  }

  PolicySummary? getForDocument(String documentId) {
    return state.where((s) => s.documentId == documentId).firstOrNull;
  }

  List<PolicySummary> get expiringSoon =>
      state.where((s) => s.isExpiringSoon).toList();

  List<PolicySummary> get expired =>
      state.where((s) => s.isExpired).toList();

  List<PolicySummary> get active =>
      state.where((s) => s.isActive).toList();
}

final coverageGapsProvider = Provider<List<CoverageGap>>((ref) {
  final summaries = ref.watch(policySummariesProvider);
  return ref.watch(policyExtractionServiceProvider).analyzeCoverageGaps(summaries);
});

final claimGuideProvider = Provider.family<ClaimGuide?, (String, String?)>((ref, params) {
  final incidentType = params.$1;
  final documentId = params.$2;
  final summaries = ref.watch(policySummariesProvider);
  final summary = documentId != null
      ? summaries.where((s) => s.documentId == documentId).firstOrNull
      : summaries.isNotEmpty
          ? summaries.first
          : null;
  return ref.watch(policyExtractionServiceProvider).getClaimGuide(incidentType, summary);
});

// Demo data for bootstrap mode
List<PolicySummary> get demoPolicySummaries => [
  PolicySummary(
    documentId: '3022ffcb-86c5-42ae-ae9f-2d6e00025631',
    policyNumber: '4214i/CPHSR/407834350/00/000',
    insurer: 'ICICI Lombard General Insurance Company Limited',
    insurerHelpline: '1800 2666',
    insurerEmail: 'ihealthcare@icicilombard.com',
    documentType: 'Health Insurance',
    coverageAmount: 2500000,
    premiumAmount: 31705,
    premiumFrequency: 'annually',
    startDate: DateTime(2025, 8, 27),
    endDate: DateTime(2026, 8, 26),
    keyBenefits: [
      'In-patient hospitalization up to sum insured',
      'Pre-hospitalization expenses for 60 days',
      'Post-hospitalization expenses for 180 days',
      'Daycare procedures covered',
      'Maternity benefit up to ₹40,000',
    ],
    exclusions: [
      'Pre-existing conditions (subject to policy terms)',
      'Cosmetic/aesthetic treatments',
      'Self-inflicted injuries',
      'War-related injuries',
    ],
    waitingPeriods: [
      'Initial 30 days waiting period',
      'Pre-existing conditions: as per policy terms',
    ],
    coverageItems: [
      CoverageItem(name: 'Hospitalization', covered: true, limitText: 'Up to ₹25L'),
      CoverageItem(name: 'Maternity', covered: true, limit: 40000, limitText: '₹40,000'),
      CoverageItem(name: 'Daycare Procedures', covered: true, limitText: 'Up to sum insured'),
      CoverageItem(name: 'Pre-hospitalization', covered: true, limitText: '60 days'),
      CoverageItem(name: 'Post-hospitalization', covered: true, limitText: '180 days'),
      CoverageItem(name: 'Dental', covered: false, notes: 'Not listed in policy schedule'),
      CoverageItem(name: 'Vision', covered: false, notes: 'Not listed in policy schedule'),
      CoverageItem(name: 'Mental Health', covered: false, notes: 'Not confirmed from schedule'),
    ],
    extractedAt: DateTime.now(),
  ),
];