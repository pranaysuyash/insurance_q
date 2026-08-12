import 'package:coverwise/models/identity.dart';
import 'package:coverwise/models/principal_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake Supabase User for testing.
///
/// Overrides [email] and [phone] to control whether the user appears
/// anonymous (no email, no phone) or registered (at least one credential).
class _FakeUser extends User {
  _FakeUser({
    required String testId,
    String? testEmail,
    String? testPhone,
  })  : _testEmail = testEmail,
        _testPhone = testPhone,
        _testId = testId,
        super(
          id: testId,
          aud: 'authenticated',
          appMetadata: const {},
          userMetadata: const {},
          createdAt: '2026-01-01T00:00:00Z',
        );

  final String _testId;
  final String? _testEmail;
  final String? _testPhone;

  @override
  String get id => _testId;

  @override
  String? get email => _testEmail;

  @override
  String? get phone => _testPhone;
}

/// Create a fake Supabase [Session] for testing.
///
/// Uses [_FakeUser] to control email/phone presence.
Session _fakeSession({
  required String userId,
  String? email,
  String? phone,
}) {
  final user = _FakeUser(
    testId: userId,
    testEmail: email,
    testPhone: phone,
  );

  return Session(
    accessToken: 'fake-access-token',
    refreshToken: 'fake-refresh-token',
    expiresIn: 3600,
    tokenType: 'bearer',
    user: user,
  );
}

