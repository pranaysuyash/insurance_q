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
      expect(
        inspection.visibleRatio,
        greaterThan(0.18),
        reason: '${entry.key} must not be empty or effectively transparent',
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
      expect(inspection.visibleRatio, greaterThan(0.90));
      expect(
        inspection.colorBuckets,
        greaterThanOrEqualTo(5),
        reason: '$path must contain the CoverWise palette',
      );
    }
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
}
