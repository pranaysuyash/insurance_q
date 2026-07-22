import 'dart:async';
import 'dart:io';

import 'package:coverwise/models/entitlement.dart';
import 'package:coverwise/providers/entitlement_provider.dart';
import 'package:coverwise/screens/upgrade_screen.dart';
import 'package:coverwise/services/billing_adapter.dart';
import 'package:coverwise/services/entitlement_service.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Fake EntitlementService for testing.
class FakeEntitlementService extends EntitlementService {
  Entitlement _current;
  FakeEntitlementService(this._current);

  @override
  Entitlement current() => _current;

  @override
  Future<void> setPlan(PlanTier tier, {DateTime? expiresAt}) async {
    _current = _current.copyWith(
      planTier: tier,
      expiresAt: expiresAt ?? _current.expiresAt,
    );
  }
}

/// Fake BillingAdapter that doesn't require RevenueCat SDK.
class FakeBillingAdapter extends BillingAdapter {
  Entitlement? purchaseResult;
  bool manageResult = true;
  Completer<Entitlement?>? purchaseCompleter;

  FakeBillingAdapter(super.service);

  @override
  Future<void> initialize({required String apiKey}) async {}

  @override
  Future<void> syncEntitlement() async {}

  @override
  Future<Entitlement?> purchasePlan(PlanTier tier,
      {bool annual = false}) async {
    if (purchaseCompleter != null) {
      return purchaseCompleter!.future;
    }
    return purchaseResult;
  }

  @override
  Future<bool> manageSubscription() async => manageResult;
}

/// Helper to pump and resolve async providers.
Future<void> _pumpAndResolve(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump();
}

/// Helper to scroll to a widget and tap it.
Future<void> _scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.tap(finder);
}

