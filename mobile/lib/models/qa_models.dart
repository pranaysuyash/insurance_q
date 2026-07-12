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
  final List<Map<String, dynamic>> citations;
  final List<String> missingInformation;
  final List<String> followUpQuestions;
  final double? confidence;
  final double? retrievalConfidence;
  final String? retrievalStrategy;
  final String? embeddingModelUsed;
  final String? error;
  final String? status;

  QaAnswer({
    required this.text,
    required this.sources,
    required this.timestamp,
    required this.documentId,
    required this.question,
    this.citations = const [],
    this.missingInformation = const [],
    this.followUpQuestions = const [],
    this.confidence,
    this.retrievalConfidence,
    this.retrievalStrategy,
    this.embeddingModelUsed,
    this.error,
    this.status,
  });

  String get query => question;

  factory QaAnswer.fromJson(Map<String, dynamic> json) {
    // Handle sources that can be either strings or objects
    List<QaSource> parsedSources = [];
    if (json['sources'] is List) {
      final sourcesList = json['sources'] as List;
      for (var source in sourcesList) {
        String sourceText = '';

        // Extract text content to check for failed processing
        if (source is String) {
          sourceText = source;
        } else if (source is Map<String, dynamic>) {
          sourceText = source['text']?.toString() ?? source.toString();
        } else {
          sourceText = source.toString();
        }

        // Filter out failed document processing sources
        if (sourceText.startsWith('Failed to process PDF:') ||
            sourceText.contains('Failed to process') ||
            sourceText.contains('test_policy.pdf')) {
          debugPrint(
              'Filtering out failed source: ${sourceText.substring(0, 50)}...');
          continue; // Skip this source
        }

        // Filter out sample documents if they contain obvious sample data
        if (sourceText.contains('John Smith') ||
            sourceText.contains('Sarah Johnson') ||
            sourceText.contains('sample_health_policy') ||
            sourceText.contains('sample_auto_policy')) {
          debugPrint('Filtering out sample document source');
          continue; // Skip sample documents
        }

        if (source is String) {
          // Backend returns sources as strings
          parsedSources.add(QaSource(
            documentId: json['document_id'] ?? '',
            text: source,
            score: 1.0,
          ));
        } else if (source is Map<String, dynamic>) {
          // Legacy format with source objects
          parsedSources.add(QaSource.fromJson(source));
        }
      }
    }

    return QaAnswer(
      text: json['answer'] ?? '',
      sources: parsedSources,
      timestamp: DateTime.now(),
      documentId: json['document_id'] ?? '',
      question: json['query'] ?? '',
      citations: json['citations'] is List
          ? List<Map<String, dynamic>>.from(json['citations'] as List)
          : const [],
      missingInformation: json['missing_information'] is List
          ? (json['missing_information'] as List).map((item) => item.toString()).toList()
          : const [],
      followUpQuestions: json['follow_up_questions'] is List
          ? (json['follow_up_questions'] as List).map((item) => item.toString()).toList()
          : const [],
      confidence: json['confidence'] is num ? (json['confidence'] as num).toDouble() : null,
      retrievalConfidence: json['retrieval_confidence'] is num
          ? (json['retrieval_confidence'] as num).toDouble()
          : null,
      retrievalStrategy: json['retrieval_strategy']?.toString(),
      embeddingModelUsed: json['embedding_model_used']?.toString(),
      error: json['error']?.toString(),
      status: json['status']?.toString(),
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

  factory QaSource.fromJson(dynamic json) {
    // Handle both Map and String inputs
    if (json is String) {
      return QaSource(
        documentId: '',
        text: json,
        score: 1.0,
      );
    } else if (json is Map<String, dynamic>) {
      return QaSource(
        documentId: json['document_id']?.toString() ?? '',
        pageNumber: json['page_number'] ?? json['page'],
        text: json['text']?.toString() ?? json.toString(),
        score: (json['score'] is num) ? (json['score'] as num).toDouble() : 1.0,
      );
    } else {
      // Fallback for any other type
      return QaSource(
        documentId: '',
        text: json.toString(),
        score: 1.0,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'document_id': documentId,
      'page_number': pageNumber,
      'text': text,
      'score': score,
    };
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

  factory QaPair.fromJson(Map<String, dynamic> json) {
    return QaPair(
      question: json['question'] ?? '',
      answer: QaAnswer.fromJson(json['answer'] as Map<String, dynamic>),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': {
        'answer': answer.text,
        'sources': answer.sources.map((s) => s.toJson()).toList(),
        'timestamp': answer.timestamp.toIso8601String(),
        'document_id': answer.documentId,
        'query': answer.question,
        'citations': answer.citations,
        'missing_information': answer.missingInformation,
        'follow_up_questions': answer.followUpQuestions,
        'confidence': answer.confidence,
        'retrieval_confidence': answer.retrievalConfidence,
        'retrieval_strategy': answer.retrievalStrategy,
        'embedding_model_used': answer.embeddingModelUsed,
        'error': answer.error,
        'status': answer.status,
      },
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
