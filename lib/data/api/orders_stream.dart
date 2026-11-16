import '../ist.dart';
import 'dart:async';
import 'dart:convert';

import 'api_client.dart';

/// Which backend live event a frame carries.
enum LiveEvent {
  /// `{orderId, orderNo, status, previousStatus, at}` — one order changed.
  order,

  /// `{userId, reason, delta, at}` — this customer's wallet moved (their own
  /// events only; the backend filters by user).
  wallet,

  /// `{productIds, reason, at}` — stock moved; every listener refetches the
  /// affected rows so shelves/prices never go stale.
  stock,

  /// `{customerId, reason, deltaPaise, at}` — this customer's credit (udhar)
  /// balance or limit moved (their own events only).
  credit,

  /// `{area, at}` — an admin changed something every screen shows. `area` is
  /// CATALOG, COUPONS, UNITS, SHOP or PAYMENT_METHODS and names exactly
  /// which collection has to be re-read.
  catalog,
}

/// One frame of the backend's order event stream.
///
/// Three shapes arrive on `GET /orders/stream` (the signed-in customer's own
/// orders) and `GET /admin/orders/stream` (staff: every order):
///
///  * `ready` — sent once per connection. The stream only lives ~10 minutes
///    and reconnects with a fresh token, so after every (re)connect the app
///    re-reads the order list once to pick up anything missed while it was
///    down.
///  * `order` — `{orderId, orderNo, status, previousStatus, at}`: one order
///    changed. The status is applied straight away and the full row is
///    re-fetched for history/items.
///  * `wallet` — `{userId, reason, delta, at}`: the signed-in customer's coin
///    balance moved (an order earned or spent coins). Re-read the wallet.
///  * `stock` — `{productIds, reason, at}`: stock moved (a sale, a restock, a
///    POS bill). Re-read the catalog so availability is right without a
///    refresh.
///  * `credit` — `{customerId, reason, deltaPaise, at}`: the signed-in
///    customer's credit (udhar) balance moved. Re-read `/credit` +
///    `/credit/ledger`.
///  * `catalog` — `{area, at}`: an admin changed something every screen
///    shows. `area` names the collection (`CATALOG`, `COUPONS`, `UNITS`,
///    `SHOP`, `PAYMENT_METHODS`) — re-read exactly that one.
///
/// A bare `: keep-alive` comment line arrives every 25 seconds and is
/// ignored; the connection is closed by the server after 10 minutes, which
/// simply starts the next connect.
class OrderStreamEvent {
  const OrderStreamEvent({
    this.orderId,
    this.orderNo,
    this.status,
    this.previousStatus,
    this.at,
    this.ready = false,
    this.kind = LiveEvent.order,
    this.walletDelta = 0,
    this.walletReason = '',
    this.stockProductIds = const <String>[],
    this.stockReason = '',
    this.creditDeltaPaise = 0,
    this.creditReason = '',
    this.catalogArea = '',
  });

  final String? orderId;
  final String? orderNo;

  /// Wire status (`DELIVERED`, …) — map with `statusFromWire`.
  final String? status;
  final String? previousStatus;
  final DateTime? at;

  /// True for the `ready` handshake (fresh connection) rather than data.
  final bool ready;

  /// Which live event this frame carries (ignored while [ready] is true).
  final LiveEvent kind;

  /// Signed coin delta for a [LiveEvent.wallet] frame.
  final int walletDelta;
  final String walletReason;

  /// Backend pack ids that moved for a [LiveEvent.stock] frame.
  final List<String> stockProductIds;
  final String stockReason;

  /// Signed money delta for a [LiveEvent.credit] frame (paise; positive =
  /// the customer owes more). Re-read the credit account + ledger.
  final int creditDeltaPaise;
  final String creditReason;

  /// Which collection changed for a [LiveEvent.catalog] frame:
  /// `CATALOG`, `COUPONS`, `UNITS`, `SHOP` or `PAYMENT_METHODS`.
  final String catalogArea;
}

/// Keeps one SSE connection alive, reconnecting with backoff until [stop].
///
/// Pure Dart (`http` streaming) — no `EventSource`, so the `Authorization`
/// header can be set on the request itself (the backend also accepts
/// `?access_token=` on these two paths, for clients that cannot).
class OrdersStream {
  OrdersStream(this._client);

  final ApiClient _client;

  StreamSubscription<OrderStreamEvent>? _sub;
  bool _want = false;
  String _endpoint = '';

  /// True while a connection is wanted (used to avoid double-subscribing).
  bool get isActive => _want;

