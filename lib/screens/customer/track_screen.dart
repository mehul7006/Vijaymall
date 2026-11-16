import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/seed_data.dart' as seed;
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/customer_wide_parts.dart';
import '../../widgets/panels.dart';
import '../../widgets/store_actions.dart';
import '../../widgets/store_kit.dart';
import '../../widgets/store_status_chip.dart';
import '../../widgets/toast.dart';
import 'missing_screen.dart';
import 'order_extras.dart';
import 'order_bill.dart';
import 'sheets/cancel_order_sheet.dart';
import 'sheets/store_info_sheet.dart';

/// `#/track/{number}` — live status, timeline, rider, details and actions.
class TrackScreen extends StatelessWidget {
  final String number;

  const TrackScreen({super.key, required this.number});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final order = state.orderByNumber(number);

    if (order == null) {
      return MissingScreen(
        title: gu ? 'ઓર્ડર ટ્રેક કરો' : 'Tracking',
        copy: gu
            ? 'અમને એ ઓર્ડર મળ્યો નહીં.'
            : 'We could not find that order.',
        backRoute: '/orders',
      );
    }

    final pickup = order.mode == 'pickup';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const StatusBar(),
            ScreenBar(
              title: gu ? 'ઓર્ડર ટ્રેક કરો' : 'Track order',
              sub: '$number · ${pickup ? (gu ? 'સ્ટોર પિકઅપ' : 'Store pickup') : (gu ? 'હોમ ડિલિવરી' : 'Home delivery')}',
              onBack: () => go('/orders'),
              right: IconBtn(
                'phone',
                iconSize: 17,
                onTap: () => showStoreInfoSheet(context),
              ),
            ),
            _trackBody(context, state, gu, order),
          ],
        ),
      ),
    );
  }
}

Widget _trackBody(BuildContext context, AppState state, bool gu, Order order) {
  final pickup = order.mode == 'pickup';
  final cancelled = order.status == 'Cancelled';
              final w = MediaQuery.sizeOf(context).width;
              const gap = SizedBox(height: 12);
              final statusW = <Widget>[
                if (order.awaitingPayment && !cancelled) PayPendingCard(order: order),
                if (cancelled)
                  _cancelledCard(state, gu, order)
                else ...[
                  _liveCard(state, gu, order),
                  _timelineCard(state, gu, order),
                ],
                if (cancelled && order.payWire == 'REFUNDED')
                  RefundNote(order: order),
              ];
              final infoW = <Widget>[
                OrderReturnsCard(order: order),
                if (!cancelled && order.partner != null) _riderCard(gu, order),
                if (!cancelled && pickup) _pickupNote(state, gu, order),
                _addressCard(gu, order),
              ];
              final detailW = <Widget>[
                _detailsCard(state, gu, order),
                if (AppState.customerCanCancel(order))
                  AppButton(
                    gu ? 'આ ઓર્ડર રદ કરો' : 'Cancel this order',
                    variant: BtnVariant.dangerSoft,
                    block: true,
                    icon: 'close',
                    onTap: () => showCancelOrderSheet(context, order),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        gu ? 'દુકાનને કૉલ' : 'Call store',
                        variant: BtnVariant.secondary,
                        icon: 'phone',
                        onTap: () => StoreActions.call(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        gu ? 'ફરી ઓર્ડર' : 'Order again',
                        variant: BtnVariant.secondary,
                        icon: 'refresh',
                        onTap: () async {
                          final msg = await StateScope.read(context)
                              .reorderFromServer(order.number);
                          final failed =
                              msg == 'Those items are not available right now';
                          showToast(msg, failed ? 'error' : 'success');
                          if (!failed) go('/cart');
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        gu
                            ? 'આ ઓર્ડરમાં મદદ જોઈએ?'
                            : 'Need help with this order?',
                        style: _ts(gu,
                            size: 12,
                            w: FontWeight.w600,
                            color: AppColors.ink3),
                      ),
                    ),
                    AppLink(
                      seed.store.phone,
                      onTap: () => StoreActions.call(),
                    ),
                  ],
                ),
              ];
              Widget col(List<Widget> items) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) gap,
                        items[i],
                      ],
                    ],
                  );
              Widget body;
              if (w >= 1400) {
                body = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 10, child: col(statusW)),
                    const SizedBox(width: 22),
                    Expanded(flex: 9, child: col(infoW)),
                    const SizedBox(width: 22),
                    Expanded(flex: 11, child: col(detailW)),
                  ],
                );
              } else if (w >= CustomerWide.breakpoint) {
                body = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: col([...statusW, ...infoW])),
                    const SizedBox(width: 22),
                    Expanded(flex: 10, child: col(detailW)),
                  ],
                );
              } else {
                body = col([...statusW, ...infoW, ...detailW]);
              }
              return ScreenScroll(bottom: 28, child: body);
}

