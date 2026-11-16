import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api/flash_dto.dart';
import '../data/flash_store.dart';
import '../data/ist.dart';
import '../data/models.dart';
import '../nav/nav.dart';
import '../provider/state_scope.dart';
import '../state/app_state.dart' show money;
import '../state/gu_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// `1d 02h`, `2:05:09` or `04:09` for a number of seconds.
String flashClockText(int secs) {
  if (secs < 0) secs = 0;
  final d = secs ~/ 86400;
  final h = (secs % 86400) ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  final s = secs % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (d > 0) return '${d}d ${two(h)}h ${two(m)}m';
  if (h > 0) return '$h:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// `9 Nov, 4:30 PM` for an India wall-clock value.
String flashWhen(DateTime? ist) {
  if (ist == null) return '';
  final h12 = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
  final mm = ist.minute.toString().padLeft(2, '0');
  final ap = ist.hour >= 12 ? 'PM' : 'AM';
  return '${ist.day} ${_months[ist.month - 1]}, $h12:$mm $ap';
}

/// True when [ist] falls on today's India calendar day.
bool _isToday(DateTime? ist) {
  if (ist == null) return false;
  final n = istNow();
  return ist.year == n.year && ist.month == n.month && ist.day == n.day;
}

String flashStartText(DateTime? ist) {
  if (ist == null) return '';
  final h12 = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
  final t =
      '$h12:${ist.minute.toString().padLeft(2, '0')} ${ist.hour >= 12 ? 'PM' : 'AM'}';
  return _isToday(ist) ? '${gt('Today')}, $t' : flashWhen(ist);
}

/// Live countdown text. [seconds] is read every second; [onZero] fires once
/// when it reaches 0 (the caller refetches: the sale may already have moved).
class FlashCountdown extends StatefulWidget {
  final int Function() seconds;
  final String prefix;
  final TextStyle? style;
  final VoidCallback? onZero;

  const FlashCountdown({
    super.key,
    required this.seconds,
    this.prefix = '',
    this.style,
    this.onZero,
  });

  @override
  State<FlashCountdown> createState() => _FlashCountdownState();
}

class _FlashCountdownState extends State<FlashCountdown> {
  Timer? _t;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.seconds() <= 0 && !_fired) {
        _fired = true;
        widget.onZero?.call();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.seconds();
    if (s > 0) _fired = false;
    return Text(
      '${widget.prefix}${flashClockText(s)}',
      style: widget.style ??
          const TextStyle(
            fontFamily: AppTheme.uiFont,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.red,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
    );
  }
}

/// Countdown to an offer's `endsAt` using the server-corrected clock.
class FlashOfferCountdown extends StatelessWidget {
  final FlashOffer offer;
  final TextStyle? style;
  final String prefix;
  const FlashOfferCountdown(this.offer, {super.key, this.style, this.prefix = ''});

  @override
  Widget build(BuildContext context) => FlashCountdown(
        seconds: () => FlashClock.secondsUntil(offer.endsAt),
        prefix: prefix,
        style: style,
        onZero: FlashStore.instance.bump,
      );
}

/// Small "Flash 20% off" pill used on product cards.
class FlashBadge extends StatelessWidget {
  final FlashOffer offer;
  const FlashBadge(this.offer, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon('bolt', size: 10, color: AppColors.white, sw: 2.2),
          const SizedBox(width: 3),
          Text(
            offer.discountPercent > 0
                ? '${gt('Flash')} ${offer.discountPercent}%'
                : gt('Flash'),
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Server-driven limits for an offer: units left and per-customer cap.
List<String> flashLimitNotes(FlashOffer o) {
  final gu = GuLang.active;
  final out = <String>[];
  final left = o.unitsLeft;
  if (left != null && left > 0 && left <= 20) {
    out.add(gu ? 'ફ્લેશ ભાવે ફક્ત $left બાકી' : 'Only $left left at this price');
  }
  if (o.perCustomerLimit > 0) {
    out.add(gu
        ? 'દરેક ગ્રાહકને વધુમાં વધુ ${o.perCustomerLimit}'
        : 'Max ${o.perCustomerLimit} per customer at this price');
  }
  return out;
}

/// Max units that can go at the flash price for one customer (null = no
/// limit). Informational only: the server quote decides.
int? flashMaxUnits(FlashOffer o) {
  int? m;
  if (o.unitsLeft != null) m = o.unitsLeft;
  if (o.perCustomerLimit > 0) {
    m = m == null
        ? o.perCustomerLimit
        : (o.perCustomerLimit < m ? o.perCustomerLimit : m);
  }
  return m;
}

/// Estimated total of [qty] units of [v]: flash price up to the allowance,
/// normal price for the rest (the server quote is the final word).
num flashLineTotal(Variant v, int qty) {
  final o = v.flash;
  if (o == null) return v.price * qty;
  final cap = flashMaxUnits(o);
  if (cap == null || qty <= cap) return v.price * qty;
  return v.price * cap + (v.listPrice ?? v.price) * (qty - cap);
}

/// Panel for the product page: title, end countdown, remaining and limits,
/// and a note when the chosen quantity goes past the flash allowance.
class FlashOfferPanel extends StatelessWidget {
  final FlashOffer offer;
  final int qty;
  final num normalPrice;
  const FlashOfferPanel(
      {super.key, required this.offer, this.qty = 1, required this.normalPrice});

  @override
  Widget build(BuildContext context) {
    final gu = GuLang.active;
    final notes = flashLimitNotes(offer);
    final cap = flashMaxUnits(offer);
    if (cap != null && qty > cap) {
      notes.add(gu
          ? 'ફ્લેશ ભાવ ફક્ત $cap નંગ માટે; બાકીના ${money(normalPrice)} ભાવે'
          : 'Flash price covers up to $cap; the rest are charged at ${money(normalPrice)}');
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.redTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon('bolt', size: 14, color: AppColors.red, sw: 2.2),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  offer.name.isEmpty ? gt('Flash sale') : offer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.red,
                  ),
                ),
              ),
              FlashOfferCountdown(offer, prefix: '${gt('Ends in')} '),
            ],
          ),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(n,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink2,
                  )),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home screen strip
// ---------------------------------------------------------------------------

/// "Flash sale" strip for the home screen: every running sale with a live
/// countdown and its items, then an "Upcoming" teaser. Hidden when there is
/// nothing to show (and for the offline prototype / when the call fails).
class FlashHomeStrip extends StatefulWidget {
  const FlashHomeStrip({super.key});

  @override
  State<FlashHomeStrip> createState() => _FlashHomeStripState();
}

class _FlashHomeStripState extends State<FlashHomeStrip> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    FlashStore.instance.addListener(_changed);
    FlashStore.instance.refresh();
    // Safety net next to the live events: the units-left numbers change
    // silently on every purchase.
    _poll = Timer.periodic(const Duration(seconds: 45), (_) {
      FlashStore.instance.refresh(force: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    FlashStore.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = FlashStore.instance;
    if (store.active.isEmpty && store.upcoming.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in store.active) _ActiveSale(sale: s),
          if (store.upcoming.isNotEmpty) _UpcomingTeaser(sales: store.upcoming),
        ],
      ),
    );
  }
}

