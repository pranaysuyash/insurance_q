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
  static Completer<List<WebPickedFile>>? _pendingMulti;

  static web.HTMLInputElement _ensureInput({bool multiple = false}) {
    final existing = _input;
    if (existing != null && existing.multiple == multiple) return existing;
    // If reusing an existing input with wrong multiple flag, remove it.
    if (existing != null) {
      existing.remove();
      _input = null;
    }

    final input = web.HTMLInputElement()
      ..type = 'file'
      ..id = 'coverwise-web-file-input'
      ..accept = '.pdf,.png,.jpg,.jpeg'
      ..multiple = multiple
      ..style.position = 'fixed'
      ..style.left = '-10000px'
      ..style.top = '-10000px'
      ..style.width = '1px'
      ..style.height = '1px'
      ..style.opacity = '0'
      ..style.pointerEvents = 'none';

    input.onChange.listen((_) async {
      final files = input.files;
      if (files == null || files.length == 0) {
        _completePending(null);
        return;
      }

      final results = <WebPickedFile>[];
      for (var i = 0; i < files.length; i++) {
        final file = files.item(i);
        if (file == null) continue;
        final reader = web.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoadEnd.first;
        final data = (reader.result as JSArrayBuffer?)?.toDart;
        if (data != null) {
          results.add(WebPickedFile(
            name: file.name,
            bytes: data.asUint8List(),
          ));
        }
      }

      if (multiple) {
        final completer = _pendingMulti;
        if (completer != null && !completer.isCompleted) {
          completer.complete(results.isEmpty ? null : results);
        }
        _pendingMulti = null;
      } else {
        _completePending(results.isEmpty ? null : results.first);
      }
    });

    web.document.body?.append(input);
    _input = input;
    return input;
  }

  static void _completePending(WebPickedFile? file) {
    final completer = _pending;
    if (completer != null && !completer.isCompleted) {
      completer.complete(file);
    }
    _pending = null;
  }

  static Future<WebPickedFile?> pickFile() async {
    final input = _ensureInput(multiple: false);
    final completer = Completer<WebPickedFile?>();
    _pending = completer;
    input.value = '';
    input.click();
    return completer.future;
  }

  /// Pick multiple files at once. Returns null if the user cancels.
  static Future<List<WebPickedFile>?> pickFiles() async {
    final input = _ensureInput(multiple: true);
    final completer = Completer<List<WebPickedFile>>();
    _pendingMulti = completer;
    input.value = '';
    input.click();
    return completer.future;
  }
}
