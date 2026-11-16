import 'dart:js_interop';

/// `window.localStorage` bound with `dart:js_interop`.
///
/// Every call is best-effort: a browser that blocks storage (private mode,
/// disabled cookies, sandboxed iframe) throws on access, and that is caught
/// here so the app degrades to the in-memory behaviour instead of crashing.
class LocalStore {
  LocalStore._();

  static String? get(String key) {
    try {
      return _getItem(key.toJS)?.toDart;
    } catch (_) {
      return null;
    }
  }

  static void set(String key, String value) {
    try {
      _setItem(key.toJS, value.toJS);
    } catch (_) {
      // Storage unavailable — the session simply won't survive a refresh.
    }
  }

  static void remove(String key) {
    try {
      _removeItem(key.toJS);
    } catch (_) {
      // Storage unavailable — nothing to clean up.
    }
  }
}

@JS('localStorage.getItem')
external JSString? _getItem(JSString key);

@JS('localStorage.setItem')
external void _setItem(JSString key, JSString value);

@JS('localStorage.removeItem')
external void _removeItem(JSString key);
