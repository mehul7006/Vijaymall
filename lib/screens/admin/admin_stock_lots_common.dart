import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/lots_api.dart';
import '../../data/api/lots_dto.dart';
import '../../data/ist.dart';
import '../../nav/nav.dart';
import '../../state/app_state.dart' show AppState, money;
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';

// ---------------------------------------------------------------------------
// Money, dates, quantities
// ---------------------------------------------------------------------------

/// Whole paise as rupees text, exact.
String lRs(int paise) => money(paise / 100);

/// A lot's unit cost (paise with up to 4 decimals) as rupees, 2 to 4 decimals.
String lCost(double paise) {
  var s = (paise / 100).toStringAsFixed(4);
  while (s.endsWith('0') && s.length - s.indexOf('.') > 3) {
    s = s.substring(0, s.length - 1);
  }
  return 'Rs $s';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// `2026-11-09` or an ISO instant -> `9 Nov 2026` (India time).
String lDate(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final d = iso.length > 10 ? parseIst(iso) : DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String lYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String lToday() => lYmd(istNow());

/// True when the `yyyy-MM-dd` expiry is before today (India).
bool lExpired(String? ymd) => ymd != null && ymd.compareTo(lToday()) < 0;

/// Weight (grams on the wire) as kg / g text.
String lKg(int grams) {
  if (grams < 1000) return '$grams g';
  final kg = grams / 1000;
  final t = kg
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '$t kg';
}

/// How a variant's quantities read: a pack label (`1 kg`, `500 ml`) for
/// counted items, grams shown as kg/g for weighed ones.
class LotUnit {
  final bool weight;
  final String pack;
  final String productName;
  const LotUnit({this.weight = false, this.pack = '', this.productName = ''});

  /// `10 x 1 kg` / `750 g` / `10`.
  String qty(int n) {
    if (weight) return lKg(n);
    return pack.isEmpty ? '$n' : '$n x $pack';
  }

  /// `+10 x 1 kg` (stock added) with an explicit sign.
  String signed(int n, {bool minus = false}) =>
      '${minus ? '-' : '+'}${qty(n)}';
}

/// Looks the variant up in the loaded catalogue; unknown = plain numbers.
LotUnit lotUnitFor(AppState state, String variantId) {
  for (final p in state.products) {
    for (final v in p.variants) {
      if (v.backendId == variantId) {
        var weight = false;
        for (final u in state.activeUnits) {
          if (u.code == v.unit && u.soldBy == 'WEIGHT') weight = true;
        }
        var pack = v.label.trim();
        if (pack.isEmpty) pack = v.unit.trim();
        return LotUnit(weight: weight, pack: pack, productName: p.name);
      }
    }
  }
  return const LotUnit();
}

// ---------------------------------------------------------------------------
// Errors, navigation, chrome
// ---------------------------------------------------------------------------

String lotsError(Object e) {
  if (e is ApiException) return e.messageWithRef;
  return gt('Could not reach the server. Please try again.');
}

void lotsBack([String fallback = '/admin/inventory']) {
  if (!Nav.instance.pop()) go(fallback);
}

const lHead = TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: 13.5,
    fontWeight: FontWeight.w800,
    color: AppColors.ink);
const lSub = TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: AppColors.ink3);
const lBody = TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: AppColors.ink2);

/// Page chrome (header + body + bottom nav) for the stock-lots module.
class LotsPage extends StatelessWidget {
  final String title, sub;
  final Widget child;
  final Future<void> Function()? onRefresh;
  const LotsPage({
    super.key,
    required this.title,
    required this.sub,
    required this.child,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  AdminHead(
                      title: title, sub: sub, bell: false, onBack: lotsBack),
                  ScreenScroll(onRefresh: onRefresh, child: child),
                ],
              ),
              const AdminNav(active: 'more'),
            ],
          ),
        ),
      );
}

/// Inline message (red = error).
class LotsNote extends StatelessWidget {
  final String text;
  final bool error;
  final bool warn;
  const LotsNote(this.text, {super.key, this.error = false, this.warn = false});

  @override
  Widget build(BuildContext context) {
    if (warn) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.goldTint,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
        child: Text(text,
            style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: AppColors.goldInk)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text,
          style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: error ? AppColors.red : AppColors.ink2)),
    );
  }
}

/// Label above value, small.
class LotsKv extends StatelessWidget {
  final String k, v;
  final Color? color;
  const LotsKv(this.k, this.v, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(gt(k), style: lSub),
          const SizedBox(height: 2),
          Text(v,
              style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color ?? AppColors.ink)),
        ],
      );
}

Widget lotSourcePill(String source) {
  switch (source.toUpperCase()) {
    case 'PURCHASE':
      return Pill.active(gt('Purchase'));
    case 'OPENING':
      return Pill(label: gt('Opening'), bg: AppColors.bg, fg: AppColors.ink2);
    case 'ADJUSTMENT':
      return Pill(
          label: gt('Adjustment'), bg: AppColors.goldTint, fg: AppColors.goldInk);
    case 'RETURN':
      return Pill(
          label: gt('Return'), bg: AppColors.navyTint, fg: AppColors.navy2);
    case 'TRANSFER':
      return Pill(
          label: gt('Transfer'), bg: AppColors.navyTint, fg: AppColors.navy2);
  }
  return Pill(label: source, bg: AppColors.bg, fg: AppColors.ink2);
}

// ---------------------------------------------------------------------------
// Lot card + write-off
// ---------------------------------------------------------------------------

