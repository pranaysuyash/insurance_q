import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/qa_models.dart';
import '../models/document_model.dart';
import '../providers/document_providers.dart';
import '../services/app_state_store.dart';
import '../utils/policy_type.dart';
import '../utils/ref_state.dart';

const _qaHistoryBoxKey = 'qa_history';

final isLoadingProvider = refStateProvider<bool>(false);
final currentAnswerProvider = refStateProvider<QaAnswer?>(null);

final List<QuestionCategory> _categories = [
  QuestionCategory(
      id: 'Policy Basics', name: 'Policy Basics', icon: Icons.fact_check),
  QuestionCategory(
      id: 'Coverage Details', name: 'Coverage Details', icon: Icons.shield),
  QuestionCategory(
      id: 'Premiums & Payments',
      name: 'Premiums & Payments',
      icon: Icons.payments),
  QuestionCategory(
      id: 'Claims', name: 'Claims', icon: Icons.fact_check_outlined),
  QuestionCategory(
      id: 'Exclusions & Limitations',
      name: 'Exclusions & Limitations',
      icon: Icons.block),
  QuestionCategory(
      id: 'Benefits', name: 'Benefits', icon: Icons.health_and_safety),
];

/// Resolves the PolicyType of the currently selected document.
final selectedDocumentPolicyTypeProvider =
    Provider<PolicyType?>((ref) {
  final selectedDocId = ref.watch(selectedDocumentProvider);
  if (selectedDocId == null) return null;
  final documents = ref.watch(documentsProvider).asData?.value ?? [];
  final doc = documents.cast<InsuranceDocument?>().firstWhere(
        (d) => d?.id == selectedDocId,
        orElse: () => null,
      );
  if (doc == null) return null;
  return classifyPolicyType(doc.documentType);
});

/// Resolves the PolicyType of the first document when no document is selected.
/// Used as a fallback when the user hasn't explicitly selected one.
final activePolicyTypeProvider = Provider<PolicyType?>((ref) {
  final explicit = ref.watch(selectedDocumentPolicyTypeProvider);
  if (explicit != null) return explicit;
  // Fallback: infer from the first available document
  final documents = ref.watch(documentsProvider).asData?.value ?? [];
  if (documents.isEmpty) return null;
  return classifyPolicyType(documents.first.documentType);
});

