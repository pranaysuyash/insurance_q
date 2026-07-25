import 'dart:io';
import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/providers/auth_provider.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/screens/profile_screen.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeUser extends User {
  _FakeUser()
      : super(
          id: 'test-user-id',
          aud: 'authenticated',
          appMetadata: const {},
          userMetadata: const {},
          createdAt: '2026-01-01T00:00:00Z',
        );
  @override
  String? get email => 'test@example.com';
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return '/tmp/coverwise-diag-tests';
    });
    await Directory('/tmp/coverwise-diag-tests').create(recursive: true);
    await Hive.initFlutter('/tmp/coverwise-diag-tests');
    if (!Hive.isBoxOpen(LocalStorageService.documentsBoxName)) {
      await Hive.openBox<String>(LocalStorageService.documentsBoxName);
    }
    if (!Hive.isBoxOpen(AppStateStore.boxName)) {
      await Hive.openBox(AppStateStore.boxName);
    }
    if (!Hive.isBoxOpen('resolved_gaps')) {
      await Hive.openBox('resolved_gaps');
    }
    if (!Hive.isBoxOpen('analytics_events')) {
      await Hive.openBox('analytics_events');
    }
    if (!Hive.isBoxOpen('consent_ledger')) {
      await Hive.openBox('consent_ledger');
    }
  });

  tearDownAll(() async {
    try { await Hive.close(); } catch (_) {}
  });

  testWidgets('debug: read documentsProvider after override', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testDocs = [
      InsuranceDocument(
        id: 'doc-1',
        filename: 'health.pdf',
        uploadedOn: DateTime(2026, 7, 10),
        processingState: 'processing',
      ),
    ];

    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsProvider.overrideWith((ref) async => testDocs),
          currentUserProvider.overrideWithValue(_FakeUser()),
        ],
        child: MaterialApp(
          home: _CapturingScreen(
            onRef: (ref) => capturedRef = ref,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Read the provider and print what we get
    final asyncValue = capturedRef.read(documentsProvider);
    print('asyncValue runtimeType: ${asyncValue.runtimeType}');
    print('asyncValue: $asyncValue');
    print('valueOrNull: ${asyncValue.valueOrNull}');
    print('valueOrNull type: ${asyncValue.valueOrNull?.runtimeType}');
    if (asyncValue.valueOrNull != null) {
      for (final doc in asyncValue.valueOrNull!) {
        print('  doc: ${doc.id}, state: ${doc.processingState}');
      }
    }

    // Now test the ProfileScreen directly
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsProvider.overrideWith((ref) async => testDocs),
          currentUserProvider.overrideWithValue(_FakeUser()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Delete account'), 200);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    // Check what's on screen
    final allText = find.byType(Text);
    final widgetCount = allText.evaluate().length;
    print('Total Text widgets after tap: $widgetCount');
    for (int i = 0; i < widgetCount && i < 30; i++) {
      final widget = allText.at(i).widget as Text;
      print('  Text[$i]: "${widget.data}"');
    }

    print('still processing found: ${find.textContaining('still processing').evaluate().length}');
    print('Delete account permanently? found: ${find.text('Delete account permanently?').evaluate().length}');
  });
}

class _CapturingScreen extends ConsumerWidget {
  final void Function(WidgetRef ref) onRef;
  const _CapturingScreen({required this.onRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onRef(ref);
    return const Scaffold(body: Text('capturing'));
  }
}
