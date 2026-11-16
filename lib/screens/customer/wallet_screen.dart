import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/customer_wide_parts.dart';
import '../../widgets/desktop_shell.dart';
import '../../widgets/panels.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/store_kit.dart';
import 'sheets/how_coins_sheet.dart';

/// `#/wallet` — coin balance hero, earning rules, activity ledger.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final balance = state.coinBalance();
    final pending = state.coinPending();
    bool showAllLedger = false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const StatusBar(),
                ScreenBar(
                  showBack: false,
                  title: gu ? 'કોઈન વોલેટ' : 'Coin wallet',
                  sub: gu
                      ? 'ચેકઆઉટ પર 1 કોઈન = ₹1'
                      : '1 coin = ₹1 at checkout',
                  right: IconBtn(
                    'info',
                    iconSize: 17,
                    onTap: () => showHowCoinsSheet(context),
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setLocal) {
                    void toggleLedger() =>
                        setLocal(() => showAllLedger = !showAllLedger);

                    final ledger = List<LedgerEntry>.of(state.ledger)
                      ..sort((a, b) => b.date.compareTo(a.date));
                    final visible =
                        showAllLedger ? ledger : ledger.take(5).toList();

                    final wide = DesktopShell.isWide(
                        MediaQuery.sizeOf(context).width);
                    final leftW = <Widget>[
                          _heroCard(gu, balance, pending,
                              big: CustomerWide.on(context)),
                          const SizedBox(height: 12),
                          _earnCard(context, state, gu),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  gu ? 'વધુ કમાઓ' : 'Earn more',
                                  variant: BtnVariant.gold,
                                  icon: 'coin',
                                  onTap: () => go('/shop'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppButton(
                                  gu ? 'કોઈન્સ વાપરો' : 'Spend coins',
                                  variant: BtnVariant.secondary,
                                  icon: 'cart',
                                  onTap: () => go('/cart'),
                                ),
                              ),
                            ],
                          ),
                    ];
                    final rightW = <Widget>[
                          const SizedBox(height: 4),
                          StoreSectionTitle(
                            gu ? 'કોઈન પ્રવૃત્તિ' : 'Coin activity',
                            icon: 'coin',
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              pending > 0
                                  ? (gu
                                      ? '$pending બાકી'
                                      : '$pending pending')
                                  : (gu
                                      ? 'બધું પતી ગયું'
                                      : 'All settled'),
                              style: _ts(gu,
                                  size: 11.5,
                                  w: FontWeight.w600,
                                  color: AppColors.ink3),
                            ),
                          ),
                          if (ledger.isEmpty &&
                              state.backendMode &&
                              !state.walletLoaded)
                            const LoadingOrElse(
                              skeleton: ListSkeleton(count: 3, rowHeight: 68),
                              fallback: ErrorState(
                                title: "Couldn't load coin activity",
                                copy: 'Pull down to refresh and try again.',
                              ),
                            )
                          else if (ledger.isEmpty)
                            CardPanel(
                              child: EmptyState(
                                icon: 'coin',
                                title: gu
                                    ? 'હજી કોઈ કોઈન પ્રવૃત્તિ નથી'
                                    : 'No coin activity yet',
                                copy: gu
                                    ? 'કોઈન્સ કમાવા ઓર્ડર કરો.'
                                    : 'Place an order to start earning coins.',
                              ),
                            )
                          else ...[
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: StoreKit.card(
                                  accent: AppColors.navy, radius: 22),
                              child: Column(
                                children: [
                                  for (var i = 0; i < visible.length; i++)
                                    _ledgerRow(
                                        gu, visible[i], i < visible.length - 1),
                                ],
                              ),
                            ),
                            if (ledger.length > 5) ...[
                              const SizedBox(height: 10),
                              Center(
                                child: AppLink(
                                  showAllLedger
                                      ? (gu ? 'ઓછું બતાવો' : 'Show less')
                                      : (gu
                                          ? 'બધી પ્રવૃત્તિ જુઓ'
                                          : 'View all activity'),
                                  onTap: toggleLedger,
                                ),
                              ),
                            ],
                          ],
                          // Udhar (counter credit): read-only, only when the
                          // shop gave this customer a limit or they owe.
                          if (state.backendMode &&
                              state.creditAccount != null &&
                              (state.creditAccount!.limitPaise > 0 ||
                                  state.creditAccount!.balancePaise > 0)) ...[
                            const SizedBox(height: 14),
                            CardPanel(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(gu ? 'ઉધાર ખાતું' : 'Udhar (credit) account',
                                        style: _ts(gu,
                                            size: 13, w: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${gu ? 'બાકી' : 'You owe'}: ${money(state.creditAccount!.balancePaise / 100)}   '
                                      '${gu ? 'મર્યાદા' : 'Limit'}: ${money(state.creditAccount!.limitPaise / 100)}   '
                                      '${gu ? 'ઉપલબ્ધ' : 'Available'}: ${money(state.creditAccount!.availablePaise / 100)}',
                                      style: _ts(gu,
                                          size: 12,
                                          w: FontWeight.w600,
                                          color: AppColors.ink2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Hint(
                            gu
                                ? 'કોઈન્સ મળ્યાના ${state.coinSettings.expiryMonths} મહિના પછી માન્ય રહેશે નહીં.'
                                : 'Coins expire ${state.coinSettings.expiryMonths} months after they’re earned. Oldest coins are used first.',
                            icon: 'clock',
                          ),
                    ];
                    return ScreenScroll(
                      bottom: 124,
                      onRefresh: () async {
                        try {
                          if (state.backendMode && !state.isBackendAdmin) {
                            await state.refreshWallet();
                          }
                        } catch (_) {}
                      },
                      child: CustomerWide.on(context)
                          // Desktop: balance + earn cards on the left, the
                          // activity ledger on the right.
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: leftW,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: rightW,
                                  ),
                                ),
                              ],
                            )
                          : wide
                              ? TwoColumns(a: leftW, b: rightW, gap: 0)
                              : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...leftW,
                                const SizedBox(height: 16),
                                ...rightW,
                              ],
                            ),
                    );
                  },
                ),
              ],
            ),
            const CustomerNav(active: 'wallet'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero + earning rules
// ---------------------------------------------------------------------------

Widget _heroCard(bool gu, int balance, int pending, {bool big = false}) {
  return Container(
    padding: EdgeInsets.all(big ? 30 : 20),
    decoration: BoxDecoration(
      gradient: StoreKit.redWarm,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
            color: AppColors.red.withValues(alpha: .32),
            offset: const Offset(0, 14),
            blurRadius: 30),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gu ? 'તમારા કોઈન્સ' : 'YOUR COINS',
                style: _ts(gu,
                    size: 11.5, w: FontWeight.w800, color: AppColors.gold2),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$balance',
                  style: _ts(gu,
                      size: big ? 84 : 56,
                      w: FontWeight.w800,
                      color: AppColors.white,
                      height: 1.0),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: StoreKit.goldWarm,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  (gu ? 'કિંમત ₹$balance' : 'Worth ₹$balance') +
                      (pending > 0
                          ? (gu
                              ? ' · $pending કોઈન્સ બાકી'
                              : ' · $pending coins pending')
                          : ''),
                  style: _ts(gu,
                      size: 12.5, w: FontWeight.w800, color: AppColors.goldInk),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: big ? 104 : 78,
          height: big ? 104 : 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: StoreKit.goldWarm,
            border: Border.all(color: AppColors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x40000000),
                  offset: Offset(0, 8),
                  blurRadius: 16),
            ],
          ),
          child: Center(
              child:
                  AppIcon('coin', size: big ? 50 : 38, color: AppColors.goldInk, sw: 2)),
        ),
      ],
    ),
  );
}

