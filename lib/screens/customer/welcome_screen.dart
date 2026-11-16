import 'package:flutter/material.dart';

import '../../data/store_text.dart';
import '../../data/seed_data.dart' as seed;
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/store_kit.dart';

/// `#/welcome` — public landing page: hero, benefits, categories, how it
/// works, coins banner and footer. Responsive: two-column hero on web, a
/// stacked layout on phones. Customer side only.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _arts = ['dryfruit', 'pickle', 'icecream', 'tea', 'snacks', 'cosmetics'];

  TextStyle _t(bool gu, double size, FontWeight w,
          {Color color = AppColors.ink, double height = 1.3, double ls = 0}) =>
      TextStyle(
        fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
        fontSize: gu ? size * 1.1 : size,
        height: height,
        fontWeight: w,
        letterSpacing: gu ? 0 : ls,
        color: color,
      );

  /// Where the "Sign in / Get started" buttons lead. A signed-out visitor
  /// goes to the OTP sign-in; someone who already has a session goes to their
  /// own area instead of being asked to sign in again.
  static String _start(BuildContext context) {
    final s = StateScope.read(context);
    if (!(s.signedIn || s.backendMode)) return '/signin';
    if (s.isBackendAdmin) return '/admin';
    if (s.isBackendStaff) return '/admin/orders';
    return '/home';
  }

  static bool _hasSession(BuildContext context) {
    final s = StateScope.read(context);
    return s.signedIn || s.backendMode;
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 900;
    final pad = wide ? 56.0 : 20.0;

    Widget bounded(Widget child) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad), child: child),
          ),
        );

    return Scaffold(
      backgroundColor: AppColors.welcomeBg,
      body: DecoratedBox(
       decoration: const BoxDecoration(gradient: StoreKit.creamSoft),
       child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(context, gu, wide, bounded),
            const SizedBox(height: 40),
            bounded(_benefits(gu, wide)),
            SizedBox(height: wide ? 72 : 48),
            bounded(_categories(gu, wide)),
            SizedBox(height: wide ? 72 : 48),
            bounded(_steps(gu, wide)),
            SizedBox(height: wide ? 72 : 48),
            bounded(_coinsBanner(context, gu, wide)),
            SizedBox(height: wide ? 72 : 48),
            _footer(context, gu, wide, bounded),
          ],
        ),
      ),
      ),
    );
  }

  // ---- hero ---------------------------------------------------------------

  Widget _hero(BuildContext context, bool gu, bool wide,
      Widget Function(Widget) bounded) {
    final nav = Row(
      children: [
        LogoMark(size: wide ? 56 : 42, color: AppColors.white),
        SizedBox(width: wide ? 16 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(brandTop(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(false, wide ? 30 : 21, FontWeight.w800,
                      color: AppColors.white, height: 1.05, ls: 3)),
              Text(brandBottom(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(false, wide ? 15 : 12, FontWeight.w800,
                      color: AppColors.white.withValues(alpha: .9), ls: 3.2)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _pill(gu ? 'EN' : 'ગુજરાતી', gu: !gu,
            onTap: () => StateScope.read(context).setLang(gu ? 'en' : 'gu')),
        if (wide) ...[
          const SizedBox(width: 10),
          _pill(
              _hasSession(context)
                  ? (gu ? 'મારું એકાઉન્ટ' : 'My account')
                  : (gu ? 'સાઇન ઇન' : 'Sign in'),
              gu: gu,
              onTap: () => go(_start(context)),
              solid: true),
        ],
      ],
    );

    final headline = Text.rich(
      TextSpan(
        style: _t(gu, wide ? 62 : 38, FontWeight.w800,
            color: AppColors.white, height: 1.08, ls: -1.4),
        children: [
          TextSpan(text: gu ? 'રોજની જરૂરિયાત.\n' : 'Everyday essentials.\n'),
          TextSpan(
              text: gu ? 'મફત ડિલિવરી.' : 'Delivered free.',
              style: const TextStyle(color: AppColors.gold2)),
        ],
      ),
    );

    final copy = Text(
      gu
          ? 'કરિયાણું, ગૃહ ઉદ્યોગ, સૂકો મેવો, કોસ્મેટિક અને આઇસ્ક્રીમ — ${seed.store.nameGu}ની દુકાનથી આપના ઘર સુધી. દરેક ઓર્ડર પર કોઈન્સ કમાઓ.'
          : 'Grocery, home-industry favourites, dry fruit, cosmetics and ice cream — from our ${seed.store.name} store to your door. Earn coins on every order.',
      style: _t(gu, wide ? 19 : 16, FontWeight.w500,
          color: AppColors.white.withValues(alpha: .92), height: 1.6),
    );

    final ctas = Wrap(
      spacing: 14,
      runSpacing: 12,
      children: [
        SizedBox(
          width: wide ? 230 : double.infinity,
          child: AppButton(gu ? 'શરૂ કરો' : 'Get started',
              onTap: () => go(_start(context)),
              icon: 'arrow',
              size: BtnSize.lg,
              block: true),
        ),
        SizedBox(
          width: wide ? 230 : double.infinity,
          child: AppButton(gu ? 'દુકાન જુઓ' : 'Browse the store',
              onTap: () => go('/home'),
              variant: BtnVariant.secondary,
              size: BtnSize.lg,
              block: true),
        ),
      ],
    );

    final chips = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _trust('truck', gu ? 'મફત ડિલિવરી' : 'Free delivery', gu),
        _trust('coin', gu ? 'કોઈન્સ કમાઓ' : 'Earn coins', gu),
        _trust('shield', gu ? 'સુરક્ષિત OTP' : 'Secure OTP login', gu),
      ],
    );

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn(child: headline),
        const SizedBox(height: 20),
        FadeSlideIn(delayMs: 100, child: copy),
        const SizedBox(height: 30),
        FadeSlideIn(delayMs: 180, child: ctas),
        const SizedBox(height: 26),
        FadeSlideIn(delayMs: 240, child: chips),
      ],
    );

    final art = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.gold2.withValues(alpha: .55), width: 1.4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .22),
              offset: const Offset(0, 14),
              blurRadius: 30),
        ],
      ),
      child: LayoutBuilder(builder: (_, c) {
        final cols = wide ? 3 : 3;
        final gap = 12.0;
        final cell = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < _arts.length; i++)
              FadeSlideIn(
                delayMs: 80 * i,
                child: Container(
                  width: cell,
                  height: cell,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: AppColors.sh2,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset('assets/landing/${_arts[i]}.jpg',
                      fit: BoxFit.cover),
                ),
              ),
          ],
        );
      }),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: StoreKit.heroNavyRed,
        borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(wide ? 48 : 32)),
        boxShadow: [
          BoxShadow(
              color: AppColors.navyDeep.withValues(alpha: .30),
              offset: const Offset(0, 16),
              blurRadius: 36),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
       Positioned(
         right: -80,
         top: -80,
         child: Container(
           width: 280,
           height: 280,
           decoration: BoxDecoration(
               shape: BoxShape.circle,
               color: AppColors.gold.withValues(alpha: .13)),
         ),
       ),
       Positioned(
         left: -60,
         bottom: -70,
         child: Container(
           width: 220,
           height: 220,
           decoration: BoxDecoration(
               shape: BoxShape.circle,
               color: AppColors.red2.withValues(alpha: .16)),
         ),
       ),
       SafeArea(
        bottom: false,
        child: bounded(
          Padding(
            padding: EdgeInsets.only(top: 18, bottom: wide ? 64 : 32),
            child: Column(
              children: [
                nav,
                SizedBox(height: wide ? 56 : 28),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 6, child: left),
                      const SizedBox(width: 56),
                      Expanded(flex: 5, child: art),
                    ],
                  )
                else ...[
                  left,
                  const SizedBox(height: 28),
                  art,
                ],
              ],
            ),
          ),
        ),
       ),
      ]),
    );
  }

  Widget _pill(String label,
      {required bool gu,
      required VoidCallback onTap,
      bool solid = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46, minWidth: 46),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: solid ? AppColors.white : AppColors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.white.withValues(alpha: .4)),
          ),
          child: Text(label,
              style: _t(gu, 14, FontWeight.w800,
                  color: solid ? AppColors.navy : AppColors.white)),
        ),
      ),
    );
  }

  Widget _trust(String icon, String text, bool gu) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.gold2.withValues(alpha: .5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AppIcon(icon, size: 17, color: AppColors.gold2, sw: 1.9),
          const SizedBox(width: 8),
          Text(text,
              style: _t(gu, 14, FontWeight.w700, color: AppColors.white)),
        ]),
      );

  // ---- sections -----------------------------------------------------------

  Widget _sectionTitle(String eyebrow, String title, bool gu, bool wide,
      {String? sub}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            gradient: StoreKit.goldWarm,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(eyebrow.toUpperCase(),
              style: _t(gu, 12, FontWeight.w800,
                  color: AppColors.goldInk, ls: 2)),
        ),
        const SizedBox(height: 8),
        Text(title,
            style: _t(gu, wide ? 36 : 26, FontWeight.w800,
                height: 1.15, ls: -.6)),
        if (sub != null) ...[
          const SizedBox(height: 10),
          Text(sub,
              style: _t(gu, wide ? 17 : 15, FontWeight.w500,
                  color: AppColors.ink2, height: 1.55)),
        ],
      ],
    );
  }

  Widget _grid(bool wide, List<Widget> kids, {int? cols}) {
    final n = cols ?? (wide ? 4 : 2);
    return LayoutBuilder(builder: (_, c) {
      const gap = 16.0;
      final cell = (c.maxWidth - gap * (n - 1)) / n;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final k in kids) SizedBox(width: cell, child: k)],
      );
    });
  }

  Widget _card(
          {required Widget child, Color accent = AppColors.red}) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: StoreKit.card(accent: accent, radius: 24, tinted: true),
        child: child,
      );

  Widget _benefits(bool gu, bool wide) {
    Widget b(String icon, int tone, String title, String body) =>
        _card(
          accent: StoreKit.tone(tone).$3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [StoreKit.tone(tone).$1, StoreKit.tone(tone).$2],
                    ),
                    borderRadius: BorderRadius.circular(16)),
                child: Center(
                    child: AppIcon(icon,
                        size: 26, color: StoreKit.tone(tone).$3, sw: 1.9)),
              ),
              const SizedBox(height: 16),
              Text(title, style: _t(gu, 18, FontWeight.w800)),
              const SizedBox(height: 6),
              Text(body,
                  style: _t(gu, 15, FontWeight.w500,
                      color: AppColors.ink2, height: 1.5)),
            ],
          ),
        );
    return _grid(wide, [
      b('truck', 0,
          gu ? 'મફત ડિલિવરી' : 'Free home delivery',
          gu ? 'તમારા ઘર સુધી, કોઈ ચાર્જ વગર.' : 'Straight to your door, no delivery charge.'),
      b('coin', 1,
          gu ? 'કોઈન્સ કમાઓ' : 'Earn coins',
          gu ? 'દરેક ઓર્ડર પર કોઈન્સ મળે, આગળ વાપરો.' : 'Coins on every order, spend them on the next.'),
      b('flame', 4,
          gu ? 'હોટ સેલ' : 'Hot sale deals',
          gu ? 'રોજ નવા ઑફર અને ફ્લેશ સેલ.' : 'Fresh offers and flash sales every day.'),
      b('shield', 3,
          gu ? 'સુરક્ષિત સાઇન ઇન' : 'Safe & simple login',
          gu ? 'OTP થી લૉગિન, પાસવર્ડ નહીં.' : 'Sign in with an OTP — no password to remember.'),
    ], cols: wide ? 4 : 1);
  }

  Widget _categories(bool gu, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(gu ? 'ખરીદી' : 'Shop', gu ? 'બધું એક જ જગ્યાએ' : 'Everything in one store', gu, wide,
            sub: gu ? 'તમારી રોજની ખરીદી માટે બધી કેટેગરી.' : 'All the categories you need for the week.'),
        const SizedBox(height: 24),
        _LandingCategories(gu: gu, wide: wide),
      ],
    );
  }

  Widget _steps(bool gu, bool wide) {
    Widget s(int n, String title, String body) => _card(
          accent: StoreKit.tone(n - 1).$3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: StoreKit.redWarm,
                    border: Border.all(color: AppColors.gold2, width: 2.5),
                    boxShadow: AppColors.shRed),
                child: Text('$n',
                    style: _t(false, 20, FontWeight.w800, color: AppColors.white)),
              ),
              const SizedBox(height: 16),
              Text(title, style: _t(gu, 19, FontWeight.w800)),
              const SizedBox(height: 6),
              Text(body,
                  style: _t(gu, 15, FontWeight.w500,
                      color: AppColors.ink2, height: 1.5)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(gu ? 'કેવી રીતે' : 'How it works',
            gu ? 'ત્રણ સરળ પગલાં' : 'Order in three easy steps', gu, wide),
        const SizedBox(height: 24),
        _grid(wide, [
          s(1, gu ? 'સાઇન ઇન કરો' : 'Sign in',
              gu ? 'ઇમેઇલ અથવા મોબાઇલથી OTP મેળવો.' : 'Get an OTP on your email or mobile.'),
          s(2, gu ? 'વસ્તુઓ પસંદ કરો' : 'Pick your items',
              gu ? 'કેટેગરી જુઓ અને કાર્ટમાં ઉમેરો.' : 'Browse categories and add to your cart.'),
          s(3, gu ? 'ઘરે મેળવો' : 'Get it delivered',
              gu ? 'ઓર્ડર ટ્રેક કરો અને કોઈન્સ મેળવો.' : 'Track the order and collect your coins.'),
        ], cols: wide ? 3 : 1),
      ],
    );
  }

  Widget _coinsBanner(BuildContext context, bool gu, bool wide) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(gu ? 'દરેક ઓર્ડર પર કોઈન્સ' : 'Coins on every order',
            style: _t(gu, wide ? 34 : 24, FontWeight.w800,
                color: AppColors.white, height: 1.15, ls: -.5)),
        const SizedBox(height: 10),
        Text(
            gu
                ? 'કોઈન્સ કમાઓ અને આગલા ઓર્ડરમાં વાપરો.'
                : 'Earn coins as you shop and use them to save on your next order.',
            style: _t(gu, wide ? 17 : 15, FontWeight.w500,
                color: AppColors.white.withValues(alpha: .92), height: 1.55)),
        const SizedBox(height: 22),
        SizedBox(
          width: 240,
          child: AppButton(gu ? 'હમણાં શરૂ કરો' : 'Start earning',
              onTap: () => go(_start(context)),
              variant: BtnVariant.gold,
              size: BtnSize.lg,
              icon: 'arrow',
              block: true),
        ),
      ],
    );
    return Container(
      padding: EdgeInsets.all(wide ? 44 : 24),
      decoration: BoxDecoration(
        gradient: StoreKit.redWarm,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.gold2.withValues(alpha: .6), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.red.withValues(alpha: .30),
              offset: const Offset(0, 14),
              blurRadius: 32),
        ],
      ),
      child: wide
          ? Row(children: [
              Expanded(child: text),
              const SizedBox(width: 32),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: StoreKit.goldWarm,
                    border: Border.all(color: AppColors.white, width: 4)),
                child: const Center(
                    child: AppIcon('coin', size: 72, color: AppColors.goldInk, sw: 1.6)),
              ),
            ])
          : text,
    );
  }

  Widget _footer(BuildContext context, bool gu, bool wide,
      Widget Function(Widget) bounded) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navy, AppColors.navyDeep],
        ),
        border: Border(top: BorderSide(color: AppColors.gold, width: 3)),
      ),
      child: bounded(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 16,
                spacing: 24,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const LogoMark(size: 28, color: AppColors.white),
                    const SizedBox(width: 10),
                    Text(brandLocalityLine(),
                        style: _t(gu, 16, FontWeight.w700,
                            color: AppColors.white)),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(gu ? 'પહેલેથી એકાઉન્ટ છે?' : 'Already have an account?',
                        style: _t(gu, 15, FontWeight.w600,
                            color: AppColors.white.withValues(alpha: .85))),
                    const SizedBox(width: 8),
                    AppLink(
                        _hasSession(context)
                            ? (gu ? 'મારું એકાઉન્ટ' : 'My account')
                            : (gu ? 'સાઇન ઇન' : 'Sign in'),
                        onTap: () => go(_start(context)),
                        color: AppColors.gold2,
                        size: 15),
                  ]),
                ],
              ),
              const SizedBox(height: 24),
              Text('© ${DateTime.now().year} ${seed.store.name}',
                  style: _t(false, 13, FontWeight.w500,
                      color: AppColors.white.withValues(alpha: .6))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fixed landing-page categories. Each photo is bundled in the app
/// (`assets/landing/`), so nothing is fetched from the backend or the web.
class _LandingCategories extends StatelessWidget {
  const _LandingCategories({required this.gu, required this.wide});
  final bool gu;
  final bool wide;

  static const _cats = <(String, String, String)>[
    ('dryfruit', 'Dry fruit', 'સૂકો મેવો'),
    ('pickle', 'Pickles & home-made', 'અથાણાં'),
    ('icecream', 'Ice cream', 'આઇસ્ક્રીમ'),
    ('tea', 'Tea & beverages', 'ચા'),
    ('snacks', 'Snacks & papad', 'નાસ્તો'),
    ('cosmetics', 'Cosmetics', 'કોસ્મેટિક'),
    ('grocery', 'Rice & grocery', 'કરિયાણું'),
    ('oil', 'Oils & ghee', 'તેલ અને ઘી'),
  ];

  @override
  Widget build(BuildContext context) {
    final n = wide ? 4 : 2;
    return LayoutBuilder(builder: (_, c) {
      const gap = 16.0;
      final cell = (c.maxWidth - gap * (n - 1)) / n;
      final imgH = wide ? 170.0 : 120.0;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final cat in _cats)
            SizedBox(
              width: cell,
              child: GestureDetector(
                onTap: () => go('/home'),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.line),
                      boxShadow: AppColors.sh1,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: imgH,
                          child: Image.asset('assets/landing/${cat.$1}.jpg',
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                          child: Text(
                            gu ? cat.$3 : cat.$2,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily:
                                  gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                              fontSize: 16,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
