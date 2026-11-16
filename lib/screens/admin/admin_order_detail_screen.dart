import 'package:flutter/material.dart';

import '../customer/missing_screen.dart';
import '../../data/models.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/payer_detail.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import 'admin_order_returns.dart';
import '../../state/gu_strings.dart';

/// `#/admin/order/:number` — customer, items, stage control, payment, cancel.
class AdminOrderDetailScreen extends StatelessWidget {
  final String number;

  const AdminOrderDetailScreen({super.key, required this.number});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    if (state.orderByNumber(number) == null) {
      return MissingScreen(
        title: gt('Order'),
        copy: gt('We could not find that order.'),
        backRoute: '/admin/orders',
      );
    }
    return _OrderDetailBody(number: number);
  }
}

class _OrderDetailBody extends StatefulWidget {
  final String number;

  const _OrderDetailBody({required this.number});

  @override
  State<_OrderDetailBody> createState() => _OrderDetailBodyState();
}

class _OrderDetailBodyState extends State<_OrderDetailBody> {
  /// Pending status selection (null → keep the order's current status).
  String? _target;
  String _reason = '';
  String? _reasonError;

  /// True while a status/cancel call is in flight. The move is sent to the
  /// backend before the local order changes, so the buttons wait on it.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final order = state.orderByNumber(widget.number);
    if (order == null) {
      return MissingScreen(
        title: gt('Order'),
        copy: gt('We could not find that order.'),
        backRoute: '/admin/orders',
      );
    }

