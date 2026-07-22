/// Tracks the upload state of a single file within a batch upload session.
///
/// Each entry progresses through: [pending] → [uploading] → [completed] | [failed].
/// The [result] field holds the server response map on success, or null on failure
/// with [errorMessage] populated.
class BatchUploadEntry {
  final String fileName;
  final int fileSizeBytes;
  final bool isWebFile; // true = WebPickedFile bytes in memory, false = File on disk
  final String? localFilePath; // only for native files
  final List<int>? webFileBytes; // only for web files
  final String? webFileName; // only for web files (original name)

  BatchUploadState state;
  String? errorMessage;
  Map<String, dynamic>? result;

  BatchUploadEntry({
    required this.fileName,
    required this.fileSizeBytes,
    this.isWebFile = false,
    this.localFilePath,
    this.webFileBytes,
    this.webFileName,
    this.state = BatchUploadState.pending,
    this.errorMessage,
    this.result,
  });

  /// User-visible status label.
  String get statusLabel {
    switch (state) {
      case BatchUploadState.pending:
        return 'Waiting…';
      case BatchUploadState.uploading:
        return 'Uploading…';
      case BatchUploadState.ocrProcessing:
        return 'Reading pages…';
      case BatchUploadState.completed:
        return 'Done';
      case BatchUploadState.failed:
        return errorMessage ?? 'Failed';
      case BatchUploadState.skipped:
        return 'Skipped';
    }
  }

  bool get isTerminal => state == BatchUploadState.completed ||
      state == BatchUploadState.failed ||
      state == BatchUploadState.skipped;
}

enum BatchUploadState {
  pending,
  uploading,
  ocrProcessing,
  completed,
  failed,
  skipped,
}
