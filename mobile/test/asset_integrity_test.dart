import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

Future<({double visibleRatio, int colorBuckets})> _inspectPng(
  String path,
) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: 64,
    targetHeight: 64,
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(data, isNotNull, reason: '$path must decode to RGBA pixels');

  var visible = 0;
  final buckets = <int>{};
  final raw = data!.buffer.asUint8List();
  for (var index = 0; index < raw.length; index += 4) {
    final red = raw[index];
    final green = raw[index + 1];
    final blue = raw[index + 2];
    final alpha = raw[index + 3];
    if (alpha > 20) {
      visible++;
      buckets.add((red ~/ 24 << 8) | (green ~/ 24 << 4) | (blue ~/ 24));
    }
  }
  frame.image.dispose();
  codec.dispose();
  return (
    visibleRatio: visible / (raw.length / 4),
    colorBuckets: buckets.length,
  );
}

Future<({int red, int green, int blue, int alpha})> _pixelAt(
  String path,
  double x,
  double y,
) async {
  const size = 128;
  final codec = await ui.instantiateImageCodec(
    await File(path).readAsBytes(),
    targetWidth: size,
    targetHeight: size,
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(data, isNotNull);
  final raw = data!.buffer.asUint8List();
  final px = (x * (size - 1)).round().clamp(0, size - 1);
  final py = (y * (size - 1)).round().clamp(0, size - 1);
  final offset = (py * size + px) * 4;
  final result = (
    red: raw[offset],
    green: raw[offset + 1],
    blue: raw[offset + 2],
    alpha: raw[offset + 3],
  );
  frame.image.dispose();
  codec.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canonical branding rasters decode with visible color variation',
      () async {
    final expectations = <String, int>{
      'assets/branding/coverwise_icon.png': 5,
      'assets/branding/coverwise_foreground.png': 3,
      'assets/branding/coverwise_splash.png': 3,
      'assets/branding/coverwise_monochrome.png': 2,
      'assets/scenes/first-policy.png': 6,
    };

    for (final entry in expectations.entries) {
      final inspection = await _inspectPng(entry.key);
      final minimumVisibleRatio =
          entry.key == 'assets/branding/coverwise_monochrome.png' ? 0.10 : 0.18;
      expect(
        inspection.visibleRatio,
        greaterThan(minimumVisibleRatio),
        reason: '${entry.key} must not be empty or effectively transparent; '
            'monochrome is an intentionally transparent glyph asset',
      );
      expect(
        inspection.colorBuckets,
        greaterThanOrEqualTo(entry.value),
        reason: '${entry.key} must not regress to an all-black export',
      );
    }
  });

  test('generated platform icon catalogs retain the branded color artwork',
      () async {
    const outputs = [
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      'web/icons/Icon-512.png',
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
    ];
    for (final path in outputs) {
      final inspection = await _inspectPng(path);
      // Android's legacy launcher output and macOS deliberately retain a
      // transparent outer mask. Adaptive Android, iOS, and web separately
      // verify their full-bleed background contracts below.
      final retainsOuterMask =
          path.startsWith('macos/') || path.startsWith('android/');
      final minimumVisibleRatio = retainsOuterMask ? 0.55 : 0.90;
      expect(
        inspection.visibleRatio,
        greaterThan(minimumVisibleRatio),
        reason: '$path must retain a visible, correctly sized brand mark',
      );
      expect(
        inspection.colorBuckets,
        greaterThanOrEqualTo(5),
        reason: '$path must contain the CoverWise palette',
      );
    }
  });

  test('launcher source and maskable web icon are full-bleed', () async {
    for (final path in [
      'assets/branding/coverwise_icon.png',
      'web/icons/Icon-maskable-512.png',
    ]) {
      final corner = await _pixelAt(path, 0, 0);
      expect(corner.alpha, greaterThan(250),
          reason: '$path needs opaque corners');
    }

    final iosCorner = await _pixelAt(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      0,
      0,
    );
    expect(iosCorner.alpha, 255);
    expect(
      iosCorner.red + iosCorner.green + iosCorner.blue,
      lessThan(700),
      reason: 'iOS must not replace source transparency with white corners',
    );
  });

  test('Android monochrome icon preserves shield and check alpha', () async {
    const path = 'assets/branding/coverwise_monochrome.png';
    final shieldTop = await _pixelAt(path, 0.5, 0.21);
    final checkStroke = await _pixelAt(path, 0.46, 0.60);
    final clearInterior = await _pixelAt(path, 0.5, 0.35);

    expect(shieldTop.alpha, greaterThan(180));
    expect(checkStroke.alpha, greaterThan(180));
    expect(clearInterior.alpha, lessThan(40));
  });

  test('web and Android expose CoverWise install metadata', () async {
    final manifest = jsonDecode(await File('web/manifest.json').readAsString())
        as Map<String, dynamic>;
    expect(manifest['short_name'], 'CoverWise');
    expect(manifest['theme_color'], '#145BC7');
    expect(
      await File('web/index.html').readAsString(),
      contains('<title>CoverWise — Understand Your Insurance</title>'),
    );
    expect(
      await File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ).readAsString(),
      contains('<monochrome>'),
    );
  });

  test('desktop runners use the CoverWise product identity', () async {
    final linuxCmake = await File('linux/CMakeLists.txt').readAsString();
    final linuxRunner =
        await File('linux/runner/my_application.cc').readAsString();
    final macProject =
        await File('macos/Runner.xcodeproj/project.pbxproj').readAsString();
    final windowsResource =
        await File('windows/runner/Runner.rc').readAsString();

    expect(linuxCmake, contains('set(BINARY_NAME "coverwise")'));
    expect(linuxCmake, contains('set(APPLICATION_ID "com.coverwise.app")'));
    expect(linuxRunner,
        contains('gtk_header_bar_set_title(header_bar, "CoverWise")'));
    expect(linuxRunner, contains('gtk_window_set_title(window, "CoverWise")'));
    expect(macProject, isNot(contains('com.example.mobile')));
    expect(macProject, contains('com.coverwise.app.RunnerTests'));
    expect(windowsResource, contains('VALUE "ProductName", "CoverWise"'));
    expect(
        windowsResource, contains('VALUE "OriginalFilename", "coverwise.exe"'));
    final windowsIcon =
        await File('windows/runner/resources/app_icon.ico').length();
    expect(windowsIcon, greaterThan(15000));
  });
}
