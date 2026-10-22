import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/screens/claims_assistant_screen.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/widgets/shared/coverwise_components.dart';
import 'helpers/policy_detail_test_helpers.dart';

void main() {
  testWidgets('ClaimsAssistantScreen renders legal boundary notice panel',
      (tester) async {
    final testDoc = InsuranceDocument(
      id: 'doc-001',
      filename: 'health_policy.pdf',
      uploadedOn: DateTime(2026, 8, 24),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsProvider.overrideWith((ref) async => [testDoc]),
          policySummariesProvider.overrideWith(() => FakeSummariesNotifier()),
        ],
        child: const MaterialApp(
          home: ClaimsAssistantScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify statutory legal disclaimer panel is rendered
    expect(find.text('Informational Guide Only'), findsOneWidget);
    expect(
      find.text(
          'CoverWise provides educational document checklists and guidance. Claim approval decisions are determined solely by your insurer.'),
      findsOneWidget,
    );
    expect(find.byType(CoverWiseInfoPanel), findsOneWidget);
  });
}
