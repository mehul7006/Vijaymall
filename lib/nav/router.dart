import 'package:flutter/material.dart';

import '../screens/screen_builder.dart';
import 'nav.dart';

/// Hash-fragment route parser (`#/home` style URLs, like the prototype).
class AppRouteParser extends RouteInformationParser<String> {
  @override
  Future<String> parseRouteInformation(
      RouteInformation routeInformation) async {
    final uri = routeInformation.uri;
    var raw = uri.path;
    // The route normally lives in the path (`/home`); when it is carried by
    // the hash fragment (`#/home`) fall back to the fragment.
    if (uri.fragment.isNotEmpty && (raw.isEmpty || raw == '/')) {
      raw = uri.fragment;
    }
    while (raw.startsWith('/')) {
      raw = raw.substring(1);
    }
    while (raw.startsWith('#')) {
      raw = raw.substring(1);
    }
    while (raw.startsWith('/')) {
      raw = raw.substring(1);
    }
    if (raw.isEmpty) return '/splash';
    var r = '/$raw';
    // Re-attach `?cat=dry&q=…` when the URI kept it out of the path.
    if (uri.hasQuery && !r.contains('?')) r = '$r?${uri.query}';
    return r;
  }

  @override
  RouteInformation? restoreRouteInformation(String configuration) =>
      RouteInformation(uri: Uri.parse(configuration));
}

/// Single-page router delegate driven by [Nav].
class AppRouterDelegate extends RouterDelegate<String> with ChangeNotifier {
  AppRouterDelegate() {
    Nav.instance.addListener(notifyListeners);
  }

  /// Whether any route has already been applied at boot.
  ///
  /// The framework re-delivers the *initial* route (state restoration and
  /// dependency-change re-parses) using the platform provider's boot value.
  /// Those re-deliveries arrive asynchronously and can be stale — after the
  /// user has already navigated in-app — so once a route is applied the
  /// initial path is ignored and in-app navigation always wins. Browser
  /// back/forward still works: it goes through [setNewRoutePath].
  bool _routeApplied = false;

  @override
  String? get currentConfiguration => Nav.instance.route;

  @override
  Future<void> setNewRoutePath(String configuration) async {
    _routeApplied = true;
    Nav.instance.setLocation(configuration);
  }

  @override
  Future<void> setInitialRoutePath(String configuration) async {
    // Stale re-parse of the boot route — the user has navigated since.
    if (_routeApplied) return;
    _routeApplied = true;
    Nav.instance.setLocation(configuration);
  }

  @override
  Future<bool> popRoute() async {
    if (Nav.instance.pop()) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final route = Nav.instance.route;
    return Navigator(
      key: rootNavKey,
      pages: [
        MaterialPage(
          key: ValueKey(route),
          child: buildScreen(route),
        ),
      ],
      onDidRemovePage: (page) {},
    );
  }
}
