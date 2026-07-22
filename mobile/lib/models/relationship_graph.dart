/// Canonical relationship types recognised by CoverWise.
///
/// Each enum value maps to an Indian insurance document role that the
/// extraction module can identify from policy text.
enum RelationshipType {
  /// The person who owns/purchased the policy.
  policyholder('Policyholder', 'primary'),

  /// The person(s) whose life/health/asset is covered.
  insured('Insured', 'primary'),

  /// Person entitled to receive the policy benefit upon claim.
  nominee('Nominee', 'primary'),

  /// Spouse of the policyholder.
  spouse('Spouse', 'familial'),

  /// Child of the policyholder.
  child('Child', 'familial'),

  /// Parent of the policyholder.
  parent('Parent', 'familial'),

  /// Sibling of the policyholder.
  sibling('Sibling', 'familial'),

  /// Any other dependent (e.g. grandparent, in-law).
  dependent('Dependent', 'familial'),

  /// An unrelated co-insured (e.g. business partner, tenant).
  other('Other', 'other');

  const RelationshipType(this.displayName, this.category);

  /// Human-readable label shown in the UI.
  final String displayName;

  /// Category for UI grouping: `primary`, `familial`, or `other`.
  final String category;

  static RelationshipType fromString(String value) {
    for (final type in values) {
      if (type.name.toLowerCase() == value.toLowerCase() ||
          type.displayName.toLowerCase() == value.toLowerCase()) {
        return type;
      }
    }
    return RelationshipType.other;
  }
}

/// A single node (person) in the relationship graph.
class RelationshipNode {
  final String id;
  final String name;
  final String? dateOfBirth;
  final RelationshipType type;

  /// Which source document(s) this node was extracted from.
  final List<String> sourceDocumentIds;

  const RelationshipNode({
    required this.id,
    required this.name,
    this.dateOfBirth,
    required this.type,
    this.sourceDocumentIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date_of_birth': dateOfBirth,
        'type': type.name,
        'source_document_ids': sourceDocumentIds,
      };

  factory RelationshipNode.fromJson(Map<String, dynamic> json) =>
      RelationshipNode(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        dateOfBirth: json['date_of_birth'],
        type: RelationshipType.fromString(json['type'] ?? 'other'),
        sourceDocumentIds:
            List<String>.from(json['source_document_ids'] ?? []),
      );
}

/// An edge connecting two nodes in the relationship graph.
///
/// Edges are directional: [source] → [target]. For example, a
/// "policyholder → insured" edge means the policyholder covers the insured.
class RelationshipEdge {
  final String sourceNodeId;
  final String targetNodeId;

  /// The insurance policy that establishes this relationship.
  final String documentId;

  /// The type of relationship (e.g., policyholder→insured).
  final RelationshipType type;

  /// Confidence 0.0–1.0 for this specific edge.
  final double confidence;

  const RelationshipEdge({
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.documentId,
    required this.type,
    this.confidence = 0.5,
  });

  Map<String, dynamic> toJson() => {
        'source_node_id': sourceNodeId,
        'target_node_id': targetNodeId,
        'document_id': documentId,
        'type': type.name,
        'confidence': confidence,
      };

  factory RelationshipEdge.fromJson(Map<String, dynamic> json) =>
      RelationshipEdge(
        sourceNodeId: json['source_node_id'] ?? '',
        targetNodeId: json['target_node_id'] ?? '',
        documentId: json['document_id'] ?? '',
        type: RelationshipType.fromString(json['type'] ?? 'other'),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      );
}

/// A directed graph of relationships extracted from policy documents.
///
/// Nodes represent people (policyholders, insured persons, nominees,
/// dependents). Edges represent the relationships between them,
/// each attributed to a specific policy document.
class RelationshipGraph {
  final Map<String, RelationshipNode> nodes;
  final List<RelationshipEdge> edges;

  const RelationshipGraph({
    this.nodes = const {},
    this.edges = const [],
  });

  /// Add a node to the graph, preserving existing data if the node
  /// already exists (e.g., merging details from multiple documents).
  RelationshipGraph withNode(RelationshipNode node) {
    final existing = nodes[node.id];
    if (existing == null) {
      return RelationshipGraph(
        nodes: {...nodes, node.id: node},
        edges: edges,
      );
    }
    // Merge: prefer non-null dateOfBirth
    return RelationshipGraph(
      nodes: {
        ...nodes,
        node.id: RelationshipNode(
          id: node.id,
          name: node.name,
          dateOfBirth: node.dateOfBirth ?? existing.dateOfBirth,
          type: node.type,
          sourceDocumentIds: [
            ...existing.sourceDocumentIds,
            ...node.sourceDocumentIds.where(
              (id) => !existing.sourceDocumentIds.contains(id),
            ),
          ],
        ),
      },
      edges: edges,
    );
  }

  /// Add an edge to the graph.
  RelationshipGraph withEdge(RelationshipEdge edge) {
    return RelationshipGraph(
      nodes: nodes,
      edges: [...edges, edge],
    );
  }

  /// Add all nodes and edges from another graph.
  RelationshipGraph merge(RelationshipGraph other) {
    var merged = this;
    for (final node in other.nodes.values) {
      merged = merged.withNode(node);
    }
    for (final edge in other.edges) {
      merged = merged.withEdge(edge);
    }
    return merged;
  }

  /// Find all nodes that have a direct edge with the given node.
  List<RelationshipNode> neighbors(String nodeId) {
    final result = <RelationshipNode>[];
    for (final edge in edges) {
      if (edge.sourceNodeId == nodeId) {
        final target = nodes[edge.targetNodeId];
        if (target != null) result.add(target);
      }
      if (edge.targetNodeId == nodeId) {
        final source = nodes[edge.sourceNodeId];
        if (source != null) result.add(source);
      }
    }
    return result;
  }

  /// All unique document IDs referenced in edges.
  Set<String> get documentIds =>
      edges.map((e) => e.documentId).toSet();

  /// Number of distinct people in the graph.
  int get personCount => nodes.length;

  /// Number of distinct relationships.
  int get relationshipCount => edges.length;

  /// Whether the graph has at least one node that is likely the
  /// policyholder (the "root" person for the family view).
  bool get hasPolicyholder =>
      nodes.values.any((n) => n.type == RelationshipType.policyholder);

  /// Convenience: return the policyholder node, if any.
  RelationshipNode? get policyholder =>
      nodes.values.where((n) => n.type == RelationshipType.policyholder).firstOrNull;

  Map<String, dynamic> toJson() => {
        'nodes': nodes.values.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };

  factory RelationshipGraph.fromJson(Map<String, dynamic> json) {
    final nodeList = (json['nodes'] as List?)
            ?.map((n) => RelationshipNode.fromJson(n as Map<String, dynamic>))
            .toList() ??
        [];
    final edgeList = (json['edges'] as List?)
            ?.map((e) => RelationshipEdge.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return RelationshipGraph(
      nodes: {for (final n in nodeList) n.id: n},
      edges: edgeList,
    );
  }
}
