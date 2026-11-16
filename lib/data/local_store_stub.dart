/// In-memory key-value store used by every non-web platform (Windows
/// desktop). Identical API to the web implementation, but values only live
/// for the current process — a desktop restart starts a fresh session.
class LocalStore {
  LocalStore._();

  static final Map<String, String> _data = <String, String>{};

  static String? get(String key) => _data[key];

  static void set(String key, String value) {
    _data[key] = value;
  }

  static void remove(String key) {
    _data.remove(key);
  }
}
