import 'package:flutter/foundation.dart';
import '../models/relationship_graph.dart';
import '../models/document_model.dart';
import 'policy_extraction_helpers.dart';
import 'relationship_prompt_templates.dart';
import 'query_service.dart';

/// Result of a relationship extraction for a single document.
class DocumentRelationships {
  /// The document this extraction applies to.
  final String documentId;

  /// The extracted relationship graph for this document.
  final RelationshipGraph graph;

  /// Overall confidence for this extraction (0.0–1.0).
  final double confidence;

  /// Any warnings encountered during extraction.
  final List<String> warnings;

  const DocumentRelationships({
    required this.documentId,
    required this.graph,
    this.confidence = 0.5,
    this.warnings = const [],
  });
}

/// Extracts relationships (policyholder, insured persons, nominees,
/// dependents) from uploaded policy documents using the LLM query
/// pipeline.
///
/// This service builds on top of the existing [PolicyExtractionService]
/// extraction pipeline. It uses the same [QueryService] but with
/// relationship-focused prompt templates instead of the 13-field
/// extraction prompts.
class RelationshipExtractionService {
  final QueryService _queryService;

  RelationshipExtractionService(this._queryService);

  /// Extract all relationships from a single document.
  ///
  /// Returns a [DocumentRelationships] containing the relationship
  /// graph, confidence score, and any warnings.
  Future<DocumentRelationships> extractRelationships(
    String documentId,
    String documentType,
  ) async {
    final warnings = <String>[];
    var graph = const RelationshipGraph();

    // 1. Extract primary policyholder
    final policyholderResult = await _ask(documentId,
        RelationshipPromptTemplates.policyholderName);
    final policyholderName = cleanText(policyholderResult);

    if (policyholderName.isEmpty) {
      warnings.add('Could not determine policyholder name.');
      return DocumentRelationships(
        documentId: documentId,
        graph: graph,
        confidence: 0.0,
        warnings: warnings,
      );
    }

    // Create policyholder node
    final policyholderId = _nodeId(documentId, policyholderName);
    var policyholderDob = await _ask(documentId,
        RelationshipPromptTemplates.policyholderDob);
    var dob = cleanText(policyholderDob);
    if (dob == 'not found' || dob.isEmpty) dob = '';

    graph = graph.withNode(RelationshipNode(
      id: policyholderId,
      name: policyholderName,
      dateOfBirth: dob.isNotEmpty ? dob : null,
      type: RelationshipType.policyholder,
      sourceDocumentIds: [documentId],
    ));

    // 2. Extract insured persons
    final insuredResult = await _ask(documentId,
        RelationshipPromptTemplates.insuredPersons);
    final insuredLines = splitLines(insuredResult);

    if (insuredLines.isEmpty) {
      warnings.add('Could not determine insured persons.');
    } else {
      for (final line in insuredLines) {
        final parts = _parseNameRelationship(line);
        final personName = parts.$1;
        final relationship = parts.$2;

        if (personName.isEmpty) continue;

        final personId = _nodeId(documentId, personName);
        final relType = _mapRelationshipType(relationship, documentType);

        // Insured persons are always connected to the policyholder
        if (personName.toLowerCase() != policyholderName.toLowerCase()) {
          graph = graph.withNode(RelationshipNode(
            id: personId,
            name: personName,
            type: relType,
            sourceDocumentIds: [documentId],
          ));

          graph = graph.withEdge(RelationshipEdge(
            sourceNodeId: policyholderId,
            targetNodeId: personId,
            documentId: documentId,
            type: relType,
            confidence: 0.7,
          ));
        } else {
          // The policyholder is also an insured person — just update the type
          graph = graph.withNode(RelationshipNode(
            id: policyholderId,
            name: policyholderName,
            type: RelationshipType.policyholder,
            sourceDocumentIds: [documentId],
          ));
        }
      }
    }

    // 3. Extract nominee / beneficiary
    final nomineeResult = await _ask(documentId,
        RelationshipPromptTemplates.nomineeDetails);
    final nomineeLines = splitLines(nomineeResult);

    if (nomineeLines.isNotEmpty &&
        !nomineeResult.toLowerCase().contains('no nominee')) {
      for (final line in nomineeLines) {
        final parts = _parseNameRelationship(line);
        final nomineeName = parts.$1;
        if (nomineeName.isEmpty) continue;

        final nomineeId = _nodeId(documentId, nomineeName);
        graph = graph.withNode(RelationshipNode(
          id: nomineeId,
          name: nomineeName,
          type: RelationshipType.nominee,
          sourceDocumentIds: [documentId],
        ));

        graph = graph.withEdge(RelationshipEdge(
          sourceNodeId: policyholderId,
          targetNodeId: nomineeId,
          documentId: documentId,
          type: RelationshipType.nominee,
          confidence: 0.6,
        ));
      }
    }

    // 4. Check for dependent coverage (family floater health policies)
    if (documentType.toLowerCase().contains('health')) {
      final dependentsResult = await _ask(documentId,
          RelationshipPromptTemplates.dependentParents);
      final dependentText = cleanText(dependentsResult);
      if (dependentText.toLowerCase() == 'yes') {
        warnings.add(
            'Policy appears to cover dependent parents; full names not '
            'extracted from document text. Add manually if needed.');
      }

      final childrenResult = await _ask(documentId,
          RelationshipPromptTemplates.dependentChildren);
      final childrenText = cleanText(childrenResult);
      if (childrenText.toLowerCase() == 'yes') {
        warnings.add(
            'Policy appears to cover children; full names not extracted '
            'from document text. Add manually if needed.');
      }
    }

    // Compute overall confidence
    final totalFields = [
      if (policyholderName.isNotEmpty) 'policyholder',
      if (insuredLines.isNotEmpty) 'insured_persons',
      if (nomineeLines.isNotEmpty && 
          !nomineeResult.toLowerCase().contains('no nominee')) 'nominee',
    ];

    final confidence = totalFields.isNotEmpty
        ? (totalFields.length * 1.0) / 3.0
        : 0.0;

    return DocumentRelationships(
      documentId: documentId,
      graph: graph,
      confidence: confidence,
      warnings: warnings,
    );
  }

