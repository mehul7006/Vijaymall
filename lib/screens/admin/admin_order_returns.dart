import '../../state/gu_strings.dart';
import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/dto_ops.dart';
import '../../data/models.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';

TextStyle _t(double size, FontWeight w, Color c) => TextStyle(
    fontFamily: AppTheme.uiFont, fontSize: size, fontWeight: w, color: c);

/// Staff returns on a DELIVERED / PICKED_UP order:
/// `GET /admin/orders/{id}/returns` and `POST /admin/orders/{id}/returns`
/// (Idempotency-Key is added by the API client). Shows what was already
/// returned and lets staff record more, each line capped at what is still
/// returnable (`RETURN_EXCEEDS_SOLD` otherwise).
class AdminOrderReturnsPanel extends StatefulWidget {
  const AdminOrderReturnsPanel({super.key, required this.order});

  final Order order;

  @override
  State<AdminOrderReturnsPanel> createState() => _AdminOrderReturnsPanelState();
}

class _AdminOrderReturnsPanelState extends State<AdminOrderReturnsPanel> {
  List<OrderReturnDto> _returns = const [];
  bool _loaded = false;

  String? get _id => StateScope.read(context).orderIdsByNo[widget.order.number];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = _id;
    if (id == null || id.isEmpty) return;
    try {
      final r = await Api.instance.admin.listOrderReturns(id);
      if (mounted) setState(() {
        _returns = r;
        _loaded = true;
      });
    } on ApiException {
      if (mounted) setState(() => _loaded = true);
    }
  }

  int _returned(String productId) => [
        for (final r in _returns)
          for (final it in r.items)
            if (it.productId == productId) it.qty
      ].fold(0, (a, b) => a + b);

  Future<void> _record() async {
    final id = _id;
    if (id == null || id.isEmpty) return;
    final lines = <String, int>{}; // productId -> qty
    final restock = <String, bool>{};
    final reason = TextEditingController();
    String? error;
    ReturnPreviewDto? preview;
    bool busy = false;
    final order = widget.order;
    final done = await showDialog<OrderReturnDto>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Record a return'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final it in order.items)
                  if (it.productId.isNotEmpty)
                    Builder(builder: (_) {
                      final left = it.qty - _returned(it.productId);
                      final q = lines[it.productId] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${it.name} · ${it.unit}',
                                style: _t(13, FontWeight.w700, AppColors.ink)),
                            Row(
                              children: [
                                Text('Returnable: $left',
                                    style: _t(11.5, FontWeight.w600,
                                        AppColors.ink3)),
                                const Spacer(),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: q > 0
                                      ? () => setD(() {
                                            lines[it.productId] = q - 1;
                                            preview = null;
                                          })
                                      : null,
                                ),
                                Text('$q',
                                    style: _t(14, FontWeight.w800,
                                        AppColors.ink)),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: q < left
                                      ? () => setD(() {
                                            lines[it.productId] = q + 1;
                                            preview = null;
                                          })
                                      : null,
                                ),
                              ],
                            ),
                            if (q > 0)
                              Row(
                                children: [
                                  Checkbox(
                                    value: restock[it.productId] ?? true,
                                    onChanged: (v) => setD(() {
                                      restock[it.productId] = v ?? true;
                                      preview = null;
                                    }),
                                  ),
                                  Text('Put back on the shelf',
                                      style: _t(12, FontWeight.w600,
                                          AppColors.ink2)),
                                ],
                              ),
                          ],
                        ),
                      );
                    }),
                TextField(
                  controller: reason,
                  maxLength: 200,
                  decoration: const InputDecoration(
                      labelText: 'Reason (required)',
                      hintText: 'e.g. Packet damaged'),
                ),
                if (preview != null) _previewBox(preview!),
                if (error != null)
                  Text(error!, style: _t(12, FontWeight.w700, AppColors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: Text(gt('Close')),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final picked = {
                        for (final e in lines.entries)
                          if (e.value > 0) e.key: e.value
                      };
                      if (picked.isEmpty) {
                        setD(() => error = 'Choose at least one item');
                        return;
                      }
                      if (reason.text.trim().isEmpty) {
                        setD(() => error = 'Enter the reason');
                        return;
                      }
                      if (reason.text.trim().length > 200) {
                        setD(() => error = 'Reason must be 200 characters or fewer');
                        return;
                      }
                      setD(() {
                        busy = true;
                        error = null;
                      });
                      // Step 1: always show the exact refund first.
                      if (preview == null) {
                        try {
                          final pv = await Api.instance.admin
                              .previewOrderReturn(id, items: [
                            for (final e in picked.entries)
                              {
                                'productId': e.key,
                                'qty': e.value,
                                'restock': restock[e.key] ?? true,
                              }
                          ]);
                          setD(() {
                            busy = false;
                            preview = pv;
                          });
                        } on ApiException catch (e) {
                          setD(() {
                            busy = false;
                            error = _returnError(e);
                          });
                        }
                        return;
                      }
                      try {
                        final r = await Api.instance.admin.recordOrderReturn(
                          id,
                          reason: reason.text.trim(),
                          items: [
                            for (final e in picked.entries)
                              {
                                'productId': e.key,
                                'qty': e.value,
                                'restock': restock[e.key] ?? true,
                              }
                          ],
                        );
                        if (ctx.mounted) Navigator.pop(ctx, r);
                      } on ApiException catch (e) {
                        setD(() {
                          busy = false;
                          error = _returnError(e);
                        });
                      }
                    },
              child: Text(busy
                  ? 'Saving…'
                  : preview == null
                      ? 'Check the refund'
                      : 'Confirm return'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if (done != null) {
      showToast(
        done.refundMode == 'CASH'
            ? 'Return recorded. Hand ${money(done.refundPaise / 100)} cash to the customer.'
            : done.refundMode == 'ONLINE'
                ? 'Return recorded. ${money(done.refundPaise / 100)} is refunded to the customer\'s payment method.'
                : 'Return recorded. Nothing to refund.',
        'success',
      );
      await _load();
    }
  }

  /// The server's exact answer: refund, coupon / coin shares kept, clawback.
  Widget _previewBox(ReturnPreviewDto pv) {
    Widget row(String l, int paise, {bool bold = false}) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(children: [
            Expanded(
                child: Text(l,
                    style: _t(12.5, bold ? FontWeight.w800 : FontWeight.w600,
                        AppColors.ink2))),
            Text(money(paise / 100),
                style: _t(12.5, bold ? FontWeight.w800 : FontWeight.w700,
                    AppColors.ink)),
          ]),
        );
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(gt('Refund preview'), style: _t(13, FontWeight.w800, AppColors.ink)),
          for (final it in pv.items)
            row('${it.qty} x ${it.name}', it.refundPaise),
          if (pv.couponShareRemovedPaise > 0)
            row(gt('Coupon share not refunded'), pv.couponShareRemovedPaise),
          if (pv.coinShareRemovedPaise > 0)
            row(gt('Coin share not refunded'), pv.coinShareRemovedPaise),
          if (pv.couponClawbackPaise > 0)
            row(gt('Coupon taken back (kept items fall below the minimum)'),
                pv.couponClawbackPaise),
          if (pv.deliveryFeeRefundedPaise > 0)
            row(gt('Delivery fee refunded'), pv.deliveryFeeRefundedPaise),
          Text(gt('Delivery fee is not refunded'),
              style: _t(11.5, FontWeight.w600, AppColors.ink3)),
          const Divider(height: 14),
          row(gt('Customer is refunded'), pv.refundPaise, bold: true),
        ],
      ),
    );
  }

  String _returnError(ApiException e) {
    final d = e.details;
    String rs(Object? v) => v is num ? money(v / 100) : '-';
    switch (e.code) {
      case 'ORDER_NOT_DELIVERED':
        return 'Only delivered or picked-up orders can have returns.';
      case 'RETURN_EXCEEDS_SOLD':
        final left = d?['returnable'];
        return 'That is more than is still returnable on this order'
            '${left is num ? ' (only $left left)' : ''}. Lower the quantity and check again.';
      case 'REFUND_EXCEEDS_ORDER':
        return 'The refund would be more than the order total (${rs(d?['totalPaise'])}). '
            'Ask the owner; do not retry.';
      case 'REFUND_EXCEEDS_PAYMENT':
        return 'The online refund would be more than was paid: paid ${rs(d?['paidPaise'])}, '
            'already refunded ${rs(d?['alreadyRefundedPaise'])}, now asked ${rs(d?['requestedPaise'])}. '
            'Refund the rest in cash if the owner agrees.';
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    if (o.status != 'Delivered' && o.status != 'Picked Up') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CardPanel(
        title: 'Returns',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loaded && _returns.isEmpty)
              Text('No returns recorded.',
                  style: _t(12.5, FontWeight.w600, AppColors.ink3)),
            for (final r in _returns) ...[
              Text('${r.reason} · ${money(r.refundPaise / 100)} (${r.refundMode})',
                  style: _t(13, FontWeight.w700, AppColors.ink)),
              for (final it in r.items)
                Text(
                    '${it.qty} × ${it.name}${it.restocked ? ' · restocked' : ''}',
                    style: _t(12, FontWeight.w600, AppColors.ink3)),
              if (r.couponClawbackPaise > 0)
                Text(
                    'Coupon benefit taken back: ${money(r.couponClawbackPaise / 100)}',
                    style: _t(11.5, FontWeight.w600, AppColors.ink3)),
              if (r.coinsClawedBack > 0 || r.coinsRestored > 0)
                Text(
                    'Coins: ${r.coinsRestored} returned, ${r.coinsClawedBack} taken back',
                    style: _t(11.5, FontWeight.w600, AppColors.ink3)),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            AppButton('Record a return',
                variant: BtnVariant.secondary, block: true, onTap: _record),
          ],
        ),
      ),
    );
  }
}
