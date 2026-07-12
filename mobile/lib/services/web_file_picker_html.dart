import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class WebPickedFile {
  final String name;
  final Uint8List bytes;

  const WebPickedFile({
    required this.name,
    required this.bytes,
  });
}

class WebFilePicker {
  static web.HTMLInputElement? _input;
  static Completer<WebPickedFile?>? _pending;

  static web.HTMLInputElement _ensureInput() {
    final existing = _input;
    if (existing != null) return existing;

    final input = web.HTMLInputElement()
      ..type = 'file'
      ..id = 'coverwise-web-file-input'
      ..accept = '.pdf,.png,.jpg,.jpeg,.tiff,.tif,.webp'
      ..multiple = false
      ..style.position = 'fixed'
      ..style.left = '-10000px'
      ..style.top = '-10000px'
      ..style.width = '1px'
      ..style.height = '1px'
      ..style.opacity = '0'
      ..style.pointerEvents = 'none';

    input.onChange.listen((_) async {
      final file = input.files?.item(0);
      final completer = _pending;
      if (completer == null || completer.isCompleted) {
        return;
      }
      if (file == null) {
        completer.complete(null);
        _pending = null;
        return;
      }

      final reader = web.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoadEnd.first;
      final result = (reader.result as JSArrayBuffer?)?.toDart;
      if (result != null) {
        completer.complete(
          WebPickedFile(
            name: file.name,
            bytes: result.asUint8List(),
          ),
        );
      } else {
        completer.complete(null);
      }
      _pending = null;
    });

    web.document.body?.append(input);
    _input = input;
    return input;
  }

  static Future<WebPickedFile?> pickFile() async {
    final input = _ensureInput();
    final completer = Completer<WebPickedFile?>();
    _pending = completer;
    input.value = '';
    input.click();
    return completer.future;
  }
}
