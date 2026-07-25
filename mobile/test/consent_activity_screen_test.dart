import 'package:coverwise/screens/consent_activity_screen.dart';
import 'package:coverwise/services/server_consent_service.dart';
import 'package:coverwise/theme/coverwise_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConsentService extends ServerConsentService {
  final List<ServerConsentRecord>? result;

  _FakeConsentService(this.result) : super(dio: Dio());

  @override
  Future<List<ServerConsentRecord>?> getConsentHistory({
    int limit = 100,
  }) async =>
      result;
}

ServerConsentRecord _record({
  required String type,
  required bool granted,
  required String version,
  required DateTime createdAt,
}) =>
    ServerConsentRecord(
      id: '$type-$version',
      userId: 'user-1',
      consentType: type,
      granted: granted,
      policyVersion: version,
      ipAddress: null,
      userAgent: null,
      createdAt: createdAt,
    );

Widget _app(ServerConsentService service) => MaterialApp(
      theme: CoverWiseTheme.light(),
      home: ConsentActivityScreen(service: service),
    );

void main() {
  testWidgets('renders grouped consent history without sensitive metadata',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _app(
        _FakeConsentService([
          _record(
            type: 'analytics',
            granted: false,
            version: 'analytics-v1',
            createdAt: DateTime.utc(2026, 7, 25, 8, 30),
          ),
          _record(
            type: 'document_processing',
            granted: true,
            version: 'processing-v2',
            createdAt: DateTime.utc(2026, 7, 24, 8, 30),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your privacy choices'), findsOneWidget);
    expect(find.text('Analytics declined'), findsOneWidget);
    expect(find.text('Document processing allowed'), findsOneWidget);
    expect(find.text('Policy analytics-v1'), findsOneWidget);
    expect(find.text('July 2026'), findsOneWidget);
    expect(find.textContaining('192.'), findsNothing);
    expect(find.textContaining('user-1'), findsNothing);
  });

  testWidgets('shows an honest unavailable state instead of partial history',
      (tester) async {
    await tester.pumpWidget(_app(_FakeConsentService(null)));
    await tester.pumpAndSettle();

    expect(find.text('Consent history unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('partial record as complete'), findsOneWidget);
  });

  testWidgets('shows a teaching empty state', (tester) async {
    await tester.pumpWidget(_app(_FakeConsentService(const [])));
    await tester.pumpAndSettle();

    expect(find.text('No consent activity yet'), findsOneWidget);
    expect(find.textContaining('policy version and time'), findsOneWidget);
  });

  testWidgets('remains usable on a narrow screen at 200 percent text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: CoverWiseTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: ConsentActivityScreen(
          service: _FakeConsentService([
            _record(
              type: 'document_processing',
              granted: true,
              version: 'processing-v2',
              createdAt: DateTime.utc(2026, 7, 24, 8, 30),
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Document processing allowed'),
      240,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Document processing allowed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
