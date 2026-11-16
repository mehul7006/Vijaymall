import 'package:flutter/material.dart';

/// The app's single [Navigator].
///
/// The site header and its drawer live in `MaterialApp.builder`, i.e. *above*
/// the Navigator, so their contexts cannot open a sheet on their own — this
/// key lets them reach the navigator's overlay instead.
final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();

/// Context to pass to `showAppSheet` / `showModalBottomSheet` from widgets
/// rendered outside the Navigator (site header, store drawer).
BuildContext? get rootSheetContext =>
    rootNavKey.currentState?.overlay?.context;

/// Hash-route navigation, mirroring the prototype's `go('#/path')`.
class Nav extends ChangeNotifier {
  Nav._();

  static final Nav instance = Nav._();

  String route = '/splash';
  final List<String> _stack = [];

  /// Page a signed-out visitor asked for before being sent to sign-in, so a
  /// customer lands back on it after the OTP (admins/staff ignore it).
  String? returnTo;

  bool get canPop => _stack.isNotEmpty;

  void go(String next) {
    if (next == route) return;
    _stack.add(route);
    route = next;
    notifyListeners();
  }

  /// Replace without pushing history (splash → welcome/home).
  void replace(String next) {
    if (next == route) return;
    route = next;
    notifyListeners();
  }

  bool pop() {
    if (_stack.isEmpty) return false;
    route = _stack.removeLast();
    notifyListeners();
    return true;
  }

  /// Browser back/forward or a fresh deep link.
  void setLocation(String next) {
    if (next == route) return;
    _stack.clear();
    route = next;
    notifyListeners();
  }
}

/// `go('#/home')` — accepts with or without the leading hash.
void go(String location) {
  var r = location;
  if (r.startsWith('#')) r = r.substring(1);
  if (!r.startsWith('/')) r = '/$r';
  Nav.instance.go(r);
}
