import 'dart:convert';
import 'dart:async';

import 'package:coverwise/screens/privacy_policy_screen.dart';
import 'package:coverwise/screens/terms_of_service_screen.dart';
import 'package:coverwise/services/consent_ledger.dart';
import 'package:coverwise/services/legal_content_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/hive_test_helper.dart';

/// Minimal markdown that produces a valid LegalDocument for testing.
const _testMarkdown = '''
# Test Legal Document

**Effective Date:** January 1, 2025

## Section One

Content for section one.

## Section Two

Content for section two.
''';

/// Mock rootBundle to return [content] for .md asset keys.
/// Non-.md assets (MaterialApp icons, fonts, etc.) receive empty bytes
/// so that pumpAndSettle doesn't hang waiting for unresolvable messages.
void _mockAssets(String content) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    if (message != null) {
      final key = utf8.decode(message.buffer.asUint8List());
      if (key.endsWith('.md')) {
        return ByteData.view(Uint8List.fromList(utf8.encode(content)).buffer);
      }
    }
    // Return empty bytes for non-.md assets so pumpAndSettle completes.
    return ByteData.view(Uint8List(0).buffer);
  });
}

/// Mock rootBundle to fail only for .md asset keys.
/// Non-.md assets (MaterialApp icons, fonts, etc.) receive empty bytes.
void _mockAssetsFailing() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    if (message != null) {
      final key = utf8.decode(message.buffer.asUint8List());
      if (key.endsWith('.md')) {
        // Return no response so PlatformAssetBundle creates its normal
        // missing-asset FlutterError. Throwing from this mock trips a
        // catchError return-type assertion in current Flutter bindings.
        return null;
      }
    }
    return ByteData.view(Uint8List(0).buffer);
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HiveTestHelper.setUp();
  });

  setUp(() {
    LegalContentLoader.clearCache();
    // AssetBundle caches loadString futures. Evict both legal keys so each
    // test owns its mock response and cannot inherit a pending future from a
    // preceding test.
    rootBundle.evict('assets/legal/privacy_policy.md');
    rootBundle.evict('assets/legal/terms_of_service.md');
    _mockAssets(_testMarkdown);
  });

  // Intentionally do NOT clear the mock handler in tearDown.
  // Clearing it leaves pending platform messages unresolved, which causes
  // pumpAndSettle to hang in the next test. setUp re-registers the handler
  // before each test, so stale handlers are overwritten automatically.

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  group('PrivacyPolicyScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('displays parsed sections from markdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyScreen()),
      );
      await tester.pumpAndSettle();

      // Sections come from the mocked _testMarkdown
      expect(find.text('Section One'), findsOneWidget);
      expect(find.text('Section Two'), findsOneWidget);
    });

    testWidgets('shows effective date from markdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Effective January 1, 2025'), findsOneWidget);
    });

    testWidgets('copy button triggers clipboard with parsed content',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyScreen()),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();

      expect(find.text('Privacy policy copied to clipboard'), findsOneWidget);
    });

    testWidgets('shows loading indicator while FutureBuilder is loading',
        (tester) async {
      // Use a slow future to observe the loading state.
      // Only intercept .md assets — let other assets resolve normally.
      final completer = Completer<String>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message != null) {
          final key = utf8.decode(message.buffer.asUint8List());
          if (key.endsWith('.md')) {
            final content = await completer.future;
            return ByteData.view(
                Uint8List.fromList(utf8.encode(content)).buffer);
          }
        }
        return ByteData.view(Uint8List(0).buffer);
      });

      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyScreen()),
      );

      // After first pump, FutureBuilder should be in loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Content should NOT be visible yet
      expect(find.text('Section One'), findsNothing);

      // Complete the future
      completer.complete(_testMarkdown);
      await tester.pumpAndSettle();

      // After settling, sections should be visible
      expect(find.text('Section One'), findsOneWidget);
      expect(find.text('Section Two'), findsOneWidget);
      // Loading indicator should be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows error state when asset loading fails', (tester) async {
      _mockAssetsFailing();

      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyScreen()),
      );
      // Use explicit pumps — FlutterError from loadString causes the framework
      // to schedule rebuilds that prevent pumpAndSettle from completing.
      await tester.pump(); // triggers didChangeDependencies → creates _future
      await tester
          .pump(); // Future completes with error → FutureBuilder rebuilds
      await tester.pump(); // final frame

      // Should show error UI
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        find.textContaining('Failed to load privacy policy'),
        findsOneWidget,
      );
      // Should NOT show sections
      expect(find.text('Section One'), findsNothing);
    });

    testWidgets('shows error state when asset loading fails', (tester) async {
      _mockAssetsFailing();

      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyScreen()),
      );
      // Use explicit pumps instead of pumpAndSettle — FlutterError from
      // loadString can cause the framework to schedule rebuilds that
      // prevent pumpAndSettle from ever completing.
      await tester.pump(); // triggers didChangeDependencies → creates _future
      await tester
          .pump(); // Future completes with error → FutureBuilder rebuilds
      await tester.pump(); // final frame

      // Should show error UI
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        find.textContaining('Failed to load privacy policy'),
        findsOneWidget,
      );
      // Should NOT show sections
      expect(find.text('Section One'), findsNothing);
    });
  });

  group('TermsOfServiceScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TermsOfServiceScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('displays parsed sections from markdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TermsOfServiceScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Section One'), findsOneWidget);
      expect(find.text('Section Two'), findsOneWidget);
    });

    testWidgets('shows effective date from markdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TermsOfServiceScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Effective January 1, 2025'), findsOneWidget);
    });

    testWidgets('copy button triggers clipboard with parsed content',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TermsOfServiceScreen()),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();

      expect(find.text('Terms of service copied to clipboard'), findsOneWidget);
    });

    testWidgets('shows error state when asset loading fails', (tester) async {
      _mockAssetsFailing();

      await tester.pumpWidget(
        const MaterialApp(home: TermsOfServiceScreen()),
      );
      // Use explicit pumps — FlutterError from loadString causes the framework
      // to schedule rebuilds that prevent pumpAndSettle from completing.
      await tester.pump(); // triggers didChangeDependencies → creates _future
      await tester
          .pump(); // Future completes with error → FutureBuilder rebuilds
      await tester.pump(); // final frame

      // Should show error UI
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        find.textContaining('Failed to load terms of service'),
        findsOneWidget,
      );
    });
  });

  group('LegalDocument.toPlainText()', () {
    test('formats document with title, date, and sections', () {
      const doc = LegalDocument(
        title: 'Test Title',
        effectiveDate: 'January 1, 2025',
        sections: [
          LegalSection(title: 'Section 1', content: 'Content A'),
          LegalSection(title: 'Section 2', content: 'Content B'),
        ],
        rawMarkdown: '',
      );

      final text = doc.toPlainText();

      expect(text, contains('Test Title (Effective January 1, 2025)'));
      expect(text, contains('Section 1'));
      expect(text, contains('Content A'));
      expect(text, contains('Section 2'));
      expect(text, contains('Content B'));
    });

    test('handles empty sections', () {
      const doc = LegalDocument(
        title: 'Empty Doc',
        effectiveDate: '',
        sections: [],
        rawMarkdown: '',
      );

      final text = doc.toPlainText();

      expect(text, contains('Empty Doc (Effective )'));
      expect(text, isNot(contains('Section')));
    });
  });

  group('LegalContentLoader.parseMarkdown()', () {
    test('parses H1 title, effective date, and H2 sections', () {
      final doc = LegalContentLoader.parseMarkdownForTest(
        _testMarkdown,
        'Fallback',
      );

      expect(doc.title, 'Test Legal Document');
      expect(doc.effectiveDate, 'January 1, 2025');
      expect(doc.sections.length, 2);
      expect(doc.sections[0].title, 'Section One');
      expect(doc.sections[1].title, 'Section Two');
    });

    test('uses fallback title when no H1 found', () {
      final doc = LegalContentLoader.parseMarkdownForTest(
        '## Only Section\n\nContent here.',
        'Fallback Title',
      );

      expect(doc.title, 'Fallback Title');
      expect(doc.sections.length, 1);
      expect(doc.sections[0].title, 'Only Section');
    });

    test('handles empty markdown', () {
      final doc = LegalContentLoader.parseMarkdownForTest('', 'Fallback');

      expect(doc.title, 'Fallback');
      expect(doc.sections, isEmpty);
    });
  });

  group('Onboarding consent checkbox', () {
    testWidgets('checkbox is unchecked by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  Checkbox(value: false, onChanged: (_) {}),
                  FilledButton(
                    onPressed: null,
                    child: const Text('Add my first policy'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add my first policy'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('checkbox enables CTA when checked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  StatefulBuilder(
                    builder: (context, setState) => Checkbox(
                      value: false,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Add my first policy'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add my first policy'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('privacy policy link navigates to screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
                child: const Text('Privacy Policy'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy Policy'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    });

    testWidgets('terms of service link navigates to screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen(),
                  ),
                ),
                child: const Text('Terms of Service'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terms of Service'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
    });

    test('consent is persisted in ledger', () async {
      final ledger = ConsentLedger();

      await ledger.recordConsent(
        purpose: ConsentPurpose.termsAccepted,
        version: 'terms-v1',
        granted: true,
      );

      expect(ledger.hasConsent(ConsentPurpose.termsAccepted), isTrue);

      await ledger.recordConsent(
        purpose: ConsentPurpose.termsAccepted,
        version: 'terms-v1',
        granted: false,
      );

      expect(ledger.hasConsent(ConsentPurpose.termsAccepted), isFalse);
    });
  });
}