/// Unit tests for the CW-P0-004 deterministic principal state machine.
///
/// Tests the three identity states ([InstallGuest], [BackendAnonymous],
/// [RegisteredPrincipal]), the [Resolve] extension factory methods,
/// equality/hashCode contracts, and the [label] getter.
///
/// These tests do NOT require Hive, FlutterSecureStorage, or Supabase
/// initialization — they exercise pure model logic.
void main() {
  const installId = 'test-install-id-abc';
  const anonymousUserId = 'anon-uuid-1234';
  const registeredUserId = 'user-uuid-5678';

  // ─── Resolve.resolve() ────────────────────────────────────────────────

  group('Resolve.resolve()', () {
    test('null session produces InstallGuest', () {
      final state = Resolve.resolve(
        session: null,
        installId: installId,
      );

      expect(state, isA<InstallGuest>());
      expect((state as InstallGuest).installId, equals(installId));
    });

    test('session with email produces RegisteredPrincipal', () {
      final session = _fakeSession(
        userId: registeredUserId,
        email: 'alice@example.com',
        phone: null,
      );

      final state = Resolve.resolve(
        session: session,
        installId: installId,
      );

      expect(state, isA<RegisteredPrincipal>());
      expect((state as RegisteredPrincipal).userId, equals(registeredUserId));
    });

    test('session with phone produces RegisteredPrincipal', () {
      final session = _fakeSession(
        userId: registeredUserId,
        email: null,
        phone: '+911234567890',
      );

      final state = Resolve.resolve(
        session: session,
        installId: installId,
      );

      expect(state, isA<RegisteredPrincipal>());
      expect((state as RegisteredPrincipal).userId, equals(registeredUserId));
    });

    test('session with both email and phone produces RegisteredPrincipal',
        () {
      final session = _fakeSession(
        userId: registeredUserId,
        email: 'bob@example.com',
        phone: '+919876543210',
      );

      final state = Resolve.resolve(
        session: session,
        installId: installId,
      );

      expect(state, isA<RegisteredPrincipal>());
    });

    test('session with empty email and no phone produces BackendAnonymous',
        () {
      final session = _fakeSession(
        userId: anonymousUserId,
        email: '',
        phone: null,
      );

      final state = Resolve.resolve(
        session: session,
        installId: installId,
      );

      expect(state, isA<BackendAnonymous>());
      expect((state as BackendAnonymous).userId, equals(anonymousUserId));
    });

    test('session with empty phone and no email produces BackendAnonymous',
        () {
      final session = _fakeSession(
        userId: anonymousUserId,
        email: null,
        phone: '',
      );

      final state = Resolve.resolve(
        session: session,
        installId: installId,
      );

      expect(state, isA<BackendAnonymous>());
    });

    test('session with null email and null phone produces BackendAnonymous',
        () {
      final session = _fakeSession(
        userId: anonymousUserId,
        email: null,
        phone: null,
      );

      final state = Resolve.resolve(
        session: session,
        installId: installId,
      );

      expect(state, isA<BackendAnonymous>());
      expect((state as BackendAnonymous).userId, equals(anonymousUserId));
    });
  });

  // ─── Principal → workspace mapping ─────────────────────────────────────

  group('workspace principal mapping', () {
    test('InstallGuest principal is LocalPrincipal with installId', () {
      final state = InstallGuest(installId);
      final principal = state.principal;

      expect(principal, isA<LocalPrincipal>());
      expect((principal as LocalPrincipal).installId, equals(installId));
      expect(principal.principalId, equals('local-only-$installId'));
    });

    test('BackendAnonymous principal is AccountPrincipal with userId', () {
      final state = BackendAnonymous(anonymousUserId);
      final principal = state.principal;

      expect(principal, isA<AccountPrincipal>());
      expect((principal as AccountPrincipal).userId, equals(anonymousUserId));
      expect(principal.principalId, equals(anonymousUserId));
    });

    test('RegisteredPrincipal principal is AccountPrincipal with userId',
        () {
      final state = RegisteredPrincipal(registeredUserId);
      final principal = state.principal;

      expect(principal, isA<AccountPrincipal>());
      expect((principal as AccountPrincipal).userId, equals(registeredUserId));
      expect(principal.principalId, equals(registeredUserId));
    });
  });

  // ─── Account identity mapping ─────────────────────────────────────────

  group('account identity mapping', () {
    test('InstallGuest identity is NoAccount', () {
      expect(InstallGuest(installId).identity, isA<NoAccount>());
    });

    test('BackendAnonymous identity is AnonymousAccount with userId', () {
      final identity = BackendAnonymous(anonymousUserId).identity;
      expect(identity, isA<AnonymousAccount>());
      expect((identity as AnonymousAccount).userId, equals(anonymousUserId));
    });

    test('RegisteredPrincipal identity is RegisteredAccount with userId',
        () {
      final identity = RegisteredPrincipal(registeredUserId).identity;
      expect(identity, isA<RegisteredAccount>());
      expect(
        (identity as RegisteredAccount).userId,
        equals(registeredUserId),
      );
    });
  });

  // ─── Convenience getters ──────────────────────────────────────────────

  group('convenience getters', () {
    test('isRegistered is true only for RegisteredPrincipal', () {
      expect(InstallGuest(installId).isRegistered, isFalse);
      expect(BackendAnonymous(anonymousUserId).isRegistered, isFalse);
      expect(RegisteredPrincipal(registeredUserId).isRegistered, isTrue);
    });

    test('hasSupabaseSession is true for BackendAnonymous and Registered',
        () {
      expect(InstallGuest(installId).hasSupabaseSession, isFalse);
      expect(BackendAnonymous(anonymousUserId).hasSupabaseSession, isTrue);
      expect(
        RegisteredPrincipal(registeredUserId).hasSupabaseSession,
        isTrue,
      );
    });
  });

  // ─── Equality and hashCode ────────────────────────────────────────────

  group('equality and hashCode', () {
    test('InstallGuest equal if installId matches', () {
      final a = InstallGuest(installId);
      final b = InstallGuest(installId);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('InstallGuest not equal if installId differs', () {
      final a = InstallGuest('id-1');
      final b = InstallGuest('id-2');
      expect(a, isNot(equals(b)));
    });

    test('BackendAnonymous equal if userId matches', () {
      final a = BackendAnonymous(anonymousUserId);
      final b = BackendAnonymous(anonymousUserId);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('BackendAnonymous not equal if userId differs', () {
      final a = BackendAnonymous('anon-1');
      final b = BackendAnonymous('anon-2');
      expect(a, isNot(equals(b)));
    });

    test('RegisteredPrincipal equal if userId matches', () {
      final a = RegisteredPrincipal(registeredUserId);
      final b = RegisteredPrincipal(registeredUserId);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('RegisteredPrincipal not equal if userId differs', () {
      final a = RegisteredPrincipal('user-1');
      final b = RegisteredPrincipal('user-2');
      expect(a, isNot(equals(b)));
    });

    test('different subtypes are never equal', () {
      final install = InstallGuest(installId);
      final anon = BackendAnonymous(installId);
      final reg = RegisteredPrincipal(installId);

      expect(install, isNot(equals(anon)));
      expect(install, isNot(equals(reg)));
      expect(anon, isNot(equals(reg)));
    });

    test('same identity is identical', () {
      final state = BackendAnonymous(anonymousUserId);
      expect(identical(state, state), isTrue);
    });

    test('equal objects are identical via hashCode in Set', () {
      final set = <PrincipalState>{
        InstallGuest(installId),
        InstallGuest(installId), // duplicate
      };
      expect(set.length, equals(1));
    });
  });

  // ─── label getter ─────────────────────────────────────────────────────

  group('label getter', () {
    test('InstallGuest label is install_guest', () {
      expect(InstallGuest(installId).label, equals('install_guest'));
    });

    test('BackendAnonymous label is backend_anonymous', () {
      expect(
        BackendAnonymous(anonymousUserId).label,
        equals('backend_anonymous'),
      );
    });

    test('RegisteredPrincipal label is registered_account', () {
      expect(
        RegisteredPrincipal(registeredUserId).label,
        equals('registered_account'),
      );
    });

    test('labels are stable strings (not null)', () {
      expect(InstallGuest(installId).label, isA<String>());
      expect(BackendAnonymous(anonymousUserId).label, isA<String>());
      expect(RegisteredPrincipal(registeredUserId).label, isA<String>());
    });
  });

  // ─── toString ─────────────────────────────────────────────────────────

  group('toString', () {
    test('InstallGuest toString includes installId', () {
      expect(InstallGuest(installId).toString(), contains(installId));
    });

    test('BackendAnonymous toString includes userId', () {
      expect(
        BackendAnonymous(anonymousUserId).toString(),
        contains(anonymousUserId),
      );
    });

    test('RegisteredPrincipal toString includes userId', () {
      expect(
        RegisteredPrincipal(registeredUserId).toString(),
        contains(registeredUserId),
      );
    });
  });

  // ─── Determinism ──────────────────────────────────────────────────────

  group('determinism', () {
    test('resolve() is deterministic — same input always produces same state',
        () {
      final session = _fakeSession(
        userId: registeredUserId,
        email: 'test@example.com',
        phone: null,
      );

      final results = List.generate(
        100,
        (_) => Resolve.resolve(
          session: session,
          installId: installId,
        ),
      );

      // All 100 results should be equal to the first.
      for (final result in results) {
        expect(result, equals(results.first));
      }
    });

    test('resolve() with null session always produces InstallGuest', () {
      final results = List.generate(
        100,
        (_) => Resolve.resolve(
          session: null,
          installId: installId,
        ),
      );

      for (final result in results) {
        expect(result, isA<InstallGuest>());
        expect((result as InstallGuest).installId, equals(installId));
      }
    });
  });
}


