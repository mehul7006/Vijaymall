/// Seed data — direct port of assets/data.js.
///
/// Timestamps are computed relative to app start, exactly like the prototype
/// (`isoMinsAgo` / `isoDaysAgo` helpers).
import 'api/api_config.dart';
import 'models.dart';

DateTime isoMinsAgo(DateTime now, int mins) => now.subtract(Duration(minutes: mins));

DateTime isoDaysAgo(DateTime now, int days, [int hour = -1, int minute = 0]) {
  final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
  if (hour >= 0) {
    return DateTime(d.year, d.month, d.day, hour, minute);
  }
  return d;
}

/// Default store details; [store] is overwritten by the backend's
/// `/admin/shop-settings` payload once an admin session loads it.
final defaultStore = StoreInfo(
  name: 'Vijay Super Mall',
  nameGu: 'વિજય સુપર મોલ',
  // A live build shows only what the backend returns (`GET /shop-settings`):
  // no phone number, address or delivery promise is hard-coded. Only the
  // product name stays so the title bar has text before the backend answers.
  phone: ApiConfig.isLive ? '' : '97140 00027',
  phoneHref: ApiConfig.isLive ? '' : '+919714000027',
  address: ApiConfig.isLive ? '' : 'Vijay Super Mall, Ahmedabad',
  promise: ApiConfig.isLive ? '' : 'Free Home Delivery',
);

/// Live store info (seed values until backend shop settings are loaded).
StoreInfo store = defaultStore;

/// Short locality for the store ("Alkapuri, Ahmedabad" style) derived from
/// the **live** [StoreInfo.address] — never a hardcoded string, so editing
/// the address in shop settings updates every screen that names the area.
///
/// The backend address may be a single line with no commas
/// ("Adinathnagar Odhav Ahmedabad"), so this takes the last two words when
/// there is nothing to split on, and the last comma-separated segment when
/// there is.
String storeLocality() {
  final raw = store.address.trim();
  if (raw.isEmpty) return '';
  if (raw.contains(',')) {
    final segs = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    final list = segs.toList();
    return list.isEmpty ? raw : list.last;
  }
  final words = raw.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length <= 2) return raw;
  return '${words[words.length - 2]} ${words.last}';
}

final coinSettings = CoinSettings(coinValue: 1, maxPercent: 100, expiryMonths: 12);

final categories = <Category>[
  Category(id: 'grocery', name: 'Grocery', nameGu: 'કરિયાણું', icon: 'bag', tone: 'mint'),
  Category(id: 'home', name: 'Home Industry', nameGu: 'ગૃહ ઉદ્યોગ', icon: 'home', tone: 'peach'),
  Category(id: 'dry', name: 'Dry Fruit', nameGu: 'સૂકો ફળ', icon: 'gift', tone: 'gold'),
  Category(id: 'cosmetic', name: 'Cosmetic', nameGu: 'કોસ્મેટિક', icon: 'heart', tone: 'rose'),
  Category(id: 'icecream', name: 'Ice cream', nameGu: 'આઇસ્ક્રીમ', icon: 'bolt', tone: 'sky'),
];

