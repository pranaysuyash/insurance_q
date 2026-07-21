// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

void main() {
  test('debug hive clear', () async {
    final dir1 = await Directory.systemTemp.createTemp('dir1');
    Hive.init(dir1.path);
    final box = await Hive.openBox('testbox');
    await box.put('key1', 'val1');
    print('Box size: \${box.length}');

    // Simulate tearDownAll from previous test
    await dir1.delete(recursive: true);

    // Simulate setUp from next test
    try {
      await box.clear();
      print('Clear succeeded! Box size: \${box.length}');
    } catch (e) {
      print('Clear failed: \$e');
    }
  });
}