// ---------------------------------------------------------------------------
// Live / cancelled status card
// ---------------------------------------------------------------------------

Widget _liveCard(AppState state, bool gu, Order order) {
  final pickup = order.mode == 'pickup';
  final statusLabel = gu
      ? (AppState.statusLabelGu[order.status] ?? order.status)
      : state.statusLabel(order.status);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: StoreKit.heroNavyRed,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
            color: AppColors.red.withValues(alpha: .25),
            offset: const Offset(0, 12),
            blurRadius: 26),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                pickup
                    ? (gu ? 'પિકઅપ ઓર્ડર' : 'PICKUP ORDER')
                    : (gu ? 'લાઇવ ડિલિવરી' : 'LIVE DELIVERY'),
                style: _ts(gu,
                    size: 11,
                    w: FontWeight.w800,
                    color: AppColors.gold2),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _time12(order.updatedAt),
                style: _ts(gu,
                    size: 11,
                    w: FontWeight.w800,
                    color: AppColors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          statusLabel,
          style: _ts(gu,
              size: 23, w: FontWeight.w800, color: AppColors.white, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          _eta(state, gu, order),
          style: _ts(gu,
              size: 13,
              w: FontWeight.w600,
              color: const Color(0xC9FFFFFF),
              height: 1.4),
        ),
      ],
    ),
  );
}

Widget _cancelledCard(AppState state, bool gu, Order order) {
  final reason = AppState.cancelText(order, gu);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: StoreKit.card(accent: AppColors.red, radius: 22, tinted: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: gu ? 'ઓર્ડર રદ' : 'ORDER CANCELLED',
                style: _ts(gu,
                    size: 13, w: FontWeight.w800, color: AppColors.red),
              ),
              TextSpan(
                text: '  ·  ${gu ? 'રિમાર્ક' : 'Remark'}: $reason',
                style: _ts(gu,
                    size: 15,
                    w: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppIcon('info',
                      size: 15, color: AppColors.ink2, sw: 2),
                  const SizedBox(width: 8),
                  Text(
                    gu ? 'કેમ રદ થયો' : 'Why this was cancelled',
                    style: _ts(gu,
                        size: 12.5,
                        w: FontWeight.w800,
                        color: AppColors.ink),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                reason,
                style: _ts(gu,
                    size: 12.5,
                    w: FontWeight.w600,
                    color: AppColors.ink2,
                    height: 1.45),
              ),
            ],
          ),
        ),
        if (order.coinsUsed > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.goldTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIcon('coin',
                    size: 14, color: AppColors.goldInk, sw: 2),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    gu
                        ? '${order.coinsUsed} કોઈન્સ તમારા વોલેટમાં પાછા મળ્યા છે. પ્રીપેઇડ રકમ 3–5 કાર્યકારી દિવસમાં પરત મળશે.'
                        : '${order.coinsUsed} coins have been returned to your wallet. Prepaid amounts are refunded in 3–5 working days.',
                    style: _ts(gu,
                        size: 11.5,
                        w: FontWeight.w600,
                        color: AppColors.goldInk,
                        height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

Widget _timelineCard(AppState state, bool gu, Order order) {
  final steps = state.orderSteps(order);
  final current = state.currentStepIndex(order);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: StoreKit.card(accent: AppColors.gold, radius: 22),
    child: Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _stepRow(state, gu, order, steps, i, current),
      ],
    ),
  );
}

