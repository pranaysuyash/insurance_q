/// Explicit QueryScope model for Q&A query targets.
/// Prevents nullable state ambiguity where null could be misconstrued as "first document".
sealed class QueryScope {
  const QueryScope();

  static const QueryScope all = _AllDocumentsScope();

  factory QueryScope.single(String documentId) = _SingleDocumentScope;

  bool get isAllDocuments;
  String? get documentId;
  String get displayLabel;
}

class _AllDocumentsScope extends QueryScope {
  const _AllDocumentsScope();

  @override
  bool get isAllDocuments => true;

  @override
  String? get documentId => null;

  @override
  String get displayLabel => 'All Documents';

  @override
  String toString() => 'QueryScope.allDocuments';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _AllDocumentsScope;

  @override
  int get hashCode => 0;
}

class _SingleDocumentScope extends QueryScope {
  @override
  final String documentId;

  const _SingleDocumentScope(this.documentId);

  @override
  bool get isAllDocuments => false;

  @override
  String get displayLabel => 'Single Policy';

  @override
  String toString() => 'QueryScope.singleDocument($documentId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _SingleDocumentScope && other.documentId == documentId);

  @override
  int get hashCode => documentId.hashCode;
}
