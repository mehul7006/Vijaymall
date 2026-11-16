/// Minimal key-value persistence with **zero platform plugins**.
library;
///
/// The web build reads/writes `window.localStorage` through `dart:js_interop`
/// (no native code, so the Windows desktop build keeps its "no symlink /
/// Developer Mode" property). Every other platform falls back to the
/// in-memory store in `local_store_stub.dart`, which matches the old
/// behaviour: nothing survives a restart there.
///
/// Both implementations expose the same four calls, so callers never need to
/// know which one they got.
export 'local_store_stub.dart'
    if (dart.library.js_interop) 'local_store_web.dart';
