import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/preventive_health_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'helpers/hive_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(HiveTestHelper.setUp);
  tearDownAll(HiveTestHelper.tearDown);

  setUp(() async {
    await Hive.box<dynamic>(AppStateStore.boxName).clear();
  });

  test('policy review notes do not infer benefits or claim outcomes', () {
    final notes = PreventiveHealthService.getAvailableTips([
      PolicySummary(
        documentId: 'health-1',
        documentType: 'Health Insurance',
        insurer: 'Example Insurer',
        deductible: 5000,
        extractedAt: DateTime(2026, 7, 24),
      ),
      PolicySummary(
        documentId: 'motor-1',
        documentType: 'Motor Insurance',
        extractedAt: DateTime(2026, 7, 24),
      ),
      PolicySummary(
        documentId: 'life-1',
        documentType: 'Life Insurance',
        extractedAt: DateTime(2026, 7, 24),
      ),
    ]);
    final prohibited = RegExp(
      r'likely covers|free annual|required for insurance claims|avoid coverage gaps|unexpected out-of-pocket',
      caseSensitive: false,
    );

    expect(notes, isNotEmpty);
    expect(
      notes.every((note) => !prohibited.hasMatch('${note.title} ${note.body}')),
      isTrue,
    );
    expect(notes.any((note) => note.body.contains('does not verify')), isTrue);
    expect(
        notes.any((note) => note.body.contains('CoverWise does not determine')),
        isTrue);
  });
}