Widget _stepRow(AppState state, bool gu, Order order, List<String> steps,
    int i, int current) {
  final step = steps[i];
  final done = i < current;
  final isCurrent = i == current;
  final last = i == steps.length - 1;

  final event = _historyAt(order, step);
  final sub = event != null
      ? '${formatDate(event)} · ${_time12(event)}'
      : (gu
          ? (_stepCopyGu[step] ?? '')
          : (_stepCopyEn[step] ?? ''));

  final stepLabel = gu
      ? (AppState.statusLabelGu[step] ?? step)
      : state.statusLabel(step);

  Widget dot;
  if (done) {
    dot = Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1FB57E), AppColors.green]),
      ),
      child: const Center(
        child: AppIcon('check', size: 13, color: AppColors.white, sw: 2.6),
      ),
    );
  } else if (isCurrent) {
    dot = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: StoreKit.redWarm,
        border: Border.all(color: AppColors.white, width: 2),
      ),
      child: const Center(
        child: AppIcon('clock', size: 12, color: AppColors.white, sw: 2.2),
      ),
    );
  } else {
    dot = Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF1EEE6),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFFD9D4C8), width: 2),
        ),
      ),
    );
  }

  if (done) {
    dot = TweenAnimationBuilder<double>(
      tween: Tween(begin: .5, end: 1),
      duration: Duration(milliseconds: 380 + 90 * i),
      curve: Curves.easeOutBack,
      builder: (context, v, c) => Transform.scale(scale: v, child: c),
      child: dot,
    );
  } else if (isCurrent) {
    dot = _PulseDot(child: dot);
  }

  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            dot,
            if (!last)
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 2,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFFE6E2D8)),
                        if (done) _GrowLine(delayMs: 120 * i),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepLabel,
                  style: _ts(gu,
                      size: 13.5,
                      w: isCurrent || done
                          ? FontWeight.w800
                          : FontWeight.w700,
                      color: isCurrent || done
                          ? AppColors.ink
                          : AppColors.ink3),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: _ts(gu,
                      size: 11.5,
                      w: FontWeight.w600,
                      color: AppColors.ink3,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Rider / pickup note / address / details
// ---------------------------------------------------------------------------

Widget _riderCard(bool gu, Order order) {
  final p = order.partner!;
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: StoreKit.card(accent: AppColors.navy, radius: 20),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.avatarGradient,
          ),
          child: const Center(
            child: AppIcon('user', size: 22, color: AppColors.white, sw: 2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                style: _ts(gu,
                    size: 14, w: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                '${p.role} · ${p.phone}',
                style: _ts(gu,
                    size: 11.5, w: FontWeight.w600, color: AppColors.ink3),
              ),
            ],
          ),
        ),
        IconBtn(
          'phone',
          size: 40,
          iconSize: 17,
          onTap: () => showToast('Calling ${p.phone}'),
        ),
      ],
    ),
  );
}