/// Build an UpgradeScreen with overridden providers.
Widget buildUpgradeScreen({
  Entitlement? entitlement,
  AsyncValue<void>? billingState,
  FakeBillingAdapter? billingAdapter,
  String? entryMessage,
}) {
  final fakeService = FakeEntitlementService(
    entitlement ?? const Entitlement(),
  );
  final fakeBilling = billingAdapter ?? FakeBillingAdapter(fakeService);

  return ProviderScope(
    overrides: [
      entitlementServiceProvider.overrideWithValue(fakeService),
      entitlementProvider.overrideWith(EntitlementNotifier.new),
      billingAdapterProvider.overrideWithValue(fakeBilling),
      billingInitProvider.overrideWith((ref) async {
        if (billingState is AsyncError) {
          throw Exception('Billing init failed');
        }
        return;
      }),
    ],
    child: MaterialApp(home: UpgradeScreen(entryMessage: entryMessage)),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return '/tmp/coverwise-upgrade-tests';
    });
    final dir = Directory('/tmp/coverwise-upgrade-tests');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    await dir.create(recursive: true);
    await Hive.initFlutter(dir.path);
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
    try {} catch (_) {}
  });

  group('UpgradeScreen — UI rendering', () {
    testWidgets('renders without crash on free tier', (tester) async {
      await tester.pumpWidget(buildUpgradeScreen());
      await _pumpAndResolve(tester);

      expect(find.byType(UpgradeScreen), findsOneWidget);
      expect(find.text('Choose your plan'), findsOneWidget);
      expect(find.text('Current plan: Free'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows limit context without duplicating plan pricing',
        (tester) async {
      await tester.pumpWidget(buildUpgradeScreen(
        entryMessage: 'You have reached the policy limit for your plan.',
      ));
      await _pumpAndResolve(tester);

      expect(find.text('Plan limit reached'), findsOneWidget);
      expect(
        find.text('You have reached the policy limit for your plan.'),
        findsOneWidget,
      );
      expect(find.text('Notify Me When Available'), findsNothing);
      expect(find.textContaining('Launch offer'), findsNothing);
    });

    testWidgets('shows Annual/Monthly toggle when billing is ready',
        (tester) async {
      await tester.pumpWidget(buildUpgradeScreen());
      await _pumpAndResolve(tester);

      expect(find.text('Annual'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.textContaining('Save up to 44%'), findsOneWidget);
    });

    testWidgets('hides Annual/Monthly toggle when billing is not ready',
        (tester) async {
      await tester.pumpWidget(
        buildUpgradeScreen(
            billingState: AsyncError('failed', StackTrace.empty)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Annual'), findsNothing);
      expect(find.text('Monthly'), findsNothing);
    });

    testWidgets('renders all three plan cards', (tester) async {
      await tester.pumpWidget(buildUpgradeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Free'), findsWidgets);
      expect(find.text('Plus'), findsWidgets);
      expect(find.text('Family'), findsWidgets);
    });

    testWidgets('shows "Current plan" button for current tier', (tester) async {
      await tester.pumpWidget(buildUpgradeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Current plan'), findsOneWidget);
    });

    testWidgets('shows upgrade buttons for non-current tiers', (tester) async {
      await tester.pumpWidget(buildUpgradeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Upgrade to Plus'), findsOneWidget);
      expect(find.text('Upgrade to Family'), findsOneWidget);
    });

    testWidgets('renders feature comparison table', (tester) async {
      await tester.pumpWidget(buildUpgradeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Compare plans'), findsOneWidget);
    });

    testWidgets('renders FAQ items', (tester) async {
      await tester.pumpWidget(buildUpgradeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Questions'), findsOneWidget);
      expect(find.text('Can I switch plans?'), findsOneWidget);
    });
  });

  group('UpgradeScreen — purchase flow', () {
    testWidgets('shows loading indicator when purchase is in progress',
        (tester) async {
      final fakeService = FakeEntitlementService(const Entitlement());
      final fakeBilling = FakeBillingAdapter(fakeService);
      fakeBilling.purchaseCompleter = Completer<Entitlement?>();

      await tester.pumpWidget(buildUpgradeScreen(
        entitlement: const Entitlement(),
        billingAdapter: fakeBilling,
      ));
      await tester.pumpAndSettle();

      await _scrollAndTap(tester, find.text('Upgrade to Plus'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Upgrade to Plus'), findsNothing);

      fakeBilling.purchaseCompleter!.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('shows success message after successful purchase',
        (tester) async {
      final fakeService = FakeEntitlementService(const Entitlement());
      final fakeBilling = FakeBillingAdapter(fakeService);
      fakeBilling.purchaseResult = const Entitlement(planTier: PlanTier.plus);

      await tester.pumpWidget(buildUpgradeScreen(
        entitlement: const Entitlement(),
        billingAdapter: fakeBilling,
      ));
      await tester.pumpAndSettle();

      await _scrollAndTap(tester, find.text('Upgrade to Plus'));
      await _pumpAndResolve(tester);

      expect(find.text('Plan upgraded! New features are now available.'),
          findsOneWidget);
      expect(find.text('Start using'), findsOneWidget);
    });

    testWidgets('no success message when purchase returns null',
        (tester) async {
      final fakeService = FakeEntitlementService(const Entitlement());
      final fakeBilling = FakeBillingAdapter(fakeService);
      fakeBilling.purchaseResult = null;

      await tester.pumpWidget(buildUpgradeScreen(
        entitlement: const Entitlement(),
        billingAdapter: fakeBilling,
      ));
      await tester.pumpAndSettle();

      await _scrollAndTap(tester, find.text('Upgrade to Plus'));
      await _pumpAndResolve(tester);

      expect(find.text('Plan upgraded!'), findsNothing);
    });

    testWidgets('enables upgrade button when billing is ready', (tester) async {
      final fakeService = FakeEntitlementService(const Entitlement());
      final fakeBilling = FakeBillingAdapter(fakeService);

      await tester.pumpWidget(buildUpgradeScreen(
        entitlement: const Entitlement(),
        billingAdapter: fakeBilling,
      ));
      await tester.pumpAndSettle();

      final plusButton = find.widgetWithText(FilledButton, 'Upgrade to Plus');
      final button = tester.widget<FilledButton>(plusButton);
      expect(button.onPressed, isNotNull);
    });
  });

  group('UpgradeScreen — annual/monthly toggle', () {
    testWidgets('defaults to annual pricing', (tester) async {
      await tester.pumpWidget(buildUpgradeScreen());
      await tester.pumpAndSettle();

      expect(find.text('₹999/yr'), findsOneWidget);
      expect(find.text('₹1,799/yr'), findsOneWidget);
    });

    testWidgets('switches to monthly pricing when toggled', (tester) async {
      await tester.pumpWidget(buildUpgradeScreen());
      await tester.pumpAndSettle();

      await _scrollAndTap(tester, find.text('Monthly'));
      await tester.pumpAndSettle();

      expect(find.text('₹149/mo'), findsOneWidget);
      expect(find.text('₹249/mo'), findsOneWidget);
    });
  });

  group('UpgradeScreen — manage subscription', () {
    testWidgets('shows manage button for paid plans', (tester) async {
      await tester.pumpWidget(buildUpgradeScreen(
        entitlement: const Entitlement(planTier: PlanTier.plus),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Manage'), findsOneWidget);
    });

    testWidgets('hides manage button for free tier', (tester) async {
      await tester.pumpWidget(buildUpgradeScreen());
      await tester.pumpAndSettle();

      expect(find.text('Manage'), findsNothing);
    });
  });
}
