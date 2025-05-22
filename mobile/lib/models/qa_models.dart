import 'package:flutter/material.dart';

class QuestionCategory {
  final String id;
  final String name;
  final IconData icon;
  
  const QuestionCategory({
    required this.id,
    required this.name,
    this.icon = Icons.help_outline,
  });
}

class StandardQuestion {
  final String id;
  final String text;
  final String category;
  final IconData icon;
  
  StandardQuestion({
    required this.id,
    required this.text,
    required this.category,
    required this.icon,
  });
}

class QaAnswer {
  final String text;
  final List<QaSource> sources;
  final DateTime timestamp;
  final String documentId;
  final String question;
  
  QaAnswer({
    required this.text,
    required this.sources,
    required this.timestamp,
    required this.documentId,
    required this.question,
  });
  
  String get query => question;
  
  factory QaAnswer.fromJson(Map<String, dynamic> json) {
    return QaAnswer(
      text: json['answer'] ?? '',
      sources: (json['sources'] as List?)
          ?.map((source) => QaSource.fromJson(source))
          .toList() ?? [],
      timestamp: DateTime.now(),
      documentId: json['document_id'] ?? '',
      question: json['query'] ?? '',
    );
  }
}

class QaSource {
  final String documentId;
  final int? pageNumber;
  final String text;
  final double score;
  
  QaSource({
    required this.documentId,
    this.pageNumber,
    required this.text,
    required this.score,
  });
  
  factory QaSource.fromJson(Map<String, dynamic> json) {
    return QaSource(
      documentId: json['document_id'] ?? '',
      pageNumber: json['page_number'] ?? json['page'],
      text: json['text'] ?? '',
      score: (json['score'] is num) ? (json['score'] as num).toDouble() : 0.0,
    );
  }
}

class QaPair {
  final String question;
  final QaAnswer answer;
  final DateTime timestamp;
  
  QaPair({
    required this.question,
    required this.answer,
    required this.timestamp,
  });
} 