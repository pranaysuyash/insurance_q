import 'package:coverwise/theme/coverwise_motion.dart';
import 'package:coverwise/screens/onboarding_screen.dart';
import 'package:coverwise/utils/policy_type.dart';
import 'package:coverwise/widgets/shared/policy_type_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _motionHost({required bool reduceMotion, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData().copyWith(disableAnimations: reduceMotion),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('motion tokens retain their configured duration by default',
      (tester) async {
    await tester.pumpWidget(_motionHost(
      reduceMotion: false,
      child: Builder(
        builder: (context) => Text(
          '${CoverWiseMotion.duration(context, CoverWiseMotion.standard).inMilliseconds}',
        ),
      ),
    ));

    expect(find.text('220'), findsOneWidget);
  });

  testWidgets('motion tokens resolve to zero for Reduce Motion',
      (tester) async {
    await tester.pumpWidget(_motionHost(
      reduceMotion: true,
      child: Builder(
        builder: (context) => Column(
          children: [
            Text(
              '${CoverWiseMotion.duration(context, CoverWiseMotion.emphasized).inMilliseconds}',
            ),
            CoverWiseStateTransition(
              child: Container(key: const ValueKey('state')),
            ),
          ],
        ),
      ),
    ));

    expect(find.text('0'), findsOneWidget);
    expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero);
  });

  testWidgets('state transition uses the canonical standard token',
      (tester) async {
    await tester.pumpWidget(_motionHost(
      reduceMotion: false,
      child: const CoverWiseStateTransition(
        child: SizedBox(key: ValueKey('ready')),
      ),
    ));

    final switcher =
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
    expect(switcher.duration, CoverWiseMotion.standard);
    expect(switcher.switchInCurve, CoverWiseMotion.enterCurve);
    expect(switcher.switchOutCurve, CoverWiseMotion.exitCurve);
  });

  testWidgets('policy-type selection motion is disabled by Reduce Motion',
      (tester) async {
    await tester.pumpWidget(_motionHost(
      reduceMotion: true,
      child: const PolicyTypeIcon(type: PolicyType.health, selected: true),
    ));

    final animated = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).first,
    );
    expect(animated.duration, Duration.zero);
  });

  testWidgets('onboarding uses static artwork motion when requested',
      (tester) async {
    await tester.pumpWidget(_motionHost(
      reduceMotion: true,
      child: OnboardingScreen(onComplete: ({bool openFilePicker = false}) {}),
    ));
    await tester.pump();

    final artwork = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>).first,
    );
    expect(artwork.duration, Duration.zero);
  });

  testWidgets('onboarding remains usable at large text on a compact screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
          disableAnimations: true,
        ),
        child: OnboardingScreen(onComplete: ({bool openFilePicker = false}) {}),
      ),
    ));
    await tester.pump();

    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