/// All standard questions, both generic and type-specific.
final standardQuestionsProvider = Provider<List<StandardQuestion>>((ref) {
  return [
    // ── Generic questions (shown for all policy types) ──
    StandardQuestion(
      id: 'pb1',
      text: 'What is my policy number?',
      category: 'Policy Basics',
      icon: Icons.badge,
    ),
    StandardQuestion(
      id: 'pb2',
      text: 'When does my policy start and end?',
      category: 'Policy Basics',
      icon: Icons.date_range,
    ),
    StandardQuestion(
      id: 'pb3',
      text: 'Who is the insurer for this policy?',
      category: 'Policy Basics',
      icon: Icons.business,
    ),
    StandardQuestion(
      id: 'pb4',
      text: 'Who are the insured parties on this policy?',
      category: 'Policy Basics',
      icon: Icons.people,
    ),
    StandardQuestion(
      id: 'pb5',
      text: 'What type of insurance is this?',
      category: 'Policy Basics',
      icon: Icons.category,
    ),
    StandardQuestion(
      id: 'cd1',
      text: 'What is the total coverage amount?',
      category: 'Coverage Details',
      icon: Icons.attach_money,
    ),
    StandardQuestion(
      id: 'cd2',
      text: 'What is my deductible?',
      category: 'Coverage Details',
      icon: Icons.money_off,
    ),
    StandardQuestion(
      id: 'cd3',
      text: 'What is the out-of-pocket maximum?',
      category: 'Coverage Details',
      icon: Icons.account_balance_wallet,
    ),
    StandardQuestion(
      id: 'cd4',
      text: 'What is the coverage for hospital stays?',
      category: 'Coverage Details',
      icon: Icons.local_hospital,
    ),
    StandardQuestion(
      id: 'cd5',
      text: 'What is the coverage for prescription drugs?',
      category: 'Coverage Details',
      icon: Icons.medication,
    ),
    StandardQuestion(
      id: 'pp1',
      text: 'What is my premium amount?',
      category: 'Premiums & Payments',
      icon: Icons.payment,
    ),
    StandardQuestion(
      id: 'pp2',
      text: 'How often do I need to pay my premium?',
      category: 'Premiums & Payments',
      icon: Icons.calendar_today,
    ),
    StandardQuestion(
      id: 'pp3',
      text: 'When is my next premium due?',
      category: 'Premiums & Payments',
      icon: Icons.event,
    ),
    StandardQuestion(
      id: 'cl1',
      text: 'How do I file a claim?',
      category: 'Claims',
      icon: Icons.file_present,
    ),
    StandardQuestion(
      id: 'cl2',
      text: 'What is the claims process?',
      category: 'Claims',
      icon: Icons.account_tree,
    ),
    StandardQuestion(
      id: 'cl3',
      text: 'What documentation is needed for claims?',
      category: 'Claims',
      icon: Icons.description,
    ),
    StandardQuestion(
      id: 'el1',
      text: 'What is not covered by this policy?',
      category: 'Exclusions & Limitations',
      icon: Icons.block,
    ),
    StandardQuestion(
      id: 'el2',
      text: 'Are there any waiting periods?',
      category: 'Exclusions & Limitations',
      icon: Icons.hourglass_empty,
    ),
    StandardQuestion(
      id: 'el3',
      text: 'Are there any pre-existing condition limitations?',
      category: 'Exclusions & Limitations',
      icon: Icons.history,
    ),
    StandardQuestion(
      id: 'bn1',
      text: 'Does this policy include dental coverage?',
      category: 'Benefits',
      icon: Icons.medical_services,
    ),
    StandardQuestion(
      id: 'bn2',
      text: 'Does this policy include vision coverage?',
      category: 'Benefits',
      icon: Icons.visibility,
    ),
    StandardQuestion(
      id: 'bn3',
      text: 'Does this policy cover mental health services?',
      category: 'Benefits',
      icon: Icons.psychology,
    ),

    // ── Type-specific questions ──
    // Health (10)
    StandardQuestion(
      id: 'h1',
      text: 'What is my room rent cap?',
      category: 'Coverage Details',
      icon: Icons.bed_rounded,
      policyType: PolicyType.health,
    ),
    StandardQuestion(
      id: 'h2',
      text: 'Does this policy cover pre-existing diseases?',
      category: 'Exclusions & Limitations',
      icon: Icons.history_rounded,
      policyType: PolicyType.health,
    ),
    StandardQuestion(
      id: 'h3',
      text: 'What is the co-pay percentage?',
      category: 'Coverage Details',
      icon: Icons.percent_rounded,
      policyType: PolicyType.health,
    ),
    StandardQuestion(
      id: 'h4',
      text: 'Which network hospitals are covered?',
      category: 'Coverage Details',
      icon: Icons.local_hotel_rounded,
      policyType: PolicyType.health,
    ),
    StandardQuestion(
      id: 'h5',
      text: 'What is the maternity cover waiting period?',
      category: 'Exclusions & Limitations',
      icon: Icons.child_friendly_rounded,
      policyType: PolicyType.health,
    ),
    StandardQuestion(
      id: 'h6',
      text: 'Is there a cumulative bonus / no claim bonus?',
      category: 'Benefits',
      icon: Icons.trending_up_rounded,
      policyType: PolicyType.health,
    ),
    StandardQuestion(
      id: 'h7',
      text: 'What day care procedures are covered?',
      category: 'Coverage Details',
      icon: Icons.access_time_rounded,
      policyType: PolicyType.health,
    ),
    StandardQuestion(
      id: 'h8',
      text: 'Is ambulance cover included?',
      category: 'Benefits',
      icon: Icons.local_hospital_rounded,
      policyType: PolicyType.health,
    ),
    StandardQuestion(
      id: 'h9',
      text: 'Does this policy cover health checkups?',
      category: 'Benefits',
      icon: Icons.favorite_border_rounded,
      policyType: PolicyType.health,
    ),
    StandardQuestion(
      id: 'h10',
      text: 'Does this policy cover critical illnesses?',
      category: 'Coverage Details',
      icon: Icons.monitor_heart_outlined,
      policyType: PolicyType.health,
    ),

    // Auto / Motor (10)
    StandardQuestion(
      id: 'a1',
      text: 'What is the Insured Declared Value (IDV) of my vehicle?',
      category: 'Coverage Details',
      icon: Icons.account_balance_rounded,
      policyType: PolicyType.auto,
    ),
    StandardQuestion(
      id: 'a2',
      text: 'What is my No Claim Bonus (NCB) percentage?',
      category: 'Coverage Details',
      icon: Icons.trending_up_rounded,
      policyType: PolicyType.auto,
    ),
    StandardQuestion(
      id: 'a3',
      text: 'Is this a comprehensive or third party only policy?',
      category: 'Policy Basics',
      icon: Icons.category_rounded,
      policyType: PolicyType.auto,
    ),
    StandardQuestion(
      id: 'a4',
      text: 'What add-on covers are included?',
      category: 'Coverage Details',
      icon: Icons.extension_rounded,
      policyType: PolicyType.auto,
    ),
    StandardQuestion(
      id: 'a5',
      text: 'Where is my vehicle covered geographically?',
      category: 'Coverage Details',
      icon: Icons.public_rounded,
      policyType: PolicyType.auto,
    ),
    StandardQuestion(
      id: 'a6',
      text: 'Is personal accident cover for the owner included?',
      category: 'Coverage Details',
      icon: Icons.person_rounded,
      policyType: PolicyType.auto,
    ),
    StandardQuestion(
      id: 'a7',
      text: 'What is the own damage premium amount?',
      category: 'Premiums & Payments',
      icon: Icons.payments_rounded,
      policyType: PolicyType.auto,
    ),
    StandardQuestion(
      id: 'a8',
      text: 'What is my vehicle engine capacity (CC)?',
      category: 'Policy Basics',
      icon: Icons.speed_rounded,
      policyType: PolicyType.auto,
    ),
    StandardQuestion(
      id: 'a9',
      text: 'Is zero depreciation or engine protector cover included?',
      category: 'Benefits',
      icon: Icons.shield_rounded,
      policyType: PolicyType.auto,
    ),
    StandardQuestion(
      id: 'a10',
      text: 'What is the validity period of this motor policy?',
      category: 'Policy Basics',
      icon: Icons.date_range_rounded,
      policyType: PolicyType.auto,
    ),

    // Life (10)
    StandardQuestion(
      id: 'l1',
      text: 'Who is the life assured and nominee?',
      category: 'Policy Basics',
      icon: Icons.favorite_rounded,
      policyType: PolicyType.life,
    ),
    StandardQuestion(
      id: 'l2',
      text: 'What is the sum assured / death benefit?',
      category: 'Coverage Details',
      icon: Icons.account_balance_rounded,
      policyType: PolicyType.life,
    ),
    StandardQuestion(
      id: 'l3',
      text: 'What is the policy term in years?',
      category: 'Policy Basics',
      icon: Icons.timeline_rounded,
      policyType: PolicyType.life,
    ),
    StandardQuestion(
      id: 'l4',
      text: 'What riders are attached to this life policy?',
      category: 'Benefits',
      icon: Icons.extension_rounded,
      policyType: PolicyType.life,
    ),
    StandardQuestion(
      id: 'l5',
      text: 'What is the premium paying term?',
      category: 'Premiums & Payments',
      icon: Icons.payments_rounded,
      policyType: PolicyType.life,
    ),
    StandardQuestion(
      id: 'l6',
      text: 'When does the policy mature?',
      category: 'Policy Basics',
      icon: Icons.event_rounded,
      policyType: PolicyType.life,
    ),
    StandardQuestion(
      id: 'l7',
      text: 'Is there an accidental death benefit included?',
      category: 'Benefits',
      icon: Icons.shield_rounded,
      policyType: PolicyType.life,
    ),
    StandardQuestion(
      id: 'l8',
      text: 'What is the suicide exclusion period?',
      category: 'Exclusions & Limitations',
      icon: Icons.block_rounded,
      policyType: PolicyType.life,
    ),
    StandardQuestion(
      id: 'l9',
      text: 'What is the free look period?',
      category: 'Policy Basics',
      icon: Icons.remove_red_eye_rounded,
      policyType: PolicyType.life,
    ),
    StandardQuestion(
      id: 'l10',
      text: 'Is there a terminal illness benefit?',
      category: 'Benefits',
      icon: Icons.medical_services_rounded,
      policyType: PolicyType.life,
    ),

    // Home (10)
    StandardQuestion(
      id: 'ho1',
      text: 'What is the building sum insured?',
      category: 'Coverage Details',
      icon: Icons.business_rounded,
      policyType: PolicyType.home,
    ),
    StandardQuestion(
      id: 'ho2',
      text: 'What perils are covered (fire, flood, earthquake)?',
      category: 'Coverage Details',
      icon: Icons.bolt_rounded,
      policyType: PolicyType.home,
    ),
    StandardQuestion(
      id: 'ho3',
      text: 'What is the insured property address?',
      category: 'Policy Basics',
      icon: Icons.location_on_rounded,
      policyType: PolicyType.home,
    ),
    StandardQuestion(
      id: 'ho4',
      text: 'Are contents / belongings covered under this policy?',
      category: 'Coverage Details',
      icon: Icons.inventory_2_rounded,
      policyType: PolicyType.home,
    ),
    StandardQuestion(
      id: 'ho5',
      text: 'Is there an underinsurance or average clause?',
      category: 'Exclusions & Limitations',
      icon: Icons.warning_rounded,
      policyType: PolicyType.home,
    ),
    StandardQuestion(
      id: 'ho6',
      text: 'What is the deductible or excess amount?',
      category: 'Coverage Details',
      icon: Icons.money_off_rounded,
      policyType: PolicyType.home,
    ),
    StandardQuestion(
      id: 'ho7',
      text: 'What type of structure is insured (apartment, house)?',
      category: 'Policy Basics',
      icon: Icons.home_rounded,
      policyType: PolicyType.home,
    ),
    StandardQuestion(
      id: 'ho8',
      text: 'Is the property owner-occupied or rented out?',
      category: 'Policy Basics',
      icon: Icons.people_rounded,
      policyType: PolicyType.home,
    ),
    StandardQuestion(
      id: 'ho9',
      text: 'What is the rebuild cost or reinstatement value?',
      category: 'Coverage Details',
      icon: Icons.construction_rounded,
      policyType: PolicyType.home,
    ),
    StandardQuestion(
      id: 'ho10',
      text: 'What add-on covers are included (jewellery, domestic help)?',
      category: 'Benefits',
      icon: Icons.extension_rounded,
      policyType: PolicyType.home,
    ),

    // Travel (10)
    StandardQuestion(
      id: 't1',
      text: 'What is the trip destination?',
      category: 'Policy Basics',
      icon: Icons.explore_rounded,
      policyType: PolicyType.travel,
    ),
    StandardQuestion(
      id: 't2',
      text: 'What is the trip duration?',
      category: 'Policy Basics',
      icon: Icons.timer_rounded,
      policyType: PolicyType.travel,
    ),
    StandardQuestion(
      id: 't3',
      text: 'What medical expenses cover is included?',
      category: 'Coverage Details',
      icon: Icons.medical_services_rounded,
      policyType: PolicyType.travel,
    ),
    StandardQuestion(
      id: 't4',
      text: 'Is medical evacuation or repatriation covered?',
      category: 'Coverage Details',
      icon: Icons.airport_shuttle_rounded,
      policyType: PolicyType.travel,
    ),
    StandardQuestion(
      id: 't5',
      text: 'Is trip cancellation or interruption covered?',
      category: 'Coverage Details',
      icon: Icons.cancel_schedule_send_rounded,
      policyType: PolicyType.travel,
    ),
    StandardQuestion(
      id: 't6',
      text: 'What is the baggage loss cover amount?',
      category: 'Coverage Details',
      icon: Icons.luggage_rounded,
      policyType: PolicyType.travel,
    ),
    StandardQuestion(
      id: 't7',
      text: 'Is this single trip or annual multi-trip cover?',
      category: 'Policy Basics',
      icon: Icons.category_rounded,
      policyType: PolicyType.travel,
    ),
    StandardQuestion(
      id: 't8',
      text: 'Does this travel policy cover pre-existing conditions?',
      category: 'Exclusions & Limitations',
      icon: Icons.healing_rounded,
      policyType: PolicyType.travel,
    ),
    StandardQuestion(
      id: 't9',
      text: 'Are adventure sports covered under this policy?',
      category: 'Coverage Details',
      icon: Icons.downhill_skiing_rounded,
      policyType: PolicyType.travel,
    ),
    StandardQuestion(
      id: 't10',
      text: 'What is the 24x7 emergency assistance number?',
      category: 'Policy Basics',
      icon: Icons.phone_in_talk_rounded,
      policyType: PolicyType.travel,
    ),

    // Marine / Cargo (5)
    StandardQuestion(
      id: 'm1',
      text: 'What cargo is insured and what is its value?',
      category: 'Coverage Details',
      icon: Icons.inventory_2_rounded,
      policyType: PolicyType.marine,
    ),
    StandardQuestion(
      id: 'm2',
      text: 'Which ports or locations are covered?',
      category: 'Policy Basics',
      icon: Icons.map_rounded,
      policyType: PolicyType.marine,
    ),
    StandardQuestion(
      id: 'm3',
      text: 'What Institute Cargo Clauses apply?',
      category: 'Coverage Details',
      icon: Icons.description_rounded,
      policyType: PolicyType.marine,
    ),
    StandardQuestion(
      id: 'm4',
      text: 'Is war risk or strikes coverage included?',
      category: 'Exclusions & Limitations',
      icon: Icons.gpp_maybe_rounded,
      policyType: PolicyType.marine,
    ),
    StandardQuestion(
      id: 'm5',
      text: 'What transport mode or vessel is covered?',
      category: 'Policy Basics',
      icon: Icons.directions_boat_rounded,
      policyType: PolicyType.marine,
    ),
  ];
});

