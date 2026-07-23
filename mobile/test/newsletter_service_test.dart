import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:coverwise/services/newsletter_service.dart';
import 'package:coverwise/services/consent_ledger.dart';

import 'helpers/hive_test_helper.dart';

void main() {
  late NewsletterService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HiveTestHelper.setUp();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  setUp(() async {
    service = NewsletterService();
    await Hive.box<dynamic>('newsletter').clear();
    await Hive.box<dynamic>('consent_ledger').clear();
  });

  tearDown(() async {
    await Hive.box<dynamic>('newsletter').clear();
    await Hive.box<dynamic>('consent_ledger').clear();
  });

  group('NewsletterService — subscribe', () {
    test('returns true for a valid email', () async {
      final result = await service.subscribe('test@example.com');
      expect(result, isTrue);
    });

    test('rejects empty email', () async {
      final result = await service.subscribe('');
      expect(result, isFalse);
    });

    test('rejects invalid email format', () async {
      final result = await service.subscribe('not-an-email');
      expect(result, isFalse);
    });

    test('rejects disposable email domain', () async {
      final result = await service.subscribe('test@mailinator.com');
      expect(result, isFalse);
    });

    test('normalizes email to lowercase', () async {
      await service.subscribe('Test@Example.COM');
      expect(service.subscribedEmail, equals('test@example.com'));
    });

    test('trims whitespace from email', () async {
      await service.subscribe('  user@example.com  ');
      expect(service.subscribedEmail, equals('user@example.com'));
    });

    test('is idempotent — subscribing twice keeps one record', () async {
      await service.subscribe('user@example.com');
      await service.subscribe('user@example.com');

      expect(service.isSubscribed, isTrue);
      expect(service.subscribedEmail, equals('user@example.com'));
    });

    test('overwrites previous email on new subscription', () async {
      await service.subscribe('first@example.com');
      await service.subscribe('second@example.com');

      expect(service.subscribedEmail, equals('second@example.com'));
    });
  });

  group('NewsletterService — isSubscribed', () {
    test('returns false before any subscription', () {
      expect(service.isSubscribed, isFalse);
    });

    test('returns true after subscribing', () async {
      await service.subscribe('user@example.com');
      expect(service.isSubscribed, isTrue);
    });

    test('returns false after unsubscribe', () async {
      await service.subscribe('user@example.com');
      await service.unsubscribe();
      expect(service.isSubscribed, isFalse);
    });
  });

  group('NewsletterService — subscribedEmail', () {
    test('returns null before any subscription', () {
      expect(service.subscribedEmail, isNull);
    });

    test('returns the subscribed email', () async {
      await service.subscribe('user@example.com');
      expect(service.subscribedEmail, equals('user@example.com'));
    });

    test('returns null after unsubscribe', () async {
      await service.subscribe('user@example.com');
      await service.unsubscribe();
      expect(service.subscribedEmail, isNull);
    });
  });

  group('NewsletterService — unsubscribe', () {
    test('does not throw when not subscribed', () async {
      await service.unsubscribe();
      // Should complete without error
    });

    test('clears opted-in flag', () async {
      await service.subscribe('user@example.com');
      await service.unsubscribe();

      expect(service.isSubscribed, isFalse);
      expect(service.subscribedEmail, isNull);
    });

    test('is idempotent — unsubscribing twice is safe', () async {
      await service.subscribe('user@example.com');
      await service.unsubscribe();
      await service.unsubscribe();

      expect(service.isSubscribed, isFalse);
    });
  });

  group('NewsletterService — consent tracking', () {
    test('records marketingEmails consent on subscribe', () async {
      await service.subscribe('user@example.com');

      final ledger = ConsentLedger();
      // Set up fresh ledger reference after box clear in setUp
      expect(ledger.hasConsent(ConsentPurpose.marketingEmails), isTrue);
    });

    test('does not double-record consent on re-subscribe', () async {
      await service.subscribe('user@example.com');
      await service.subscribe('user@example.com');

      final ledger = ConsentLedger();
      final records = ledger.getAllRecords(
        purpose: ConsentPurpose.marketingEmails,
      );
      // The subscribe method checks hasConsent before recording;
      // if already granted, it skips the recordConsent call.
      expect(records.where((r) => r.granted).length, 1);
    });

    test('revokes marketingEmails consent on unsubscribe', () async {
      await service.subscribe('user@example.com');
      await service.unsubscribe();

      final ledger = ConsentLedger();
      expect(ledger.hasConsent(ConsentPurpose.marketingEmails), isFalse);
    });

    test('subscribe + unsubscribe + re-subscribe cycle is valid', () async {
      await service.subscribe('user@example.com');
      await service.unsubscribe();
      final result = await service.subscribe('user@example.com');

      expect(result, isTrue);
      expect(service.isSubscribed, isTrue);

      final ledger = ConsentLedger();
      expect(ledger.hasConsent(ConsentPurpose.marketingEmails), isTrue);
    });
  });

  group('NewsletterService — edge cases', () {
    test('handles email with subdomain', () async {
      final result = await service.subscribe('user@sub.example.com');
      expect(result, isTrue);
      expect(service.subscribedEmail, equals('user@sub.example.com'));
    });

    test('handles email with plus addressing', () async {
      final result = await service.subscribe('user+tag@example.com');
      expect(result, isTrue);
      expect(service.subscribedEmail, equals('user+tag@example.com'));
    });

    test('rejects disposable domain (exact match)', () async {
      final result = await service.subscribe('user@mailinator.com');
      expect(result, isFalse);
    });
  });
}
