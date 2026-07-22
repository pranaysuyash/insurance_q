import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/policy_summary.dart';
import '../utils/policy_type.dart';
import 'document_service.dart';
import 'policy_extraction_helpers.dart';
import 'query_service.dart';

class PolicyExtractionService {
  final QueryService _queryService;
  final Dio _dio;
  static const _summariesBoxKey = 'policy_summaries';

  PolicyExtractionService(this._queryService) : _dio = DocumentService.authenticatedDio;

  Box get _box => Hive.box('app_state_box');

  Future<PolicySummary?> extractSummary(String documentId, String documentType) async {
    // Try to fetch from backend first (single API call instead of 13 LLM queries)
    try {
      final response = await _dio.get('/documents/$documentId/summary');
      if (response.statusCode == 200 && response.data['summary'] != null) {
        final summaryData = response.data['summary'] as Map<String, dynamic>;
        final summary = PolicySummary.fromJson(summaryData);
        await saveSummary(summary);
        return summary;
      }
    } catch (e) {
      debugPrint('Backend summary fetch failed, falling back to query-based extraction: $e');
    }

    // Fallback: query-based extraction (13 sequential questions)
    return _extractViaQueries(documentId, documentType);
  }

  Future<PolicySummary?> _extractViaQueries(String documentId, String documentType) async {
    try {
      final policyNumber = await _ask(documentId, 'What is the policy number shown in this document? Answer with just the number.');
      final insurer = await _ask(documentId, 'What is the name of the insurance company? Answer with just the company name.');
      final helpline = await _ask(documentId, 'What is the claims helpline or customer care phone number? Answer with just the number.');
      final email = await _ask(documentId, 'What is the customer care email address? Answer with just the email, or say "not listed".');
      final coverage = await _ask(documentId, 'What is the total coverage amount or sum insured? Answer with just the number.');
      final deductible = await _ask(documentId, 'What is the deductible amount? Answer with just the number, or say "not applicable".');
      final premium = await _ask(documentId, 'What is the premium amount? Answer with just the number.');
      final premiumFreq = await _ask(documentId, 'How often is the premium paid? Answer with: monthly, quarterly, half-yearly, or annually.');
      final startDate = await _ask(documentId, 'What is the policy start date? Answer in DD-MM-YYYY format.');
      final endDate = await _ask(documentId, 'What is the policy end date or expiry date? Answer in DD-MM-YYYY format.');
      final benefits = await _ask(documentId, 'List the top 5 key benefits covered by this policy. One per line, brief.');
      final exclusions = await _ask(documentId, 'List the top 5 exclusions or things not covered. One per line, brief.');
      final waiting = await _ask(documentId, 'List any waiting periods mentioned. One per line, brief.');

      final summary = PolicySummary(
        documentId: documentId,
        policyNumber: _clean(policyNumber),
        insurer: _clean(insurer),
        insurerHelpline: _clean(helpline),
        insurerEmail: _cleanEmail(email),
        documentType: documentType,
        coverageAmount: _parseAmount(coverage),
        deductible: _parseAmount(deductible),
        premiumAmount: _parseAmount(premium),
        premiumFrequency: _clean(premiumFreq),
        startDate: _parseDate(startDate),
        endDate: _parseDate(endDate),
        keyBenefits: _splitLines(benefits),
        exclusions: _splitLines(exclusions),
        waitingPeriods: _splitLines(waiting),
        extractedAt: DateTime.now(),
      );

      await saveSummary(summary);
      return summary;
    } catch (e) {
      debugPrint('Error extracting policy summary: $e');
      return null;
    }
  }

  Future<String> _ask(String documentId, String question) async {
    try {
      final result = await _queryService.queryDocument(question, documentId: documentId);
      return result['answer']?.toString() ?? '';
    } catch (e) {
      debugPrint('Error asking "$question": $e');
      return '';
    }
  }

  // Pure helper methods delegated to policy_extraction_helpers.dart so they
  // can be unit-tested without a Dio or Hive dependency.

  String _clean(String? text) => cleanText(text);
  String? _cleanEmail(String? text) => extractEmail(text);
  double? _parseAmount(String? text) => parseAmount(text);
  DateTime? _parseDate(String? text) => parseDate(text);
  List<String> _splitLines(String? text) => splitLines(text);

  Future<void> saveSummary(PolicySummary summary) async {
    final existing = getAllSummaries();
    existing.removeWhere((s) => s.documentId == summary.documentId);
    existing.add(summary);
    final serialized = existing.map((s) => s.toJsonString()).toList();
    await _box.put(_summariesBoxKey, jsonEncode(serialized));
  }

  List<PolicySummary> getAllSummaries() {
    final raw = _box.get(_summariesBoxKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((s) => PolicySummary.fromJsonString(s as String)).toList();
    } catch (e) {
      debugPrint('Error loading policy summaries: $e');
      return [];
    }
  }

