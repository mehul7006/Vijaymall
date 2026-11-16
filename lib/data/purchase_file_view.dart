/// Opens downloaded bytes (an invoice PDF or photo) in a new browser tab, and
/// saves bytes (a CSV export) as a browser download. Other platforms return
/// false.
library;

export 'purchase_file_view_stub.dart'
    if (dart.library.js_interop) 'purchase_file_view_web.dart';
