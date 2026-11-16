/// Opens `tel:`, `mailto:` and `https:` links. Web uses the browser; other
/// platforms return false so the caller can copy the value instead.
export 'open_link_stub.dart' if (dart.library.js_interop) 'open_link_web.dart';