  PolicySummary? getSummary(String documentId) {
    final all = getAllSummaries();
    for (final s in all) {
      if (s.documentId == documentId) return s;
    }
    return null;
  }

  Future<void> deleteSummary(String documentId) async {
    final all = getAllSummaries();
    all.removeWhere((s) => s.documentId == documentId);
    final serialized = all.map((s) => s.toJsonString()).toList();
    await _box.put(_summariesBoxKey, jsonEncode(serialized));
  }

  List<CoverageGap> analyzeCoverageGaps(List<PolicySummary> summaries) {
    final gaps = <CoverageGap>[];
    final policyTypes = summaries
        .map((s) => classifyPolicyType(s.documentType))
        .toSet();

    if (!policyTypes.contains(PolicyType.health)) {
      gaps.add(CoverageGap(
        category: 'Health Insurance',
        description: 'No health insurance policy found. Medical emergencies can be financially devastating without coverage.',
        severity: 'high',
        recommendation: 'Consider purchasing health insurance to cover hospitalization and medical expenses.',
      ));
    }
    if (!policyTypes.contains(PolicyType.life)) {
      gaps.add(CoverageGap(
        category: 'Life Insurance',
        description: 'No life insurance policy found. If you have dependents, life insurance protects their financial future.',
        severity: 'high',
        recommendation: 'Consider term life insurance, especially if you have dependents.',
      ));
    }
    if (!policyTypes.contains(PolicyType.auto)) {
      gaps.add(CoverageGap(
        category: 'Auto Insurance',
        description: 'No auto insurance policy found. In most jurisdictions, auto insurance is legally required.',
        severity: 'medium',
        recommendation: 'Ensure you have at least third-party auto insurance coverage.',
      ));
    }
    for (final s in summaries) {
      if (classifyPolicyType(s.documentType) == PolicyType.health) {
        if (!s.keyBenefits.any((b) => b.toLowerCase().contains('maternity'))) {
          gaps.add(CoverageGap(
            category: 'Maternity Coverage',
            description: 'Your health policy "${s.insurer ?? 'Unknown'}" does not appear to include maternity coverage.',
            severity: 'low',
            recommendation: 'If you are planning a family, check if maternity coverage can be added as a rider.',
          ));
        }
        if (!s.keyBenefits.any((b) => b.toLowerCase().contains('critical illness') || b.toLowerCase().contains('critical'))) {
          gaps.add(CoverageGap(
            category: 'Critical Illness',
            description: 'No critical illness coverage detected in your health policy.',
            severity: 'medium',
            recommendation: 'Consider adding a critical illness rider for major diseases like cancer, heart attack, or stroke.',
          ));
        }
      }
      if (s.endDate != null && s.isExpiringSoon && !s.isExpired) {
        gaps.add(CoverageGap(
          category: 'Policy Expiry',
          description: 'Your ${s.documentType} from ${s.insurer ?? 'Unknown'} expires in ${s.daysUntilExpiry} days (${s.formattedExpiryDate}).',
          severity: 'high',
          recommendation: 'Renew before expiry to avoid a coverage gap. Pre-existing conditions may not be covered if the policy lapses.',
        ));
      }
      if (s.isExpired) {
        gaps.add(CoverageGap(
          category: 'Expired Policy',
          description: 'Your ${s.documentType} from ${s.insurer ?? 'Unknown'} expired on ${s.formattedExpiryDate}.',
          severity: 'high',
          recommendation: 'This policy is no longer active. Renew immediately or purchase a new policy.',
        ));
      }
    }
    return gaps;
  }

