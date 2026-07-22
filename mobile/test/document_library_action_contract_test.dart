import 'package:flutter_test/flutter_test.dart';

import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/screens/documents_list.dart';

void main() {
  final remoteOnly = InsuranceDocument(
    id: 'local-id',
    remoteId: 'remote-id',
    filename: 'policy.pdf',
    uploadedOn: DateTime(2026, 7, 21),
    processingState: 'ready',
  );
  final pending = InsuranceDocument(
    id: 'pending-id',
    filename: 'pending.pdf',
    uploadedOn: DateTime(2026, 7, 21),
    syncState: 'pending_upload',
    processingState: 'pending',
  );

  test('remote-only account policies remain queryable', () {
    expect(canAskQuestions(remoteOnly, isReady: true), isTrue);
  });

  test('pending uploads remain blocked until remote identity exists', () {
    expect(canAskQuestions(pending, isReady: false), isFalse);
    expect(canAskQuestions(pending, isReady: true), isFalse);
  });
}