/// Returns questions filtered to match the currently active policy type.
/// Generic questions (with null policyType) are always included.
final filteredStandardQuestionsProvider =
    Provider<List<StandardQuestion>>((ref) {
  final allQuestions = ref.watch(standardQuestionsProvider);
  final policyType = ref.watch(activePolicyTypeProvider);

  if (policyType == null) {
    // No document selected or no documents — show only generic questions
    return allQuestions.where((q) => q.policyType == null).toList();
  }

  return allQuestions.where((q) {
    // Include generic questions and questions specific to this policy type
    return q.policyType == null || q.policyType == policyType;
  }).toList();
});

final questionCategoriesProvider = Provider<List<QuestionCategory>>((ref) {
  return _categories;
});

final selectedDocumentProvider = refStateProvider<String?>(null);

final qaHistoryProvider = NotifierProvider<QaHistoryNotifier, List<QaPair>>(
  QaHistoryNotifier.new);

class QaHistoryNotifier extends Notifier<List<QaPair>> {
  @override
  List<QaPair> build() {
    try {
      if (Hive.isBoxOpen(AppStateStore.boxName)) {
        final box = Hive.box(AppStateStore.boxName);
        final raw = box.get(_qaHistoryBoxKey) as List<dynamic>?;
        if (raw != null) {
          return raw
              .map((item) => QaPair.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading QA history: $e');
    }
    return [];
  }

  void addItem(String question, QaAnswer answer) {
    final newItem = QaPair(
      question: question,
      answer: answer,
      timestamp: DateTime.now(),
    );

    state = [newItem, ...state];

    if (state.length > 50) {
      state = state.take(50).toList();
    }

    _saveHistory();
  }

  Future<void> _saveHistory() async {
    try {
      final box = Hive.box(AppStateStore.boxName);
      final serialized = state.map((item) => item.toJson()).toList();
      await box.put(_qaHistoryBoxKey, serialized);
    } catch (e) {
      debugPrint('Error saving QA history: $e');
    }
  }

  void clearHistory() {
    state = [];
    _saveHistory();
  }
}
