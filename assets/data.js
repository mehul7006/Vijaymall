/* Vijay Super Mall — shared catalogue, rewards and order seed data */
(function () {
  const categories = [
    { id: 'grocery', name: 'Grocery', nameGu: 'કરિયાણું', icon: 'bag', tone: 'mint' },
    { id: 'home', name: 'Home Industry', nameGu: 'ગૃહ ઉદ્યોગ', icon: 'home', tone: 'peach' },
    { id: 'dry', name: 'Dry Fruit', nameGu: 'સૂકો ફળ', icon: 'gift', tone: 'gold' },
    { id: 'cosmetic', name: 'Cosmetic', nameGu: 'કોસ્મેટિક', icon: 'heart', tone: 'rose' },
    { id: 'icecream', name: 'Ice cream', nameGu: 'આઇસ્ક્રીમ', icon: 'bolt', tone: 'sky' }
  ];

  const products = [
    {
      id: 'almonds', name: 'Premium Almonds', nameGu: 'પ્રીમિયમ બદામ', category: 'dry', unit: '500 g',
      desc: 'Hand-picked California almonds, rich in protein and vitamin E. Sealed fresh in our store and delivered to your door.',
      descGu: 'હાથે પસંદ કરેલી કેલિફોર્નિયા બદામ, પ્રોટીન અને વિટામિન E થી ભરપૂર. દુકાનમાં તાજી સીલ કરીને ઘર સુધી પહોંચાડીએ છીએ.',
      rating: 4.8, reviews: 212, art: 'almonds', tone: 'gold', stock: 48, lowStock: 10,
      available: true, earnsCoins: true, allowCoins: true,
      variants: [
        { label: '250 g', price: 249, mrp: 290, unit: '250 g' },
        { label: '500 g', price: 449, mrp: 520, unit: '500 g' },
        { label: '1 kg', price: 849, mrp: 980, unit: '1 kg' }
      ], defaultVariant: 1
    },
    {
      id: 'pickle', name: 'Homemade Mango Pickle', nameGu: 'ઘરનું કેરીનું અથાણું', category: 'home', unit: '400 g',
      desc: 'Sun-cured mango pickle made in small batches with cold-pressed oil and our family masala. No preservatives.',
      descGu: 'કોલ્ડ-પ્રેસ્ડ તેલ અને ઘરના મસાલા સાથે નાના બેચમાં બનેલું કેરીનું અથાણું. કોઈ પ્રિઝર્વેટિવ નહીં.',
      rating: 4.9, reviews: 184, art: 'pickle', tone: 'peach', stock: 22, lowStock: 6,
      available: true, earnsCoins: true, allowCoins: true,
      variants: [
        { label: '400 g', price: 160, mrp: 190, unit: '400 g' },
        { label: '1 kg', price: 360, mrp: 430, unit: '1 kg' }
      ], defaultVariant: 0
    },
    {
      id: 'rice', name: 'Basmati Rice 5kg', nameGu: 'બાસમતી ચોખા 5 કિલો', category: 'grocery', unit: '5 kg',
      desc: 'Aged long-grain basmati that cooks fluffy every time. Perfect for biryani, pulao and everyday dal-chawal.',
      descGu: 'લાંબા દાણાના જૂના બાસમતી ચોખા. બિરયાની, પુલાવ અને રોજિંદા ભોજન માટે ઉત્તમ.',
      rating: 4.6, reviews: 326, art: 'rice', tone: 'lilac', stock: 12, lowStock: 8,
      available: true, earnsCoins: true, allowCoins: true,
      variants: [
        { label: '1 kg', price: 130, mrp: 130, unit: '1 kg' },
        { label: '5 kg', price: 560, mrp: 560, unit: '5 kg' },
        { label: '10 kg', price: 1080, mrp: 1080, unit: '10 kg' }
      ], defaultVariant: 1
    },
    {
      id: 'cream', name: 'Face Glow Cream', nameGu: 'ફેસ ગ્લો ક્રીમ', category: 'cosmetic', unit: '50 g',
      desc: 'Light day cream with vitamin C and aloe. Fades dullness and leaves a soft, non-greasy glow.',
      descGu: 'વિટામિન C અને એલોવેરા સાથેની હળવી ડે ક્રીમ. ચહેરાને કુદરતી ચમક આપે છે.',
      rating: 4.5, reviews: 98, art: 'cream', tone: 'rose', stock: 5, lowStock: 8,
      available: true, earnsCoins: true, allowCoins: true,
      variants: [
        { label: '50 g', price: 249, mrp: 299, unit: '50 g' },
        { label: '100 g', price: 449, mrp: 520, unit: '100 g' }
      ], defaultVariant: 0
    },
    {
      id: 'kulfi', name: 'Kulfi Ice Cream 1L', nameGu: 'કુલ્ફી આઇસ્ક્રીમ 1L', category: 'icecream', unit: '1 L',
      desc: 'Slow-churned kulfi with pistachio and saffron. Delivered frozen from our cold counter in Alkapuri.',
      descGu: 'પિસ્તા અને કેસર સાથેની મલાઈ કુલ્ફી. અલકાપુરીના કોલ્ડ કાઉન્ટરથી ફ્રોઝન ડિલિવરી.',
      rating: 4.7, reviews: 156, art: 'kulfi', tone: 'sky', stock: 30, lowStock: 6,
      available: true, earnsCoins: true, allowCoins: true,
      variants: [
        { label: '500 ml', price: 99, mrp: 99, unit: '500 ml' },
        { label: '1 L', price: 180, mrp: 180, unit: '1 L' }
      ], defaultVariant: 1
    },
    {
      id: 'tea', name: 'Kadak Masala Tea', nameGu: 'કડક મસાલા ચા', category: 'grocery', unit: '250 g',
      desc: 'Assam tea blended with cardamom, ginger and clove for a strong kadak cup every morning.',
      descGu: 'એલાયચી, આદુ અને લવિંગ સાથેની આસામ ચા. દરેક સવારે કડક ચા માટે.',
      rating: 4.6, reviews: 142, art: 'tea', tone: 'mint', stock: 60, lowStock: 10,
      available: true, earnsCoins: true, allowCoins: false,
      variants: [
        { label: '250 g', price: 145, mrp: 170, unit: '250 g' },
        { label: '500 g', price: 275, mrp: 320, unit: '500 g' }
      ], defaultVariant: 0
    },
    {
      id: 'cashew', name: 'Roasted Cashews', nameGu: 'ભેળેલા કાજુ', category: 'dry', unit: '250 g',
      desc: 'Whole roasted cashews, lightly salted and packed the same day to stay crunchy.',
      descGu: 'આખા ભેળેલા કાજુ, હળવા મીઠા સાથે એ જ દિવસે પેક કરેલા.',
      rating: 4.8, reviews: 121, art: 'cashew', tone: 'sand', stock: 26, lowStock: 8,
      available: true, earnsCoins: true, allowCoins: true,
      variants: [
        { label: '250 g', price: 349, mrp: 399, unit: '250 g' },
        { label: '500 g', price: 660, mrp: 720, unit: '500 g' }
      ], defaultVariant: 0
    },
    {
      id: 'oil', name: 'Cold-Pressed Groundnut Oil', nameGu: 'કોલ્ડ-પ્રેસ્ડ મગફળીનું તેલ', category: 'grocery', unit: '1 L',
      desc: 'Cold-pressed, unrefined groundnut oil from local mills. A staple for everyday Gujarati cooking.',
      descGu: 'સ્થાનિક ઘાણીનું કોલ્ડ-પ્રેસ્ડ, અનરિફાઇન્ડ મગફળીનું તેલ. રોજિંદા ગુજરાતી રસોઈ માટે.',
      rating: 4.6, reviews: 89, art: 'oil', tone: 'amber', stock: 60, lowStock: 12,
      available: true, earnsCoins: true, allowCoins: false,
      variants: [
        { label: '1 L', price: 210, mrp: 240, unit: '1 L' },
        { label: '5 L', price: 999, mrp: 1100, unit: '5 L' }
      ], defaultVariant: 0
    },
    {
      id: 'fafda', name: 'Gujarati Fafda', nameGu: 'ગુજરાતી ફાફડા', category: 'home', unit: '500 g',
      desc: 'Crisp, hand-rolled Gujarati fafda made fresh in our home-industry kitchen. Best with papaya sambharo.',
      descGu: 'અમારા ગૃહ ઉદ્યોગના રસોડામાં તાજા બનેલા કડક ફાફડા. પપૈયાના સંભારો સાથે ઉત્તમ.',
      rating: 4.7, reviews: 74, art: 'fafda', tone: 'sand', stock: 35, lowStock: 10,
      available: true, earnsCoins: true, allowCoins: true,
      variants: [
        { label: '500 g', price: 120, mrp: 140, unit: '500 g' },
        { label: '1 kg', price: 230, mrp: 260, unit: '1 kg' }
      ], defaultVariant: 0
    },
    {
      id: 'facewash', name: 'Neem Face Wash', nameGu: 'નીમ ફેસ વોશ', category: 'cosmetic', unit: '100 ml',
      desc: 'Neem and tulsi face wash that keeps skin clear through Vadodara summers. Sulphate free.',
      descGu: 'નીમ અને તુલસી સાથેનું ફેસ વોશ. ઉનાળામાં ત્વચા સ્વચ્છ અને તાજી રાખે. સલ્ફેટ ફ્રી.',
      rating: 4.4, reviews: 67, art: 'facewash', tone: 'mint', stock: 4, lowStock: 6,
      available: true, earnsCoins: true, allowCoins: true,
      variants: [
        { label: '100 ml', price: 199, mrp: 249, unit: '100 ml' },
        { label: '150 ml', price: 279, mrp: 329, unit: '150 ml' }
      ], defaultVariant: 0
    },
    {
      id: 'coldcoffee', name: 'Cold Coffee Ice Cream 1L', nameGu: 'કોલ્ડ કોફી આઇસ્ક્રીમ 1L', category: 'icecream', unit: '1 L',
      desc: 'Roasted coffee folded into creamy ice cream. A tall-glass treat, straight from the freezer.',
      descGu: 'ભેળેલી કોફી અને ક્રીમી આઇસ્ક્રીમ. ફ્રીઝરમાંથી સીધું ઘરે માણો.',
      rating: 4.6, reviews: 53, art: 'icecream-tub', tone: 'lilac', stock: 18, lowStock: 6,
      available: true, earnsCoins: true, allowCoins: true,
      variants: [
        { label: '500 ml', price: 110, mrp: 120, unit: '500 ml' },
        { label: '1 L', price: 190, mrp: 210, unit: '1 L' }
      ], defaultVariant: 1
    },
    {
      id: 'bajra', name: 'Bajra Flour 1kg', nameGu: 'બાજરીનું લોટ 1 કિલો', category: 'grocery', unit: '1 kg',
      desc: 'Stone-ground bajra flour for soft rotlo and winter bhakri. Milled weekly.',
      descGu: 'માવઠા વિહોણું, પથ્થર પર દળેલું બાજરીનું લોટ. નરમ રોટલો અને શિયાળુ ભાખરી માટે.',
      rating: 4.5, reviews: 41, art: 'flour', tone: 'sand', stock: 42, lowStock: 10,
      available: true, earnsCoins: true, allowCoins: true,
      variants: [
        { label: '1 kg', price: 80, mrp: 90, unit: '1 kg' },
        { label: '5 kg', price: 390, mrp: 420, unit: '5 kg' }
      ], defaultVariant: 0
    }
  ];

  const coupons = [
    {
      code: 'FESTIVE50', desc: '₹50 off on orders above ₹999', type: 'flat', value: 50, min: 999,
      scope: 'all', active: true, starts: '2026-10-18', expires: '2026-10-31',
      uses: 12, maxUses: 500, worksWithCoins: true, firstOrderOnly: false
    },
    {
      code: 'DRYFRUIT10', desc: '10% off Dry Fruit · max ₹150', type: 'percent', value: 10, maxDiscount: 150, min: 499,
      scope: 'dry', active: true, starts: '2026-10-01', expires: '2026-11-15',
      uses: 34, maxUses: 300, worksWithCoins: true, firstOrderOnly: false
    },
    {
      code: 'WELCOME', desc: '₹30 off your first order', type: 'flat', value: 30, min: 199,
      scope: 'all', active: true, starts: '2026-08-01', expires: '2026-12-31',
      uses: 87, maxUses: 1000, worksWithCoins: true, firstOrderOnly: true
    },
    {
      code: 'SUMMER20', desc: '20% off Ice cream · max ₹200', type: 'percent', value: 20, maxDiscount: 200, min: 299,
      scope: 'icecream', active: true, starts: '2026-06-01', expires: '2026-09-30',
      uses: 41, maxUses: 400, worksWithCoins: true, firstOrderOnly: false
    }
  ];

  const coinRules = [
    {
      id: 'standard', name: 'Standard rule', spend: 1000, coins: 10, mode: 'pro-rata',
      scope: 'All items', active: true, starts: '', expires: '', everGreen: true
    },
    {
      id: 'diwali', name: 'Diwali bonus', spend: 2000, coins: 30, mode: 'slab',
      scope: 'All items', active: true, starts: '2026-11-01', expires: '2026-11-05', everGreen: false
    }
  ];

  const coinSettings = { coinValue: 1, maxPercent: 100, expiryMonths: 12 };

  const hotSale = {
    live: true,
    eyebrow: 'HOT SALE · TODAY ONLY',
    title: 'Up to 30% off on Dry Fruit',
    starts: '2026-10-24',
    ends: '2026-10-26',
    featured: ['almonds', 'pickle', 'cream', 'cashew']
  };

  const addresses = [
    { id: 'home', label: 'Home', detail: '12, Shree Residency, Alkapuri, Vadodara 390007', phone: '97140 12345' },
    { id: 'shop', label: 'Shop', detail: 'Shop 4, Surya Complex, Race Course Road, Vadodara 390007', phone: '97140 12345' }
  ];

  const now = new Date();
  const isoMinsAgo = (mins) => new Date(now.getTime() - mins * 60000).toISOString();
  const isoDaysAgo = (days, hour, minute) => {
    const d = new Date(now);
    d.setDate(d.getDate() - days);
    if (hour != null) d.setHours(hour, minute || 0, 0, 0);
    return d.toISOString();
  };

  function snapshotItems(list) {
    return list.map((it) => {
      const p = products.find((x) => x.id === it.id);
      const vi = it.variantIndex != null ? it.variantIndex : p.defaultVariant;
      const v = p.variants[vi];
      return {
        productId: p.id, variantIndex: vi, name: p.name, nameGu: p.nameGu, unit: v.unit, price: v.price,
        qty: it.qty, earnsCoins: p.earnsCoins, allowCoins: p.allowCoins, art: p.art, tone: p.tone
      };
    });
  }

  function buildOrder(def) {
    const items = snapshotItems(def.items);
    const subtotal = items.reduce((sum, it) => sum + it.price * it.qty, 0);
    const coupon = def.coupon ? coupons.find((c) => c.code === def.coupon) : null;
    let couponDiscount = 0;
    if (coupon) {
      couponDiscount = coupon.type === 'flat' ? coupon.value : Math.min(Math.round(subtotal * coupon.value / 100), coupon.maxDiscount || 99999);
    }
    const coinsUsed = def.coinsUsed || 0;
    const total = Math.max(0, subtotal - couponDiscount - coinsUsed);
    const earnBase = items.filter((it) => it.earnsCoins).reduce((sum, it) => sum + it.price * it.qty, 0);
    const coinsEarned = subtotal ? Math.floor((earnBase / subtotal) * total / 1000 * 10) : 0;
    const history = def.timeline.map(([status, mins]) => ({ status, at: isoMinsAgo(mins) }));
    return {
      number: def.number,
      customer: def.customer,
      phone: def.phone,
      customerEmail: '',
      items,
      mode: def.mode,
      address: def.address || (def.mode === 'delivery' ? addresses[0].detail : 'Vijay Super Mall, Alkapuri Main Road, Vadodara'),
      slot: def.slot || (def.mode === 'pickup' ? 'Today · 6:00 – 8:00 PM' : ''),
      payment: def.payment,
      paymentState: def.paymentState || 'Pending',
      status: def.timeline[def.timeline.length - 1][0],
      statusHistory: history,
      placedAt: history[0].at,
      updatedAt: history[history.length - 1].at,
      bill: {
        subtotal,
        couponCode: coupon ? coupon.code : '',
        couponDiscount,
        coinsUsed,
        delivery: 0,
        total
      },
      coinsUsed,
      coinsEarned,
      coinRule: 'Standard rule',
      cancelReason: def.cancelReason || '',
      partner: def.partner || null,
      stockReserved: !!def.stockReserved,
      createdBy: def.createdBy || 'seed'
    };
  }

  const orders = [
    buildOrder({
      number: 'VSM-1043', customer: 'Hetal P.', phone: '97140 22118', mode: 'delivery',
      items: [{ id: 'almonds', qty: 1, variantIndex: 0 }, { id: 'cashew', qty: 1 }],
      payment: 'Cash on delivery', paymentState: 'Pending', timeline: [['Placed', 7]],
      address: '7, Nilkanth Society, Akota, Vadodara 390020', createdBy: 'seed', stockReserved: false
    }),
    buildOrder({
      number: 'VSM-1042', customer: 'Mahipal H.', phone: '97140 12345', mode: 'delivery',
      items: [
        { id: 'almonds', qty: 1, variantIndex: 1 }, { id: 'rice', qty: 1, variantIndex: 1 },
        { id: 'kulfi', qty: 1, variantIndex: 1 }, { id: 'pickle', qty: 1 }
      ],
      coupon: 'FESTIVE50', coinsUsed: 120, payment: 'Cash on delivery', paymentState: 'Pending',
      timeline: [['Placed', 26]], address: '12, Shree Residency, Alkapuri, Vadodara 390007', createdBy: 'seed'
    }),
    buildOrder({
      number: 'VSM-1041', customer: 'Kavita S.', phone: '98795 44110', mode: 'pickup',
      items: [{ id: 'cream', qty: 1 }, { id: 'facewash', qty: 1 }],
      coinsUsed: 10, payment: 'Pay at store', paymentState: 'Pending',
      timeline: [['Placed', 48], ['Confirmed', 44]], stockReserved: true
    }),
    buildOrder({
      number: 'VSM-1040', customer: 'Rajesh P.', phone: '98240 77231', mode: 'delivery',
      items: [
        { id: 'rice', qty: 2, variantIndex: 1 }, { id: 'cashew', qty: 1 }, { id: 'almonds', qty: 1, variantIndex: 1 },
        { id: 'oil', qty: 1 }, { id: 'tea', qty: 1 }, { id: 'fafda', qty: 1 }
      ],
      coupon: 'FESTIVE50', coinsUsed: 33, payment: 'Cash on delivery', paymentState: 'Pending',
      timeline: [['Placed', 82], ['Confirmed', 78], ['Packed', 56]], stockReserved: true
    }),
    buildOrder({
      number: 'VSM-1039', customer: 'Nirali D.', phone: '90999 88320', mode: 'pickup',
      items: [{ id: 'rice', qty: 1, variantIndex: 1 }, { id: 'bajra', qty: 1 }, { id: 'fafda', qty: 1 }],
      coinsUsed: 70, payment: 'Pay at store', paymentState: 'Pending',
      timeline: [['Placed', 96], ['Confirmed', 90], ['Packed', 70]], stockReserved: true
    }),
    buildOrder({
      number: 'VSM-1038', customer: 'Kiran P.', phone: '98790 66217', mode: 'delivery',
      items: [{ id: 'rice', qty: 1, variantIndex: 1 }, { id: 'almonds', qty: 1, variantIndex: 1 }],
      coupon: 'FESTIVE50', coinsUsed: 114, payment: 'UPI / Card', paymentState: 'Paid',
      timeline: [['Placed', 140], ['Confirmed', 135], ['Packed', 110], ['Out for Delivery', 85]],
      partner: { name: 'Ramesh', role: 'Vijay Super Mall rider', phone: '98250 11223' }, stockReserved: true
    }),
    buildOrder({
      number: 'VSM-1037', customer: 'Jignesh M.', phone: '95370 44102', mode: 'pickup',
      items: [
        { id: 'rice', qty: 2, variantIndex: 1 }, { id: 'cashew', qty: 1 }, { id: 'cream', qty: 1 }
      ],
      coupon: 'FESTIVE50', coinsUsed: 128, payment: 'UPI / Card', paymentState: 'Paid',
      timeline: [['Placed', 180], ['Confirmed', 175], ['Packed', 150], ['Ready for Pickup', 120]], stockReserved: true
    }),
    buildOrder({
      number: 'VSM-1036', customer: 'Anjali T.', phone: '99980 31176', mode: 'delivery',
      items: [
        { id: 'almonds', qty: 2, variantIndex: 1 }, { id: 'rice', qty: 2, variantIndex: 1 }, { id: 'cream', qty: 1 }
      ],
      coupon: 'FESTIVE50', coinsUsed: 37, payment: 'Cash on delivery', paymentState: 'Paid',
      timeline: [['Placed', 240], ['Confirmed', 235], ['Packed', 210], ['Out for Delivery', 170], ['Delivered', 80]],
      partner: { name: 'Ramesh', role: 'Vijay Super Mall rider', phone: '98250 11223' }, stockReserved: true
    }),
    buildOrder({
      number: 'VSM-1035', customer: 'Paresh K.', phone: '97260 55408', mode: 'pickup',
      items: [{ id: 'rice', qty: 1, variantIndex: 1 }, { id: 'bajra', qty: 1 }, { id: 'fafda', qty: 1 }],
      coinsUsed: 85, payment: 'Pay at store', paymentState: 'Paid',
      timeline: [['Placed', 1560], ['Confirmed', 1550], ['Packed', 1530], ['Ready for Pickup', 1495], ['Picked Up', 1420]],
      stockReserved: true
    }),
    buildOrder({
      number: 'VSM-1034', customer: 'Mehul S.', phone: '98980 12764', mode: 'delivery',
      items: [{ id: 'kulfi', qty: 1, variantIndex: 1 }, { id: 'pickle', qty: 1 }],
      payment: 'UPI / Card', paymentState: 'Refunded',
      timeline: [['Placed', 1620], ['Cancelled', 1580]], cancelReason: 'Customer changed the order'
    })
  ];

  const ledger = [
    {
      id: 'lg-pending-1042', title: 'Order #VSM-1042', sub: 'Pending delivery', coins: 11,
      status: 'pending', type: 'earn', orderNumber: 'VSM-1042', date: isoMinsAgo(26)
    },
    {
      id: 'lg-redeem-1042', title: 'Redeemed on #VSM-1042', sub: 'Coins used at checkout', coins: -120,
      status: 'spent', type: 'spend', orderNumber: 'VSM-1042', date: isoMinsAgo(26)
    },
    {
      id: 'lg-festive', title: 'Festive bonus', sub: 'Diwali shopping bonus', coins: 176,
      status: 'credited', type: 'bonus', orderNumber: '', date: isoDaysAgo(9)
    },
    {
      id: 'lg-order-1031', title: 'Order #VSM-1031', sub: 'Coins credited', coins: 14,
      status: 'credited', type: 'earn', orderNumber: 'VSM-1031', date: isoDaysAgo(12)
    },
    {
      id: 'lg-welcome', title: 'Welcome bonus', sub: 'First order with Vijay Super Mall', coins: 50,
      status: 'credited', type: 'bonus', orderNumber: '', date: isoDaysAgo(22)
    }
  ];

  const stockMoves = [
    { id: 'stk-almonds-today', productId: 'almonds', productName: 'Premium Almonds', variantIndex: 1, variantLabel: '500 g', qty: 24, at: isoMinsAgo(190), note: 'Supplier purchase' },
    { id: 'stk-tea-today', productId: 'tea', productName: 'Kadak Masala Tea', variantIndex: 0, variantLabel: '250 g', qty: 30, at: isoMinsAgo(155), note: 'Supplier purchase' },
    { id: 'stk-kulfi-today', productId: 'kulfi', productName: 'Kulfi Ice Cream 1L', variantIndex: 1, variantLabel: '1 L', qty: 18, at: isoMinsAgo(125), note: 'Supplier purchase' },
    { id: 'stk-fafda-today', productId: 'fafda', productName: 'Gujarati Fafda', variantIndex: 0, variantLabel: '500 g', qty: 20, at: isoMinsAgo(85), note: 'Supplier purchase' },
    { id: 'stk-rice-1', productId: 'rice', productName: 'Basmati Rice 5kg', variantIndex: 1, variantLabel: '5 kg', qty: 18, at: isoDaysAgo(1, 9, 10), note: 'Supplier purchase' },
    { id: 'stk-cashew-1', productId: 'cashew', productName: 'Roasted Cashews', variantIndex: 0, variantLabel: '250 g', qty: 16, at: isoDaysAgo(1, 9, 40), note: 'Supplier purchase' },
    { id: 'stk-oil-1', productId: 'oil', productName: 'Cold-Pressed Groundnut Oil', variantIndex: 0, variantLabel: '1 L', qty: 24, at: isoDaysAgo(1, 10, 15), note: 'Supplier purchase' },
    { id: 'stk-pickle-1', productId: 'pickle', productName: 'Homemade Mango Pickle', variantIndex: 0, variantLabel: '400 g', qty: 12, at: isoDaysAgo(1, 11, 5), note: 'Supplier purchase' },
    { id: 'stk-cream-2', productId: 'cream', productName: 'Face Glow Cream', variantIndex: 0, variantLabel: '50 g', qty: 6, at: isoDaysAgo(2, 9, 20), note: 'Supplier purchase' },
    { id: 'stk-facewash-2', productId: 'facewash', productName: 'Neem Face Wash', variantIndex: 0, variantLabel: '100 ml', qty: 8, at: isoDaysAgo(2, 10, 0), note: 'Supplier purchase' },
    { id: 'stk-almonds-2', productId: 'almonds', productName: 'Premium Almonds', variantIndex: 0, variantLabel: '250 g', qty: 12, at: isoDaysAgo(2, 10, 35), note: 'Supplier purchase' },
    { id: 'stk-tea-2', productId: 'tea', productName: 'Kadak Masala Tea', variantIndex: 1, variantLabel: '500 g', qty: 18, at: isoDaysAgo(2, 11, 15), note: 'Supplier purchase' },
    { id: 'stk-kulfi-4', productId: 'kulfi', productName: 'Kulfi Ice Cream 1L', variantIndex: 0, variantLabel: '500 ml', qty: 20, at: isoDaysAgo(4, 9, 30), note: 'Supplier purchase' },
    { id: 'stk-cashew-4', productId: 'cashew', productName: 'Roasted Cashews', variantIndex: 1, variantLabel: '500 g', qty: 10, at: isoDaysAgo(4, 10, 10), note: 'Supplier purchase' },
    { id: 'stk-fafda-4', productId: 'fafda', productName: 'Gujarati Fafda', variantIndex: 1, variantLabel: '1 kg', qty: 12, at: isoDaysAgo(4, 10, 50), note: 'Supplier purchase' },
    { id: 'stk-rice-6', productId: 'rice', productName: 'Basmati Rice 5kg', variantIndex: 2, variantLabel: '10 kg', qty: 10, at: isoDaysAgo(6, 9, 15), note: 'Supplier purchase' },
    { id: 'stk-oil-6', productId: 'oil', productName: 'Cold-Pressed Groundnut Oil', variantIndex: 1, variantLabel: '5 L', qty: 8, at: isoDaysAgo(6, 9, 55), note: 'Supplier purchase' },
    { id: 'stk-pickle-6', productId: 'pickle', productName: 'Homemade Mango Pickle', variantIndex: 1, variantLabel: '1 kg', qty: 6, at: isoDaysAgo(6, 10, 40), note: 'Supplier purchase' }
  ];

  const weekSales = [
    { day: 'M', amount: 8200 }, { day: 'T', amount: 11200 }, { day: 'W', amount: 7600 },
    { day: 'T', amount: 13800 }, { day: 'F', amount: 10200 }, { day: 'S', amount: 15600 }, { day: 'S', amount: 9100 }
  ];

  const store = {
    name: 'Vijay Super Mall',
    nameGu: 'વિજય સુપર મોલ',
    phone: '97140 00027',
    phoneHref: '+919714000027',
    address: 'Vijay Super Mall, Alkapuri Main Road, Vadodara 390007',
    promise: 'Free Home Delivery'
  };

  window.VSM_DATA = {
    categories, products, coupons, coinRules, coinSettings, hotSale, addresses,
    orders, ledger, stockMoves, weekSales, store, isoMinsAgo, isoDaysAgo
  };
})();