  /// Connect to [endpoint] (`/orders/stream` or `/admin/orders/stream`).
  /// Replaces any previous subscription.
  ///
  /// [onConnected] fires once the HTTP stream is open and `ready` is about to
  /// be delivered; [onDisconnected] fires whenever a connect attempt fails or
  /// the server closes the stream (the caller uses it to start polling).
  void start({
    required String endpoint,
    required void Function(OrderStreamEvent) onEvent,
    void Function()? onConnected,
    void Function()? onDisconnected,
  }) {
    if (_want && _endpoint == endpoint && _sub != null) return;
    stop();
    _want = true;
    _endpoint = endpoint;
    _onConnected = onConnected;
    _onDisconnected = onDisconnected;
    _sub = _reconnect(endpoint).listen(
      onEvent,
      // The loop below already swallows connect/read errors; this only
      // catches anything the listener itself throws.
      onError: (Object _) {},
      cancelOnError: false,
    );
  }

  void Function()? _onConnected;
  void Function()? _onDisconnected;

  /// Close the connection and stop reconnecting (sign-out / role change).
  void stop() {
    _want = false;
    final sub = _sub;
    _sub = null;
    _onConnected = null;
    _onDisconnected = null;
    // Cancelling propagates into the in-flight `yield*`, which cancels the
    // HTTP body subscription and drops the socket.
    unawaited(sub?.cancel());
  }

  Stream<OrderStreamEvent> _reconnect(String endpoint) async* {
    var attempt = 0;
    while (_want) {
      try {
        final resp = await _client.stream(endpoint);
        attempt = 0;
        // A fresh connection: whatever changed while we were away has to be
        // read back once.
        _onConnected?.call();
        yield const OrderStreamEvent(ready: true);
        yield* _frames(resp.stream);
        // The server closed the stream (its ~10-minute lifetime) — treat it
        // as down until the next connect succeeds.
        _onDisconnected?.call();
      } catch (_) {
        // Auth/network failure: fall through to the backoff below.
        _onDisconnected?.call();
      }
      if (!_want) break;
      attempt += 1;
      // 1s, 2s, 5s, 10s, then 30s (the guide's back-off) - quick to recover
      // from the backend's deliberate 10-minute close, never a tight loop.
      const steps = [1, 2, 5, 10, 30];
      final wait = steps[(attempt - 1).clamp(0, steps.length - 1)];
      await Future<void>.delayed(Duration(seconds: wait));
    }
  }

  /// SSE framing: lines → `event:`/`data:` blocks separated by a blank line.
  static Stream<OrderStreamEvent> _frames(Stream<List<int>> bytes) async* {
    final lines =
        bytes.transform(utf8.decoder).transform(const LineSplitter());
    var event = '';
    final data = <String>[];

    await for (final line in lines) {
      if (line.isEmpty) {
        if (event == 'ready') {
          yield const OrderStreamEvent(ready: true);
        } else if (data.isNotEmpty) {
          final parsed = _parse(event, data.join('\n'));
          if (parsed != null) yield parsed;
        }
        event = '';
        data.clear();
      } else if (line.startsWith(':')) {
        // Keep-alive comment — nothing to do.
      } else if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trim());
      }
    }
  }

  static OrderStreamEvent? _parse(String event, String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);

      switch (event) {
        case 'order':
          return OrderStreamEvent(
            kind: LiveEvent.order,
            orderId: map['orderId']?.toString(),
            orderNo: map['orderNo']?.toString(),
            status: map['status']?.toString(),
            previousStatus: map['previousStatus']?.toString(),
            at: parseIst(map['at']?.toString() ?? ''),
          );
        case 'wallet':
          // Only the customer's own wallet frames are delivered, so a balance
          // change on this device can never be skipped.
          return OrderStreamEvent(
            kind: LiveEvent.wallet,
            walletDelta: (map['delta'] as num?)?.toInt() ?? 0,
            walletReason: map['reason']?.toString() ?? '',
            at: parseIst(map['at']?.toString() ?? ''),
          );
        case 'stock':
          final ids = map['productIds'];
          return OrderStreamEvent(
            kind: LiveEvent.stock,
            stockProductIds: ids is List
                ? ids.map((e) => e.toString()).toList()
                : const <String>[],
            stockReason: map['reason']?.toString() ?? '',
            at: parseIst(map['at']?.toString() ?? ''),
          );
        case 'credit':
          // Only the customer's own credit frames are delivered.
          return OrderStreamEvent(
            kind: LiveEvent.credit,
            creditDeltaPaise: (map['deltaPaise'] as num?)?.toInt() ?? 0,
            creditReason: map['reason']?.toString() ?? '',
            at: parseIst(map['at']?.toString() ?? ''),
          );
        case 'catalog':
          return OrderStreamEvent(
            kind: LiveEvent.catalog,
            catalogArea: map['area']?.toString() ?? '',
            at: parseIst(map['at']?.toString() ?? ''),
          );
        default:
          return null; // unknown events are ignored
      }
    } catch (_) {
      return null;
    }
  }
}
