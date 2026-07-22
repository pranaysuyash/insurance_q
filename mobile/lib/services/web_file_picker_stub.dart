import 'dart:typed_data';

class WebPickedFile {
  final String name;
  final Uint8List bytes;

  const WebPickedFile({
    required this.name,
    required this.bytes,
  });
}

class WebFilePicker {
  static Future<WebPickedFile?> pickFile() async {
    return null;
  }

  /// Pick multiple files at once. Returns null if the user cancels.
  static Future<List<WebPickedFile>?> pickFiles() async {
    return null;
  }
}