final products = <Product>[
  Product(
    id: 'almonds', name: 'Premium Almonds', nameGu: 'પ્રીમિયમ બદામ', category: 'dry', unit: '500 g',
    desc: 'Hand-picked California almonds, rich in protein and vitamin E. Sealed fresh in our store and delivered to your door.',
    descGu: 'હાથે પસંદ કરેલી કેલિફોર્નિયા બદામ, પ્રોટીન અને વિટામિન E થી ભરપૂર. દુકાનમાં તાજી સીલ કરીને ઘર સુધી પહોંચાડીએ છીએ.',
    rating: 4.8, reviews: 212, art: 'almonds', tone: 'gold', stock: 48, lowStock: 10,
    available: true, earnsCoins: true, allowCoins: true,
    variants: [
      Variant(label: '250 g', price: 249, mrp: 290, unit: '250 g'),
      Variant(label: '500 g', price: 449, mrp: 520, unit: '500 g'),
      Variant(label: '1 kg', price: 849, mrp: 980, unit: '1 kg'),
    ],
    defaultVariant: 1,
  ),
  Product(
    id: 'pickle', name: 'Homemade Mango Pickle', nameGu: 'ઘરનું કેરીનું અથાણું', category: 'home', unit: '400 g',
    desc: 'Sun-cured mango pickle made in small batches with cold-pressed oil and our family masala. No preservatives.',
    descGu: 'કોલ્ડ-પ્રેસ્ડ તેલ અને ઘરના મસાલા સાથે નાના બેચમાં બનેલું કેરીનું અથાણું. કોઈ પ્રિઝર્વેટિવ નહીં.',
    rating: 4.9, reviews: 184, art: 'pickle', tone: 'peach', stock: 22, lowStock: 6,
    available: true, earnsCoins: true, allowCoins: true,
    variants: [
      Variant(label: '400 g', price: 160, mrp: 190, unit: '400 g'),
      Variant(label: '1 kg', price: 360, mrp: 430, unit: '1 kg'),
    ],
    defaultVariant: 0,
  ),
  Product(
    id: 'rice', name: 'Basmati Rice 5kg', nameGu: 'બાસમતી ચોખા 5 કિલો', category: 'grocery', unit: '5 kg',
    desc: 'Aged long-grain basmati that cooks fluffy every time. Perfect for biryani, pulao and everyday dal-chawal.',
    descGu: 'લાંબા દાણાના જૂના બાસમતી ચોખા. બિરયાની, પુલાવ અને રોજિંદા ભોજન માટે ઉત્તમ.',
    rating: 4.6, reviews: 326, art: 'rice', tone: 'lilac', stock: 12, lowStock: 8,
    available: true, earnsCoins: true, allowCoins: true,
    variants: [
      Variant(label: '1 kg', price: 130, mrp: 130, unit: '1 kg'),
      Variant(label: '5 kg', price: 560, mrp: 560, unit: '5 kg'),
      Variant(label: '10 kg', price: 1080, mrp: 1080, unit: '10 kg'),
    ],
    defaultVariant: 1,
  ),
  Product(
    id: 'cream', name: 'Face Glow Cream', nameGu: 'ફેસ ગ્લો ક્રીમ', category: 'cosmetic', unit: '50 g',
    desc: 'Light day cream with vitamin C and aloe. Fades dullness and leaves a soft, non-greasy glow.',
    descGu: 'વિટામિન C અને એલોવેરા સાથેની હળવી ડે ક્રીમ. ચહેરાને કુદરતી ચમક આપે છે.',
    rating: 4.5, reviews: 98, art: 'cream', tone: 'rose', stock: 5, lowStock: 8,
    available: true, earnsCoins: true, allowCoins: true,
    variants: [
      Variant(label: '50 g', price: 249, mrp: 299, unit: '50 g'),
      Variant(label: '100 g', price: 449, mrp: 520, unit: '100 g'),
    ],
    defaultVariant: 0,
  ),
  Product(
    id: 'kulfi', name: 'Kulfi Ice Cream 1L', nameGu: 'કુલ્ફી આઇસ્ક્રીમ 1L', category: 'icecream', unit: '1 L',
    desc: 'Slow-churned kulfi with pistachio and saffron. Delivered frozen from our cold counter.',
    descGu: 'પિસ્તા અને કેસર સાથેની મલાઈ કુલ્ફી. કોલ્ડ કાઉન્ટરથી ફ્રોઝન ડિલિવરી.',
    rating: 4.7, reviews: 156, art: 'kulfi', tone: 'sky', stock: 30, lowStock: 6,
    available: true, earnsCoins: true, allowCoins: true,
    variants: [
      Variant(label: '500 ml', price: 99, mrp: 99, unit: '500 ml'),
      Variant(label: '1 L', price: 180, mrp: 180, unit: '1 L'),
    ],
    defaultVariant: 1,
  ),
  Product(
    id: 'tea', name: 'Kadak Masala Tea', nameGu: 'કડક મસાલા ચા', category: 'grocery', unit: '250 g',
    desc: 'Assam tea blended with cardamom, ginger and clove for a strong kadak cup every morning.',
    descGu: 'એલાયચી, આદુ અને લવિંગ સાથેની આસામ ચા. દરેક સવારે કડક ચા માટે.',
    rating: 4.6, reviews: 142, art: 'tea', tone: 'mint', stock: 60, lowStock: 10,
    available: true, earnsCoins: true, allowCoins: false,
    variants: [
      Variant(label: '250 g', price: 145, mrp: 170, unit: '250 g'),
      Variant(label: '500 g', price: 275, mrp: 320, unit: '500 g'),
    ],
    defaultVariant: 0,
  ),
  Product(
    id: 'cashew', name: 'Roasted Cashews', nameGu: 'ભેળેલા કાજુ', category: 'dry', unit: '250 g',
    desc: 'Whole roasted cashews, lightly salted and packed the same day to stay crunchy.',
    descGu: 'આખા ભેળેલા કાજુ, હળવા મીઠા સાથે એ જ દિવસે પેક કરેલા.',
    rating: 4.8, reviews: 121, art: 'cashew', tone: 'sand', stock: 26, lowStock: 8,
    available: true, earnsCoins: true, allowCoins: true,
    variants: [
      Variant(label: '250 g', price: 349, mrp: 399, unit: '250 g'),
      Variant(label: '500 g', price: 660, mrp: 720, unit: '500 g'),
    ],
    defaultVariant: 0,
  ),
  Product(
    id: 'oil', name: 'Cold-Pressed Groundnut Oil', nameGu: 'કોલ્ડ-પ્રેસ્ડ મગફળીનું તેલ', category: 'grocery', unit: '1 L',
    desc: 'Cold-pressed, unrefined groundnut oil from local mills. A staple for everyday Gujarati cooking.',
    descGu: 'સ્થાનિક ઘાણીનું કોલ્ડ-પ્રેસ્ડ, અનરિફાઇન્ડ મગફળીનું તેલ. રોજિંદા ગુજરાતી રસોઈ માટે.',
    rating: 4.6, reviews: 89, art: 'oil', tone: 'amber', stock: 60, lowStock: 12,
    available: true, earnsCoins: true, allowCoins: false,
    variants: [
      Variant(label: '1 L', price: 210, mrp: 240, unit: '1 L'),
      Variant(label: '5 L', price: 999, mrp: 1100, unit: '5 L'),
    ],
    defaultVariant: 0,
  ),
  Product(
    id: 'fafda', name: 'Gujarati Fafda', nameGu: 'ગુજરાતી ફાફડા', category: 'home', unit: '500 g',
    desc: 'Crisp, hand-rolled Gujarati fafda made fresh in our home-industry kitchen. Best with papaya sambharo.',
    descGu: 'અમારા ગૃહ ઉદ્યોગના રસોડામાં તાજા બનેલા કડક ફાફડા. પપૈયાના સંભારો સાથે ઉત્તમ.',
    rating: 4.7, reviews: 74, art: 'fafda', tone: 'sand', stock: 35, lowStock: 10,
    available: true, earnsCoins: true, allowCoins: true,
    variants: [
      Variant(label: '500 g', price: 120, mrp: 140, unit: '500 g'),
      Variant(label: '1 kg', price: 230, mrp: 260, unit: '1 kg'),
    ],
    defaultVariant: 0,
  ),
  Product(
    id: 'facewash', name: 'Neem Face Wash', nameGu: 'નીમ ફેસ વોશ', category: 'cosmetic', unit: '100 ml',
    desc: 'Neem and tulsi face wash that keeps skin clear through Ahmedabad summers. Sulphate free.',
    descGu: 'નીમ અને તુલસી સાથેનું ફેસ વોશ. ઉનાળામાં ત્વચા સ્વચ્છ અને તાજી રાખે. સલ્ફેટ ફ્રી.',
    rating: 4.4, reviews: 67, art: 'facewash', tone: 'mint', stock: 4, lowStock: 6,
    available: true, earnsCoins: true, allowCoins: true,
    variants: [
      Variant(label: '100 ml', price: 199, mrp: 249, unit: '100 ml'),
      Variant(label: '150 ml', price: 279, mrp: 329, unit: '150 ml'),
    ],
    defaultVariant: 0,
  ),
  Product(
    id: 'coldcoffee', name: 'Cold Coffee Ice Cream 1L', nameGu: 'કોલ્ડ કોફી આઇસ્ક્રીમ 1L', category: 'icecream', unit: '1 L',
    desc: 'Roasted coffee folded into creamy ice cream. A tall-glass treat, straight from the freezer.',
    descGu: 'ભેળેલી કોફી અને ક્રીમી આઇસ્ક્રીમ. ફ્રીઝરમાંથી સીધું ઘરે માણો.',
    rating: 4.6, reviews: 53, art: 'icecream-tub', tone: 'lilac', stock: 18, lowStock: 6,
    available: true, earnsCoins: true, allowCoins: true,
    variants: [
      Variant(label: '500 ml', price: 110, mrp: 120, unit: '500 ml'),
      Variant(label: '1 L', price: 190, mrp: 210, unit: '1 L'),
    ],
    defaultVariant: 1,
  ),
  Product(
    id: 'bajra', name: 'Bajra Flour 1kg', nameGu: 'બાજરીનું લોટ 1 કિલો', category: 'grocery', unit: '1 kg',
    desc: 'Stone-ground bajra flour for soft rotlo and winter bhakri. Milled weekly.',
    descGu: 'માવઠા વિહોણું, પથ્થર પર દળેલું બાજરીનું લોટ. નરમ રોટલો અને શિયાળુ ભાખરી માટે.',
    rating: 4.5, reviews: 41, art: 'flour', tone: 'sand', stock: 42, lowStock: 10,
    available: true, earnsCoins: true, allowCoins: true,
    variants: [
      Variant(label: '1 kg', price: 80, mrp: 90, unit: '1 kg'),
      Variant(label: '5 kg', price: 390, mrp: 420, unit: '5 kg'),
    ],
    defaultVariant: 0,
  ),
];

