import 'package:flutter/material.dart';

import 'data/api/api_service.dart';
import 'data/api/session_store.dart';
import 'data/cart_store.dart';
import 'data/seed_data.dart' as seed;
import 'data/store_profile_cache.dart';
import 'nav/nav.dart' show go;
import 'nav/router.dart';
import 'provider/state_scope.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/desktop_shell.dart';
import 'widgets/toast.dart';

Future<void> main() async {
  // Flutter web uses the hash URL strategy by default (`#/home`), which
  // matches the prototype's routing exactly.
  WidgetsFlutterBinding.ensureInitialized();
  // Restore any persisted JWT session + device basket, then point the API at
  // the backend. Both are read before `runApp` so the very first frame is
  // already signed in / carries the cart instead of flashing an empty state.
  await SessionStore.instance.init();
  await CartStore.load();
  Api.configure();
  // Store identity (name / logo / address) is cached on the device: load it
  // synchronously so the very first frame already paints the shop's own brand.
  StoreProfileHub.instance.loadCache();
  runApp(const VijayMallApp());
}

class VijayMallApp extends StatefulWidget {
  const VijayMallApp({super.key});

  @override
  State<VijayMallApp> createState() => _VijayMallAppState();
}

class _VijayMallAppState extends State<VijayMallApp> with WidgetsBindingObserver {
  late final AppState _state = AppState();
  late final AppRouterDelegate _delegate = AppRouterDelegate();
  bool _bootstrapped = false;

  /// Last error already shown by the global watcher below, so a message that
  /// stays set doesn't toast on every rebuild.
  String? _shownError;

  @override
  void initState() {
    super.initState();
    // The SSE feed and its poller are tied to the app being visible: drop the
    // socket when the app is backgrounded (a hidden tab/mobile app in the
    // background would otherwise hold a server slot for nothing) and
    // reconnect on return — the fresh `ready` reloads what was missed.
    WidgetsBinding.instance.addObserver(this);
    // Refresh token refused mid-session: the client already wiped the tokens;
    // fall back to the signed-out state and the sign-in screen.
    Api.instance.client.onSessionExpired = () {
      final wasBooting = !_state.sessionSettled;
      _state.handleSessionExpired();
      // At boot the restore flow falls back to guest browsing by itself.
      if (!wasBooting) go('/signin');
    };
    // Every backend call records its failure in `apiLastError`. Most screens
    // don't read it, which used to make a rejected request (400 validation,
    // 409 stock, 503 not configured, …) look like a success. Watch it here so
    // no API error can pass silently; screens that already toast the same
    /// message keep working because the field is never cleared.
    _state.addListener(_watchApiErrors);
    // If a real session was restored, adopt the user and (for admins) pull
    // live data from the backend once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_bootstrapped) return;
      _bootstrapped = true;
      // Revalidate the cached store profile in the background (conditional GET).
      _state.refreshStoreProfile();
      if (_state.backendMode) {
        _state.bootstrapFromSession();
      } else {
        // Guest browsing: nothing to resolve, so identity is settled now —
        // otherwise an admin route would wait forever for a session that
        // does not exist. Preload the public catalog so signed-out visitors
        // see live data (a live build has no fallback catalogue of its own —
        // it stays empty if the backend is down).
        _state.settleSession();
        _state.bootstrapGuest();
      }
    });
  }

  void _watchApiErrors() {
    final err = _state.apiLastError;
    if (err == null) {
      _shownError = null;
    } else if (err != _shownError) {
      _shownError = err;
      showToast(err, 'error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.removeListener(_watchApiErrors);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background: stop the live feed and its polling fallback.
    // Foreground: reconnect — `ready` refetches orders, wallet, credit and
    // products, so nothing that happened while hidden is missed.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _state.pauseLiveOrders();
    } else if (state == AppLifecycleState.resumed) {
      _state.resumeLiveOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: _state,
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            onGenerateTitle: (_) => seed.store.name,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: RouterConfig(
              routerDelegate: _delegate,
              routeInformationParser: AppRouteParser(),
              routeInformationProvider: PlatformRouteInformationProvider(
                // Start on the deep-linked hash route (`#/signin`, `#/home`, …)
                // and fall back to the splash screen.
                initialRouteInformation: RouteInformation(
                  uri: Uri.parse(
                    WidgetsBinding
                        .instance.platformDispatcher.defaultRouteName,
                  ),
                ),
              ),
            ),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              Widget app = child ?? const SizedBox.shrink();
              if (DesktopShell.useSiteChrome(mq.size.width)) {
                // Web (any width) and wide desktop: a real website — site
                // header, admin sidebar and a full-width content column.
                app = DesktopShell(child: app);
              } else if (mq.size.width > 540) {
                // Small windows keep the phone card.
                final h = mq.size.height > 920 ? 920.0 : mq.size.height;
                app = Container(
                  color: AppColors.bg,
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  child: Container(
                    width: 420,
                    height: h,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: AppColors.line),
                      boxShadow: AppColors.sh2,
                    ),
                    child: app,
                  ),
                );
              }
              // MaterialApp injects its debug `_errorTextStyle` (red text +
              // yellow double underline) as the root DefaultTextStyle. Any
              // widget rendered here that isn't wrapped by a Material — the
              // ToastLayer especially — would inherit that ugly fallback.
              // One base style for the whole app fixes it everywhere.
              final base =
                  (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                      .copyWith(decoration: TextDecoration.none);
              return DefaultTextStyle(
                style: base,
                child: Stack(
                  children: [app, const ToastLayer()],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
