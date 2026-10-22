import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/services/document_service.dart';
import 'package:coverwise/services/upload_retry_service.dart';

class FakeDocumentService extends Fake implements DocumentService {
  int retryCalls = 0;
  Map<String, int> resultToReturn = {'synced': 1, 'failed': 0, 'pending': 0};

  @override
  Future<Map<String, int>> retryPendingUploads({int? epoch}) async {
    retryCalls++;
    return resultToReturn;
  }
}

void main() {
  late FakeDocumentService fakeDocService;
  late UploadRetryService retryService;

  setUp(() {
    fakeDocService = FakeDocumentService();
    retryService = UploadRetryService(
      documentService: fakeDocService,
      backoffDelays: const [Duration.zero],
    );
  });

  tearDown(() {
    retryService.dispose();
  });

  test('does not retry when online initially', () async {
    await retryService.handleConnectivityChange([ConnectivityResult.wifi]);

    expect(retryService.wasOffline, isFalse);
    expect(fakeDocService.retryCalls, equals(0));
  });

  test('retries with backoff when transitioning from offline to online', () async {
    // Step 1: Go offline
    await retryService.handleConnectivityChange([ConnectivityResult.none]);
    expect(retryService.wasOffline, isTrue);
    expect(fakeDocService.retryCalls, equals(0));

    // Step 2: Come online
    await retryService.handleConnectivityChange([ConnectivityResult.wifi]);
    expect(retryService.wasOffline, isFalse);
    expect(fakeDocService.retryCalls, equals(1));
  });

  test('retryWithBackoff stops early when all pending items synced', () async {
    final service = UploadRetryService(
      documentService: fakeDocService,
      backoffDelays: const [Duration.zero, Duration.zero, Duration.zero],
    );

    final res = await service.retryWithBackoff();
    expect(res['synced'], equals(1));
    expect(fakeDocService.retryCalls, equals(1));
  });
}