  ClaimGuide? getClaimGuide(String incidentType, PolicySummary? summary) {
    final helpline = summary?.insurerHelpline;
    final email = summary?.insurerEmail;

    switch (incidentType.toLowerCase()) {
      case 'hospitalization':
      case 'health':
        return ClaimGuide(
          incidentType: 'hospitalization',
          title: 'Hospitalization Claim',
          steps: [
            ClaimStep(
              title: '1. Notify the insurer',
              description: 'Call the insurer within 24-48 hours of hospitalization. For cashless claims, inform the network hospital.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '2. Get pre-authorization (cashless)',
              description: 'If using a network hospital, the hospital will send a pre-authorization request to the insurer. Keep your policy number and ID ready.',
              documents: ['Policy number', 'Photo ID', 'Aadhaar card'],
            ),
            ClaimStep(
              title: '3. Submit claim documents',
              description: 'After discharge, submit all documents to the insurer (for reimbursement) or the hospital handles it (for cashless).',
              documents: [
                'Discharge summary',
                'Hospital bills (original)',
                'Pharmacy bills',
                'Lab reports',
                'Doctor\'s prescription',
                'Pre- and post-hospitalization records',
                'Claim form (duly filled)',
                'Policy copy',
                'Photo ID',
              ],
            ),
            ClaimStep(
              title: '4. Track your claim',
              description: 'Use the insurer\'s app or helpline to track claim status. Claims are typically processed within 7-30 days.',
              contactInfo: helpline,
            ),
          ],
          requiredDocuments: [
            'Discharge summary',
            'Hospital bills (original)',
            'Pharmacy bills',
            'Lab reports',
            'Doctor\'s prescription',
            'Claim form',
            'Policy copy',
            'Photo ID',
          ],
          helpline: helpline,
          email: email,
          notes: 'For cashless claims at network hospitals, the hospital handles most paperwork. For reimbursement, you submit documents to the insurer.',
        );

      case 'accident':
      case 'auto':
      case 'motor':
        return ClaimGuide(
          incidentType: 'accident',
          title: 'Auto Insurance Claim',
          steps: [
            ClaimStep(
              title: '1. Ensure safety first',
              description: 'Move to a safe location. Call emergency services (112) if anyone is injured. Do not admit fault at the scene.',
            ),
            ClaimStep(
              title: '2. Document the scene',
              description: 'Take photos of all vehicles, damage, license plates, and the accident scene. Note time, location, and weather conditions.',
              documents: ['Photos of damage', 'Photos of scene', 'Other driver\'s details', 'Witness contacts (if any)'],
            ),
            ClaimStep(
              title: '3. File an FIR if needed',
              description: 'File an FIR at the nearest police station if there is injury, death, or significant property damage. Get a copy.',
            ),
            ClaimStep(
              title: '4. Notify the insurer',
              description: 'Call the insurer within 48 hours. Mention the policy number, date, time, and location of the accident.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '5. Submit claim documents',
              description: 'Submit all documents to the insurer. The insurer will arrange a surveyor to assess damage.',
              documents: [
                'FIR copy (if applicable)',
                'Claim form (duly filled)',
                'Policy copy',
                'RC book copy',
                'Driving license copy',
                'Photos of damage',
                'Repair estimate from garage',
              ],
            ),
          ],
          requiredDocuments: [
            'FIR copy (if applicable)',
            'Claim form',
            'Policy copy',
            'RC book copy',
            'Driving license copy',
            'Photos of damage',
            'Repair estimate',
          ],
          helpline: helpline,
          email: email,
        );

      case 'death':
      case 'life':
        return ClaimGuide(
          incidentType: 'death',
          title: 'Life Insurance Death Claim',
          steps: [
            ClaimStep(
              title: '1. Notify the insurer',
              description: 'The nominee or beneficiary should call the insurer to intimate the claim. Get the claim reference number.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '2. Collect documents',
              description: 'Gather all required documents. The insurer will provide a claim form and a list of requirements.',
              documents: [
                'Death certificate (original)',
                'Claim form (duly filled)',
                'Policy document',
                'Nominee\'s ID proof',
                'Deceased\'s ID proof',
                'Bank details of nominee',
                'Medical records (if applicable)',
              ],
            ),
            ClaimStep(
              title: '3. Submit claim',
              description: 'Submit all documents to the insurer. The insurer may assign an investigator for early death claims (within 2 years of policy).',
            ),
            ClaimStep(
              title: '4. Receive payout',
              description: 'Death claims are typically processed within 30 days of receiving all documents. The payout goes to the nominee\'s bank account.',
              contactInfo: helpline,
            ),
          ],
          requiredDocuments: [
            'Death certificate (original)',
            'Claim form',
            'Policy document',
            'Nominee\'s ID proof',
            'Deceased\'s ID proof',
            'Bank details of nominee',
          ],
          helpline: helpline,
          email: email,
          notes: 'Life insurance death claims are generally straightforward if the policy is active and all documents are in order.',
        );

      default:
        return ClaimGuide(
          incidentType: incidentType,
          title: 'General Insurance Claim',
          steps: [
            ClaimStep(
              title: '1. Notify the insurer',
              description: 'Call the insurer to report the incident. Keep your policy number ready.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '2. Document everything',
              description: 'Take photos, keep receipts, and gather all relevant documents.',
              documents: ['Photos', 'Receipts', 'Police report (if applicable)'],
            ),
            ClaimStep(
              title: '3. Submit claim form',
              description: 'Fill out the claim form provided by the insurer and submit with all supporting documents.',
              documents: ['Claim form', 'Policy copy', 'Photo ID', 'Supporting documents'],
            ),
          ],
          requiredDocuments: ['Claim form', 'Policy copy', 'Photo ID'],
          helpline: helpline,
          email: email,
        );
    }
  }
}