TextStyle _ts(double size, FontWeight w, Color c, {double? height}) =>
    TextStyle(
      fontFamily: GuLang.active ? AppTheme.gujaratiFont : AppTheme.uiFont,
      fontSize: size,
      fontWeight: w,
      color: c,
      height: height,
    );

class _ActiveSale extends StatelessWidget {
  final FlashPublicSale sale;
  const _ActiveSale({required this.sale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const AppIcon('bolt', size: 20, color: AppColors.gold2, sw: 2.2),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gt('Flash sale'),
                          style: _ts(10.5, FontWeight.w800,
                              const Color(0xFFFFD9DB))),
                      Text(sale.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _ts(15, FontWeight.w800, AppColors.white)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FlashCountdown(
                    seconds: () => sale.remainingToEnd,
                    prefix: '${gt('Ends in')} ',
                    onZero: FlashStore.instance.bump,
                    style: _ts(12, FontWeight.w800, AppColors.white).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sale.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _FlashItemCard(item: sale.items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashItemCard extends StatelessWidget {
  final FlashPublicItem item;
  const _FlashItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.read(context);
    final ref = state.packIndex[item.productId];
    final Product? p = ref?.product;
    final gu = GuLang.active;
    final name = gu && item.nameGu.isNotEmpty ? item.nameGu : item.nameEn;
    final soldOut = item.soldOut || !item.inStock;
    final left = item.unitsLeft;
    String? note;
    if (item.soldOut) {
      note = gt('Sold out');
    } else if (left != null && left <= 5) {
      note = gu ? 'ફક્ત $left બાકી' : 'Only $left left';
    } else if (item.perCustomerLimit > 0) {
      note = gu
          ? 'વધુમાં વધુ ${item.perCustomerLimit}'
          : 'Max ${item.perCustomerLimit} each';
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: p == null ? null : () => go('/product/${p.id}'),
      child: Opacity(
        opacity: soldOut ? .6 : 1,
        child: Container(
          width: 142,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
            boxShadow: AppColors.sh1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 78,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ProductArtView(
                          p?.art.isNotEmpty == true ? p!.art : item.imageUrl,
                          size: 70),
                    ),
                  ),
                  if (item.discountPercent > 0)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${item.discountPercent}%',
                            style: _ts(9.5, FontWeight.w800, AppColors.white)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ts(12.5, FontWeight.w800, AppColors.ink)),
              Text(item.unitLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ts(10.5, FontWeight.w600, AppColors.ink3)),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(item.salePricePaise / 100),
                      style: _ts(14.5, FontWeight.w800, AppColors.red)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(money(item.listPricePaise / 100),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _ts(10.5, FontWeight.w600, AppColors.ink3)
                            .copyWith(decoration: TextDecoration.lineThrough)),
                  ),
                ],
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(
                          10.5,
                          FontWeight.w800,
                          item.soldOut ? AppColors.ink3 : AppColors.orange)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingTeaser extends StatelessWidget {
  final List<FlashPublicSale> sales;
  const _UpcomingTeaser({required this.sales});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.goldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon('clock', size: 16, color: AppColors.goldInk, sw: 2),
              const SizedBox(width: 6),
              Text(gt('Upcoming flash sales'),
                  style: _ts(13, FontWeight.w800, AppColors.goldInk)),
            ],
          ),
          const SizedBox(height: 8),
          for (final s in sales.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _ts(13, FontWeight.w800, AppColors.ink)),
                        Text(
                          '${gt('Starts')} ${flashStartText(s.startsAt)}'
                          '${s.items.isEmpty ? '' : ' · ${_names(s)}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _ts(11, FontWeight.w600, AppColors.ink2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FlashCountdown(
                    seconds: () => s.remainingToStart,
                    prefix: '${gt('in')} ',
                    onZero: FlashStore.instance.bump,
                    style: _ts(11.5, FontWeight.w800, AppColors.goldInk)
                        .copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _names(FlashPublicSale s) {
    final n = s.items.take(2).map((i) => GuLang.active && i.nameGu.isNotEmpty
        ? i.nameGu
        : i.nameEn);
    final more = s.items.length - 2;
    return n.join(', ') + (more > 0 ? ' +$more' : '');
  }
}
