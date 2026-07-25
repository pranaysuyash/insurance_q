import 'package:flutter_test/flutter_test.dart';

import 'package:coverwise/config/app_config.dart';
import 'package:coverwise/services/on_device_inference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const runInstallAttempt = bool.fromEnvironment(
    'ON_DEVICE_TEST_INSTALL_ATTEMPT',
    defaultValue: false,
  );

  test('on-device inference config reflects compile-time environment', () {
    if (AppConfig.onDeviceInferenceEnabled) {
      expect(AppConfig.onDeviceModelUrl, isNotEmpty);
      expect(AppConfig.hasOnDeviceInferenceConfig, isTrue);
    } else {
      expect(AppConfig.onDeviceInferenceEnabled, isFalse);
      expect(AppConfig.hasOnDeviceInferenceConfig, isFalse);
    }
    expect(OnDeviceInferenceService.maxContextTokens, 2048);
  });

  test('service refuses model installation without an approved configuration',
      () async {
    if (AppConfig.hasOnDeviceInferenceConfig || runInstallAttempt) {
      return;
    }
    final service = OnDeviceInferenceService();
    expect(
      () => service.installModel(),
      throwsA(isA<StateError>()),
    );
  });

  test('service install attempt path is reachable when configured', () async {
    if (!runInstallAttempt) {
      return;
    }
    if (!AppConfig.hasOnDeviceInferenceConfig) {
      fail(
        'ON_DEVICE_TEST_INSTALL_ATTEMPT=true requires ON_DEVICE_INFERENCE_ENABLED=true '
        'and a valid HTTPS ON_DEVICE_MODEL_URL.',
      );
    }

    final service = OnDeviceInferenceService();
    await expectLater(
      service.installModel(),
      throwsA(anything),
    );
  }, timeout: const Timeout.factor(2));
}
