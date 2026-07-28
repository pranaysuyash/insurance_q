import 'package:coverwise/l10n/app_localizations_gen.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'package:coverwise/screens/policy_detail_screen.dart';
import 'package:coverwise/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/hive_test_helper.dart';
import 'helpers/policy_detail_test_helpers.dart';

/// Wraps a policy detail screen with test providers.
Widget buildTestApp({
  required String documentId,
  List<PolicySummary>? summaries,
  List<InsuranceDocument>? documents,
}) {
  return ProviderScope(
    overrides: [
      policySummariesProvider.overrideWith(
        () => FakeSummariesNotifier(summaries ?? [fullSummary()]),
      ),
      documentsProvider.overrideWith((ref) async => documents ?? []),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
      supportedLocales: AppLocalizationsGen.supportedLocales,
      home: PolicyDetailScreen(documentId: documentId),
    ),
  );
}

void main() {
  late List<Map<String, dynamic>> capturedEvents;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HiveTestHelper.setUp();
  });

  setUp(() {
    // Enable the AnalyticsService fallback buffer and grab a reference to it.
    // The Riverpod AnalyticsNotifier is not instantiated by the ProviderScope
    // used in these tests (no ref.read of analyticsServiceProvider), so
    // AnalyticsService.track() will use the fallback path.
    capturedEvents = AnalyticsService.enableFallbackBuffer();
  });

  tearDown(() {
    capturedEvents.clear();
    // Reset consent for the next test.
    AnalyticsService.dispose();
  });

  tearDownAll(() {
    HiveTestHelper.tearDown();
  });

  group('PolicyDetailScreen — analytics events', () {
    testWidgets('policy_detail_opened is fired once on mount with correct properties',
        (tester) async {
      await tester.pumpWidget(buildTestApp(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      expect(capturedEvents.length, greaterThanOrEqualTo(1));

      final opened = capturedEvents.firstWhere(
        (e) => e['event'] == 'policy_detail_opened',
        orElse: () => <String, dynamic>{},
      );
      expect(opened, isNotEmpty);
      expect(opened['event'], 'policy_detail_opened');
      final props = opened['props'] as Map<String, dynamic>;
      expect(props['policy_type'], 'Health Insurance');
      expect(props['is_expired'], isFalse);
      expect(props['has_evidence'], isTrue);
    });

    testWidgets('policy_detail_section_opened is fired with section count',
        (tester) async {
      await tester.pumpWidget(buildTestApp(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      final section = capturedEvents.firstWhere(
        (e) => e['event'] == 'policy_detail_section_opened',
        orElse: () => <String, dynamic>{},
      );
      expect(section, isNotEmpty);
      final props = section['props'] as Map<String, dynamic>;
      expect(props['section_count'], greaterThan(0));
      expect(props['sections'], isA<String>());
      // Should include common sections
      expect(props['sections'], contains('executive_summary'));
      expect(props['sections'], contains('benefits'));
      expect(props['sections'], contains('exclusions'));
      expect(props['sections'], contains('quick_actions'));
    });

    testWidgets('events are not duplicated on rebuild', (tester) async {
      await tester.pumpWidget(buildTestApp(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // Count how many opened events were fired
      final openedEvents =
          capturedEvents.where((e) => e['event'] == 'policy_detail_opened');
      expect(openedEvents.length, 1);

      final sectionEvents =
          capturedEvents.where((e) => e['event'] == 'policy_detail_section_opened');
      expect(sectionEvents.length, 1);
    });

    testWidgets('policy_detail_coverage_gap_tapped fires on button tap',
        (tester) async {
      await tester.pumpWidget(buildTestApp(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // Scroll to the _PolicyActionsRow buttons
      await tester.scrollUntilVisible(
        find.text('What your policy covers'),
        200,
      );
      await tester.tap(find.text('What your policy covers'));
      await tester.pumpAndSettle();

      final event = capturedEvents.firstWhere(
        (e) => e['event'] == 'policy_detail_coverage_gap_tapped',
        orElse: () => <String, dynamic>{},
      );
      expect(event, isNotEmpty);
      final props = event['props'] as Map<String, dynamic>;
      expect(props['document_id_hash'], isA<String>());
      expect((props['document_id_hash'] as String).length, greaterThan(0));
    });

    testWidgets('policy_detail_claim_assist_tapped fires on button tap',
        (tester) async {
      await tester.pumpWidget(buildTestApp(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // Scroll to the _PolicyActionsRow buttons
      await tester.scrollUntilVisible(
        find.text('How to file a claim'),
        200,
      );
      await tester.tap(find.text('How to file a claim'));
      await tester.pumpAndSettle();

      final event = capturedEvents.firstWhere(
        (e) => e['event'] == 'policy_detail_claim_assist_tapped',
        orElse: () => <String, dynamic>{},
      );
      expect(event, isNotEmpty);
      final props = event['props'] as Map<String, dynamic>;
      expect(props['document_id_hash'], isA<String>());
    });

    testWidgets('policy_detail_shared fires when share button is tapped',
        (tester) async {
      await tester.pumpWidget(buildTestApp(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // Scroll to the share button in quick actions
      await tester.scrollUntilVisible(
        find.text('Share policy summary'),
        200,
      );
      await tester.tap(find.text('Share policy summary'));
      await tester.pumpAndSettle();

      final event = capturedEvents.firstWhere(
        (e) => e['event'] == 'policy_detail_shared',
        orElse: () => <String, dynamic>{},
      );
      expect(event, isNotEmpty);
      final props = event['props'] as Map<String, dynamic>;
      expect(props['policy_type'], 'Health Insurance');
    });

    testWidgets('policy_detail_source_preview_opened fires with available:false when no documents',
        (tester) async {
      // No documents provided — preview should be unavailable
      await tester.pumpWidget(buildTestApp(documentId: 'doc-1', documents: []));
      await tester.pumpAndSettle();

      // Tap the document preview button in the app bar
      await tester.tap(find.byIcon(Icons.description_outlined));
      await tester.pumpAndSettle();

      final event = capturedEvents.firstWhere(
        (e) => e['event'] == 'policy_detail_source_preview_opened',
        orElse: () => <String, dynamic>{},
      );
      expect(event, isNotEmpty);
      final props = event['props'] as Map<String, dynamic>;
      expect(props['available'], isFalse);
    });

    testWidgets('policy_detail_source_preview_opened fires with available:true when document has localFilePath',
        (tester) async {
      // Provide a document with localFilePath set — preview should be available
      final docWithPath = InsuranceDocument(
        id: 'doc-1',
        filename: 'test_policy.pdf',
        uploadedOn: DateTime(2026, 7, 10),
        status: 'completed',
        localFilePath: '/tmp/test_preview.pdf',
      );

      await tester.pumpWidget(buildTestApp(
        documentId: 'doc-1',
        documents: [docWithPath],
      ));
      await tester.pumpAndSettle();

      // Tap the document preview button in the app bar
      await tester.tap(find.byIcon(Icons.description_outlined));
      // Use pump() instead of pumpAndSettle() because the screen may try to
      // read a non-existent file, which prevents animations from settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final event = capturedEvents.firstWhere(
        (e) => e['event'] == 'policy_detail_source_preview_opened',
        orElse: () => <String, dynamic>{},
      );
      expect(event, isNotEmpty);
      final props = event['props'] as Map<String, dynamic>;
      expect(props['available'], isTrue);
    });

    testWidgets('expired policy sets is_expired=true in policy_detail_opened',
        (tester) async {
      final expiredSummary = PolicySummary(
        documentId: 'doc-expired',
        documentType: 'Motor Insurance',
        insurer: 'Test Insurer',
        policyNumber: 'POL-EXPIRED',
        coverageAmount: 200000,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2025, 1, 1), // past — expired
        extractedAt: DateTime(2026, 7, 10),
      );

      await tester.pumpWidget(buildTestApp(
        documentId: 'doc-expired',
        summaries: [expiredSummary],
      ));
      await tester.pumpAndSettle();

      final opened = capturedEvents.firstWhere(
        (e) => e['event'] == 'policy_detail_opened',
        orElse: () => <String, dynamic>{},
      );
      expect(opened, isNotEmpty);
      final props = opened['props'] as Map<String, dynamic>;
      // classifyPolicyType('Motor Insurance') → PolicyType.auto → canonicalTypeName = 'Auto Insurance'
      expect(props['policy_type'], 'Auto Insurance');
      expect(props['is_expired'], isTrue);
    });
  });
}
