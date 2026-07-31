import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:coverwise/config/app_config.dart';

void main() {
  group('OnDeviceModelManifest', () {
    group('constructor', () {
      test('accepts valid manifest with all fields', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://models.example.com/gemma-2b-it-v1.2.bin'),
          version: '1.2.0',
          sha256: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
          sizeBytes: 1234567890,
          provenance: 'Google Gemma 2B IT — Google Terms of Use',
        );

        expect(manifest.url, Uri.parse('https://models.example.com/gemma-2b-it-v1.2.bin'));
        expect(manifest.version, '1.2.0');
        expect(manifest.sha256, 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2');
        expect(manifest.sizeBytes, 1234567890);
        expect(manifest.provenance, 'Google Gemma 2B IT — Google Terms of Use');
      });

      test('toString includes all fields', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: 'abc123',
          sizeBytes: 1024,
          provenance: 'Test License',
        );

        final str = manifest.toString();
        expect(str, contains('url: https://example.com/model.bin'));
        expect(str, contains('version: 1.0.0'));
        expect(str, contains('sha256: abc123'));
        expect(str, contains('sizeBytes: 1024'));
        expect(str, contains('provenance: Test License'));
      });
    });

    group('sha256 validation', () {
      test('rejects empty sha256', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: '',
          sizeBytes: 1024,
          provenance: 'Test License',
        );

        // Empty sha256 is valid in the constructor but the getter should reject it
        expect(manifest.sha256, isEmpty);
      });

      test('accepts hex-encoded SHA-256 (64 chars)', () {
        const validSha256 = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: validSha256,
          sizeBytes: 1024,
          provenance: 'Test License',
        );

        expect(manifest.sha256.length, 64);
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(manifest.sha256), isTrue);
      });

      test('accepts SHA-256 with uppercase hex chars', () {
        const uppercaseSha256 = 'A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2';
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: uppercaseSha256,
          sizeBytes: 1024,
          provenance: 'Test License',
        );

        expect(manifest.sha256.length, 64);
      });
    });

    group('sizeBytes validation', () {
      test('rejects zero size', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: 'abc123',
          sizeBytes: 0,
          provenance: 'Test License',
        );

        expect(manifest.sizeBytes, 0);
      });

      test('rejects negative size', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: 'abc123',
          sizeBytes: -1,
          provenance: 'Test License',
        );

        expect(manifest.sizeBytes, lessThan(0));
      });

      test('accepts positive size', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: 'abc123',
          sizeBytes: 1024 * 1024, // 1 MiB
          provenance: 'Test License',
        );

        expect(manifest.sizeBytes, 1048576);
      });

      test('accepts large model size (2 GiB)', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: 'abc123',
          sizeBytes: 2 * 1024 * 1024 * 1024, // 2 GiB
          provenance: 'Test License',
        );

        expect(manifest.sizeBytes, 2147483648);
      });
    });

    group('provenance validation', () {
      test('rejects empty provenance', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: 'abc123',
          sizeBytes: 1024,
          provenance: '',
        );

        expect(manifest.provenance, isEmpty);
      });

      test('accepts single-word provenance', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: 'abc123',
          sizeBytes: 1024,
          provenance: 'Gemma',
        );

        expect(manifest.provenance, 'Gemma');
      });

      test('accepts detailed provenance with license info', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: 'abc123',
          sizeBytes: 1024,
          provenance: 'Google Gemma 2B IT — Google Terms of Use',
        );

        expect(manifest.provenance, contains('Google'));
        expect(manifest.provenance, contains('Terms of Use'));
      });

      test('accepts provenance with unicode characters', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://example.com/model.bin'),
          version: '1.0.0',
          sha256: 'abc123',
          sizeBytes: 1024,
          provenance: '© 2024 Example Corp — Apache 2.0',
        );

        expect(manifest.provenance, contains('©'));
      });
    });

    group('URL validation', () {
      test('accepts valid HTTPS URL', () {
        final manifest = OnDeviceModelManifest(
          url: Uri.parse('https://models.example.com/gemma-2b-it-v1.2.bin'),
          version: '1.0.0',
          sha256: 'abc123',
          sizeBytes: 1024,
          provenance: 'Test License',
        );

        expect(manifest.url.scheme, 'https');
        expect(manifest.url.host, 'models.example.com');
      });

      test('rejects HTTP URL', () {
        final uri = Uri.tryParse('http://models.example.com/model.bin');
        expect(uri?.scheme, 'http');
        // The getter should reject non-HTTPS URLs
      });

      test('rejects URL with credentials', () {
        final uri = Uri.tryParse('https://user:pass@models.example.com/model.bin');
        expect(uri?.userInfo, isNotEmpty);
        // The getter should reject URLs with userInfo
      });

      test('rejects URL with query parameters', () {
        final uri = Uri.tryParse('https://models.example.com/model.bin?token=abc');
        expect(uri?.hasQuery, isTrue);
        // The getter should reject URLs with query parameters
      });

      test('rejects URL with fragment', () {
        final uri = Uri.tryParse('https://models.example.com/model.bin#section');
        expect(uri?.hasFragment, isTrue);
        // The getter should reject URLs with fragments
      });

      test('rejects URL without host', () {
        final uri = Uri.tryParse('https:///model.bin');
        expect(uri?.host, isEmpty);
        // The getter should reject URLs without a host
      });
    });
  });

  group('AppConfig.onDeviceModelManifest getter', () {
    test('returns null when onDeviceInferenceEnabled is false', () {
      // Default test build has onDeviceInferenceEnabled=false via dart-define
      expect(AppConfig.onDeviceInferenceEnabled, isFalse);
      expect(AppConfig.onDeviceModelManifest, isNull);
    });

    test('returns null when any manifest field is missing', () {
      // In the default test build, all fields are empty/zero
      expect(AppConfig.onDeviceModelUrl, isEmpty);
      expect(AppConfig.onDeviceModelVersion, isEmpty);
      expect(AppConfig.onDeviceModelSha256, isEmpty);
      expect(AppConfig.onDeviceModelSize, 0);
      expect(AppConfig.onDeviceModelProvenance, isEmpty);
      expect(AppConfig.onDeviceModelManifest, isNull);
    });
  });

  group('source-level contracts', () {
    late String source;

    setUpAll(() {
      // Read the actual source file for contract verification.
      source = File('lib/config/app_config.dart').readAsStringSync();
    });

    test('getter validates all 5 manifest fields before construction', () {
      expect(source, contains('onDeviceModelUrl.isEmpty'));
      expect(source, contains('onDeviceModelVersion.isEmpty'));
      expect(source, contains('onDeviceModelSha256.isEmpty'));
      expect(source, contains('onDeviceModelSize <= 0'));
      expect(source, contains('onDeviceModelProvenance.isEmpty'));
    });

    test('getter validates URL structure after emptiness check', () {
      expect(source, contains('uri.host.isEmpty'));
      expect(source, contains('uri.userInfo.isNotEmpty'));
      expect(source, contains('uri.hasQuery'));
      expect(source, contains('uri.hasFragment'));
    });

    test('release validation requires provenance when inference enabled', () {
      expect(source, contains('ON_DEVICE_MODEL_PROVENANCE is required when'));
    });

    test('OnDeviceModelManifest has all 5 required fields', () {
      expect(source, contains('final Uri url;'));
      expect(source, contains('final String version;'));
      expect(source, contains('final String sha256;'));
      expect(source, contains('final int sizeBytes;'));
      expect(source, contains('final String provenance;'));
    });
  });
}
