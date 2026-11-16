import 'package:flutter/material.dart';

/// Vijay Super Mall design tokens — sourced 1:1 from `design-source.html` `:root`.
class AppColors {
  AppColors._();

  // Red (primary)
  static const Color red = Color(0xFFD3202B);
  static const Color red2 = Color(0xFFEE4A52);
  static const Color red3 = Color(0xFFB3121C);
  static const Color redTint = Color(0xFFFDE8E9);

  // Navy
  static const Color navy = Color(0xFF1F2A6B);
  static const Color navy2 = Color(0xFF3447B5);
  static const Color navyDeep = Color(0xFF121A47);
  static const Color navyTint = Color(0xFFE8EBF8);

  // Staff (cashier) top bar — deep teal, white text is 7.6:1 (AA/AAA)
  static const Color staffBar = Color(0xFF0B5F5A);
  static const Color staffBar2 = Color(0xFF0F7A72);
  static const Color staffTint = Color(0xFFD9F1EE);

  // Maroon
  static const Color maroon = Color(0xFF5E0F18);
  static const Color maroon2 = Color(0xFF8E1B1B);

  // Gold
  static const Color gold = Color(0xFFF5B301);
  static const Color gold2 = Color(0xFFFFD66B);
  static const Color goldInk = Color(0xFF7A4B00);
  static const Color goldTint = Color(0xFFFFF1C8);

  // Accents
  static const Color green = Color(0xFF12875A);
  static const Color greenTint = Color(0xFFDDF3E8);
  static const Color orange = Color(0xFFF26B1D);
  static const Color orangeTint = Color(0xFFFDF0E7);

  // Neutrals
  static const Color ink = Color(0xFF14162B);
  static const Color ink2 = Color(0xFF565A78);
  static const Color ink3 = Color(0xFF8A8EA8);
  static const Color line = Color(0xFFE4E6F1);
  static const Color bg = Color(0xFFF4F5FB);
  static const Color white = Color(0xFFFFFFFF);

  // Glass
  static const Color glass = Color(0xB8FFFFFF); // rgba(255,255,255,.72)
  static const Color glassEdge = Color(0xD9FFFFFF); // rgba(255,255,255,.85)

  // Extra values used across the design
  static const Color cream = Color(0xFFFFF4D1);
  static const Color welcomeBg = Color(0xFFFFF9EB);
  static const Color knobOff = Color(0xFFC9CEE2);
  static const Color sliderTrack = Color(0xFFDDE0EE);
  static const Color stepLine = Color(0xFFD5D8E8);
  static const Color navIdle = ink3;

  // Shadows
  static const List<BoxShadow> sh1 = [
    BoxShadow(color: Color(0x0F14162B), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x141F2A6B), offset: Offset(0, 6), blurRadius: 18),
  ];
  static const List<BoxShadow> sh2 = [
    BoxShadow(color: Color(0x0F14162B), offset: Offset(0, 2), blurRadius: 6),
    BoxShadow(color: Color(0x2E1F2A6B), offset: Offset(0, 20), blurRadius: 44),
  ];
  static const List<BoxShadow> shRed = [
    BoxShadow(color: Color(0x59D3202B), offset: Offset(0, 10), blurRadius: 24),
  ];

  /// Primary button gradient: 135° #EE4A52 → #D3202B 60% → #B3121C
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [red2, red, red3],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy2, navy],
  );

  /// The "mica" screen background: three soft radial tints over #F4F5FB.
  static const RadialGradient micaRed = RadialGradient(
    center: Alignment.topRight,
    radius: .85,
    colors: [Color(0x24D3202B), Color(0x00D3202B)],
    stops: [0.0, 0.7],
  );
  static const RadialGradient micaNavy = RadialGradient(
    center: Alignment(-1, -0.2),
    radius: .95,
    colors: [Color(0x293447B5), Color(0x003447B5)],
    stops: [0.0, 0.7],
  );
  static const RadialGradient micaGold = RadialGradient(
    center: Alignment.bottomRight,
    radius: .85,
    colors: [Color(0x38F5B301), Color(0x00F5B301)],
    stops: [0.0, 0.7],
  );

  /// Hero / admin header gradient: 150° #121A47 → #1F2A6B → #5E0F18
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, navy, maroon],
    stops: [0.0, 0.55, 1.0],
  );

  /// Admin header gradient: 150° #121A47 → #1F2A6B 60% → #3447B5
  static const LinearGradient adminHeadGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, navy, navy2],
    stops: [0.0, 0.6, 1.0],
  );

  /// Gold orb (radial): #FFE08A → #F5B301 → #C98A00
  static const RadialGradient goldOrb = RadialGradient(
    center: Alignment(-0.3, -0.3),
    colors: [Color(0xFFFFE08A), Color(0xFFF5B301), Color(0xFFC98A00)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Coin badge: 135° #FFD66B → #F5B301
  static const LinearGradient coinGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold2, gold],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1FB57E), green],
  );

  static const LinearGradient hotPill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A3D), orange],
  );

  /// `.sale-banner` background: 118deg #1F2A6B 0% → #3447B5 58% → #4B3E9F 100%
  static const LinearGradient bannerGradient = LinearGradient(
    begin: Alignment(-0.88, -0.47),
    end: Alignment(0.88, 0.47),
    colors: [navy, navy2, Color(0xFF4B3E9F)],
    stops: [0.0, 0.58, 1.0],
  );

  /// `.sale-banner::after` gold orb:
  /// `radial-gradient(circle at 34% 30%, #FFE7A8, #FFD66B 34%, #F5B301 64%, #E29A00)`
  static const RadialGradient bannerOrb = RadialGradient(
    center: Alignment(-0.32, -0.40),
    radius: 0.96,
    colors: [
      Color(0xFFFFE7A8),
      Color(0xFFFFD66B),
      Color(0xFFF5B301),
      Color(0xFFE29A00),
    ],
    stops: [0.0, 0.34, 0.64, 1.0],
  );

  static const LinearGradient chartBar = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF8FA0F0), navy2],
  );

  static const LinearGradient chartBarPeak = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [red2, red],
  );

  static const LinearGradient goldPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xF2FFF1C8), Color(0xB8FFFFFF)],
  );

  static const LinearGradient avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold2, gold],
  );

  static const LinearGradient walletHero = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [navyDeep, navy, navy2],
    stops: [0.0, 0.52, 1.0],
  );

  static const LinearGradient profileHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, navy, Color(0xFF7A2431)],
    stops: [0.0, 0.58, 1.3],
  );
}