final coupons = <Coupon>[
  Coupon(
    code: 'FESTIVE50', desc: '₹50 off on orders above ₹999', type: 'flat', value: 50, min: 999,
    scope: 'all', active: true, starts: '2026-10-18', expires: '2026-10-31',
    uses: 12, maxUses: 500, worksWithCoins: true, firstOrderOnly: false,
  ),
  Coupon(
    code: 'DRYFRUIT10', desc: '10% off Dry Fruit · max ₹150', type: 'percent', value: 10, maxDiscount: 150, min: 499,
    scope: 'dry', active: true, starts: '2026-10-01', expires: '2026-11-15',
    uses: 34, maxUses: 300, worksWithCoins: true, firstOrderOnly: false,
  ),
  Coupon(
    code: 'WELCOME', desc: '₹30 off your first order', type: 'flat', value: 30, min: 199,
    scope: 'all', active: true, starts: '2026-08-01', expires: '2026-12-31',
    uses: 87, maxUses: 1000, worksWithCoins: true, firstOrderOnly: false,
  ),
  Coupon(
    code: 'SUMMER20', desc: '20% off Ice cream · max ₹200', type: 'percent', value: 20, maxDiscount: 200, min: 299,
    scope: 'icecream', active: true, starts: '2026-06-01', expires: '2026-09-30',
    uses: 41, maxUses: 400, worksWithCoins: true, firstOrderOnly: false,
  ),
];

