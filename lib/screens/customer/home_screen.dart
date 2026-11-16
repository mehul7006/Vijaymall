import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../../widgets/desktop_shell.dart';
import '../../widgets/flash_widgets.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/orders_paused_banner.dart';
import '../../widgets/store_actions.dart';
import '../../widgets/store_kit.dart';
import '../../widgets/store_layout.dart';
import '../../widgets/store_mini_cart.dart';
import '../../widgets/toast.dart';
import 'sheets/addresses_sheet.dart';
import 'sheets/notifications_sheet.dart';

/// First backend product photo (absolute or backend-relative URL) of a
/// category, or null so the tile falls back to the category icon.
String? _categoryPhoto(AppState state, String catId) {
  for (final p in state.products) {
    if (p.category != catId || !p.available) continue;
    final a = p.art.trim();
    if (a.startsWith('http://') ||
        a.startsWith('https://') ||
        a.startsWith('/')) {
      return a;
    }
  }
  return null;
}

/// `#/home` — deliver header, search, banners, categories, live order strip,
/// coin banner and the two product sections (§3.4).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _search(String value) {
    final q = value.trim();
    go(q.isEmpty ? '/shop' : '/shop?q=${Uri.encodeQueryComponent(q)}');
  }

  static Future<void> _copyPhone() async {
    await StoreActions.call();
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';

    final address = state.addresses.isEmpty
        ? null
        : state.addresses.firstWhere(
            (a) => a.id == state.flow.selectedAddressId,
            orElse: () => state.addresses.first,
          );
    final addrText = address == null
        ? (gu ? 'સરનામું ઉમેરો' : 'Add an address')
        : '${address.label} · ${address.full.split(',').first.trim()}';

    final live = state.liveOrders();
    final mine = live
        .where((o) =>
            digits(o.phone) == digits(state.userPhone) ||
            o.customer == state.userName)
        .toList();
    final activeOrder =
        mine.isNotEmpty ? mine.first : (live.isNotEmpty ? live.first : null);

    final featured = state.hotSale.featured
        .map((id) => state.productById(id))
        .whereType<Product>()
        .toList();
    final best = state.products
        .where((p) => p.available && p.stock > 0)
        .take(4)
        .toList();
    final cats = state.categories
        .where((c) => state.products.any((p) => p.category == c.id))
        .toList();
    final balance = state.coinBalance();
    // Web / wide desktop carries "Deliver to" and notifications in the sticky
    // site header, so the phone-style header block is dropped there.
    final siteChrome =
        DesktopShell.useSiteChrome(MediaQuery.sizeOf(context).width);
    final offers = _liveOffers(state, gu);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const StatusBar(),

                // 1. header — only on the phone layout; the site header
                //    carries "Deliver to" and notifications on the web.
                if (!siteChrome)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gu ? 'ડિલિવરી સરનામું' : 'Deliver to',
                        style: TextStyle(
                          fontFamily:
                              gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                          color: AppColors.ink3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => showAddressSheet(context),
                            child: Row(
                              children: [
                                const AppIcon('pin',
                                    size: 16, color: AppColors.red),
                                const SizedBox(width: 7),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 232),
                                  child: Text(
                                    addrText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: gu
                                          ? AppTheme.gujaratiFont
                                          : AppTheme.uiFont,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const AppIcon('down',
                                    size: 12, color: AppColors.ink3),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconBtn(
                            'bell',
                            size: 38,
                            iconSize: 18,
                            onTap: () => showNotificationsSheet(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. search bar --------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
                      border: Border.all(
                          color: AppColors.red.withValues(alpha: .18)),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.red.withValues(alpha: .10),
                            offset: const Offset(0, 6),
                            blurRadius: 18),
                      ],
                    ),
                    child: Row(
                      children: [
                        const AppIcon('search', size: 18, color: AppColors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            textInputAction: TextInputAction.search,
                            onSubmitted: _search,
                            style: const TextStyle(
                              fontFamily: AppTheme.uiFont,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: gu
                                  ? 'કરિયાણું, સૂકો ફળ, આઇસ્ક્રીમ શોધો…'
                                  : 'Search grocery, dry fruit, ice cream…',
                              hintStyle: const TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink3,
                              ),
                            ),
                          ),
                        ),
                        const AppIcon('filter', size: 17, color: AppColors.ink3),
                      ],
                    ),
                  ),
                ),

                ScreenScroll(
                  bottom: 112,
                  onRefresh: () => refreshStorefront(state),
                  child: Builder(builder: (context) {
                    final w = MediaQuery.sizeOf(context).width;
                    final wide = StoreBreakpoints.wide(w) && siteChrome;
                    final mid = StoreBreakpoints.mid(w);
                    final strip = activeOrder == null
                        ? null
                        : _activeOrderStrip(context, state, activeOrder, gu);
                    final coins = _coinBanner(balance, gu);
                    final free = _freeDelivery(gu);
                    final hero = _hero(state, gu, offers, siteChrome, wide);
                    final catsW = _catStrip(state, cats, gu, wide);
                    final bestList = mid
                        ? state.products
                            .where((p) => p.available && p.stock > 0)
                            .take(14)
                            .toList()
                        : best;
                    final deals = state.products
                        .where((p) =>
                            p.available &&
                            p.stock > 0 &&
                            p.variants.any((v) => discountPct(v) > 0))
                        .take(14)
                        .toList();
                    final loading = (best.isEmpty && storefrontLoading(state))
                        ? Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: LoadingOrElse(
                              skeleton: const ProductGridSkeleton(count: 4),
                              fallback: ErrorState(
                                onRetry: () => refreshStorefront(state),
                              ),
                            ),
                          )
                        : const SizedBox.shrink();
                    final catShelves = <Widget>[];
                    if (mid) {
                      for (final c in cats.take(4)) {
                        final ps = state.products
                            .where((p) =>
                                p.category == c.id &&
                                p.available &&
                                p.stock > 0)
                            .take(14)
                            .toList();
                        catShelves.add(_shelf(
                          gu ? c.nameGu : c.name,
                          ps,
                          gu,
                          () => go('/shop?cat=${c.id}'),
                          gu ? 'બધું જુઓ' : 'See all',
                          wide,
                        ));
                      }
                    }
                    final leftRail = w >= 1500 && cats.isNotEmpty;
                    final center = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        hero,
                        // 3b. flash sales (running + upcoming teaser)
                        const FlashHomeStrip(),
                        if (wide)
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: IntrinsicHeight(
                             child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: free),
                                const SizedBox(width: 14),
                                Expanded(child: coins),
                                if (strip != null) ...[
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 0),
                                      child: strip,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            ),
                          ),
                        catsW,
                        if (!wide) ...[
                          if (strip != null) strip,
                          const SizedBox(height: 14),
                          coins,
                        ],
                        _shelf(
                          gu ? 'હમણાં હોટ' : 'Hot right now',
                          featured,
                          gu,
                          () => go('/shop?hot=1'),
                          gu ? 'બધું જુઓ' : 'See all',
                          mid ? wide : null,
                          icon: 'flame',
                          horizontal: true,
                        ),
                        loading,
                        _shelf(
                          gu ? 'મોલની બેસ્ટ' : 'Best of the mall',
                          bestList,
                          gu,
                          () => go('/shop'),
                          gu ? 'બધું જુઓ' : 'View all',
                          mid ? wide : null,
                          icon: 'star',
                        ),
                        if (mid && deals.isNotEmpty)
                          _shelf(
                            gu ? 'ડીલ્સ' : 'Deals',
                            deals,
                            gu,
                            () => go('/shop'),
                            gu ? 'બધું જુઓ' : 'View all',
                            wide,
                            icon: 'ticket',
                          ),
                        ...catShelves,
                        if (!wide) ...[
                          const SizedBox(height: 18),
                          free,
                        ],
                      ],
                    );
                    final mainCol = leftRail
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 200,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 30),
                                  child: _catRail(state, cats, gu),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(child: center),
                            ],
                          )
                        : center;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OrdersPausedBanner(),
                        if (wide)
                          StoreTwoPane(
                            main: mainCol,
                            asideWidth: 340,
                            aside: const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: StoreMiniCart(),
                            ),
                          )
                        else
                          mainCol,
                      ],
                    );
                  }),
                ),
              ],
            ),
            CustomerNav(active: 'home'),
          ],
        ),
      ),
    );
  }


  Widget _coinBanner(int balance, bool gu) {
    return
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => go('/wallet'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: StoreKit.goldWarm,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    AppColors.gold.withValues(alpha: .35),
                                offset: const Offset(0, 10),
                                blurRadius: 24),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.white,
                                boxShadow: AppColors.sh1,
                              ),
                              child: const Center(
                                child: AppIcon('coin',
                                    size: 20,
                                    color: AppColors.goldInk,
                                    sw: 2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    gu
                                        ? '$balance કોઈન્સ · ${money(balance)}'
                                        : '$balance coins · ${money(balance)}',
                                    style: TextStyle(
                                      fontFamily: gu
                                          ? AppTheme.gujaratiFont
                                          : AppTheme.uiFont,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.goldInk,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    gu
                                        ? 'ચેકઆઉટ પર માન્ય વસ્તુઓમાં વાપરો'
                                        : 'Use them on eligible items at checkout',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: gu
                                          ? AppTheme.gujaratiFont
                                          : AppTheme.uiFont,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.goldInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const AppIcon('right',
                                size: 16, color: AppColors.goldInk),
                          ],
                        ),
                      ),
                    );
  }

  Widget _freeDelivery(bool gu) {
    return
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: StoreKit.card(
                          accent: AppColors.green, radius: 20, tinted: true),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.greenTint,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: AppIcon('truck',
                                  size: 20,
                                  color: AppColors.green,
                                  sw: 1.9),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  gu
                                      ? 'મફત હોમ ડિલિવરી'
                                      : 'Free home delivery',
                                  style: TextStyle(
                                    fontFamily: gu
                                        ? AppTheme.gujaratiFont
                                        : AppTheme.uiFont,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  gu
                                      ? 'દરેક ઓર્ડર પર${seed.storeLocality().isEmpty ? '' : ' · ${seed.storeLocality()}'}.'
                                      : 'On every order${seed.storeLocality().isEmpty ? '' : ' · ${seed.storeLocality()}'}.',
                                  style: TextStyle(
                                    fontFamily: gu
                                        ? AppTheme.gujaratiFont
                                        : AppTheme.uiFont,
                                    fontSize: 12,
                                    height: 1.4,
                                    color: AppColors.ink2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppLink(
                            seed.store.phone,
                            onTap: _copyPhone,
                            size: 13,
                          ),
                        ],
                      ),
                    );
  }

  /// Left category list (very wide screens): every category with a live
  /// product, one tap to its shop page.
  Widget _catRail(AppState state, List<Category> cats, bool gu) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: StoreKit.card(accent: AppColors.gold, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in cats)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => go('/shop?cat=${c.id}'),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    children: [
                      AppIcon(c.icon, size: 16, color: AppColors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          gu ? c.nameGu : c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily:
                                gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const AppIcon('right', size: 12, color: AppColors.ink3),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Hot-sale banner + offer tiles (wide) or banner + offer strip.
  Widget _hero(AppState state, bool gu, List<_HomeOffer> offers,
      bool siteChrome, bool wide) {
    if (!state.hotSale.live) return const SizedBox.shrink();
    final h = wide ? 236.0 : 196.0;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: siteChrome
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: wide ? 8 : 9,
                  child: SizedBox(
                    height: h,
                    child: _HotBanner(state: state, gu: gu),
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  flex: wide ? 12 : 12,
                  child: SizedBox(
                    height: h,
                    child: _OfferGrid(
                        offers: offers, gu: gu, cardHeight: (h - 12) / 2),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HotBanner(state: state, gu: gu),
                if (offers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 104,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: offers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _OfferCard(
                        offer: offers[i],
                        gu: gu,
                        width: 248,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _catStrip(AppState state, List<Category> cats, bool gu, bool wide) {
    if (cats.isEmpty) return const SizedBox.shrink();
    final size = wide ? 88.0 : 76.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        StoreSectionTitle(
          gu ? 'શ્રેણીઓ' : 'Shop by category',
          icon: 'store',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: size + 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 14),
            itemCount: cats.length,
            separatorBuilder: (_, __) => SizedBox(width: wide ? 14 : 8),
            itemBuilder: (context, i) {
              final c = cats[i];
              final photo = _categoryPhoto(state, c.id);
              return StoreCategoryTile(
                index: i,
                label: gu ? c.nameGu : c.name,
                icon: c.icon,
                size: size,
                image: photo == null ? null : ProductArtView(photo, size: size),
                onTap: () => go('/shop?cat=${c.id}'),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Product group. [wide] null = phone layout (today's cards); otherwise a
  /// StoreShelf whose cards stretch to fill the row.
  Widget _shelf(String title, List<Product> items, bool gu, VoidCallback onAll,
      String actionLabel, bool? wide,
      {String? icon, bool horizontal = false}) {
    if (items.isEmpty) return const SizedBox.shrink();
    Widget cell(Product p, double w) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ProductCard(p, width: w),
            if (p.isLowStock) ...[
              const SizedBox(height: 6),
              StoreStockBadge(
                  gu ? 'માત્ર ${p.stock} બાકી' : 'Only ${p.stock} left',
                  StoreStockLevel.low),
            ],
          ],
        );
    if (wide == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreSectionTitle(title,
                icon: icon, actionLabel: actionLabel, onAction: onAll),
            const SizedBox(height: 12),
            if (horizontal)
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => ProductCard(items[i], width: 172),
                ),
              )
            else
              LayoutBuilder(builder: (context, c) {
                final w = ((c.maxWidth - 12) / 2).clamp(120.0, 200.0);
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [for (final p in items) cell(p, w)],
                );
              }),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: LayoutBuilder(builder: (context, c) {
        final n = StoreBreakpoints.gridCols(c.maxWidth + 12, minCard: 178);
        final iw = (c.maxWidth - (n - 1) * 12) / n;
        return StoreShelf(
          title: title,
          actionLabel: actionLabel,
          onAction: onAll,
          itemCount: items.length,
          itemWidth: iw,
          height: 330,
          itemBuilder: (_, i) => cell(items[i], iw),
        );
      }),
    );
  }

  /// §3.4 item 5 — live order strip with its per-status ETA copy.
  Widget _activeOrderStrip(
      BuildContext context, AppState state, Order? order, bool gu) {
    if (order == null) return const SizedBox.shrink();
    final o = order;
    final eta = (o.mode == 'pickup'
        ? AppState.etaPickup[o.status]
        : AppState.etaDelivery[o.status]) ??
        '';
    final status = gu
        ? (AppState.statusLabelGu[o.status] ?? o.status)
        : state.statusLabel(o.status);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => go('/track/${o.number}'),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration:
              StoreKit.card(accent: AppColors.red, radius: 20, tinted: true)
                  .copyWith(
            border: Border.all(color: AppColors.red.withValues(alpha: .35)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.red,
                  boxShadow: [
                    BoxShadow(color: Color(0x59D3202B), blurRadius: 6)
                  ],
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${gu ? 'ઓર્ડર' : 'Order'} ${o.number} · $status',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily:
                            gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      eta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily:
                            gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const AppIcon('right', size: 16, color: AppColors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hot sale banner + live offer cards (the wide layout fills the banner's
// empty right half with the best sales and coupons).
// ---------------------------------------------------------------------------

/// One advertisement tile on the home page.
class _HomeOffer {
  final String icon;
  final String tag;
  final String title;
  final String sub;
  final String cta;
  final bool copy;
  final VoidCallback onTap;

  const _HomeOffer({
    required this.icon,
    required this.tag,
    required this.title,
    required this.sub,
    required this.cta,
    this.copy = false,
    required this.onTap,
  });
}

/// Best live offers: the strongest product sales first, padded with coupons
/// that are inside their date window and still have uses left.
List<_HomeOffer> _liveOffers(AppState state, bool gu) {
  final out = <_HomeOffer>[];

  int bestDiscount(Product p) {
    var best = 0;
    for (final v in p.variants) {
      final d = discountPct(v);
      if (d > best) best = d;
    }
    return best;
  }

  final sales = state.products
      .where((p) => p.available && p.stock > 0)
      .map((p) => MapEntry(p, bestDiscount(p)))
      .where((e) => e.value > 0)
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  for (final e in sales.take(2)) {
    final p = e.key;
    out.add(_HomeOffer(
      icon: 'flame',
      tag: gu ? 'સેલ' : 'SALE',
      title: '${e.value}% ${gu ? 'છૂટ' : 'OFF'}',
      sub: gu ? p.nameGu : p.name,
      cta: gu ? 'જુઓ' : 'Shop now',
      onTap: () => go('/product/${p.id}'),
    ));
  }

  final coupons = state.coupons
      .where((c) =>
          state.couponDateStatus(c) == 'active' && c.uses < c.maxUses)
      .toList();
  for (final c in coupons) {
    if (out.length >= 4) break;
    out.add(_HomeOffer(
      icon: 'ticket',
      tag: gu ? 'કૂપન' : 'COUPON',
      title: c.type == 'percent'
          ? '${c.value}% ${gu ? 'છૂટ' : 'OFF'}'
          : '₹${c.value} ${gu ? 'છૂટ' : 'OFF'}',
      sub: c.desc,
      cta: c.code,
      copy: true,
      onTap: () {
        Clipboard.setData(ClipboardData(text: c.code));
        showToast('Coupon code copied · ${c.code}');
      },
    ));
  }
  return out.take(4).toList();
}

/// `.sale-banner` — the prototype's gradient hot-sale slide.
class _HotBanner extends StatelessWidget {
  final AppState state;
  final bool gu;

  const _HotBanner({required this.state, required this.gu});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => go('/shop?hot=1'),
      child: Container(
        // prototype: `min-height:142px` — the banner grows
        // with its copy instead of clipping it.
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: StoreKit.heroNavyRed,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
                color: Color(0x4D121A47), offset: Offset(0, 16), blurRadius: 34),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 170),
          child: Stack(
            children: [
              // .sale-banner::before — left-hand dark wash
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: const Alignment(0.24, 0),
                      colors: const [
                        Color(0x4D121A47),
                        Color(0x00121A47),
                      ],
                      stops: const [0.0, 0.62],
                    ),
                  ),
                ),
              ),
              // .sale-banner::after — gold orb (172px)
              Positioned(
                right: -34,
                top: -14,
                child: Container(
                  width: 172,
                  height: 172,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: StoreKit.goldWarm,
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x52F5B301),
                          offset: Offset(0, 18),
                          blurRadius: 40),
                    ],
                  ),
                ),
              ),
              // copy — kept out of a Positioned.fill so it
              // drives the banner height (prototype centres
              // the copy with min-height:142px).
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 102),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.hotSale.eyebrow,
                          style: const TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            height: 1.2,
                            color: AppColors.gold2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 215),
                          child: Text(
                            state.hotSale.title,
                            style: const TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontSize: 25,
                              fontWeight: FontWeight.w400,
                              height: 1.08,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              gu ? 'સેલ ખરીદો' : 'Shop the sale',
                              style: TextStyle(
                                fontFamily: gu
                                    ? AppTheme.gujaratiFont
                                    : AppTheme.uiFont,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const AppIcon('arrow',
                                size: 14, color: AppColors.white),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // .sale-flame — white flame over the orb
              Positioned(
                right: 23,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AppIcon('flame',
                      size: 34, color: AppColors.white, sw: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2×2 offer grid that sits beside the banner on the web layout.
class _OfferGrid extends StatelessWidget {
  final List<_HomeOffer> offers;
  final bool gu;
  final double cardHeight;

  const _OfferGrid(
      {required this.offers, required this.gu, this.cardHeight = 92});

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var i = 0; i < offers.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 12));
      rows.add(Row(
        children: [
          Expanded(
            child: _OfferCard(offer: offers[i], gu: gu, height: cardHeight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: i + 1 < offers.length
                ? _OfferCard(offer: offers[i + 1], gu: gu, height: cardHeight)
                : const SizedBox.shrink(),
          ),
        ],
      ));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// `.offer-card` — icon tile, discount headline, detail and a CTA pill.
class _OfferCard extends StatelessWidget {
  final _HomeOffer offer;
  final bool gu;
  final double height;
  final double? width;

  const _OfferCard({
    required this.offer,
    required this.gu,
    this.height = 92,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final sale = offer.tag == 'SALE' || offer.tag == 'સેલ';
    final chip = sale ? AppColors.redTint : AppColors.goldTint;
    final ink = sale ? AppColors.red : AppColors.goldInk;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: offer.onTap,
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: sale ? const Color(0xFFFFF7F7) : const Color(0xFFFFFBEE),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ink.withValues(alpha: .22)),
            boxShadow: [
              BoxShadow(
                  color: ink.withValues(alpha: .12),
                  offset: const Offset(0, 6),
                  blurRadius: 16),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: chip,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: AppIcon(offer.icon, size: 19, color: ink, sw: 1.8),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.tag,
                      style: TextStyle(
                        fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                        fontSize: 8.5,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .9,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      offer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontSize: 17,
                        height: 1.05,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -.01,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      offer.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                        fontSize: 10.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: chip,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (offer.copy) ...[
                      AppIcon('ticket', size: 11, color: ink, sw: 2),
                      const SizedBox(width: 4),
                    ],
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 74),
                      child: Text(
                        offer.cta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily:
                              gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                          fontSize: 10,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
