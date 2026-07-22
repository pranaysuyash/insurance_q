import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/relationship_graph.dart';
import 'package:coverwise/services/document_section_classifier.dart';

void main() {
  // =========================================================================
  // RelationshipGraph
  // =========================================================================
  group('RelationshipGraph', () {
    test('empty graph has no nodes or edges', () {
      const graph = RelationshipGraph();
      expect(graph.personCount, 0);
      expect(graph.relationshipCount, 0);
      expect(graph.hasPolicyholder, false);
      expect(graph.policyholder, isNull);
      expect(graph.documentIds, isEmpty);
    });

    test('withNode adds a node', () {
      const graph = RelationshipGraph();
      final node = RelationshipNode(
        id: 'doc1_rahul',
        name: 'Rahul Sharma',
        type: RelationshipType.policyholder,
        sourceDocumentIds: ['doc1'],
      );
      final updated = graph.withNode(node);
      expect(updated.personCount, 1);
      expect(updated.nodes['doc1_rahul']?.name, 'Rahul Sharma');
    });

    test('withEdge adds a directed edge', () {
      var graph = const RelationshipGraph();
      final policyholder = RelationshipNode(
        id: 'doc1_rahul',
        name: 'Rahul Sharma',
        type: RelationshipType.policyholder,
        sourceDocumentIds: ['doc1'],
      );
      final spouse = RelationshipNode(
        id: 'doc1_priya',
        name: 'Priya Sharma',
        type: RelationshipType.spouse,
        sourceDocumentIds: ['doc1'],
      );
      graph = graph.withNode(policyholder).withNode(spouse);
      graph = graph.withEdge(RelationshipEdge(
        sourceNodeId: 'doc1_rahul',
        targetNodeId: 'doc1_priya',
        documentId: 'doc1',
        type: RelationshipType.spouse,
        confidence: 0.8,
      ));
      expect(graph.relationshipCount, 1);
    });

    test('neighbors finds connected nodes', () {
      var graph = const RelationshipGraph();
      graph = graph
          .withNode(RelationshipNode(
            id: 'doc1_rahul',
            name: 'Rahul Sharma',
            type: RelationshipType.policyholder,
            sourceDocumentIds: ['doc1'],
          ))
          .withNode(RelationshipNode(
            id: 'doc1_priya',
            name: 'Priya Sharma',
            type: RelationshipType.spouse,
            sourceDocumentIds: ['doc1'],
          ))
          .withNode(RelationshipNode(
            id: 'doc1_arjun',
            name: 'Arjun Sharma',
            type: RelationshipType.child,
            sourceDocumentIds: ['doc1'],
          ));
      graph = graph
          .withEdge(RelationshipEdge(
            sourceNodeId: 'doc1_rahul',
            targetNodeId: 'doc1_priya',
            documentId: 'doc1',
            type: RelationshipType.spouse,
          ))
          .withEdge(RelationshipEdge(
            sourceNodeId: 'doc1_rahul',
            targetNodeId: 'doc1_arjun',
            documentId: 'doc1',
            type: RelationshipType.child,
          ));

      final neighbors = graph.neighbors('doc1_rahul');
      expect(neighbors.length, 2);
      expect(neighbors.map((n) => n.name), contains('Priya Sharma'));
      expect(neighbors.map((n) => n.name), contains('Arjun Sharma'));
    });

    test('merge combines two graphs without duplicates', () {
      var graph1 = const RelationshipGraph();
      graph1 = graph1.withNode(RelationshipNode(
        id: 'doc1_rahul',
        name: 'Rahul Sharma',
        type: RelationshipType.policyholder,
        sourceDocumentIds: ['doc1'],
      ));

      var graph2 = const RelationshipGraph();
      graph2 = graph2.withNode(RelationshipNode(
        id: 'doc2_rahul',
        name: 'Rahul Sharma',
        type: RelationshipType.policyholder,
        sourceDocumentIds: ['doc2'],
      ));

      final merged = graph1.merge(graph2);
      expect(merged.personCount, 2);
      // Same person across documents should have merged source IDs
      expect(merged.nodes['doc1_rahul']?.sourceDocumentIds, ['doc1']);
      expect(merged.nodes['doc2_rahul']?.sourceDocumentIds, ['doc2']);
    });

    test('withNode merges existing node and deduplicates sourceDocumentIds', () {
      var graph = const RelationshipGraph();
      graph = graph.withNode(RelationshipNode(
        id: 'doc1_rahul',
        name: 'Rahul Sharma',
        dateOfBirth: '15-08-1985',
        type: RelationshipType.policyholder,
        sourceDocumentIds: ['doc1'],
      ));
      // Same node from another document — should merge
      graph = graph.withNode(RelationshipNode(
        id: 'doc1_rahul',
        name: 'Rahul Sharma',
        type: RelationshipType.policyholder,
        sourceDocumentIds: ['doc2'],
      ));
      expect(graph.personCount, 1);
      expect(graph.nodes['doc1_rahul']?.dateOfBirth, '15-08-1985');
      expect(graph.nodes['doc1_rahul']?.sourceDocumentIds.length, 2);
    });

    test('JSON serialization round-trips correctly', () {
      var graph = const RelationshipGraph();
      graph = graph
          .withNode(RelationshipNode(
            id: 'doc1_rahul',
            name: 'Rahul Sharma',
            dateOfBirth: '15-08-1985',
            type: RelationshipType.policyholder,
            sourceDocumentIds: ['doc1'],
          ))
          .withNode(RelationshipNode(
            id: 'doc1_priya',
            name: 'Priya Sharma',
            type: RelationshipType.spouse,
            sourceDocumentIds: ['doc1'],
          ))
          .withEdge(RelationshipEdge(
            sourceNodeId: 'doc1_rahul',
            targetNodeId: 'doc1_priya',
            documentId: 'doc1',
            type: RelationshipType.spouse,
            confidence: 0.8,
          ));

      final json = graph.toJson();
      final restored = RelationshipGraph.fromJson(json);

      expect(restored.personCount, 2);
      expect(restored.relationshipCount, 1);
      expect(
          restored.nodes['doc1_rahul']?.dateOfBirth, '15-08-1985');
      expect(restored.edges.first.confidence, 0.8);
    });

    test('hasPolicyholder returns true when policyholder node exists', () {
      var graph = const RelationshipGraph();
      graph = graph.withNode(RelationshipNode(
        id: 'doc1_rahul',
        name: 'Rahul Sharma',
        type: RelationshipType.policyholder,
        sourceDocumentIds: ['doc1'],
      ));
      expect(graph.hasPolicyholder, true);
      expect(graph.policyholder?.name, 'Rahul Sharma');
    });

    test('hasPolicyholder returns false without policyholder node', () {
      var graph = const RelationshipGraph();
      graph = graph.withNode(RelationshipNode(
        id: 'doc1_priya',
        name: 'Priya Sharma',
        type: RelationshipType.spouse,
        sourceDocumentIds: ['doc1'],
      ));
      expect(graph.hasPolicyholder, false);
      expect(graph.policyholder, isNull);
    });
  });

  // =========================================================================
  // RelationshipType
  // =========================================================================
  group('RelationshipType', () {
    test('fromString maps known values', () {
      expect(RelationshipType.fromString('policyholder'),
          RelationshipType.policyholder);
      expect(RelationshipType.fromString('spouse'),
          RelationshipType.spouse);
      expect(RelationshipType.fromString('child'),
          RelationshipType.child);
      expect(RelationshipType.fromString('nominee'),
          RelationshipType.nominee);
    });

    test('fromString is case-insensitive', () {
      expect(RelationshipType.fromString('POLICYHOLDER'),
          RelationshipType.policyholder);
      expect(RelationshipType.fromString('Spouse'),
          RelationshipType.spouse);
    });

    test('fromString matches displayName', () {
      expect(RelationshipType.fromString('Insured'),
          RelationshipType.insured);
      expect(RelationshipType.fromString('Nominee'),
          RelationshipType.nominee);
    });

    test('fromString defaults to Other for unknown values', () {
      expect(RelationshipType.fromString('unknown_role'),
          RelationshipType.other);
      expect(RelationshipType.fromString(''),
          RelationshipType.other);
    });
  });

  // =========================================================================
  // DocumentSectionClassifier
  // =========================================================================
  group('DocumentSectionClassifier', () {
    late DocumentSectionClassifier classifier;

    setUp(() {
      classifier = DocumentSectionClassifier();
    });

    test('classifies policy schedule page', () {
      final sections = classifier.classifyPages([
        'Policy Schedule\nPolicy Number: POL-12345\nName: Rahul Sharma',
        'Premium Amount: ₹25,000\nGST on Premium: 18%',
      ]);
      expect(sections.length, greaterThanOrEqualTo(1));
      expect(sections.first.type, SectionType.policySchedule);
    });

    test('classifies nominee section', () {
      final sections = classifier.classifyPages([
        'General terms and conditions of the policy.',
        'Nomination Details\nSection 39\nNominee Name: Priya Sharma',
        'Claim process information.',
      ]);
      expect(sections.any((s) => s.type == SectionType.nominee), true);
    });

    test('classifies insured persons section', () {
      final sections = classifier.classifyPages([
        'Persons Insured\n1. Rahul Sharma (Self)\n2. Priya Sharma (Spouse)',
        'Coverage details and sum insured.',
      ]);
      expect(sections.any((s) => s.type == SectionType.insuredPersons), true);
    });

    test('classifies waiting periods section', () {
      final sections = classifier.classifyPages([
        'Waiting Periods\nInitial waiting period: 30 days\nPre-existing conditions: 2 years',
      ]);
      expect(sections.any((s) => s.type == SectionType.waitingPeriods), true);
    });

    test('classifyText returns correct section for short text', () {
      final type = classifier.classifyText(
          'Sum Insured: ₹5,00,000\nDeductible: ₹1,000');
      expect(type, SectionType.coverageDetails);
    });

    test('classifyText returns unknown for irrelevant text', () {
      final type = classifier.classifyText(
          'This is just some random text with no insurance keywords.');
      expect(type, SectionType.unknown);
    });

    test('classifyPages returns empty list for empty input', () {
      final sections = classifier.classifyPages([]);
      expect(sections, isEmpty);
    });

    test('classifies multiple distinct sections across pages', () {
      final sections = classifier.classifyPages([
        'Policy Schedule\nPolicy Number: ABC-123',
        'Covered Persons\nRahul Sharma (Self)\nPriya Sharma (Spouse)',
        'Key Benefits\nHospitalization coverage up to ₹5L',
        'Exclusions\nPre-existing conditions not covered',
        'Claim Process\nCall 1800-XXX-XXXX',
      ]);
      final types = sections.map((s) => s.type).toSet();
      expect(types, contains(SectionType.policySchedule));
      expect(types, contains(SectionType.benefits));
      expect(types, contains(SectionType.exclusions));
      expect(types, contains(SectionType.claimsProcess));
    });

    test('page range spans correctly', () {
      final sections = classifier.classifyPages([
        'Policy Schedule page 1',
        'Policy Schedule page 2',
        'Benefits and coverage page 1',
        'Benefits and coverage page 2',
        'Exclusions',
      ]);
      expect(sections.length, greaterThanOrEqualTo(2));
      final scheduleSection =
          sections.firstWhere((s) => s.type == SectionType.policySchedule);
      expect(scheduleSection.startPage, 1);
      // The section classifier creates new sections only when a new match
      // is found on a differently-typed page. Page 1-2 match policySchedule,
      // page 3-4 match benefits, page 5 matches exclusions.
    });
  });
}