final coinRules = <CoinRule>[
  CoinRule(
    id: 'standard', name: 'Standard rule', spend: 1000, coins: 10, mode: 'pro-rata',
    scope: 'All items', active: true, starts: '', expires: '', everGreen: true,
  ),
  CoinRule(
    id: 'diwali', name: 'Diwali bonus', spend: 2000, coins: 30, mode: 'slab',
    scope: 'All items', active: true, starts: '2026-11-01', expires: '2026-11-05', everGreen: false,
  ),
];

final hotSale = HotSale(
  live: true,
  eyebrow: 'HOT SALE · TODAY ONLY',
  title: 'Up to 30% off on Dry Fruit',
  starts: '2026-10-24',
  ends: '2026-10-26',
  featured: ['almonds', 'pickle', 'cream', 'cashew'],
);

final addresses = <Address>[
  Address(id: 'home', label: 'Home', detail: '12, Shree Residency, Alkapuri, Ahmedabad 390007', phone: '97140 12345'),
  Address(id: 'shop', label: 'Shop', detail: 'Shop 4, Surya Complex, Race Course Road, Ahmedabad 390007', phone: '97140 12345'),
];

final weekSales = <WeekSale>[
  WeekSale(day: 'M', amount: 8200),
  WeekSale(day: 'T', amount: 11200),
  WeekSale(day: 'W', amount: 7600),
  WeekSale(day: 'T', amount: 13800),
  WeekSale(day: 'F', amount: 10200),
  WeekSale(day: 'S', amount: 15600),
  WeekSale(day: 'S', amount: 9100),
];

