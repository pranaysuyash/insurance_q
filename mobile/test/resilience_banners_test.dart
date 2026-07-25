import 'package:coverwise/providers/backend_health_provider.dart';
import 'package:coverwise/providers/connectivity_provider.dart';
import 'package:coverwise/screens/splash_screen.dart';
import 'package:coverwise/widgets/shared/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a recoverable service warning when online health fails',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendHealthProvider.overrideWith((ref) async => false),
          isOnlineProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          home: SplashScreen(
            onComplete: () {},
            minimumDuration: const Duration(days: 1),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Service unavailable. Some features may be limited. Reconnecting…'),
      findsOneWidget,
    );
  });

  testWidgets('explains offline limits without hiding local-document access',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
      ),
    );

    expect(
      find.text(
        "You're offline. Documents are available locally, but Ask and uploads need a connection.",
      ),
      findsOneWidget,
    );
  });
}