/// Accent colours for one area of the admin console (catalog, stock, purchase,
/// money, reports...). Only colour: layout and fields never depend on it.
class SectionPalette {
  final Color accent; // buttons, active marks
  final Color deep; // dark end of the header gradient
  final Color mid; // middle of the header gradient
  final Color tint; // light fill for table heads and soft chips
  final Color glow; // soft light in the header corner
  const SectionPalette(this.accent, this.deep, this.mid, this.tint, this.glow);

  static const brand = SectionPalette(AppColors.red, AppColors.navyDeep,
      AppColors.navy, AppColors.redTint, Color(0xFFF5B301));
  static const catalog = SectionPalette(Color(0xFF3B6CF0), Color(0xFF1E3FA8),
      Color(0xFF2B55D4), Color(0xFFE6ECFD), Color(0xFF9DB8FF));
  static const stock = SectionPalette(Color(0xFF12A397), Color(0xFF0A6F68),
      Color(0xFF0E8A80), Color(0xFFDAF3F0), Color(0xFF7FE9DC));
  static const purchase = SectionPalette(Color(0xFF3447B5), Color(0xFF1F2A6B),
      Color(0xFF2B3A9A), Color(0xFFE8EBF8), Color(0xFFFFD66B));
  static const money = SectionPalette(Color(0xFF16A06B), Color(0xFF0C7049),
      Color(0xFF108859), Color(0xFFDDF3E8), Color(0xFF86EDBB));
  static const sales = SectionPalette(Color(0xFF0FA3CF), Color(0xFF0A6D93),
      Color(0xFF0C86B0), Color(0xFFDFF3FA), Color(0xFF8DEBFA));
  static const people = SectionPalette(Color(0xFF8B52DD), Color(0xFF5A2DA6),
      Color(0xFF7240C4), Color(0xFFEEE5FB), Color(0xFFD0B4FF));
  static const reports = SectionPalette(Color(0xFF6D4AE0), Color(0xFF4630B0),
      Color(0xFF5A3FCB), Color(0xFFEAE6FC), Color(0xFFBFB2FF));

  /// Palette for an admin route such as `/admin/purchases` or
  /// `/admin/counter?tab=low`.
  static SectionPalette forRoute(String route) {
    final r = route.toLowerCase();
    if (!r.startsWith('/admin')) return brand;
    bool has(List<String> k) => k.any(r.contains);
    if (r.contains('tab=low') || has(['stock-ops', 'stock-lots', 'stock-report'])) {
      return stock;
    }
    if (has(['inventory', 'categories', 'units', 'labels', 'gst-master', 'product'])) {
      return catalog;
    }
    if (has(['purchases'])) return purchase;
    if (has(['bank', 'payments', 'credit', 'refunds'])) return money;
    if (has(['orders', '/pos', 'hot-sale', 'flash', 'coupons', 'coins', 'shift'])) {
      return sales;
    }
    if (has(['customers', 'staff', 'push'])) return people;
    if (has(['reports', 'tab=shifts', 'tab=audit', 'tab=anomalies', 'tab=sync'])) {
      return reports;
    }
    return brand;
  }
}
