import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../widgets/panels.dart';

/// `orderTotals(order)` — the placed order's bill snapshot as [BillData],
/// so `BillLines` can render it exactly like the live cart totals.
BillData orderBillData(AppState state, Order order) {
  final o = order;
  return BillData(
    subtotal: o.bill.subtotal,
    couponCode: o.bill.couponCode,
    discount: o.bill.couponDiscount,
    coinsUsed: o.bill.coinsUsed,
    coinDiscount: o.bill.coinsUsed * state.coinSettings.coinValue,
    total: o.bill.total,
  );
}
