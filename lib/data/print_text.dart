/// Prints plain monospace receipt text through the browser's print dialog
/// (58 mm and 80 mm paper). Web only; other platforms return false so the
/// caller can offer "Copy" instead.
export 'print_text_stub.dart' if (dart.library.js_interop) 'print_text_web.dart';