List<OrderItem> snapshotItems(List<Map<String, dynamic>> list) {
  return list.map((it) {
    final p = products.firstWhere((x) => x.id == it['id']);
    final vi = (it['variantIndex'] ?? p.defaultVariant) as int;
    final v = p.variants[vi];
    return OrderItem(
      productId: p.id,
      variantIndex: vi,
      name: p.name,
      nameGu: p.nameGu,
      unit: v.unit,
      price: v.price,
      qty: it['qty'] as int,
      earnsCoins: p.earnsCoins,
      allowCoins: p.allowCoins,
      art: p.art,
      tone: p.tone,
    );
  }).toList();
}

Order buildOrder({
  required String number,
  required String customer,
  required String phone,
  required String mode,
  required List<Map<String, dynamic>> items,
  required String payment,
  required List<List<dynamic>> timeline, // [status, minsAgo]
  String? coupon,
  int coinsUsed = 0,
  String? address,
  String? slot,
  String? paymentState,
  String? cancelReason,
  Map<String, dynamic>? partner,
  bool stockReserved = false,
  String createdBy = 'seed',
  required DateTime now,
}) {
  final snapshot = snapshotItems(items);
  final subtotal = snapshot.fold<num>(0, (sum, it) => sum + it.price * it.qty);
  final c = coupon == null ? null : coupons.firstWhere((x) => x.code == coupon);
  num couponDiscount = 0;
  if (c != null) {
    couponDiscount = c.type == 'flat'
        ? c.value
        : [
            (subtotal * c.value / 100).round(),
            c.maxDiscount ?? 99999,
          ].reduce((num a, num b) => a < b ? a : b);
  }
  final total = [0, subtotal - couponDiscount - coinsUsed].reduce((num a, num b) => a > b ? a : b);
  final earnBase =
      snapshot.where((it) => it.earnsCoins).fold<num>(0, (sum, it) => sum + it.price * it.qty);
  final coinsEarned = subtotal == 0 ? 0 : ((earnBase / subtotal) * total / 1000 * 10).floor();
  final history = timeline
      .map((t) => StatusEvent(status: t[0] as String, at: isoMinsAgo(now, t[1] as int)))
      .toList();
  final partnerObj = partner == null
      ? null
      : DeliveryPartner(
          name: partner['name'] as String,
          role: partner['role'] as String,
          phone: partner['phone'] as String,
        );

  return Order(
    number: number,
    customer: customer,
    phone: phone,
    customerEmail: '',
    items: snapshot,
    mode: mode,
    address: address ??
        (mode == 'delivery' ? addresses[0].full : store.address),
    slot: slot ?? (mode == 'pickup' ? 'Today · 6:00 – 8:00 PM' : ''),
    payment: payment,
    paymentState: paymentState ?? 'Pending',
    status: timeline.last[0] as String,
    statusHistory: history,
    placedAt: history.first.at,
    updatedAt: history.last.at,
    bill: Bill(
      subtotal: subtotal,
      couponCode: c?.code ?? '',
      couponDiscount: couponDiscount,
      coinsUsed: coinsUsed,
      delivery: 0,
      total: total,
    ),
    coinsUsed: coinsUsed,
    coinsEarned: coinsEarned,
    coinRule: 'Standard rule',
    cancelReason: cancelReason ?? '',
    partner: partnerObj,
    stockReserved: stockReserved,
    createdBy: createdBy,
  );
}

