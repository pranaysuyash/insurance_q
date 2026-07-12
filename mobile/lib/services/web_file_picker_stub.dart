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
}