    final current = _target ?? order.status;
    // A finished order (Delivered / Picked Up / Cancelled) is locked by the
    // backend — see `AppState.isFinalStatus` — so there is nothing to offer.
    final isOpen = !AppState.isFinalStatus(order.status);
    // PAYMENT_PENDING (an unpaid ONLINE order, shown as Placed): the backend
    // answers 409 AWAITING_PAYMENT to any move except cancel/reject, so the
    // stage rows stay disabled until the payment arrives.
    final open = isOpen && !order.awaitingPayment;
    final canUpdate = _target != null && _target != order.status && open;
    final steps = state.orderSteps(order);
    // The backend accepts a move to **any** stage of an open order, in any
    // order (see `AppState.stageMoveRejection`, which mirrors
    // `OrderStatus.next`), so every stage other than the one it is already on
    // is offered. Only a finished order has its rows disabled — offering a
    // move there could only end in a 409 that the old code reported as a
    // success.
    final stageHint = order.awaitingPayment
        ? 'Waiting for the customer to pay online. You cannot confirm it '
            'until the payment arrives; you can still cancel it.'
        : open
        ? 'Open order — move it to any stage; the shop sets the sequence.'
        : 'This order has reached its final stage.';
    final coinValue =
        state.coinSettings.coinValue > 0 ? state.coinSettings.coinValue : 1;
    final coinDiscount = order.coinsUsed * coinValue;
    final showCancel = isOpen;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: 'Order ${widget.number}',
                  // The list endpoint carries no customer name, so only join
                  // what actually exists — otherwise the sub reads "· 1 items".
                  sub: [
                    if (order.customer.isNotEmpty) order.customer,
                    '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                  ].join(' · '),
                  bell: false,
                  onBack: () => go('/admin/orders'),
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summary(order, state),
                      const SizedBox(height: 12),
                      _cols(
                    left: [
                      // ---- Customer ----
                      // Rows the backend actually has are shown; an order
                      // placed without a name/phone leaves those out rather
                      // than printing empty labels. Email is the identity the
                      // store really holds for a web checkout.
                      CardPanel(
                        title: gt('Customer'),
                        child: Column(
                          children: [
                            if (order.customer.isNotEmpty)
                              BillRow('Name', order.customer),
                            if (order.customerEmail.isNotEmpty)
                              BillRow('Email', order.customerEmail),
                            if (order.phone.isNotEmpty)
                              BillRow('Phone', order.phone),
                            BillRow('Address', order.address),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ---- Items ----
                      CardPanel(
                        title: gt('Items'),
                        child: Column(
                          children: [
                            for (var i = 0; i < order.items.length; i++)
                              _itemRow(order.items[i],
                                  divider: i < order.items.length - 1),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    right: [
                      // ---- Order status ----
                      CardPanel(
                        title: gt('Order status'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final s in steps)
                              RadioRow(
                                label: state.statusLabel(s),
                                selected: current == s,
                                // Offered while the order is open; the stage
                                // it already sits on is a no-op, so leave that
                                // row disabled rather than show a dead button.
                                onTap: (open &&
                                        s != current &&
                                        state.stageMoveRejection(order, s) ==
                                            null)
                                    ? () => setState(() => _target = s)
                                    : null,
                              ),
                            const SizedBox(height: 6),
                            Hint(stageHint),
                            if (canUpdate) ...[
                              const SizedBox(height: 12),
                              AppButton(
                                'Update status',
                                block: true,
                                loading: _busy,
                                onTap: _updateStatus,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ---- Payment summary ----
                      CardPanel(
                        title: gt('Payment summary'),
                        child: Column(
                          children: [
                            BillRow('Subtotal', money(order.bill.subtotal)),
                            if (order.bill.couponCode.isNotEmpty)
                              BillRow(
                                'Coupon (${order.bill.couponCode})',
                                '−${money(order.bill.couponDiscount)}',
                                valueColor: AppColors.green,
                              ),
                            if (order.coinsUsed > 0)
                              BillRow(
                                'Coins used',
                                '−${money(coinDiscount)}',
                                valueColor: AppColors.green,
                              ),
                            BillRow('Total', money(order.bill.total),
                                strong: true),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: BillRow('Payment', order.payment),
                                ),
                                PayPill(
                                  order.paymentState,
                                  label: order.paymentState,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ---- Payer detail (admin only; hidden for cashiers) ----
                      Builder(builder: (ctx) {
                        final oid =
                            StateScope.read(ctx).orderIdsByNo[order.number];
                        if (oid == null || oid.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: PayerDetail.order(oid),
                        );
                      }),

                      AdminOrderReturnsPanel(order: order),

                      // ---- Recorded cancellation remark ----
                      if (order.isCancelled) ...[
                        const SizedBox(height: 12),
                        CardPanel(
                          title: gt('Cancellation'),
                          child: Text(
                            AppState.cancelText(order, false),
                            style: const TextStyle(
                              fontFamily: AppTheme.uiFont,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink2,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],

                      // ---- Cancellation ----
                      if (showCancel) ...[
                        const SizedBox(height: 12),
                        CardPanel(
                          title: gt('Cancellation'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppField(
                                label: gt('Reason'),
                                placeholder: gt('Why is this order cancelled?'),
                                value: _reason,
                                error: _reasonError,
                                onChanged: (v) => setState(() {
                                  _reason = v;
                                  if (v.trim().isNotEmpty) _reasonError = null;
                                }),
                              ),
                              const SizedBox(height: 12),
                              AppButton(
                                'Cancel order',
                                variant: BtnVariant.danger,
                                block: true,
                                loading: _busy,
                                onTap: _cancel,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ]),
                    ],
                  ),
                ),
              ],
            ),
            const AdminNav(active: 'orders'),
          ],
        ),
      ),
    );
  }

  /// Two columns on wide layouts (details left, actions right); a single
  /// column (left then right) on phones.
  Widget _cols({required List<Widget> left, required List<Widget> right}) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 760) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: left,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: right,
              ),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [...left, ...right],
      );
    });
  }

  /// At-a-glance strip: status, payment, total and when it was placed.
  Widget _summary(Order order, AppState state) {
    const label = TextStyle(
      fontFamily: AppTheme.uiFont,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.ink3,
    );
    return CardPanel(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('TOTAL', style: label),
              const SizedBox(height: 2),
              Text(
                money(order.bill.total),
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('STATUS', style: label),
              const SizedBox(height: 4),
              StatusPill(order.status, label: state.statusLabel(order.status)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PAYMENT', style: label),
              const SizedBox(height: 4),
              PayPill(order.paymentState, label: order.paymentState),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PLACED', style: label),
              const SizedBox(height: 4),
              Text(
                '${order.placedAt.day}/${order.placedAt.month}/${order.placedAt.year}  '
                '${order.placedAt.hour.toString().padLeft(2, '0')}:'
                '${order.placedAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Server-first: the local order only moves after the backend has accepted
  /// the transition, so a refusal (`ILLEGAL_TRANSITION`, `VERSION_CONFLICT`,
  /// unreachable server) is shown as an error instead of a success toast.
  Future<void> _updateStatus() async {
    final target = _target;
    if (target == null || _busy) return;
    setState(() => _busy = true);
    final res =
        await StateScope.read(context).changeOrderStage(widget.number, target);
    if (!mounted) return;
    setState(() {
      _busy = false;
      // Cleared either way: after a success the order sits on that stage,
      // after a refusal it never moved there in the first place.
      _target = null;
    });
    if (res != null) showToast(res.message, res.ok ? 'success' : 'error');
  }

  Future<void> _cancel() async {
    final reason = _reason.trim();
    if (reason.isEmpty) {
      setState(() => _reasonError = 'Enter a cancellation reason');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    final res = await StateScope.read(context)
        .cancelOrder(widget.number, reason, 'admin');
    if (!mounted) return;
    setState(() => _busy = false);
    if (res == null) return;
    showToast(res.message, res.ok ? 'success' : 'error');
    // Leave only when the server really cancelled it.
    if (res.ok) go('/admin/orders');
  }

  /// `orderLineRow(item)` — name · unit, qty × price, line total.
  Widget _itemRow(OrderItem it, {bool divider = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: divider ? AppColors.line : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${it.name} · ${it.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${it.qty} × ${money(it.price)}',
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            money(it.price * it.qty),
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
