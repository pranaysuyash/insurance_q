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

  PolicyExtractionService(this._queryService)
      : _dio = DocumentService.authenticatedDio;

  Box get _box => Hive.box('app_state_box');

  Future<PolicySummary?> extractSummary(
      String documentId, String documentType) async {
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
      debugPrint(
          'Backend summary fetch failed, falling back to query-based extraction: $e');
    }

    // Fallback: query-based extraction (13 sequential questions)
    return _extractViaQueries(documentId, documentType);
  }

  Future<PolicySummary?> _extractViaQueries(
      String documentId, String documentType) async {
    try {
      final policyNumber = await _ask(documentId,
          'What is the policy number shown in this document? Answer with just the number.');
      final insurer = await _ask(documentId,
          'What is the name of the insurance company? Answer with just the company name.');
      final helpline = await _ask(documentId,
          'What is the claims helpline or customer care phone number? Answer with just the number.');
      final email = await _ask(documentId,
          'What is the customer care email address? Answer with just the email, or say "not listed".');
      final coverage = await _ask(documentId,
          'What is the total coverage amount or sum insured? Answer with just the number.');
      final deductible = await _ask(documentId,
          'What is the deductible amount? Answer with just the number, or say "not applicable".');
      final premium = await _ask(documentId,
          'What is the premium amount? Answer with just the number.');
      final premiumFreq = await _ask(documentId,
          'How often is the premium paid? Answer with: monthly, quarterly, half-yearly, or annually.');
      final startDate = await _ask(documentId,
          'What is the policy start date? Answer in DD-MM-YYYY format.');
      final endDate = await _ask(documentId,
          'What is the policy end date or expiry date? Answer in DD-MM-YYYY format.');
      final benefits = await _ask(documentId,
          'List the top 5 key benefits covered by this policy. One per line, brief.');
      final exclusions = await _ask(documentId,
          'List the top 5 exclusions or things not covered. One per line, brief.');
      final waiting = await _ask(documentId,
          'List any waiting periods mentioned. One per line, brief.');

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
      final result =
          await _queryService.queryDocument(question, documentId: documentId);
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
      return list
          .map((s) => PolicySummary.fromJsonString(s as String))
          .toList();
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
    final policyTypes =
        summaries.map((s) => classifyPolicyType(s.documentType)).toSet();

    if (!policyTypes.contains(PolicyType.health)) {
      gaps.add(CoverageGap(
        category: 'Health Insurance',
        description: 'No health policy was found in the uploaded workspace.',
        severity: 'info',
        evidenceStatus: CoverageEvidenceStatus.notFoundInWorkspace,
        recommendation:
            'If you have a health policy, upload it or review this with your insurer.',
      ));
    }
    if (!policyTypes.contains(PolicyType.life)) {
      gaps.add(CoverageGap(
        category: 'Life Insurance',
        description: 'No life policy was found in the uploaded workspace.',
        severity: 'info',
        evidenceStatus: CoverageEvidenceStatus.notFoundInWorkspace,
        recommendation:
            'If you have a life policy, upload it or review this with your insurer.',
      ));
    }
    if (!policyTypes.contains(PolicyType.auto)) {
      gaps.add(CoverageGap(
        category: 'Auto Insurance',
        description: 'No auto policy was found in the uploaded workspace.',
        severity: 'info',
        evidenceStatus: CoverageEvidenceStatus.notFoundInWorkspace,
        recommendation:
            'If you have an auto policy, upload it or review this with your insurer.',
      ));
    }
    for (final s in summaries) {
      if (classifyPolicyType(s.documentType) == PolicyType.health) {
        if (!s.keyBenefits.any((b) => b.toLowerCase().contains('maternity'))) {
          gaps.add(CoverageGap(
            category: 'Maternity Coverage',
            description:
                'Maternity coverage was not verified in the extracted benefits for ${s.insurer ?? 'this policy'}.',
            severity: 'info',
            evidenceStatus: CoverageEvidenceStatus.notVerified,
            sourceDocumentIds: [s.documentId],
            recommendation:
                'Review the source policy wording or ask the insurer about maternity coverage.',
          ));
        }
        if (!s.keyBenefits.any((b) =>
            b.toLowerCase().contains('critical illness') ||
            b.toLowerCase().contains('critical'))) {
          gaps.add(CoverageGap(
            category: 'Critical Illness',
            description:
                'Critical illness coverage was not verified in the extracted benefits for ${s.insurer ?? 'this policy'}.',
            severity: 'info',
            evidenceStatus: CoverageEvidenceStatus.notVerified,
            sourceDocumentIds: [s.documentId],
            recommendation:
                'Review the source policy wording or ask the insurer about critical illness coverage.',
          ));
        }
      }
      if (s.endDate != null && s.isExpiringSoon && !s.isExpired) {
        gaps.add(CoverageGap(
          category: 'Policy Expiry',
          description:
              'Your ${s.documentType} from ${s.insurer ?? 'Unknown'} expires in ${s.daysUntilExpiry} days (${s.formattedExpiryDate}).',
          severity: 'high',
          evidenceStatus: CoverageEvidenceStatus.expiring,
          sourceDocumentIds: [s.documentId],
          sourceFieldNames: ['policy_end_date'],
          recommendation:
              'Review the policy details and contact the insurer if you need clarification before the date.',
        ));
      }
      if (s.isExpired) {
        gaps.add(CoverageGap(
          category: 'Expired Policy',
          description:
              'Your ${s.documentType} from ${s.insurer ?? 'Unknown'} expired on ${s.formattedExpiryDate}.',
          severity: 'high',
          evidenceStatus: CoverageEvidenceStatus.expired,
          sourceDocumentIds: [s.documentId],
          sourceFieldNames: ['policy_end_date'],
          recommendation:
              'Review the policy details and contact the insurer to confirm the current status.',
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
              description:
                  'Call the insurer within 24-48 hours of hospitalization. For cashless claims, inform the network hospital.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '2. Get pre-authorization (cashless)',
              description:
                  'If using a network hospital, the hospital will send a pre-authorization request to the insurer. Keep your policy number and ID ready.',
              documents: ['Policy number', 'Photo ID', 'Aadhaar card'],
            ),
            ClaimStep(
              title: '3. Submit claim documents',
              description:
                  'After discharge, submit all documents to the insurer (for reimbursement) or the hospital handles it (for cashless).',
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
              description:
                  'Use the insurer\'s app or helpline to track claim status. Claims are typically processed within 7-30 days.',
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
          notes:
              'For cashless claims at network hospitals, the hospital handles most paperwork. For reimbursement, you submit documents to the insurer.',
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
              description:
                  'Move to a safe location. Call emergency services (112) if anyone is injured. Do not admit fault at the scene.',
            ),
            ClaimStep(
              title: '2. Document the scene',
              description:
                  'Take photos of all vehicles, damage, license plates, and the accident scene. Note time, location, and weather conditions.',
              documents: [
                'Photos of damage',
                'Photos of scene',
                'Other driver\'s details',
                'Witness contacts (if any)'
              ],
            ),
            ClaimStep(
              title: '3. File an FIR if needed',
              description:
                  'File an FIR at the nearest police station if there is injury, death, or significant property damage. Get a copy.',
            ),
            ClaimStep(
              title: '4. Notify the insurer',
              description:
                  'Call the insurer within 48 hours. Mention the policy number, date, time, and location of the accident.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '5. Submit claim documents',
              description:
                  'Submit all documents to the insurer. The insurer will arrange a surveyor to assess damage.',
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
              description:
                  'The nominee or beneficiary should call the insurer to intimate the claim. Get the claim reference number.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '2. Collect documents',
              description:
                  'Gather all required documents. The insurer will provide a claim form and a list of requirements.',
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
              description:
                  'Submit all documents to the insurer. The insurer may assign an investigator for early death claims (within 2 years of policy).',
            ),
            ClaimStep(
              title: '4. Receive payout',
              description:
                  'Death claims are typically processed within 30 days of receiving all documents. The payout goes to the nominee\'s bank account.',
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
          notes:
              'Life insurance death claims are generally straightforward if the policy is active and all documents are in order.',
        );

      // ── Home insurance claims ──
      case 'fire':
      case 'home':
        return ClaimGuide(
          incidentType: 'fire',
          title: 'Home Insurance — Fire & Allied Perils Claim',
          steps: [
            ClaimStep(
              title: '1. Ensure safety first',
              description:
                  'Evacuate the premises immediately. Call the fire department (101) and emergency services (112) if anyone is injured. Do not re-enter until declared safe.',
            ),
            ClaimStep(
              title: '2. Document the damage',
              description:
                  'Once the premises are safe, take photos and videos of all damaged areas — structure, contents, appliances. Make a detailed inventory of damaged items with estimated value and purchase year.',
              documents: [
                'Photos/videos of damage',
                'Inventory of damaged items',
                'Purchase receipts (if available)',
                'Fire brigade report copy',
              ],
            ),
            ClaimStep(
              title: '3. Notify the insurer',
              description:
                  'Call the insurer within 48 hours to report the fire loss. Share your policy number and preliminary damage assessment. The insurer will assign a surveyor to assess the loss onsite.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '4. Submit formal claim',
              description:
                  'Complete the claim form and submit all supporting documents. The surveyor report will determine the claim amount based on sum insured, depreciation, and policy terms.',
              documents: [
                'Claim form (duly filled)',
                'Policy copy',
                'Fire brigade report',
                'Police report (if suspicious)',
                'Inventory of damaged items',
                'Photos/videos of damage',
                'Repair estimates (if applicable)',
                'Proof of ownership (for valuables)',
              ],
            ),
          ],
          requiredDocuments: [
            'Claim form',
            'Policy copy',
            'Fire brigade report',
            'Inventory of damaged items',
            'Photos/videos of damage',
          ],
          helpline: helpline,
          email: email,
          notes:
              'Home insurance claims typically require a surveyor visit. Standard fire claims are processed within 15-45 days. Keep all communication with the surveyor in writing.',
        );

      case 'burglary':
      case 'theft':
        return ClaimGuide(
          incidentType: 'burglary',
          title: 'Home Insurance — Burglary & Theft Claim',
          steps: [
            ClaimStep(
              title: '1. File a police report',
              description:
                  'Do not disturb the scene. File an FIR at the nearest police station immediately. Get a copy of the FIR — it is the most critical document for your claim.',
              documents: ['FIR copy'],
            ),
            ClaimStep(
              title: '2. Document the scene',
              description:
                  'Take photos and videos of the point of entry, disturbed areas, and any evidence of forced entry. Make a detailed list of stolen items with descriptions, estimated value, and purchase details.',
              documents: [
                'Photos/videos of the scene',
                'List of stolen items with descriptions',
                'Purchase receipts (if available)',
              ],
            ),
            ClaimStep(
              title: '3. Notify the insurer',
              description:
                  'Call the insurer within 24-48 hours to report the theft. Provide the FIR number and preliminary loss assessment. The insurer will guide you on next steps and may assign a surveyor.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '4. Submit claim documents',
              description:
                  'Complete the claim form and submit with supporting documents. The insurer will process the claim based on policy terms. Claims for jewellery and electronics require proof of ownership.',
              documents: [
                'Claim form (duly filled)',
                'Policy copy',
                'FIR copy',
                'Inventory of stolen items',
                'Proof of ownership (receipts, photos)',
                'Photos/videos of the scene',
                'ID proof',
              ],
            ),
          ],
          requiredDocuments: [
            'Claim form',
            'Policy copy',
            'FIR copy',
            'Inventory of stolen items',
            'Proof of ownership',
          ],
          helpline: helpline,
          email: email,
          notes:
              'Burglary claims require a valid FIR. Claims without FIR are rarely accepted. Jewellery and cash have sub-limits — check your policy schedule. Processing time: 21-45 days.',
        );

      case 'flood':
      case 'earthquake':
      case 'natural disaster':
        return ClaimGuide(
          incidentType: 'natural disaster',
          title: 'Home Insurance — Natural Disaster Claim',
          steps: [
            ClaimStep(
              title: '1. Ensure safety & document',
              description:
                  'Wait for official all-clear before entering the premises. Take photos and videos of all damage. Make a detailed inventory of damaged structure and contents.',
              documents: [
                'Photos/videos of damage',
                'Inventory of damaged items',
              ],
            ),
            ClaimStep(
              title: '2. Notify the insurer',
              description:
                  'Report the loss to the insurer as soon as possible. Many insurers have special disaster helplines for natural calamities. The insurer will prioritise surveyor assignment in disaster zones.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '3. Submit claim documents',
              description:
                  'Complete the claim form and submit with supporting documents. The surveyor will assess damage within the disaster area. Government disaster declaration may expedite claims.',
              documents: [
                'Claim form (duly filled)',
                'Policy copy',
                'Photos/videos of damage',
                'Inventory of damaged items',
                'Repair estimates',
                'Local authority damage report (if available)',
              ],
            ),
          ],
          requiredDocuments: [
            'Claim form',
            'Policy copy',
            'Photos/videos of damage',
            'Inventory of damaged items',
          ],
          helpline: helpline,
          email: email,
          notes:
              'Flood and earthquake coverage depends on your policy — not all home policies include these perils. Check your policy wording. Insurers often set up special processing teams for widespread disasters. Claims may take 30-60 days in disaster zones.',
        );

      // ── Travel insurance claims ──
      case 'medical emergency':
      case 'travel medical':
        return ClaimGuide(
          incidentType: 'medical emergency',
          title: 'Travel Insurance — Medical Emergency Claim',
          steps: [
            ClaimStep(
              title: '1. Contact emergency assistance',
              description:
                  'Call the 24x7 emergency assistance number immediately. They will guide you to an approved medical facility and coordinate with the insurer for direct billing if possible.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '2. Seek medical treatment',
              description:
                  'Visit the recommended hospital or clinic. Keep all original medical records, prescriptions, and bills. For cashless treatment, the assistance company coordinates directly with the hospital.',
              documents: [
                'Medical reports and diagnosis',
                'Prescriptions',
                'Hospital bills (original)',
                'Doctor\'s certificate',
              ],
            ),
            ClaimStep(
              title: '3. Submit claim documents',
              description:
                  'Submit all original documents to the insurer along with the claim form. Many travel insurers accept digital submissions. Keep copies of everything before submitting originals.',
              documents: [
                'Claim form (duly filled)',
                'Policy copy',
                'Medical reports',
                'Hospital bills (original)',
                'Doctor\'s prescription',
                'Travel itinerary / ticket copies',
                'Passport copy (photo page)',
              ],
            ),
            ClaimStep(
              title: '4. Track & follow up',
              description:
                  'Medical claims are usually processed within 7-21 days post-submission. For medical evacuation claims, the assistance company coordinates evacuation logistics directly.',
              contactInfo: helpline,
            ),
          ],
          requiredDocuments: [
            'Claim form',
            'Policy copy',
            'Medical reports',
            'Hospital bills (original)',
            'Passport copy',
            'Travel itinerary',
          ],
          helpline: helpline,
          email: email,
          notes:
              'Always carry the emergency assistance number and policy document while travelling. For cashless treatment, contact the assistance company BEFORE seeking treatment. Medical evacuation is pre-authorised by the assistance company — do not arrange evacuation yourself unless it is an emergency.',
        );

      case 'baggage':
      case 'baggage loss':
      case 'baggage delay':
        return ClaimGuide(
          incidentType: 'baggage',
          title: 'Travel Insurance — Baggage Claim',
          steps: [
            ClaimStep(
              title: '1. Report to the airline',
              description:
                  'Report missing or delayed baggage to the airline\'s baggage counter at the airport BEFORE leaving the arrival area. Get a Property Irregularity Report (PIR) reference number.',
              documents: ['PIR reference number', 'Boarding pass', 'Baggage tag'],
            ),
            ClaimStep(
              title: '2. Document the loss',
              description:
                  'For lost items: make a detailed list with descriptions, brand, age, and estimated value. For delayed baggage: the policy covers essential purchases (toiletries, clothes) — keep all receipts.',
              documents: [
                'List of items (for loss)',
                'Purchase receipts (for valuables)',
                'Receipts for essential purchases (for delay)',
              ],
            ),
            ClaimStep(
              title: '3. Submit claim to insurer',
              description:
                  'Submit the claim form with supporting documents. Baggage delay claims must typically be filed within 21 days of the incident. Baggage loss claims require the airline to confirm the baggage is lost (usually after 21 days of tracing).',
              contactInfo: helpline,
              documents: [
                'Claim form (duly filled)',
                'Policy copy',
                'PIR from airline',
                'Boarding pass and baggage tag',
                'Inventory of lost/delayed items',
                'Receipts for emergency purchases',
              ],
            ),
          ],
          requiredDocuments: [
            'Claim form',
            'Policy copy',
            'PIR from airline',
            'Boarding pass',
            'Inventory of items',
          ],
          helpline: helpline,
          email: email,
          notes:
              'Most travel insurance covers baggage delay after 6-12 hours, and baggage loss up to a sub-limit (typically USD 500-2,000). Check your policy for specific limits. Claims for valuables like electronics require original purchase receipts.',
        );

      case 'trip cancellation':
      case 'cancellation':
        return ClaimGuide(
          incidentType: 'trip cancellation',
          title: 'Travel Insurance — Trip Cancellation Claim',
          steps: [
            ClaimStep(
              title: '1. Check coverage & notify',
              description:
                  'Check the covered reasons for trip cancellation in your policy (illness, death of family member, natural disaster, job loss, visa denial). Notify the insurer and travel provider immediately when you know you must cancel.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '2. Cancel bookings',
              description:
                  'Cancel flights, hotels, and other bookings. Keep all cancellation confirmations and any refund/penalty statements from the travel providers. Do not cancel before checking policy requirements.',
              documents: [
                'Cancellation confirmations',
                'Airline/hotel penalty statements',
                'Refund statements',
              ],
            ),
            ClaimStep(
              title: '3. Submit claim documents',
              description:
                  'Submit the claim form with proof of cancellation, travel itinerary, and evidence for the reason of cancellation (medical certificate, death certificate, employer letter, visa rejection letter).',
              documents: [
                'Claim form (duly filled)',
                'Policy copy',
                'Travel itinerary',
                'Booking confirmations',
                'Cancellation confirmations',
                'Proof of cancellation reason',
                'Passport copy',
              ],
            ),
          ],
          requiredDocuments: [
            'Claim form',
            'Policy copy',
            'Travel itinerary',
            'Cancellation confirmations',
            'Proof of cancellation reason',
          ],
          helpline: helpline,
          email: email,
          notes:
              'Trip cancellation claims are valid only for covered reasons listed in the policy. Disruption due to change of mind or work commitments is generally not covered. Claims should be filed within 30 days of the cancellation event. The claim amount is typically the non-refundable trip cost up to the sum insured.',
        );

      case 'flight delay':
        return ClaimGuide(
          incidentType: 'flight delay',
          title: 'Travel Insurance — Flight Delay Claim',
          steps: [
            ClaimStep(
              title: '1. Get delay documentation',
              description:
                  'Get a written delay certificate from the airline at the airport. Note the scheduled departure time and actual departure time. Most policies require a minimum delay of 6-12 hours.',
              documents: ['Delay certificate from airline', 'Boarding pass'],
            ),
            ClaimStep(
              title: '2. Claim essentials',
              description:
                  'If the policy covers delay, keep receipts for essential expenses incurred due to the delay — meals, refreshments, accommodation (if overnight), and toiletries. Only reasonable expenses are reimbursed.',
              documents: ['Receipts for meals', 'Hotel bill (if overnight)', 'Receipts for essentials'],
            ),
            ClaimStep(
              title: '3. Submit claim to insurer',
              description:
                  'Submit the claim form with the delay certificate, boarding pass, and all receipts. Delay claims typically pay a fixed amount per full 6/12-hour block, up to the policy limit.',
              contactInfo: helpline,
              documents: [
                'Claim form (duly filled)',
                'Policy copy',
                'Delay certificate from airline',
                'Boarding pass',
                'Receipts for expenses',
              ],
            ),
          ],
          requiredDocuments: [
            'Claim form',
            'Delay certificate from airline',
            'Boarding pass',
            'Receipts for expenses',
          ],
          helpline: helpline,
          email: email,
          notes:
              'Flight delay cover typically pays a fixed amount per delay period (e.g., ₹3,000 per 6-hour block, up to ₹15,000 max). Delay is calculated from the scheduled departure time. Some policies also cover missed connection if the delay causes you to miss a connecting flight.',
        );

      case 'travel':
        return ClaimGuide(
          incidentType: 'travel',
          title: 'Travel Insurance — General Claim',
          steps: [
            ClaimStep(
              title: '1. Contact emergency assistance',
              description:
                  'Call the 24x7 emergency assistance number. They can guide you on the claim process specific to your situation — medical, baggage, or cancellation.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '2. Document the incident',
              description:
                  'Get written documentation from relevant authorities (airline, police, hospital). Take photos and keep all receipts and original documents.',
              documents: [
                'Incident documentation',
                'Photos',
                'Receipts',
                'Police report (if applicable)',
              ],
            ),
            ClaimStep(
              title: '3. Submit claim documents',
              description:
                  'Complete the claim form and submit with all supporting documents. Most travel insurers accept digital submissions. Keep copies of everything.',
              documents: [
                'Claim form (duly filled)',
                'Policy copy',
                'Travel itinerary',
                'Passport copy',
                'Supporting documents',
              ],
            ),
          ],
          requiredDocuments: [
            'Claim form',
            'Policy copy',
            'Travel itinerary',
            'Passport copy',
          ],
          helpline: helpline,
          email: email,
          notes:
              'Report incidents to local authorities and get written documentation. Keep original receipts for all expenses. File the claim within the time limit specified in your policy (usually 15-30 days).',
        );

      default:
        return ClaimGuide(
          incidentType: incidentType,
          title: 'General Insurance Claim',
          steps: [
            ClaimStep(
              title: '1. Notify the insurer',
              description:
                  'Call the insurer to report the incident. Keep your policy number ready.',
              contactInfo: helpline,
            ),
            ClaimStep(
              title: '2. Document everything',
              description:
                  'Take photos, keep receipts, and gather all relevant documents.',
              documents: [
                'Photos',
                'Receipts',
                'Police report (if applicable)'
              ],
            ),
            ClaimStep(
              title: '3. Submit claim form',
              description:
                  'Fill out the claim form provided by the insurer and submit with all supporting documents.',
              documents: [
                'Claim form',
                'Policy copy',
                'Photo ID',
                'Supporting documents'
              ],
            ),
          ],
          requiredDocuments: ['Claim form', 'Policy copy', 'Photo ID'],
          helpline: helpline,
          email: email,
        );
    }
  }
}