List<Order> seedOrders(DateTime now) => [
      buildOrder(
        number: 'VSM-1043', customer: 'Hetal P.', phone: '97140 22118', mode: 'delivery',
        items: [
          {'id': 'almonds', 'qty': 1, 'variantIndex': 0},
          {'id': 'cashew', 'qty': 1},
        ],
        payment: 'Cash on delivery', paymentState: 'Pending',
        timeline: [
          ['Placed', 7]
        ],
        address: '7, Nilkanth Society, Akota, Ahmedabad 390020',
        createdBy: 'seed', stockReserved: false, now: now,
      ),
      buildOrder(
        number: 'VSM-1042', customer: 'Mahipal H.', phone: '97140 12345', mode: 'delivery',
        items: [
          {'id': 'almonds', 'qty': 1, 'variantIndex': 1},
          {'id': 'rice', 'qty': 1, 'variantIndex': 1},
          {'id': 'kulfi', 'qty': 1, 'variantIndex': 1},
          {'id': 'pickle', 'qty': 1},
        ],
        coupon: 'FESTIVE50', coinsUsed: 120, payment: 'Cash on delivery', paymentState: 'Pending',
        timeline: [
          ['Placed', 26]
        ],
        address: '12, Shree Residency, Alkapuri, Ahmedabad 390007',
        now: now,
      ),
      buildOrder(
        number: 'VSM-1041', customer: 'Kavita S.', phone: '98795 44110', mode: 'pickup',
        items: [
          {'id': 'cream', 'qty': 1},
          {'id': 'facewash', 'qty': 1},
        ],
        coinsUsed: 10, payment: 'Pay at store', paymentState: 'Pending',
        timeline: [
          ['Placed', 48],
          ['Confirmed', 44]
        ],
        stockReserved: true, now: now,
      ),
      buildOrder(
        number: 'VSM-1040', customer: 'Rajesh P.', phone: '98240 77231', mode: 'delivery',
        items: [
          {'id': 'rice', 'qty': 2, 'variantIndex': 1},
          {'id': 'cashew', 'qty': 1},
          {'id': 'almonds', 'qty': 1, 'variantIndex': 1},
          {'id': 'oil', 'qty': 1},
          {'id': 'tea', 'qty': 1},
          {'id': 'fafda', 'qty': 1},
        ],
        coupon: 'FESTIVE50', coinsUsed: 33, payment: 'Cash on delivery', paymentState: 'Pending',
        timeline: [
          ['Placed', 82],
          ['Confirmed', 78],
          ['Packed', 56]
        ],
        stockReserved: true, now: now,
      ),
      buildOrder(
        number: 'VSM-1039', customer: 'Nirali D.', phone: '90999 88320', mode: 'pickup',
        items: [
          {'id': 'rice', 'qty': 1, 'variantIndex': 1},
          {'id': 'bajra', 'qty': 1},
          {'id': 'fafda', 'qty': 1},
        ],
        coinsUsed: 70, payment: 'Pay at store', paymentState: 'Pending',
        timeline: [
          ['Placed', 96],
          ['Confirmed', 90],
          ['Packed', 70]
        ],
        stockReserved: true, now: now,
      ),
      buildOrder(
        number: 'VSM-1038', customer: 'Kiran P.', phone: '98790 66217', mode: 'delivery',
        items: [
          {'id': 'rice', 'qty': 1, 'variantIndex': 1},
          {'id': 'almonds', 'qty': 1, 'variantIndex': 1},
        ],
        coupon: 'FESTIVE50', coinsUsed: 114, payment: 'UPI / Card', paymentState: 'Paid',
        timeline: [
          ['Placed', 140],
          ['Confirmed', 135],
          ['Packed', 110],
          ['Out for Delivery', 85]
        ],
        partner: {'name': 'Ramesh', 'role': 'Vijay Super Mall rider', 'phone': '98250 11223'},
        stockReserved: true, now: now,
      ),
      buildOrder(
        number: 'VSM-1037', customer: 'Jignesh M.', phone: '95370 44102', mode: 'pickup',
        items: [
          {'id': 'rice', 'qty': 2, 'variantIndex': 1},
          {'id': 'cashew', 'qty': 1},
          {'id': 'cream', 'qty': 1},
        ],
        coupon: 'FESTIVE50', coinsUsed: 128, payment: 'UPI / Card', paymentState: 'Paid',
        timeline: [
          ['Placed', 180],
          ['Confirmed', 175],
          ['Packed', 150],
          ['Ready for Pickup', 120]
        ],
        stockReserved: true, now: now,
      ),
      buildOrder(
        number: 'VSM-1036', customer: 'Anjali T.', phone: '99980 31176', mode: 'delivery',
        items: [
          {'id': 'almonds', 'qty': 2, 'variantIndex': 1},
          {'id': 'rice', 'qty': 2, 'variantIndex': 1},
          {'id': 'cream', 'qty': 1},
        ],
        coupon: 'FESTIVE50', coinsUsed: 37, payment: 'Cash on delivery', paymentState: 'Paid',
        timeline: [
          ['Placed', 240],
          ['Confirmed', 235],
          ['Packed', 210],
          ['Out for Delivery', 170],
          ['Delivered', 80]
        ],
        partner: {'name': 'Ramesh', 'role': 'Vijay Super Mall rider', 'phone': '98250 11223'},
        stockReserved: true, now: now,
      ),
      buildOrder(
        number: 'VSM-1035', customer: 'Paresh K.', phone: '97260 55408', mode: 'pickup',
        items: [
          {'id': 'rice', 'qty': 1, 'variantIndex': 1},
          {'id': 'bajra', 'qty': 1},
          {'id': 'fafda', 'qty': 1},
        ],
        coinsUsed: 85, payment: 'Pay at store', paymentState: 'Paid',
        timeline: [
          ['Placed', 1560],
          ['Confirmed', 1550],
          ['Packed', 1530],
          ['Ready for Pickup', 1495],
          ['Picked Up', 1420]
        ],
        stockReserved: true, now: now,
      ),
      buildOrder(
        number: 'VSM-1034', customer: 'Mehul S.', phone: '98980 12764', mode: 'delivery',
        items: [
          {'id': 'kulfi', 'qty': 1, 'variantIndex': 1},
          {'id': 'pickle', 'qty': 1},
        ],
        payment: 'UPI / Card', paymentState: 'Refunded',
        timeline: [
          ['Placed', 1620],
          ['Cancelled', 1580]
        ],
        cancelReason: 'Customer changed the order', now: now,
      ),
    ];