Widget _earnCard(BuildContext context, AppState state, bool gu) {
  final active = state.coinRules
      .where((r) => state.ruleWindowStatus(r) == 'active')
      .toList();
  final best = state.bestEarnRule(1000);
  final rules = active.isNotEmpty
      ? active
      : (best.rule != null ? <CoinRule>[best.rule!] : const <CoinRule>[]);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: StoreKit.card(accent: AppColors.gold, radius: 22, tinted: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StoreSectionTitle(
          gu ? 'કેવી રીતે કમાઓ' : 'How you earn',
          actionLabel: gu ? 'નિયમો જુઓ' : 'View rules',
          onAction: () => showHowCoinsSheet(context),
        ),
        const SizedBox(height: 14),
        for (final rule in rules) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                _ruleChip(gu, money(rule.spend)),
                const SizedBox(width: 7),
                const AppIcon('arrow',
                    size: 13, color: AppColors.ink3, sw: 2),
                const SizedBox(width: 7),
                _ruleChip(
                  gu,
                  gu
                      ? '${rule.coins} કોઈન્સ'
                      : '${rule.coins} coins',
                  gold: true,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    rule.mode == 'slab'
                        ? (gu ? 'દરેક સ્લેબ પર' : 'on every slab')
                        : (gu ? 'પ્રમાણસર' : 'pro-rata'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(gu,
                        size: 11,
                        w: FontWeight.w600,
                        color: AppColors.ink3),
                  ),
                ),
              ],
            ),
          ),
        ],
        Text(
          gu
              ? 'ડિલિવરી કે પિકઅપ પછી કોઈન્સ મળે. ચેકઆઉટ પર માન્ય વસ્તુઓમાં વાપરો.'
              : 'Coins are credited after delivery or pickup. Redeem them on eligible items at checkout.',
          style: _ts(gu,
              size: 11.5,
              w: FontWeight.w600,
              color: AppColors.ink3,
              height: 1.45),
        ),
      ],
    ),
  );
}

Widget _ruleChip(bool gu, String label, {bool gold = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      gradient: gold
          ? StoreKit.goldWarm
          : const LinearGradient(
              colors: [Color(0xFFE0E6FF), Color(0xFFB4C1F7)]),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: _ts(gu,
          size: 11.5,
          w: FontWeight.w800,
          color: gold ? AppColors.goldInk : AppColors.navy),
    ),
  );
}

// ---------------------------------------------------------------------------
// Ledger
// ---------------------------------------------------------------------------

Widget _ledgerRow(bool gu, LedgerEntry e, bool divider) {
  final pending = e.status == 'pending';
  final spend = e.coins < 0;
  final icon = e.type == 'spend'
      ? 'cart'
      : e.type == 'bonus'
          ? 'gift'
          : 'coin';

  final Color bg;
  final Color fg;
  if (spend) {
    bg = AppColors.redTint;
    fg = AppColors.red;
  } else if (pending) {
    bg = AppColors.goldTint;
    fg = AppColors.goldInk;
  } else {
    bg = AppColors.greenTint;
    fg = AppColors.green;
  }

  final coinsLabel = e.coins > 0 ? '+${e.coins}' : '${e.coins}';

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: divider ? AppColors.line : Colors.transparent,
        ),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: fg.withValues(alpha: .2)),
          ),
          child: Center(
            child: AppIcon(icon, size: 20, color: fg, sw: 1.9),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(gu,
                    size: 13, w: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                '${e.sub} · ${formatDate(e.date)}${pending ? (gu ? ' · બાકી' : ' · Pending') : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(gu,
                    size: 11.5, w: FontWeight.w600, color: AppColors.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(99)),
          child: Text(
            coinsLabel,
            style: _ts(gu, size: 14, w: FontWeight.w800, color: fg),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
