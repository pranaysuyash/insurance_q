import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/utils/app_error.dart';

void main() {
  group('AppError.userMessage', () {
    test('SocketException returns connectivity message', () {
      final msg = AppError.userMessage(
        const SocketException('Connection refused'),
      );
      expect(msg, contains('internet connection'));
    });

    test('FileSystemException returns file access message', () {
      final msg = AppError.userMessage(
        FileSystemException('No such file', '/tmp/missing.pdf'),
      );
      expect(msg, contains('file could not be found'));
    });

    test('Hive box not open returns restart message', () {
      final msg = AppError.userMessage(
        Exception('BoxNotOpenError: box not open'),
      );
      expect(msg, contains('restart the app'));
    });

    test('Hive corrupted returns clear data message', () {
      final msg = AppError.userMessage(
        Exception('CriticalError: data corrupted'),
      );
      expect(msg, contains('Clearing local data'));
    });

    test('Auth wrong password returns friendly auth message', () {
      final msg = AppError.userMessage(
        Exception('AuthException: invalid password'),
      );
      expect(msg, contains('Incorrect email or password'));
    });

    test('Auth user not found returns no account message', () {
      final msg = AppError.userMessage(
        Exception('AuthException: user not found'),
      );
      expect(msg, contains('No account found'));
    });

    test('Auth email not confirmed returns verify message', () {
      final msg = AppError.userMessage(
        Exception('AuthException: email not confirmed'),
      );
      expect(msg, contains('verify your email'));
    });

    test('Billing user cancelled returns empty string', () {
      final msg = AppError.userMessage(
        Exception('RevenueCat: user_cancelled'),
      );
      expect(msg, isEmpty);
    });

    test('Billing network error returns connection message', () {
      final msg = AppError.userMessage(
        Exception('BillingException: network error'),
      );
      expect(msg, contains('app store'));
    });

    test('Upload too large returns size limit message', () {
      final msg = AppError.userMessage(
        Exception('UploadException: file too large'),
      );
      expect(msg, contains('too large'));
    });

    test('DioException 401 returns session expired message', () {
      final msg = AppError.userMessage(
        Exception('DioException [401]: unauthorized'),
      );
      expect(msg, contains('session has expired'));
    });

    test('DioException 429 returns rate limit message', () {
      final msg = AppError.userMessage(
        Exception('DioException [429]: too many requests'),
      );
      expect(msg, contains('Too many requests'));
    });

    test('DioException 500 returns server error message', () {
      final msg = AppError.userMessage(
        Exception('DioException [500]: internal server error'),
      );
      expect(msg, contains('server encountered an error'));
    });

    test('DioException timeout returns timeout message', () {
      final msg = AppError.userMessage(
        Exception('DioException [connectiontimedout]: connection timed out'),
      );
      expect(msg, contains('took too long'));
    });

    test('Permission denied returns permission message', () {
      final msg = AppError.userMessage(
        Exception('PermissionDeniedException: permissiondenied'),
      );
      expect(msg, contains('Permission denied'));
    });

    test('Unknown exception returns generic safe fallback', () {
      final msg = AppError.userMessage(
        Exception('Something completely unexpected'),
      );
      expect(msg, contains('Something went wrong'));
      expect(msg, contains('try again'));
    });

    test('Generic fallback never contains raw exception text', () {
      final error = Exception('InternalStateError: _stackOverflow at line 42');
      final msg = AppError.userMessage(error);
      // The message should NOT contain the technical error class name
      expect(msg, isNot(contains('InternalStateError')));
      expect(msg, isNot(contains('_stackOverflow')));
    });
  });

  group('AppError.contextual', () {
    test('delete_document returns contextual message', () {
      final msg = AppError.contextual(
        error: Exception('FileSystemException'),
        operation: 'delete_document',
      );
      expect(msg, contains('remove this document'));
    });

    test('clear_data returns contextual message', () {
      final msg = AppError.contextual(
        error: Exception('Hive error'),
        operation: 'clear_data',
      );
      expect(msg, contains('clear all local data'));
    });

    test('account_deletion returns contextual message', () {
      final msg = AppError.contextual(
        error: Exception('Network error'),
        operation: 'account_deletion',
      );
      expect(msg, contains('delete your account'));
    });

    test('unknown operation falls back to userMessage', () {
      final msg = AppError.contextual(
        error: SocketException('Connection refused'),
        operation: 'unknown_operation',
      );
      expect(msg, contains('internet connection'));
    });
  });
}