List<LedgerEntry> seedLedger(DateTime now) => [
      LedgerEntry(
        id: 'lg-pending-1042', title: 'Order #VSM-1042', sub: 'Pending delivery', coins: 11,
        status: 'pending', type: 'earn', orderNumber: 'VSM-1042', date: isoMinsAgo(now, 26),
      ),
      LedgerEntry(
        id: 'lg-redeem-1042', title: 'Redeemed on #VSM-1042', sub: 'Coins used at checkout', coins: -120,
        status: 'spent', type: 'spend', orderNumber: 'VSM-1042', date: isoMinsAgo(now, 26),
      ),
      LedgerEntry(
        id: 'lg-festive', title: 'Festive bonus', sub: 'Diwali shopping bonus', coins: 176,
        status: 'credited', type: 'bonus', orderNumber: '', date: isoDaysAgo(now, 9),
      ),
      LedgerEntry(
        id: 'lg-order-1031', title: 'Order #VSM-1031', sub: 'Coins credited', coins: 14,
        status: 'credited', type: 'earn', orderNumber: 'VSM-1031', date: isoDaysAgo(now, 12),
      ),
      LedgerEntry(
        id: 'lg-welcome', title: 'Welcome bonus', sub: 'First order with Vijay Super Mall', coins: 50,
        status: 'credited', type: 'bonus', orderNumber: '', date: isoDaysAgo(now, 22),
      ),
    ];

