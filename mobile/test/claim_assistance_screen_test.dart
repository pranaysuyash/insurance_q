import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/screens/claims_assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake StateNotifier that exposes an empty list without needing a real service.
/// Must implement [PolicySummariesNotifier] because [policySummariesProvider]
/// is typed as StateNotifierProvider<PolicySummariesNotifier, ...>.
final class _FakeSummariesNotifier extends StateNotifier<List<PolicySummary>>
    implements PolicySummariesNotifier {
  _FakeSummariesNotifier() : super(const []);

  @override
  Future<PolicySummary?> extractForDocument(
          String documentId, String documentType) async =>
      null;

  @override
  Future<void> fetchFromBackend(String documentId, String documentType) async {}

  @override
  Future<void> deleteSummary(String documentId) async {}

  @override
  PolicySummary? getForDocument(String documentId) => null;

  @override
  List<PolicySummary> get expiringSoon => const [];

  @override
  List<PolicySummary> get expired => const [];

  @override
  List<PolicySummary> get active => const [];
}

/// Minimal InsuranceDocument for tests that need the incident list to render.
final _dummyDoc = InsuranceDocument(
  id: 'doc-1',
  filename: 'test_policy.pdf',
  uploadedOn: DateTime(2026, 1, 1),
);

/// Harness for tests that expect the empty state (no documents, no summaries).
Widget _harnessEmpty(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return ProviderScope(
    overrides: [
      policySummariesProvider.overrideWith((ref) => _FakeSummariesNotifier()),
      documentsProvider.overrideWith((ref) async => const <InsuranceDocument>[]),
    ],
    child: MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: mode,
      home: child,
    ),
  );
}

/// Harness for tests that need the incident list (documents present, summaries empty).
Widget _harnessWithData(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return ProviderScope(
    overrides: [
      policySummariesProvider.overrideWith((ref) => _FakeSummariesNotifier()),
      documentsProvider.overrideWith((ref) async => [_dummyDoc]),
    ],
    child: MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: mode,
      home: child,
    ),
  );
}

void main() {
  testWidgets('renders app bar and page header', (tester) async {
    await tester.pumpWidget(_harnessWithData(const ClaimsAssistantScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Claim guide'), findsOneWidget);
    expect(find.text('What happened?'), findsOneWidget);
    expect(
      find.textContaining('Choose an incident'), findsOneWidget,
    );
  });

  testWidgets('shows empty state when no documents uploaded', (tester) async {
    await tester.pumpWidget(_harnessEmpty(const ClaimsAssistantScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No documents uploaded'), findsOneWidget);
    expect(
      find.textContaining('Upload insurance documents'), findsOneWidget,
    );
  });

  testWidgets('shows all incident types', (tester) async {
    await tester.pumpWidget(_harnessWithData(const ClaimsAssistantScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Hospitalization'), findsOneWidget);
    expect(find.text('Auto accident'), findsOneWidget);
    expect(find.text('Life insurance claim'), findsOneWidget);
    expect(find.text('Other or general'), findsOneWidget);
  });

  testWidgets('selecting an incident shows action button', (tester) async {
    await tester.pumpWidget(_harnessWithData(const ClaimsAssistantScreen()));
    await tester.pumpAndSettle();
    // No button visible before selection.
    expect(find.text('View preparation guide'), findsNothing);
    // Tap Hospitalization — scroll it into view first.
    await tester.scrollUntilVisible(
      find.text('Hospitalization'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Hospitalization'));
    await tester.pumpAndSettle();
    // Button is below the incident list — scroll to find it.
    await tester.scrollUntilVisible(
      find.text('View preparation guide'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('View preparation guide'), findsOneWidget);
  });

  testWidgets('renders correctly in dark mode (no hardcoded colors)', (tester) async {
    await tester.pumpWidget(
      _harnessWithData(
        const ClaimsAssistantScreen(),
        mode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ClaimsAssistantScreen), findsOneWidget);
    expect(find.text('What happened?'), findsOneWidget);
  });
}
