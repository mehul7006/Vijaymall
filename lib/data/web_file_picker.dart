import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Opens the browser's file picker and returns the chosen file's bytes + name,
/// or null when the dialog was dismissed / the file couldn't be read.
///
/// Pure-Dart web interop (`dart:js_interop` + `package:web`) — no native
/// plugin, so it works in `flutter build web` without Developer Mode
/// symlinks. Callers should only expose this behind a web-platform check.
Future<({List<int> bytes, String name})?> pickImageFile({
  String accept = 'image/*',
}) async {
  // `package:web` has no FileUploadInputElement factory — build a plain
  // `<input type="file">` through the DOM instead.
  final input = (web.document.createElement('input') as web.HTMLInputElement)
    ..type = 'file'
    ..accept = accept;
  final done = Completer<({List<int> bytes, String name})?>();
  void settle(({List<int> bytes, String name})? value) {
    if (!done.isCompleted) done.complete(value);
  }

  void onChange(web.Event _) {
    final file = (input.files?.length ?? 0) > 0 ? input.files!.item(0) : null;
    if (file == null) {
      settle(null);
      return;
    }
    file.arrayBuffer().toDart.then((buf) {
      settle((bytes: buf.toDart.asUint8List(), name: file.name));
    }).catchError((Object _) {
      settle(null);
    });
  }

  // The dialog steals focus; when it closes without a change event (cancel),
  // settle with null so the caller never hangs.
  void onFocus(web.Event _) {
    Future.delayed(const Duration(milliseconds: 500), () => settle(null));
  }

  input.addEventListener('change', onChange.toJS);
  web.window.addEventListener('focus', onFocus.toJS);
  input.click();

  final result = await done.future;
  input.removeEventListener('change', onChange.toJS);
  web.window.removeEventListener('focus', onFocus.toJS);
  return result;
}