Widget _pickupNote(AppState state, bool gu, Order order) {
  final slot = order.slot.isNotEmpty ? order.slot : state.flow.selectedSlot;
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: StoreKit.card(accent: AppColors.navy, radius: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.navyTint,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Center(
            child: AppIcon('store', size: 16, color: AppColors.navy, sw: 2),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gu ? 'પિકઅપ કાઉન્ટર' : 'Pickup counter',
                style: _ts(gu,
                    size: 13.5, w: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                seed.store.addressFor(gu),
                style: _ts(gu,
                    size: 12,
                    w: FontWeight.w600,
                    color: AppColors.ink2,
                    height: 1.4),
              ),
              const SizedBox(height: 5),
              Text(
                '$slot · ${seed.store.phone}',
                style: _ts(gu,
                    size: 11.5, w: FontWeight.w700, color: AppColors.navy),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _addressCard(bool gu, Order order) {
  final pickup = order.mode == 'pickup';
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: StoreKit.card(accent: AppColors.navy, radius: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.navyTint,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: AppIcon(
              pickup ? 'store' : 'pin',
              size: 18,
              color: AppColors.navy,
              sw: 1.9,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickup
                    ? (gu ? 'અહીંથી લો' : 'Collect from')
                    : (gu ? 'ડિલિવરી સરનામું' : 'Delivering to'),
                style: _ts(gu,
                    size: 11.5, w: FontWeight.w700, color: AppColors.ink3),
              ),
              const SizedBox(height: 5),
              Text(
                order.address,
                style: _ts(gu,
                    size: 13,
                    w: FontWeight.w700,
                    color: AppColors.ink,
                    height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _detailsCard(AppState state, bool gu, Order order) {
  final statusLabel = gu
      ? (AppState.statusLabelGu[order.status] ?? order.status)
      : state.statusLabel(order.status);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: StoreKit.card(accent: AppColors.navy, radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                gu ? 'ઓર્ડર વિગત' : 'Order details',
                style: _ts(gu,
                    size: 16, w: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            StoreStatusChip(order.status, label: statusLabel),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < order.items.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: AppColors.line),
          _itemRow(gu, order.items[i]),
        ],
        const SizedBox(height: 6),
        const Divider(height: 1, thickness: 1, color: AppColors.line),
        BillLines(orderBillData(state, order)),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: AppColors.line),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                _paymentLabel(gu, order.payment),
                style: _ts(gu,
                    size: 13.5, w: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            PayPill(
              order.paymentState,
              label: gu
                  ? (AppState.payStateGu[order.paymentState] ??
                      order.paymentState)
                  : order.paymentState,
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _itemRow(bool gu, OrderItem it) {
  final name = gu && it.nameGu.isNotEmpty ? it.nameGu : it.name;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_toneBg(it.tone), const Color(0xFFFFF3DC)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.white, width: 2),
          ),
          child: Center(
            child: ProductArtView(it.art, size: 30),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(gu,
                    size: 13, w: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                '${it.unit} × ${it.qty}',
                style: _ts(gu,
                    size: 11.5, w: FontWeight.w600, color: AppColors.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          money(it.price * it.qty),
          style: _ts(gu, size: 13, w: FontWeight.w800, color: AppColors.ink),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const Map<String, String> _stepCopyEn = {
  'Placed': 'Order received by the store',
  'Confirmed': 'Store confirmed your items',
  'Packed': 'Packed and bill checked',
  'Out for Delivery': 'Rider is on the way',
  'Ready for Pickup': 'Waiting at the store counter',
  'Delivered': 'Handed over at your door',
  'Picked Up': 'Collected from the store',
};

const Map<String, String> _stepCopyGu = {
  'Placed': 'દુકાને ઓર્ડર મળ્યો',
  'Confirmed': 'દુકાને વસ્તુઓ કન્ફર્મ કરી',
  'Packed': 'પેક થયો અને બિલ ચકાસ્યું',
  'Out for Delivery': 'રાઇડર રસ્તે છે',
  'Ready for Pickup': 'દુકાન કાઉન્ટર પર તૈયાર',
  'Delivered': 'તમારા ઘરે પહોંચાડ્યો',
  'Picked Up': 'દુકાનથી લઈ લીધો',
};

const Map<String, Map<String, String>> _etaGu = {
  'delivery': {
    'Placed': 'આજે 8:00 વાગ્યા સુધી ડિલિવરી',
    'Confirmed': 'દુકાન તમારો ઓર્ડર પેક કરી રહી છે',
    'Packed': 'રાઇડર થોડી વારમાં લેશે',
    'Out for Delivery': '15 – 25 મિનિટમાં પહોંચશે',
    'Delivered': 'પહોંચાડાયો',
  },
  'pickup': {
    'Placed': 'દુકાન 15 મિનિટમાં કન્ફર્મ કરશે',
    'Confirmed': 'તમારો ઓર્ડર પેક થઈ રહ્યો છે',
    'Packed': 'પિકઅપ માટે લગભગ તૈયાર',
    'Ready for Pickup': 'આજે દુકાનમાંથી લઈ જાઓ',
    'Picked Up': 'લઈ લીધો',
  },
};

DateTime? _historyAt(Order order, String status) {
  DateTime? at;
  for (final e in order.statusHistory) {
    if (e.status == status) at = e.at;
  }
  return at;
}

String _eta(AppState state, bool gu, Order order) {
  final map =
      order.mode == 'pickup' ? AppState.etaPickup : AppState.etaDelivery;
  var base = map[order.status] ?? '';
  if (gu) {
    base = _etaGu[order.mode]?[order.status] ?? base;
  }
  if (order.status == 'Delivered' || order.status == 'Picked Up') {
    final at = _historyAt(order, order.status) ?? order.updatedAt;
    return '$base · ${_time12(at)}';
  }
  return base;
}

/// `formatTime()` — 12-hour clock label.
String _time12(DateTime t) {
  var h = t.hour % 12;
  if (h == 0) h = 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _paymentLabel(bool gu, String payment) {
  if (!gu) return payment;
  switch (payment) {
    case 'UPI / Card':
      return 'UPI / કાર્ડ';
    case 'Cash on delivery':
      return 'ડિલિવરી પર રોકડ';
    case 'Pay at store':
      return 'દુકાન પર ચૂકવો';
    default:
      return payment;
  }
}

Color _toneBg(String tone) => switch (tone) {
      'mint' => const Color(0xFFDFF4EA),
      'peach' => const Color(0xFFFFE9DC),
      'gold' => const Color(0xFFFFF1C8),
      'rose' => const Color(0xFFFBE3EA),
      'sky' => const Color(0xFFE3F1FA),
      'lilac' => const Color(0xFFECE7F8),
      'sand' => const Color(0xFFF6EDDD),
      _ => AppColors.bg,
    };

TextStyle _ts(
  bool gu, {
  double size = 13,
  FontWeight w = FontWeight.w600,
  Color color = AppColors.ink,
  double? height,
}) {
  if (gu) return AppTheme.guj(size: size, w: w, color: color);
  return TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
  );
}

/// Green connector that fills downward once on first build.
class _GrowLine extends StatelessWidget {
  final int delayMs;
  const _GrowLine({required this.delayMs});

  @override
  Widget build(BuildContext context) {
    final total = 500 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: Curves.easeOut),
      builder: (context, v, _) => Align(
        alignment: Alignment.topCenter,
        child: FractionallySizedBox(
          heightFactor: v.clamp(0.0, 1.0),
          widthFactor: 1,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.green, AppColors.red],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft pulsing halo behind the current timeline step.
class _PulseDot extends StatefulWidget {
  final Widget child;
  const _PulseDot({required this.child});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, c) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withValues(alpha: .15 + .35 * _c.value),
              blurRadius: 2 + 8 * _c.value,
              spreadRadius: 1 + 3 * _c.value,
            ),
          ],
        ),
        child: c,
      ),
    );
  }
}
