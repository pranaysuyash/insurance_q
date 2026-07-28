import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/family_providers.dart';
import 'package:coverwise/screens/family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/hive_test_helper.dart';
import 'package:coverwise/l10n/app_localizations_gen.dart';

/// Helper to create a test document with named policy holders.
InsuranceDocument _makeDoc({
  required String id,
  required String filename,
  String type = 'Health Insurance',
  String? insurer,
  List<PolicyHolder>? holders,
}) {
  return InsuranceDocument(
    id: id,
    filename: filename,
    uploadedOn: DateTime(2026, 7, 1),
    status: 'completed',
    documentType: type,
    insurer: insurer,
    policyHolders: holders,
  );
}

/// Helper to create a test policy holder.
PolicyHolder _makeHolder({
  required String name,
  String relationship = 'Insured',
  bool isManual = false,
}) {
  return PolicyHolder(
    name: name,
    relationship: relationship,
    source: isManual ? 'manual' : 'document',
  );
}

void main() {
  setUpAll(() async {
    await HiveTestHelper.setUp();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  group('FamilyScreen — empty state', () {
    testWidgets('shows empty state when no documents', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) async => const []),
            mergedFamilyMembersProvider.overrideWith(
              (_, __) async => <String, PolicyHolder>{},
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
            home: const FamilyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state should render since no documents → no members
      // The empty state icon appears when docs are empty
      expect(find.byIcon(Icons.family_restroom), findsOneWidget);
      // S.familyNoMembersYet = "No family members yet"
      expect(find.text('No family members yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FamilyScreen — member card rendering', () {
    final john = _makeHolder(name: 'John Doe', relationship: 'Primary Insured');
    final jane = _makeHolder(name: 'Jane Doe', relationship: 'Spouse');

    final policies = [
      _makeDoc(
        id: 'doc-1',
        filename: 'health_icici.pdf',
        type: 'Health Insurance',
        insurer: 'ICICI Lombard',
        holders: [john, jane],
      ),
      _makeDoc(
        id: 'doc-2',
        filename: 'auto_bajaj.pdf',
        type: 'Auto Insurance',
        insurer: 'Bajaj Allianz',
        holders: [john],
      ),
    ];

    final mergedMap = {'John Doe': john, 'Jane Doe': jane};

    Widget buildFamilyScreen() {
      return ProviderScope(
        overrides: [
          documentsProvider.overrideWith((ref) async => policies),
          mergedFamilyMembersProvider.overrideWith(
            (_, __) async => mergedMap,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
          home: const FamilyScreen()),
      );
    }

    testWidgets('renders member names and relationships', (tester) async {
      await tester.pumpWidget(buildFamilyScreen());
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsWidgets);
      expect(find.text('Jane Doe'), findsWidgets);
      expect(find.text('Primary Insured'), findsOneWidget);
      expect(find.text('Spouse'), findsOneWidget);
    });

    testWidgets('shows policy count badge on members with policies',
        (tester) async {
      await tester.pumpWidget(buildFamilyScreen());
      await tester.pumpAndSettle();

      // John is covered by 2 policies, Jane by 1
      expect(find.text('2 policies'), findsOneWidget);
      expect(find.text('1 policy'), findsOneWidget);
    });

    testWidgets('shows expand toggle text with correct policy count',
        (tester) async {
      await tester.pumpWidget(buildFamilyScreen());
      await tester.pumpAndSettle();

      // John has 2 policies → "View 2 policies covering John Doe"
      expect(find.textContaining('View'), findsWidgets);
      // Appears in badge ("2 policies") and toggle text ("View 2 policies...")
      expect(find.textContaining('2 polic'), findsWidgets);
    });

    testWidgets('tapping expand reveals inline policy list', (tester) async {
      await tester.pumpWidget(buildFamilyScreen());
      await tester.pumpAndSettle();

      // Tap the expand toggle for John (exact text to avoid badge ambiguity)
      await tester.tap(find.text('View 2 policies covering John Doe'));
      await tester.pumpAndSettle();

      // Policy assignment list appears with policy type names.
      // Use findsWidgets because the coverage matrix may also show these.
      expect(find.text('Health Insurance'), findsWidgets);
      expect(find.text('Auto Insurance'), findsOneWidget);
      expect(find.text('Covered by:'), findsWidgets);
    });

    testWidgets('tapping expand shows insurer names', (tester) async {
      await tester.pumpWidget(buildFamilyScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('View 2 policies covering John Doe'));
      await tester.pumpAndSettle();

      // Insurer names appear in the expanded policy tiles.
      // Use findsWidgets because the coverage matrix may also show these.
      expect(find.text('ICICI Lombard'), findsWidgets);
      expect(find.text('Bajaj Allianz'), findsOneWidget);
    });

    testWidgets('expand toggle shows Hide label after expansion',
        (tester) async {
      await tester.pumpWidget(buildFamilyScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('View 2 policies covering John Doe'));
      await tester.pumpAndSettle();

      expect(find.text('Hide policy assignments'), findsOneWidget);
    });

    testWidgets('tap expand again collapses the policy list', (tester) async {
      await tester.pumpWidget(buildFamilyScreen());
      await tester.pumpAndSettle();

      // Expand
      await tester.tap(find.text('View 2 policies covering John Doe'));
      await tester.pumpAndSettle();
      expect(find.text('Hide policy assignments'), findsOneWidget);

      // Collapse
      await tester.tap(find.text('Hide policy assignments'));
      await tester.pumpAndSettle();

      // After collapsing, the expand toggle text returns.
      // AnimatedCrossFade builds both children, so "Covered by:" is
      // always present. Instead verify the toggle state flipped.
      expect(find.text('View 2 policies covering John Doe'), findsOneWidget);
      expect(find.text('Hide policy assignments'), findsNothing);
    });
  });

  group('FamilyScreen — single member single policy', () {
    final alice = _makeHolder(name: 'Alice');

    final policies = [
      _makeDoc(
        id: 'doc-1',
        filename: 'life_hdfc.pdf',
        type: 'Life Insurance',
        insurer: 'HDFC Life',
        holders: [alice],
      ),
    ];

    testWidgets('does not show coverage matrix with 1 member and 1 doc',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) async => policies),
            mergedFamilyMembersProvider.overrideWith(
              (_, __) async => {'Alice': alice},
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
            home: const FamilyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Coverage matrix section label should not appear (uppercased by
      // CoverWiseSectionLabel). If this assertion ever fails, a matrix
      // rendering regression is introducing the label.
      expect(find.text('COVERAGE SUMMARY'), findsNothing);
    });
  });

  group('FamilyScreen — coverage matrix with 3 members 3 policies', () {
    // No underscore prefix on locals to avoid analyzer warnings.
    final matJohn = _makeHolder(name: 'John Doe', relationship: 'Primary Insured');
    final matJane = _makeHolder(name: 'Jane Doe', relationship: 'Spouse');

    // Use a member name unique to the matrix so assertions don't
    // overlap with member card text.
    final matExtra = _makeHolder(name: 'Zara Extra', relationship: 'Dependent');

    final policies = [
      _makeDoc(
        id: 'doc-x1',
        filename: 'health_x.pdf',
        type: 'Health Insurance',
        insurer: 'ICICI Lombard',
        holders: [matJohn, matJane],
      ),
      _makeDoc(
        id: 'doc-x2',
        filename: 'auto_x.pdf',
        type: 'Auto Insurance',
        insurer: 'Bajaj Allianz',
        holders: [matJohn],
      ),
      // Third doc so the matrix has 3 columns
      _makeDoc(
        id: 'doc-x3',
        filename: 'life_x.pdf',
        type: 'Life Insurance',
        insurer: 'HDFC Life',
        holders: [matExtra],
      ),
    ];

    final mergedMap = {
      'John Doe': matJohn,
      'Jane Doe': matJane,
      'Zara Extra': matExtra,
    };

    Widget buildFamilyScreen() {
      return ProviderScope(
        overrides: [
          documentsProvider.overrideWith((ref) async => policies),
          mergedFamilyMembersProvider.overrideWith(
            (_, __) async => mergedMap,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
          home: const FamilyScreen()),
      );
    }

    testWidgets('renders coverage matrix section label', (tester) async {
      await tester.pumpWidget(buildFamilyScreen());
      await tester.pumpAndSettle();

      // CoverWiseSectionLabel uppercases its label.
      expect(find.text('COVERAGE SUMMARY'), findsOneWidget);
    });

    testWidgets('renders member names in the matrix', (tester) async {
      await tester.pumpWidget(buildFamilyScreen());
      await tester.pumpAndSettle();

      // Zara Extra appears in both the member card AND the coverage
      // matrix row label (mergedMap includes Zara).
      await tester.scrollUntilVisible(find.text('Zara Extra'), 200);
      expect(find.text('Zara Extra'), findsWidgets);
    });

    testWidgets('coverage matrix content renders', (tester) async {
      await tester.pumpWidget(buildFamilyScreen());
      await tester.pumpAndSettle();

      // First verify no build error
      expect(tester.takeException(), isNull);

      // Scroll to make sure the matrix is in view
      await tester.scrollUntilVisible(find.text('COVERAGE SUMMARY'), 200);
      await tester.pumpAndSettle();

      // Matrix should be horizontally scrollable
      expect(find.byType(SingleChildScrollView), findsWidgets);

      // Check icons should appear (John covered by both, Jane by one)
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);

      // Remove icons for uncovered cells (e.g. Jane not in auto, Zara not in health/auto)
      expect(
          find.byIcon(Icons.remove_circle_outline_rounded), findsWidgets);
    });
  });

  group('FamilyScreen — member card edge cases', () {
    // Must provide at least one document so _FamilyList renders
    // (FamilyMembersContent checks documents.isEmpty first).
    final memberDoc = _makeDoc(
      id: 'doc-dummy',
      filename: 'doc.pdf',
      type: 'Health Insurance',
      holders: [],
    );

    testWidgets('no expand toggle when member has zero policies',
        (tester) async {
      final solo = _makeHolder(name: 'Solo Member');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) async => [memberDoc]),
            mergedFamilyMembersProvider.overrideWith(
              (_, __) async => {'Solo Member': solo},
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
            home: const FamilyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Member name renders
      expect(find.text('Solo Member'), findsOneWidget);

      // No expand toggle — the toggle text format is "View N polic(y|ies)
      // covering NAME". Check for absence of that specific pattern.
      // Don't check for bare "polic" — it matches "policies" in the
      // page header subtitle ("A clear view of the people found in your
      // policies...").
      expect(find.textContaining('policies covering'), findsNothing);
      expect(find.textContaining('Hide policy'), findsNothing);
    });

    testWidgets('manual member shows manual badge', (tester) async {
      final manual = _makeHolder(
        name: 'Manual Mem',
        relationship: 'Dependent',
        isManual: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) async => [memberDoc]),
            mergedFamilyMembersProvider.overrideWith(
              (_, __) async => {'Manual Mem': manual},
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
            home: const FamilyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // S.familyManualBadge = "Manual"
      expect(find.text('Manual'), findsOneWidget);
    });
  });
}