  /// Merge all document-level relationship graphs into a single
  /// family-level graph.
  RelationshipGraph buildFamilyGraph(
    List<DocumentRelationships> documentRelationships,
  ) {
    var familyGraph = const RelationshipGraph();
    for (final docRel in documentRelationships) {
      familyGraph = familyGraph.merge(docRel.graph);
    }
    return familyGraph;
  }

  /// Convert a [RelationshipGraph] back to a list of [PolicyHolder]
  /// objects for compatibility with the existing family provider pipeline.
  List<PolicyHolder> graphToPolicyHolders(RelationshipGraph graph) {
    return graph.nodes.values.map((node) {
      return PolicyHolder(
        name: node.name,
        dob: node.dateOfBirth,
        relationship: node.type.displayName,
        source: 'document',
      );
    }).toList();
  }

  Future<String> _ask(String documentId, String question) async {
    try {
      final result = await _queryService.queryDocument(
        question,
        documentId: documentId,
      );
      return result['answer']?.toString() ?? '';
    } catch (e) {
      debugPrint('Error asking "$question": $e');
      return '';
    }
  }

  /// Stable node ID derived from document and person name.
  String _nodeId(String documentId, String name) {
    final normalized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${documentId}_$normalized';
  }

  /// Parse a "Name - Relationship" or "Name - Relationship - Share%" line.
  (String, String) _parseNameRelationship(String line) {
    final parts = line.split(' - ');
    if (parts.length >= 2) {
      return (parts[0].trim(), parts[1].trim());
    }
    // Try splitting on other common delimiters
    final colonParts = line.split(':');
    if (colonParts.length >= 2) {
      return (colonParts[0].trim(), colonParts[1].trim());
    }
    // Unrecognised format — log for diagnostics
    debugPrint(
        '⚠️ _parseNameRelationship: unrecognised format "$line"');
    return (line.trim(), '');
  }

  /// Map a relationship string from the LLM to a canonical
  /// [RelationshipType].
  RelationshipType _mapRelationshipType(String relationship, String documentType) {
    final lower = relationship.toLowerCase();
    if (lower.contains('self') || lower.contains('policyholder')) {
      return RelationshipType.policyholder;
    }
    if (lower.contains('spouse') || lower.contains('wife') ||
        lower.contains('husband') || lower.contains('partner')) {
      return RelationshipType.spouse;
    }
    if (lower.contains('son') || lower.contains('daughter') ||
        lower.contains('child')) {
      return RelationshipType.child;
    }
    if (lower.contains('father') || lower.contains('mother') ||
        lower.contains('parent')) {
      return RelationshipType.parent;
    }
    if (lower.contains('brother') || lower.contains('sister') ||
        lower.contains('sibling')) {
      return RelationshipType.sibling;
    }
    if (lower.contains('dependent')) {
      return RelationshipType.dependent;
    }
    return RelationshipType.other;
  }
}
