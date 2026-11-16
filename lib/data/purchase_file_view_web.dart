import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Shows [bytes] as [mime] in a new tab through a temporary blob URL.
bool openBytesInTab(List<int> bytes, String mime) {
  try {
    final data = Uint8List.fromList(bytes).toJS;
    final blob = web.Blob([data].toJS, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
    Future.delayed(const Duration(minutes: 2), () => web.URL.revokeObjectURL(url));
    return true;
  } catch (_) {
    return false;
  }
}

/// Saves [bytes] as a file called [filename] through a temporary blob URL.
bool downloadBytes(List<int> bytes, String filename, String mime) {
  try {
    final data = Uint8List.fromList(bytes).toJS;
    final blob = web.Blob([data].toJS, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    final a = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = filename;
    web.document.body?.append(a);
    a.click();
    a.remove();
    Future.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
    return true;
  } catch (_) {
    return false;
  }
}
