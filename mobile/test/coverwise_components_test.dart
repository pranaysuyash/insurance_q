import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/theme/coverwise_theme.dart';
import 'package:coverwise/widgets/shared/coverwise_components.dart';
import 'package:coverwise/widgets/shared/empty_state_widget.dart';
import 'package:coverwise/widgets/shared/coverwise_scene.dart';

Widget _host(Widget child, {ThemeData? theme, double textScale = 1}) {
  return MaterialApp(
    theme: theme ?? CoverWiseTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('status chip exposes text status independent of color',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const Center(
          child: CoverWiseStatusChip(
            icon: Icons.schedule_rounded,
            label: '12 days left',
            color: Colors.orange,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Status: 12 days left'), findsOneWidget);
    expect(find.text('12 days left'), findsOneWidget);
  });

  testWidgets('empty state uses the action-specific icon', (tester) async {
    await tester.pumpWidget(
      _host(
        EmptyStateWidget(
          icon: Icons.manage_search_rounded,
          title: 'Summary not ready',
          actionLabel: 'Ask about this policy',
          actionIcon: Icons.chat_bubble_outline_rounded,
          onAction: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('shared state components remain usable in dark mode at 2x text',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        const SingleChildScrollView(
          child: Column(
            children: [
              EmptyStateWidget(
                icon: Icons.family_restroom_rounded,
                title: 'No family members yet',
                subtitle: 'Add someone manually or upload a policy.',
                color: Color(0xFF16866B),
              ),
              CoverWiseInfoPanel(
                icon: Icons.info_outline_rounded,
                title: 'General guidance only',
                body: 'Policy-specific contacts are not available.',
              ),
            ],
          ),
        ),
        theme: CoverWiseTheme.dark(),
        textScale: 2,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('No family members yet'), findsOneWidget);
    expect(find.text('General guidance only'), findsOneWidget);
  });

  testWidgets('typed first-policy scene loads and remains decorative',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const CoverWiseScene(scene: CoverWiseSceneKind.firstPolicy),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.excludeFromSemantics, isTrue);
    expect(tester.takeException(), isNull);
  });
}
