import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/services/auth_service.dart';

void main() {
  test('deletion status parses lifecycle timestamps and hides internals', () {
    final status = DeletionStatus.fromJson({
      'status': 'running',
      'request_id': 'request-1',
      'requested_at': '2026-07-21T10:00:00Z',
      'started_at': '2026-07-21T10:01:00Z',
      'updated_at': '2026-07-21T10:02:00Z',
      'stage_state': {'auth': false},
      'last_error_class': 'RuntimeError',
    });

    expect(status.status, 'running');
    expect(status.requestId, 'request-1');
    expect(status.requestedAt, isNotNull);
    expect(status.startedAt, isNotNull);
    expect(status.completedAt, isNull);
    expect(status.isActionable, isTrue);
  });

  test('none status is not actionable', () {
    expect(
      DeletionStatus.fromJson({'status': 'none'}).isActionable,
      isFalse,
    );
  });
}