/// One lot. [unit] formats quantities; [showName] adds the product name
/// (expiring list); [onChanged] runs after a successful write-off or a
/// "already done" refresh.
class LotCard extends StatelessWidget {
  final LotRow lot;
  final LotUnit unit;
  final bool showName;
  final VoidCallback onChanged;
  final VoidCallback? onStockHealth;
  const LotCard({
    super.key,
    required this.lot,
    required this.unit,
    required this.onChanged,
    this.showName = false,
    this.onStockHealth,
  });

  @override
  Widget build(BuildContext context) {
    final expired = lExpired(lot.expiryDate);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: expired ? AppColors.red : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    showName
                        ? lot.productName
                        : '${gt('Received')} ${lDate(lot.receivedAt)}',
                    style: lHead),
              ),
              const SizedBox(width: 8),
              lotSourcePill(lot.source),
            ],
          ),
          if (showName)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${gt('Received')} ${lDate(lot.receivedAt)}',
                  style: lSub),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              LotsKv('Received', unit.signed(lot.qtyReceived)),
              LotsKv('Left', unit.qty(lot.qtyRemaining),
                  color: lot.qtyRemaining == 0 ? AppColors.ink3 : null),
              LotsKv('Sold', unit.qty(lot.qtySold)),
              LotsKv('Unit cost',
                  lot.costKnown ? lCost(lot.unitCost) : gt('Cost unknown'),
                  color: lot.costKnown ? null : AppColors.red),
              LotsKv('MRP',
                  lot.mrpPaise == null ? gt('Variant price') : lRs(lot.mrpPaise!)),
              LotsKv(
                  'Price',
                  lot.pricePaise == null
                      ? gt('Variant price')
                      : lRs(lot.pricePaise!)),
              LotsKv('Batch', lot.batchNo.isEmpty ? '-' : lot.batchNo),
              LotsKv(
                  'Expiry',
                  lot.expiryDate == null
                      ? '-'
                      : '${lDate(lot.expiryDate)}${expired ? ' (${gt('expired')})' : ''}',
                  color: expired ? AppColors.red : null),
            ],
          ),
          if (lot.purchaseItemId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(gt('Received on a purchase'), style: lSub),
            ),
          if (lot.qtyRemaining > 0) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton('Write off remaining',
                  size: BtnSize.sm,
                  variant: BtnVariant.dangerSoft,
                  onTap: () async {
                    final r = await writeOffLot(context, lot, unit);
                    if (r == LotWriteOff.stockMismatch) {
                      onStockHealth?.call();
                    }
                    if (r != LotWriteOff.cancelled) onChanged();
                  }),
            ),
          ],
        ],
      ),
    );
  }
}

enum LotWriteOff { cancelled, done, alreadyDone, stockMismatch, failed }

/// Confirm + `POST /admin/stock/lots/{id}/write-off`. The reason is optional
/// (200 characters at most). It cannot be undone from the app.
Future<LotWriteOff> writeOffLot(
    BuildContext context, LotRow lot, LotUnit unit) async {
  final reason = TextEditingController();
  var busy = false;
  String? err;
  var result = LotWriteOff.cancelled;
  await showAppSheet<void>(
    context: context,
    title: gt('Write off remaining stock'),
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      Future<void> go0() async {
        if (reason.text.trim().length > 200) {
          set(() => err = gt('Reason is 200 characters at most'));
          return;
        }
        set(() {
          busy = true;
          err = null;
        });
        try {
          final r = await LotsApi.instance
              .writeOff(lot.id, reason: reason.text);
          showToast(
              '${unit.signed(r.unitsWrittenOff, minus: true)} · ${lot.productName} ${gt('written off')}');
          result = LotWriteOff.done;
          if (ctx.mounted) Navigator.of(ctx).pop();
        } on ApiException catch (e) {
          if (e.code == 'LOT_EMPTY') {
            showToast(gt('Already written off or sold. List refreshed.'));
            result = LotWriteOff.alreadyDone;
            if (ctx.mounted) Navigator.of(ctx).pop();
            return;
          }
          if (e.code == 'STOCK_MISMATCH') {
            showToast(
                gt('Stock on hand is lower than this lot. Open Stock health.'),
                'error');
            result = LotWriteOff.stockMismatch;
            if (ctx.mounted) Navigator.of(ctx).pop();
            return;
          }
          result = LotWriteOff.failed;
          set(() {
            busy = false;
            err = ApiException.fieldError(e.fields, ['reason']) ??
                e.messageWithRef;
          });
        } catch (e) {
          set(() {
            busy = false;
            err = lotsError(e);
          });
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              '${lot.productName}: ${unit.qty(lot.qtyRemaining)} ${gt('will be taken out of stock. This cannot be undone from the app.')}',
              style: lBody),
          const SizedBox(height: 12),
          AppField(
            label: 'Reason (optional)',
            controller: reason,
            maxLength: 200,
            placeholder: gt('For example: expired'),
            error: err,
          ),
          const SizedBox(height: 14),
          AppButton('Write off',
              variant: BtnVariant.danger,
              block: true,
              loading: busy,
              onTap: busy ? null : go0),
          const SizedBox(height: 8),
          AppButton('Keep stock',
              variant: BtnVariant.secondary,
              block: true,
              onTap: () => Navigator.of(ctx).pop()),
          const SizedBox(height: 8),
        ],
      );
    }),
  );
  reason.dispose();
  return result;
}
