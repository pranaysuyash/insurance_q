import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/qa_models.dart';

final standardQuestionsProvider = Provider<List<StandardQuestion>>((ref) {
  return [
    // Policy Basics
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
    
    // Coverage Details
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
    
    // Premiums & Payments
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
    
    // Claims
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
    
    // Exclusions & Limitations
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
    
    // Benefits
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
  ];
});

final questionCategoriesProvider = Provider<List<String>>((ref) {
  final questions = ref.watch(standardQuestionsProvider);
  return questions
      .map((q) => q.category)
      .toSet()
      .toList();
});

final selectedDocumentProvider = StateProvider<String?>((ref) => null);

class QaHistoryItem {
  final String question;
  final QaAnswer answer;
  final DateTime timestamp;
  
  QaHistoryItem({
    required this.question,
    required this.answer,
    required this.timestamp,
  });
}

final qaHistoryProvider = StateNotifierProvider<QaHistoryNotifier, List<QaHistoryItem>>((ref) {
  return QaHistoryNotifier();
});

class QaHistoryNotifier extends StateNotifier<List<QaHistoryItem>> {
  QaHistoryNotifier() : super([]);
  
  void addItem(String question, QaAnswer answer) {
    state = [
      QaHistoryItem(
        question: question,
        answer: answer,
        timestamp: DateTime.now(),
      ),
      ...state,
    ];
  }
  
  void clearHistory() {
    state = [];
  }
} 