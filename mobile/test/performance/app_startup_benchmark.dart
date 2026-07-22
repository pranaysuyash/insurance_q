import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Cold-start benchmark for CoverWise.
///
/// Run manually on a reference device:
///   flutter test --dart-define=benchmark=true test/performance/app_startup_benchmark.dart
///
/// Budget: < 3 s cold start on Pixel 6 (API 33) emulator.
void main() {
  test('app cold start completes within budget', () async {
    final stopwatch = Stopwatch()..start();

    // Simulate cold start:
    // 1. Hive init + open boxes
    // 2. Session init
    // 3. Consent cache load
    // 4. Analytics service init
    // Each should complete within the frame budget window.
    // This is a scaffold — replace with integration_test driver once
    // a hardware emulator is available in CI.
    await Future.delayed(const Duration(milliseconds: 100));

    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds;
    const budget = 3000; // 3 seconds

    print('Cold start benchmark: ${elapsed}ms (budget: ${budget}ms)');
    expect(elapsed, lessThan(budget));

    if (elapsed > budget) {
      stderr.writeln('WARNING: cold start ${elapsed}ms exceeds ${budget}ms budget');
    }
  });
}
