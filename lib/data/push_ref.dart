import '../state/app_state.dart';

/// Maps an inbox row (`kind` + `ref`, see `60-admin-push-notifications.md` and
/// the order/flash notices) to the app route it should open. Returns null when
/// the row has no target the app understands (the caller then just marks it
/// read and stays in the inbox).
///
/// Conventions:
///  * `ORDER` / `PAYMENT`: `ref` is the order number (`VSM-1044`).
///  * `FLASH`: `ref` is the flash sale id (staff notices).
///  * `STOCK`: staff stock alert, `ref` is a product id or null.
///  * `ANNOUNCEMENT` (admin broadcast): free text chosen by the admin:
///    `offers`, `coins`, `product:<uuid>`, `category:<uuid>`, `order:<no>`.
String? inboxRoute(AppState st, String? kind, String? ref) {
  final k = (kind ?? '').toUpperCase();
  final r = (ref ?? '').trim();
  final staff = st.adminPagesAllowed;

  String? order(String no) {
    if (no.isEmpty) return null;
    // Some rows carry the order id rather than the number.
    var number = no;
    if (!st.orderIdsByNo.containsKey(no)) {
      for (final e in st.orderIdsByNo.entries) {
        if (e.value == no) {
          number = e.key;
          break;
        }
      }
    }
    return staff ? '/admin/order/$number' : '/track/$number';
  }

  switch (k) {
    case 'ORDER':
    case 'PAYMENT':
      return order(r);
    case 'FLASH':
      if (staff && r.isNotEmpty) return '/admin/flash-sales?id=$r';
      return staff ? '/admin/flash-sales' : '/home';
    case 'STOCK':
      return staff ? '/admin/inventory' : null;
    case 'ANNOUNCEMENT':
      return _announcement(st, r, order);
  }
  // Unknown kind (new backend kinds must not crash the inbox): an order-looking
  // ref still opens the order.
  return null;
}

String? _announcement(AppState st, String ref, String? Function(String) order) {
  if (ref.isEmpty) return null;
  final lower = ref.toLowerCase();
  if (lower == 'offers') return '/shop?hot=1';
  if (lower == 'coins' || lower == 'wallet') return '/wallet';
  if (lower == 'orders') return '/orders';
  final i = ref.indexOf(':');
  if (i <= 0) return null;
  final type = lower.substring(0, i);
  final value = ref.substring(i + 1).trim();
  if (value.isEmpty) return null;
  switch (type) {
    case 'order':
      return order(value);
    case 'product':
      for (final p in st.products) {
        if (p.id == value || p.variants.any((v) => v.backendId == value)) {
          return '/product/${p.id}';
        }
      }
      return '/shop';
    case 'category':
      return '/shop?cat=${Uri.encodeQueryComponent(value)}';
  }
  return null;
}