List<StockMove> seedStockMoves(DateTime now) => [
      StockMove(id: 'stk-almonds-today', productId: 'almonds', productName: 'Premium Almonds', variantIndex: 1, variantLabel: '500 g', qty: 24, at: isoMinsAgo(now, 190), note: 'Supplier purchase'),
      StockMove(id: 'stk-tea-today', productId: 'tea', productName: 'Kadak Masala Tea', variantIndex: 0, variantLabel: '250 g', qty: 30, at: isoMinsAgo(now, 155), note: 'Supplier purchase'),
      StockMove(id: 'stk-kulfi-today', productId: 'kulfi', productName: 'Kulfi Ice Cream 1L', variantIndex: 1, variantLabel: '1 L', qty: 18, at: isoMinsAgo(now, 125), note: 'Supplier purchase'),
      StockMove(id: 'stk-fafda-today', productId: 'fafda', productName: 'Gujarati Fafda', variantIndex: 0, variantLabel: '500 g', qty: 20, at: isoMinsAgo(now, 85), note: 'Supplier purchase'),
      StockMove(id: 'stk-rice-1', productId: 'rice', productName: 'Basmati Rice 5kg', variantIndex: 1, variantLabel: '5 kg', qty: 18, at: isoDaysAgo(now, 1, 9, 10), note: 'Supplier purchase'),
      StockMove(id: 'stk-cashew-1', productId: 'cashew', productName: 'Roasted Cashews', variantIndex: 0, variantLabel: '250 g', qty: 16, at: isoDaysAgo(now, 1, 9, 40), note: 'Supplier purchase'),
      StockMove(id: 'stk-oil-1', productId: 'oil', productName: 'Cold-Pressed Groundnut Oil', variantIndex: 0, variantLabel: '1 L', qty: 24, at: isoDaysAgo(now, 1, 10, 15), note: 'Supplier purchase'),
      StockMove(id: 'stk-pickle-1', productId: 'pickle', productName: 'Homemade Mango Pickle', variantIndex: 0, variantLabel: '400 g', qty: 12, at: isoDaysAgo(now, 1, 11, 5), note: 'Supplier purchase'),
      StockMove(id: 'stk-cream-2', productId: 'cream', productName: 'Face Glow Cream', variantIndex: 0, variantLabel: '50 g', qty: 6, at: isoDaysAgo(now, 2, 9, 20), note: 'Supplier purchase'),
      StockMove(id: 'stk-facewash-2', productId: 'facewash', productName: 'Neem Face Wash', variantIndex: 0, variantLabel: '100 ml', qty: 8, at: isoDaysAgo(now, 2, 10, 0), note: 'Supplier purchase'),
      StockMove(id: 'stk-almonds-2', productId: 'almonds', productName: 'Premium Almonds', variantIndex: 0, variantLabel: '250 g', qty: 12, at: isoDaysAgo(now, 2, 10, 35), note: 'Supplier purchase'),
      StockMove(id: 'stk-tea-2', productId: 'tea', productName: 'Kadak Masala Tea', variantIndex: 1, variantLabel: '500 g', qty: 18, at: isoDaysAgo(now, 2, 11, 15), note: 'Supplier purchase'),
      StockMove(id: 'stk-kulfi-4', productId: 'kulfi', productName: 'Kulfi Ice Cream 1L', variantIndex: 0, variantLabel: '500 ml', qty: 20, at: isoDaysAgo(now, 4, 9, 30), note: 'Supplier purchase'),
      StockMove(id: 'stk-cashew-4', productId: 'cashew', productName: 'Roasted Cashews', variantIndex: 1, variantLabel: '500 g', qty: 10, at: isoDaysAgo(now, 4, 10, 10), note: 'Supplier purchase'),
      StockMove(id: 'stk-fafda-4', productId: 'fafda', productName: 'Gujarati Fafda', variantIndex: 1, variantLabel: '1 kg', qty: 12, at: isoDaysAgo(now, 4, 10, 50), note: 'Supplier purchase'),
      StockMove(id: 'stk-rice-6', productId: 'rice', productName: 'Basmati Rice 5kg', variantIndex: 2, variantLabel: '10 kg', qty: 10, at: isoDaysAgo(now, 6, 9, 15), note: 'Supplier purchase'),
      StockMove(id: 'stk-oil-6', productId: 'oil', productName: 'Cold-Pressed Groundnut Oil', variantIndex: 1, variantLabel: '5 L', qty: 8, at: isoDaysAgo(now, 6, 9, 55), note: 'Supplier purchase'),
      StockMove(id: 'stk-pickle-6', productId: 'pickle', productName: 'Homemade Mango Pickle', variantIndex: 1, variantLabel: '1 kg', qty: 6, at: isoDaysAgo(now, 6, 10, 40), note: 'Supplier purchase'),
    ];
