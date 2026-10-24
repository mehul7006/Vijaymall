/* Vijay Super Mall — state, commerce rules and shared UI */
(function () {
  'use strict';

  const D = window.VSM_DATA;
  const I = window.VSM_ICONS;
  const appEl = document.getElementById('app');
  const STORAGE_KEY = 'vijay-super-mall-state-v1';
  const STATE_VERSION = 1;
  const clone = (v) => JSON.parse(JSON.stringify(v));
  const pad = (n) => String(n).padStart(2, '0');
  const nowISO = () => new Date().toISOString();
  const todayISO = () => {
    const d = new Date();
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  };
  const localDayKey = (value) => {
    const d = value instanceof Date ? value : new Date(value);
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  };

  function esc(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  function money(value) {
    const n = Math.round(Number(value) || 0);
    return '₹' + n.toLocaleString('en-IN');
  }

  function formatTime(iso) {
    if (!iso) return '';
    return new Date(iso).toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit' });
  }

  function formatDate(iso) {
    if (!iso) return '';
    const d = new Date(iso);
    return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
  }

  function whenLabel(iso) {
    if (!iso) return '';
    const mins = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 60000));
    if (mins < 2) return 'Just now';
    if (mins < 60) return `${mins} min ago`;
    if (mins < 1440) return `${Math.floor(mins / 60)} hr ago`;
    if (mins < 2880) return 'Yesterday';
    return formatDate(iso);
  }

  function timeOnly(iso) {
    return formatTime(iso);
  }

  function seedUserOrder() {
    const at = (days, h, m) => D.isoDaysAgo(days, h, m);
    const items = [
      { productId: 'rice', name: 'Basmati Rice 5kg', nameGu: 'બાસમતી ચોખા 5 કિલો', unit: '5 kg', price: 560, qty: 2, earnsCoins: true, allowCoins: true, art: 'rice', tone: 'lilac' },
      { productId: 'kulfi', name: 'Kulfi Ice Cream 1L', nameGu: 'કુલ્ફી આઇસ્ક્રીમ 1L', unit: '1 L', price: 180, qty: 1, earnsCoins: true, allowCoins: true, art: 'kulfi', tone: 'sky' },
      { productId: 'fafda', name: 'Gujarati Fafda', nameGu: 'ગુજરાતી ફાફડા', unit: '500 g', price: 120, qty: 1, earnsCoins: true, allowCoins: true, art: 'fafda', tone: 'sand' }
    ];
    const history = [
      { status: 'Placed', at: at(12, 18, 12) },
      { status: 'Confirmed', at: at(12, 18, 16) },
      { status: 'Packed', at: at(12, 18, 38) },
      { status: 'Out for Delivery', at: at(12, 18, 55) },
      { status: 'Delivered', at: at(12, 19, 20) }
    ];
    return {
      number: 'VSM-1031', customer: 'Mahipal Hada', phone: '97140 12345', customerEmail: 'mahipal.hada@email.com',
      items, mode: 'delivery',
      address: '12, Shree Residency, Alkapuri, Vadodara 390007', slot: '',
      payment: 'UPI / Card', paymentState: 'Paid', status: 'Delivered',
      statusHistory: history, placedAt: history[0].at, updatedAt: history[history.length - 1].at,
      bill: { subtotal: 1420, couponCode: '', couponDiscount: 0, coinsUsed: 0, delivery: 0, total: 1420 },
      coinsUsed: 0, coinsEarned: 14, coinRule: 'Standard rule', cancelReason: '',
      partner: { name: 'Ramesh', role: 'Vijay Super Mall rider', phone: '98250 11223' },
      stockReserved: false, createdBy: 'seed'
    };
  }

  function freshState() {
    return {
      version: STATE_VERSION,
      signedIn: false,
      lang: 'en',
      user: { name: 'Mahipal Hada', phone: '97140 12345', email: 'mahipal.hada@email.com', joined: '2025-11-02' },
      cart: {
        items: [
          { productId: 'almonds', variantIndex: 1, qty: 1 },
          { productId: 'rice', variantIndex: 1, qty: 1 },
          { productId: 'kulfi', variantIndex: 1, qty: 1 },
          { productId: 'pickle', variantIndex: 0, qty: 1 }
        ],
        coupon: 'FESTIVE50', useCoins: true, coinMode: 'all', coinPercent: 50, coinCustom: ''
      },
      categories: clone(D.categories),
      products: clone(D.products),
      orders: [seedUserOrder(), ...clone(D.orders)],
      coupons: clone(D.coupons),
      coinRules: clone(D.coinRules),
      coinSettings: clone(D.coinSettings),
      hotSale: clone(D.hotSale),
      ledger: clone(D.ledger),
      stockMoves: clone(D.stockMoves || []),
      weekSales: clone(D.weekSales),
      addresses: clone(D.addresses),
      selectedAddress: 'home',
      wishlist: [],
      settings: { notifications: true }
    };
  }

  let STATE;
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
    STATE = saved && saved.version === STATE_VERSION ? saved : freshState();
  } catch (err) {
    STATE = freshState();
  }

  function save() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(STATE)); } catch (err) { /* storage can be blocked */ }
  }

  const ui = {
    sheet: null,
    shop: { sort: 'popular', stock: false, coins: false },
    search: '',
    pdProduct: null,
    pdVariant: 0,
    pdQty: 1,
    checkoutMode: 'delivery',
    checkoutPayment: 'cod',
    selectedSlot: 'Today · 6:00 – 8:00 PM',
    showAllLedger: false,
    ordersFilter: 'all',
    adminOrderFilter: 'new',
    invCat: 'all',
    invQuery: '',
    reportPeriod: 'week',
    stockDay: todayISO(),
    stockShowAll: false,
    cancelReason: 'Changed my mind',
    stageTarget: '',
    couponFormOpen: false,
    lastScroll: 0
  };

  const T = (en, gu) => (STATE.lang === 'gu' ? gu : en);
  const pname = (p) => (STATE.lang === 'gu' ? p.nameGu || p.name : p.name);
  const pdesc = (p) => (STATE.lang === 'gu' ? p.descGu || p.desc : p.desc);
  const digits = (v) => String(v || '').replace(/\D/g, '').slice(-10);
  const initials = (name) => String(name || 'V').split(/\s+/).filter(Boolean).slice(0, 2).map((x) => x[0].toUpperCase()).join('');
  const productById = (id) => STATE.products.find((p) => p.id === id);
  const variantOf = (p, index) => p.variants[index] || p.variants[p.defaultVariant] || p.variants[0];
  const variantStock = (p, index) => Math.max(0, Math.round(Number(variantOf(p, index).stock) || 0));

  function syncProductStock(p) {
    p.stock = p.variants.reduce((sum, v) => sum + Math.max(0, Math.round(Number(v.stock) || 0)), 0);
    return p.stock;
  }

  function ensureCategories() {
    let changed = false;
    if (!Array.isArray(STATE.categories)) { STATE.categories = []; changed = true; }
    const ids = new Set(STATE.categories.map((c) => c.id));
    clone(D.categories).forEach((c) => {
      if (!ids.has(c.id)) { STATE.categories.push(c); changed = true; }
    });
    return changed;
  }

  function createCategory(name, nameGu) {
    const clean = String(name || '').trim().replace(/\s+/g, ' ');
    if (!clean) return null;
    if (STATE.categories.some((c) => c.name.toLowerCase() === clean.toLowerCase())) return null;
    const base = clean.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'type';
    let id = base;
    let n = 2;
    while (STATE.categories.some((c) => c.id === id)) {
      id = `${base}-${n}`;
      n += 1;
    }
    const tones = ['mint', 'peach', 'gold', 'rose', 'sky'];
    const cat = {
      id, name: clean, nameGu: String(nameGu || '').trim() || clean,
      icon: 'bag', tone: tones[STATE.categories.length % tones.length]
    };
    STATE.categories.push(cat);
    save();
    return cat;
  }

  function ensureStockMoves() {
    if (Array.isArray(STATE.stockMoves)) return false;
    STATE.stockMoves = clone(D.stockMoves || []);
    return true;
  }

  function logStockMove(p, variantIndex, qty, note) {
    const units = Math.max(0, Math.round(Number(qty) || 0));
    if (!p || !units) return;
    if (!Array.isArray(STATE.stockMoves)) STATE.stockMoves = [];
    const v = p.variants[variantIndex];
    STATE.stockMoves.unshift({
      id: `stk-${Date.now().toString(36)}-${STATE.stockMoves.length + 1}`,
      productId: p.id,
      productName: p.name,
      variantIndex,
      variantLabel: v ? v.label : '',
      qty: units,
      at: nowISO(),
      note: note || 'Supplier purchase'
    });
  }

  function ensureVariantStocks() {
    let changed = false;
    STATE.products.forEach((p) => {
      const missing = p.variants.some((v) => !Number.isFinite(v.stock));
      if (missing) {
        const total = Math.max(0, Math.round(Number(p.stock) || 0));
        const def = p.variants[p.defaultVariant] ? p.defaultVariant : 0;
        const others = p.variants.length - 1;
        const base = others > 0 ? Math.floor(total / 2) : total;
        const share = others > 0 ? Math.floor((total - base) / others) : 0;
        let rest = others > 0 ? total - base - share * others : 0;
        p.variants.forEach((v, i) => {
          if (i === def) {
            v.stock = base;
          } else {
            v.stock = share + (rest > 0 ? 1 : 0);
            if (rest > 0) rest -= 1;
          }
        });
        changed = true;
      }
      p.variants.forEach((v) => {
        if (v.stock !== Math.max(0, Math.round(Number(v.stock) || 0))) {
          v.stock = Math.max(0, Math.round(Number(v.stock) || 0));
          changed = true;
        }
      });
      const sum = p.variants.reduce((s, v) => s + v.stock, 0);
      if (p.stock !== sum) {
        p.stock = sum;
        changed = true;
      }
      if (p.stock === 0 && p.available) {
        p.available = false;
        changed = true;
      }
    });
    return changed;
  }

  function discountPct(v) {
    return v.mrp > v.price ? Math.round(((v.mrp - v.price) / v.mrp) * 100) : 0;
  }

  function cartDetails() {
    return STATE.cart.items.map((it) => {
      const p = productById(it.productId);
      if (!p) return null;
      const variantIndex = p.variants[it.variantIndex] ? it.variantIndex : p.defaultVariant;
      const v = variantOf(p, variantIndex);
      return { ...it, variantIndex, p, v, lineTotal: v.price * it.qty };
    }).filter(Boolean);
  }

  const cartCount = () => STATE.cart.items.reduce((sum, it) => sum + it.qty, 0);

  function userOrders() {
    const phone = digits(STATE.user.phone);
    return STATE.orders
      .filter((o) => digits(o.phone) === phone || o.customer === STATE.user.name)
      .sort((a, b) => new Date(b.placedAt) - new Date(a.placedAt));
  }

  const orderByNumber = (number) => STATE.orders.find((o) => o.number === number);

  function coinBalance() {
    return STATE.ledger.filter((l) => l.status !== 'pending').reduce((sum, l) => sum + l.coins, 0);
  }

  function coinPending() {
    return STATE.ledger.filter((l) => l.status === 'pending').reduce((sum, l) => sum + l.coins, 0);
  }

  function couponDateStatus(c) {
    const today = todayISO();
    if (!c.active) return 'inactive';
    if (c.starts && today < c.starts) return 'scheduled';
    if (c.expires && today > c.expires) return 'expired';
    return 'active';
  }

  function scopeCategories(scope) {
    if (scope === 'all') return STATE.products.map((p) => p.category).filter((v, i, a) => a.indexOf(v) === i);
    return [scope];
  }

  const scopeLabel = (scope) => {
    if (scope === 'all') return 'All items';
    const cat = STATE.categories.find((c) => c.id === scope);
    return cat ? cat.name : scope;
  };

  function couponCheck(code, details) {
    const items = details || cartDetails();
    const clean = String(code || '').trim().toUpperCase();
    const empty = { ok: false, discount: 0, message: 'Enter a coupon code.' };
    if (!clean) return empty;
    const coupon = STATE.coupons.find((c) => c.code === clean);
    if (!coupon) return { ok: false, discount: 0, message: 'That coupon code is not valid.' };
    const status = couponDateStatus(coupon);
    if (status === 'inactive') return { ok: false, discount: 0, coupon, message: 'This coupon is currently paused.' };
    if (status === 'expired') return { ok: false, discount: 0, coupon, message: 'This coupon has expired.' };
    if (status === 'scheduled') return { ok: false, discount: 0, coupon, message: `This coupon starts on ${formatDate(coupon.starts)}.` };
    if (coupon.uses >= coupon.maxUses) return { ok: false, discount: 0, coupon, message: 'This coupon has reached its usage limit.' };
    if (coupon.firstOrderOnly) {
      const prior = STATE.orders.filter((o) => (digits(o.phone) === digits(STATE.user.phone) || o.customer === STATE.user.name) && o.status !== 'Cancelled');
      if (prior.length) return { ok: false, discount: 0, coupon, message: 'This coupon is valid on your first order only.' };
    }
    const subtotal = items.reduce((sum, it) => sum + it.lineTotal, 0);
    if (!items.length) return { ok: false, discount: 0, coupon, message: 'Add items to apply a coupon.' };
    const scopeBase = items
      .filter((it) => coupon.scope === 'all' || it.p.category === coupon.scope)
      .reduce((sum, it) => sum + it.lineTotal, 0);
    if (!scopeBase) return { ok: false, discount: 0, coupon, message: `This coupon only works on ${scopeLabel(coupon.scope)}.` };
    if (subtotal < coupon.min) {
      return { ok: false, discount: 0, coupon, message: `Add ${money(coupon.min - subtotal)} more to use this coupon.` };
    }
    let discount = coupon.type === 'flat'
      ? Math.min(coupon.value, scopeBase)
      : Math.round((scopeBase * coupon.value) / 100);
    if (coupon.maxDiscount) discount = Math.min(discount, coupon.maxDiscount);
    return { ok: true, discount, coupon, scopeBase, message: `Coupon applied. You saved ${money(discount)}.` };
  }

  function ruleWindowStatus(rule) {
    if (!rule.active) return 'inactive';
    if (rule.everGreen) return 'active';
    const today = todayISO();
    if (rule.starts && today < rule.starts) return 'scheduled';
    if (rule.expires && today > rule.expires) return 'expired';
    return 'active';
  }

  function ruleCoins(rule, amount) {
    if (!rule || !rule.spend) return 0;
    return rule.mode === 'slab'
      ? Math.floor(amount / rule.spend) * rule.coins
      : Math.floor((amount / rule.spend) * rule.coins);
  }

  function bestEarnRule(amount) {
    let best = { rule: null, coins: 0 };
    STATE.coinRules.forEach((rule) => {
      if (ruleWindowStatus(rule) !== 'active') return;
      const coins = ruleCoins(rule, amount);
      if (coins > best.coins) best = { rule, coins };
    });
    if (!best.rule) {
      const standard = STATE.coinRules.find((r) => r.id === 'standard') || STATE.coinRules[0];
      best = { rule: standard, coins: 0 };
    }
    return best;
  }

  function cartTotals() {
    const details = cartDetails();
    const subtotal = details.reduce((sum, it) => sum + it.lineTotal, 0);
    const coupon = STATE.cart.coupon ? couponCheck(STATE.cart.coupon, details) : null;
    const couponOk = !!(coupon && coupon.ok);
    const discount = couponOk ? Math.min(coupon.discount, subtotal) : 0;
    const payable = Math.max(0, subtotal - discount);
    const coinValue = Number(STATE.coinSettings.coinValue) || 1;
    const balance = coinBalance();
    const eligibleRaw = details.filter((it) => it.p.allowCoins).reduce((sum, it) => sum + it.lineTotal, 0);
    const eligibleBase = subtotal > 0 ? eligibleRaw * (payable / subtotal) : 0;
    const cap = Math.max(0, Math.floor((eligibleBase * (Number(STATE.coinSettings.maxPercent) || 100)) / 100));
    const canUse = !couponOk || coupon.coupon.worksWithCoins;
    let desired = 0;
    if (STATE.cart.useCoins && canUse && eligibleRaw > 0) {
      if (STATE.cart.coinMode === 'all') desired = balance;
      else if (STATE.cart.coinMode === 'percent') desired = Math.floor((balance * (Number(STATE.cart.coinPercent) || 0)) / 100);
      else desired = parseInt(STATE.cart.coinCustom, 10) || 0;
    }
    const coinsUsed = Math.max(0, Math.min(desired, balance, cap));
    const coinDiscount = coinsUsed * coinValue;
    const total = Math.max(0, subtotal - discount - coinDiscount);
    const earnRaw = details.filter((it) => it.p.earnsCoins).reduce((sum, it) => sum + it.lineTotal, 0);
    const earnRatio = subtotal > 0 ? earnRaw / subtotal : 0;
    const earn = bestEarnRule(total * earnRatio);
    return {
      details, subtotal, coupon, couponOk, discount, payable, eligibleRaw, eligibleBase, cap,
      balance, coinValue, coinsUsed, coinDiscount, total, earnRatio,
      coinsEarned: earn.coins, earnRule: earn.rule, canUseCoins: canUse
    };
  }

  function orderTotals(order) {
    return {
      subtotal: order.bill.subtotal,
      couponCode: order.bill.couponCode,
      discount: order.bill.couponDiscount,
      coinsUsed: order.coinsUsed,
      coinDiscount: order.coinsUsed * (Number(STATE.coinSettings.coinValue) || 1),
      total: order.bill.total,
      coinsEarned: order.coinsEarned,
      earnRule: { name: order.coinRule }
    };
  }

  const activeStatuses = ['Placed', 'Confirmed', 'Packed', 'Ready for Pickup', 'Out for Delivery'];
  const isActiveOrder = (order) => activeStatuses.indexOf(order.status) !== -1;

  const statusClass = (status) => ({
    'Placed': 'placed', 'Confirmed': 'confirmed', 'Packed': 'packed',
    'Ready for Pickup': 'ready', 'Out for Delivery': 'out',
    'Delivered': 'done', 'Picked Up': 'done', 'Cancelled': 'cancelled'
  }[status] || 'grey');

  const statusLabel = (status) => ({
    'Placed': 'Placed', 'Confirmed': 'Confirmed', 'Packed': 'Packed',
    'Ready for Pickup': 'Ready for pickup', 'Out for Delivery': 'Out for delivery',
    'Delivered': 'Delivered', 'Picked Up': 'Picked up', 'Cancelled': 'Cancelled'
  }[status] || status);

  const CUSTOMER_STATUS_GU = {
    'Placed': 'પ્લેસ થયો', 'Confirmed': 'કન્ફર્મ', 'Packed': 'પેક થયો',
    'Ready for Pickup': 'પિકઅપ માટે તૈયાર', 'Out for Delivery': 'ડિલિવરી માટે નીકળ્યો',
    'Delivered': 'પહોંચાડાયો', 'Picked Up': 'લઈ લીધો', 'Cancelled': 'રદ'
  };
  const cStatus = (status) => (STATE.lang === 'gu' ? CUSTOMER_STATUS_GU[status] || status : statusLabel(status));
  const customerStatusPill = (status) => `<span class="pill pill--${statusClass(status)}">${esc(cStatus(status))}</span>`;

  const PAY_STATE_GU = { Paid: 'ચૂકવાયું', Pending: 'બાકી', Refunded: 'પરત મળ્યું' };
  function customerPayPill(state) {
    const cls = state === 'Paid' ? 'done' : state === 'Refunded' ? 'cancelled' : 'gold';
    const label = STATE.lang === 'gu' ? PAY_STATE_GU[state] || state : state;
    return `<span class="pill pill--${cls}">${esc(label)}</span>`;
  }

  const CANCEL_REASON_GU = {
    'Changed my mind': 'મન બદલાઈ ગયું',
    'Ordered by mistake': 'ભૂલથી ઓર્ડર કર્યો',
    'Need a different address': 'બીજું સરનામું જોઈએ',
    'Found a better price': 'વધુ સારી કિંમત મળી'
  };
  const reasonLabel = (reason) => (STATE.lang === 'gu' ? CANCEL_REASON_GU[reason] || reason : reason);
  const paymentName = (payment) => {
    if (STATE.lang !== 'gu') return payment;
    return { 'UPI / Card': 'UPI / કાર્ડ', 'Cash on delivery': 'ડિલિવરી પર રોકડ', 'Pay at store': 'દુકાન પર ચૂકવો' }[payment] || payment;
  };
  const categoryLabel = (category) => {
    const en = { grocery: 'Grocery', home: 'Home industry', dry: 'Dry fruit', cosmetic: 'Cosmetics', icecream: 'Ice cream' }[category] || category;
    const gu = { grocery: 'કરિયાણું', home: 'ગૃહ ઉદ્યોગ', dry: 'સૂકો ફળ', cosmetic: 'કોસ્મેટિક', icecream: 'આઇસ્ક્રીમ' }[category] || category;
    return T(en, gu);
  };

  function orderSteps(order) {
    return order.mode === 'pickup'
      ? ['Placed', 'Confirmed', 'Packed', 'Ready for Pickup', 'Picked Up']
      : ['Placed', 'Confirmed', 'Packed', 'Out for Delivery', 'Delivered'];
  }

  function currentStepIndex(order) {
    if (order.status === 'Cancelled') return -1;
    const steps = orderSteps(order);
    const idx = steps.indexOf(order.status);
    return idx === -1 ? 0 : idx;
  }

  function stepTime(order, status) {
    const entry = order.statusHistory.find((h) => h.status === status);
    return entry ? entry.at : '';
  }

  function nextStatus(order) {
    if (order.status === 'Placed') return 'Confirmed';
    if (order.status === 'Confirmed') return 'Packed';
    if (order.status === 'Packed') return order.mode === 'pickup' ? 'Ready for Pickup' : 'Out for Delivery';
    if (order.status === 'Out for Delivery') return 'Delivered';
    if (order.status === 'Ready for Pickup') return 'Picked Up';
    return '';
  }

  function primaryAction(order) {
    const next = nextStatus(order);
    if (!next) return null;
    const labels = {
      'Confirmed': 'Confirm order',
      'Packed': 'Mark as packed',
      'Out for Delivery': 'Send out for delivery',
      'Ready for Pickup': 'Mark ready for pickup',
      'Delivered': 'Mark delivered',
      'Picked Up': 'Mark picked up'
    };
    return { next, label: labels[next] || `Move to ${next}`, short: { 'Confirmed': 'Confirm', 'Packed': 'Pack', 'Out for Delivery': 'Dispatch', 'Ready for Pickup': 'Ready', 'Delivered': 'Deliver', 'Picked Up': 'Picked up' }[next] || next };
  }

  function orderEta(order, localized = true) {
    const L = localized ? T : (en) => en;
    if (order.status === 'Cancelled') {
      if (!localized) return order.cancelReason || 'This order was cancelled.';
      return reasonLabel(order.cancelReason) || T('Cancelled by the store', 'દુકાને ઓર્ડર રદ કર્યો');
    }
    if (order.mode === 'pickup') {
      return {
        'Placed': L('Store will confirm within 15 minutes', 'દુકાન 15 મિનિટમાં કન્ફર્મ કરશે'),
        'Confirmed': L('Your order is being packed', 'તમારો ઓર્ડર પેક થઈ રહ્યો છે'),
        'Packed': L('Almost ready for pickup', 'પિકઅપ માટે લગભગ તૈયાર'),
        'Ready for Pickup': L('Collect from the store today', 'આજે દુકાનમાંથી લઈ જાઓ'),
        'Picked Up': L(`Picked up · ${timeOnly(order.updatedAt)}`, `લઈ લીધો · ${timeOnly(order.updatedAt)}`)
      }[order.status] || '';
    }
    return {
      'Placed': L('Delivering today by 8:00 PM', 'આજે 8:00 વાગ્યા સુધી ડિલિવરી'),
      'Confirmed': L('Store is packing your order', 'દુકાન તમારો ઓર્ડર પેક કરી રહી છે'),
      'Packed': L('Rider will pick up shortly', 'રાઇડર થોડી વારમાં લેશે'),
      'Out for Delivery': L('Arriving in 15 – 25 minutes', '15 – 25 મિનિટમાં પહોંચશે'),
      'Delivered': L(`Delivered · ${timeOnly(order.updatedAt)}`, `પહોંચાડાયો · ${timeOnly(order.updatedAt)}`)
    }[order.status] || '';
  }

  function nextOrderNumber() {
    const max = STATE.orders.reduce((m, o) => {
      const n = parseInt(String(o.number).replace(/\D/g, ''), 10);
      return Number.isFinite(n) ? Math.max(m, n) : m;
    }, 1000);
    return `VSM-${max + 1}`;
  }

  function reserveStock(details) {
    details.forEach((it) => {
      const p = it.p;
      const vi = p.variants[it.variantIndex] ? it.variantIndex : p.defaultVariant;
      const v = p.variants[vi];
      if (!v) return;
      v.stock = Math.max(0, variantStock(p, vi) - it.qty);
      if (syncProductStock(p) === 0) p.available = false;
    });
  }

  function restoreStock(order) {
    order.items.forEach((it) => {
      const p = productById(it.productId);
      if (!p) return;
      let vi = Number.isInteger(it.variantIndex) && p.variants[it.variantIndex] ? it.variantIndex : -1;
      if (vi < 0) vi = p.variants.findIndex((v) => v.unit === it.unit);
      if (vi < 0) vi = p.defaultVariant;
      const v = p.variants[vi];
      if (!v) return;
      v.stock = variantStock(p, vi) + it.qty;
      if (syncProductStock(p) > 0) p.available = true;
    });
  }

  function creditOrderCoins(order) {
    const pending = STATE.ledger.find((l) => l.orderNumber === order.number && l.status === 'pending');
    if (pending) {
      pending.status = 'credited';
      pending.sub = 'Coins credited';
      return true;
    }
    if (order.coinsEarned > 0 && digits(order.phone) === digits(STATE.user.phone)) {
      STATE.ledger.unshift({
        id: `lg-earn-${order.number}`, title: `Order #${order.number}`, sub: 'Coins credited',
        coins: order.coinsEarned, status: 'credited', type: 'earn', orderNumber: order.number, date: nowISO()
      });
      return true;
    }
    return false;
  }

  function advanceOrder(number) {
    const order = orderByNumber(number);
    if (!order) return;
    const action = primaryAction(order);
    if (!action) return;
    order.status = action.next;
    order.updatedAt = nowISO();
    order.statusHistory.push({ status: action.next, at: order.updatedAt });
    if (action.next === 'Out for Delivery' && !order.partner) {
      order.partner = { name: 'Ramesh', role: 'Vijay Super Mall rider', phone: '98250 11223' };
    }
    if (action.next === 'Delivered' || action.next === 'Picked Up') {
      order.paymentState = 'Paid';
      const credited = creditOrderCoins(order);
      save();
      render(true);
      showToast(credited ? `Order ${action.next.toLowerCase()} · ${order.coinsEarned} coins credited` : `Order ${order.number} marked ${action.next.toLowerCase()}`, 'success');
      return;
    }
    save();
    render(true);
    showToast(`Order ${order.number} moved to ${statusLabel(action.next)}`, 'success');
  }

  function reverseOrderCoins(order) {
    const credit = STATE.ledger.find((l) => l.orderNumber === order.number && l.type === 'earn' && l.status === 'credited');
    if (!credit) return false;
    credit.status = 'pending';
    credit.sub = 'Pending delivery';
    return true;
  }

  function changeOrderStage(number, target) {
    const order = orderByNumber(number);
    if (!order || order.status === 'Cancelled' || target === order.status) return;
    const steps = orderSteps(order);
    const fromIdx = steps.indexOf(order.status);
    const toIdx = steps.indexOf(target);
    if (toIdx === -1) return;
    const wasFinal = ['Delivered', 'Picked Up'].indexOf(order.status) !== -1;
    const nowFinal = ['Delivered', 'Picked Up'].indexOf(target) !== -1;
    const movingBack = toIdx < fromIdx;
    const wasPaid = order.paymentState === 'Paid';
    let detail = '';
    order.status = target;
    order.updatedAt = nowISO();
    order.statusHistory.push({ status: target, at: order.updatedAt, note: 'Stage changed by owner' });
    if (nowFinal) {
      order.paymentState = 'Paid';
      if (!wasPaid) detail = ' · payment marked paid';
      if (order.coinsEarned && creditOrderCoins(order)) detail += ` · ${order.coinsEarned} coins credited`;
    } else if (wasFinal) {
      if (order.payment !== 'UPI / Card' && order.paymentState === 'Paid') {
        order.paymentState = 'Pending';
        detail = ' · cash payment marked pending';
      }
      if (order.coinsEarned && reverseOrderCoins(order)) detail += ` · ${order.coinsEarned} coins returned to pending`;
    }
    if (order.mode === 'delivery') {
      if (toIdx >= steps.indexOf('Out for Delivery')) {
        if (!order.partner) order.partner = { name: 'Ramesh', role: 'Vijay Super Mall rider', phone: '98250 11223' };
      } else {
        order.partner = null;
      }
    }
    save();
    render(true);
    showToast(`Order ${order.number} ${movingBack ? 'moved back' : 'moved'} to ${statusLabel(target)}${detail}`, 'success');
  }

  function orderStageEffect(order, target) {
    const steps = orderSteps(order);
    const fromIdx = currentStepIndex(order);
    const toIdx = steps.indexOf(target);
    if (toIdx === -1 || toIdx === fromIdx) return '';
    const wasFinal = ['Delivered', 'Picked Up'].indexOf(order.status) !== -1;
    const nowFinal = ['Delivered', 'Picked Up'].indexOf(target) !== -1;
    const bits = [toIdx < fromIdx
      ? `This moves the order back to ${statusLabel(target)}; later stages will show as pending again.`
      : `This jumps the order forward to ${statusLabel(target)}.`];
    if (nowFinal && !wasFinal) {
      bits.push(`The payment will be marked paid${order.coinsEarned ? ` and ${order.coinsEarned} coins will be credited` : ''}.`);
    }
    if (wasFinal && !nowFinal) {
      if (order.coinsEarned) bits.push(`${order.coinsEarned} credited coins will return to pending.`);
      if (order.payment === 'UPI / Card') bits.push('The prepaid payment stays marked paid.');
      else if (order.paymentState === 'Paid') bits.push('The cash payment will be marked pending.');
    }
    if (order.mode === 'delivery') {
      const dispatchIdx = steps.indexOf('Out for Delivery');
      if (fromIdx < dispatchIdx && toIdx >= dispatchIdx) bits.push('Ramesh will be assigned as the rider.');
      if (fromIdx >= dispatchIdx && toIdx < dispatchIdx) bits.push('The rider assignment will be removed.');
    }
    bits.push('Stock stays unchanged.');
    return bits.join(' ');
  }

  function cancelOrder(number, reason, by) {
    const order = orderByNumber(number);
    if (!order) return;
    if (['Delivered', 'Picked Up', 'Cancelled'].indexOf(order.status) !== -1) return;
    if (by === 'customer' && order.status !== 'Placed') return;
    order.status = 'Cancelled';
    order.cancelReason = reason || 'Cancelled';
    order.updatedAt = nowISO();
    order.statusHistory.push({ status: 'Cancelled', at: order.updatedAt });
    if (order.paymentState === 'Paid' && order.payment === 'UPI / Card') order.paymentState = 'Refunded';
    if (order.stockReserved) {
      restoreStock(order);
      order.stockReserved = false;
    }
    STATE.ledger = STATE.ledger.filter((l) => !(l.orderNumber === order.number && l.status === 'pending'));
    if (order.coinsUsed > 0) {
      STATE.ledger.unshift({
        id: `lg-refund-${order.number}-${Date.now()}`, title: 'Coins returned',
        sub: `Order #${order.number} cancelled`, coins: order.coinsUsed,
        status: 'credited', type: 'refund', orderNumber: order.number, date: nowISO()
      });
    }
    const coupon = STATE.coupons.find((c) => c.code === order.bill.couponCode);
    if (coupon && coupon.uses > 0) coupon.uses -= 1;
    save();
    render(true);
    showToast(`Order ${order.number} cancelled${order.coinsUsed ? ` · ${order.coinsUsed} coins returned` : ''}`, 'success');
  }

  function addToCart(productId, variantIndex, qty) {
    const p = productById(productId);
    if (!p) return;
    if (!p.available || p.stock <= 0) {
      showToast('This item is out of stock', 'error');
      return;
    }
    const vi = p.variants[variantIndex] ? variantIndex : p.defaultVariant;
    const pack = variantOf(p, vi);
    const available = variantStock(p, vi);
    if (available <= 0) {
      showToast(`${pack.label} is out of stock`, 'error');
      return;
    }
    const amount = qty || 1;
    const existing = STATE.cart.items.find((it) => it.productId === productId && it.variantIndex === vi);
    const already = existing ? existing.qty : 0;
    if (already + amount > available) {
      showToast(`Only ${available} left of ${pack.label}`, 'error');
      return;
    }
    if (existing) existing.qty += amount;
    else STATE.cart.items.push({ productId, variantIndex: vi, qty: amount });
    save();
    render(true);
    showToast(`${T('Added to cart', 'કાર્ટમાં ઉમેર્યું')} · ${pname(p)}`, 'success');
  }

  function setQty(index, delta) {
    const it = STATE.cart.items[index];
    if (!it) return;
    const p = productById(it.productId);
    const next = it.qty + delta;
    if (next <= 0) {
      STATE.cart.items.splice(index, 1);
    } else {
      const available = p ? variantStock(p, it.variantIndex) : 0;
      if (p && next > available) {
        showToast(`Only ${available} left in this pack`, 'error');
        return;
      }
      it.qty = next;
    }
    save();
    render(true);
  }

  function reorder(number) {
    const order = orderByNumber(number);
    if (!order) return;
    let added = 0;
    order.items.forEach((it) => {
      const p = productById(it.productId);
      if (!p || !p.available || p.stock <= 0) return;
      let vi = p.variants.findIndex((v) => v.unit === it.unit);
      if (vi < 0) vi = p.defaultVariant;
      const available = variantStock(p, vi);
      if (available <= 0) return;
      const existing = STATE.cart.items.find((c) => c.productId === p.id && c.variantIndex === vi);
      const qty = Math.min(it.qty, available - (existing ? existing.qty : 0));
      if (qty <= 0) return;
      if (existing) existing.qty += qty;
      else STATE.cart.items.push({ productId: p.id, variantIndex: vi, qty });
      added += qty;
    });
    if (!added) {
      showToast('Those items are not available right now', 'error');
      return;
    }
    STATE.cart.coupon = '';
    STATE.cart.useCoins = false;
    save();
    go('#/cart');
    showToast(`${added} item${added > 1 ? 's' : ''} added back to cart`, 'success');
  }

  function placeOrder() {
    const totals = cartTotals();
    if (!totals.details.length) {
      showToast('Your cart is empty', 'error');
      return;
    }
    const short = totals.details.find((it) => !it.p.available || it.qty > variantStock(it.p, it.variantIndex));
    if (short) {
      showToast(`${short.p.name} · ${short.v.unit} only has ${variantStock(short.p, short.variantIndex)} left`, 'error');
      return;
    }
    const mode = ui.checkoutMode;
    let pay = ui.checkoutPayment;
    if (mode === 'pickup' && pay === 'cod') pay = 'store';
    const payLabel = pay === 'upi' ? 'UPI / Card' : pay === 'store' ? 'Pay at store' : 'Cash on delivery';
    const payState = pay === 'upi' ? 'Paid' : 'Pending';
    const chosen = STATE.addresses.find((a) => a.id === STATE.selectedAddress) || STATE.addresses[0];
    const now = nowISO();
    const number = nextOrderNumber();
    reserveStock(totals.details);
    const order = {
      number, customer: STATE.user.name, phone: STATE.user.phone, customerEmail: STATE.user.email,
      items: totals.details.map((it) => ({
        productId: it.p.id, variantIndex: it.variantIndex, name: it.p.name, nameGu: it.p.nameGu, unit: it.v.unit,
        price: it.v.price, qty: it.qty, earnsCoins: it.p.earnsCoins, allowCoins: it.p.allowCoins,
        art: it.p.art, tone: it.p.tone
      })),
      mode,
      address: mode === 'delivery' ? chosen.detail : D.store.address,
      slot: mode === 'pickup' ? ui.selectedSlot : '',
      payment: payLabel, paymentState: payState, status: 'Placed',
      statusHistory: [{ status: 'Placed', at: now }],
      placedAt: now, updatedAt: now,
      bill: {
        subtotal: totals.subtotal,
        couponCode: totals.couponOk ? totals.coupon.coupon.code : '',
        couponDiscount: totals.discount,
        coinsUsed: totals.coinsUsed,
        delivery: 0,
        total: totals.total
      },
      coinsUsed: totals.coinsUsed,
      coinsEarned: totals.coinsEarned,
      coinRule: totals.earnRule ? totals.earnRule.name : 'Standard rule',
      cancelReason: '', partner: null, stockReserved: true, createdBy: 'customer'
    };
    STATE.orders.unshift(order);
    if (totals.coinsUsed > 0) {
      STATE.ledger.unshift({
        id: `lg-redeem-${number}`, title: `Redeemed on #${number}`, sub: 'Coins used at checkout',
        coins: -totals.coinsUsed, status: 'spent', type: 'spend', orderNumber: number, date: now
      });
    }
    if (order.coinsEarned > 0) {
      STATE.ledger.unshift({
        id: `lg-pending-${number}`, title: `Order #${number}`, sub: 'Pending delivery',
        coins: order.coinsEarned, status: 'pending', type: 'earn', orderNumber: number, date: now
      });
    }
    if (totals.couponOk) totals.coupon.coupon.uses += 1;
    STATE.cart = { items: [], coupon: '', useCoins: false, coinMode: 'all', coinPercent: 50, coinCustom: '' };
    ui.pdQty = 1;
    save();
    ui.sheet = null;
    go(`#/placed/${number}`);
    showToast(`Order ${number} placed`, 'success');
  }

  function setLang(lang) {
    STATE.lang = lang === 'gu' ? 'gu' : 'en';
    save();
    render(true);
  }

  function toggleWishlist(id) {
    const i = STATE.wishlist.indexOf(id);
    if (i >= 0) STATE.wishlist.splice(i, 1);
    else STATE.wishlist.push(id);
    save();
    render(true);
    showToast(i >= 0 ? 'Removed from saved items' : 'Saved for later', 'success');
  }

  function resetDemo() {
    STATE = freshState();
    ensureVariantStocks();
    save();
    ui.sheet = null;
    ui.shop = { sort: 'popular', stock: false, coins: false };
    ui.search = '';
    ui.pdProduct = null;
    ui.pdVariant = 0;
    ui.pdQty = 1;
    ui.checkoutMode = 'delivery';
    ui.checkoutPayment = 'cod';
    ui.selectedSlot = 'Today · 6:00 – 8:00 PM';
    ui.showAllLedger = false;
    ui.ordersFilter = 'all';
    ui.adminOrderFilter = 'new';
    ui.invCat = 'all';
    ui.invQuery = '';
    ui.reportPeriod = 'week';
    ui.stockDay = todayISO();
    ui.stockShowAll = false;
    ui.cancelReason = 'Changed my mind';
    ui.couponFormOpen = false;
    ui.couponMsg = '';
    go('#/splash');
    showToast('Demo data restored', 'success');
  }

  /* ---------- navigation + stage ---------- */
  function go(hash) {
    if (location.hash === hash) render(false);
    else location.hash = hash;
  }

  function parseRoute() {
    const raw = (location.hash || '').replace(/^#\/?/, '');
    const parts = raw.split('?');
    const seg = parts[0].split('/').filter(Boolean);
    return { seg, params: new URLSearchParams(parts[1] || '') };
  }

  const journeys = {
    customer: {
      title: 'Customer journey',
      steps: [
        { label: 'Welcome & sign in', routes: ['splash', 'welcome', 'signin'] },
        { label: 'Discover the store', routes: ['home'] },
        { label: 'Shop products', routes: ['shop', 'product'] },
        { label: 'Cart & offers', routes: ['cart'] },
        { label: 'Checkout & pay', routes: ['checkout', 'placed'] },
        { label: 'Track your order', routes: ['track', 'orders'] },
        { label: 'Coins wallet', routes: ['wallet'] },
        { label: 'Profile & language', routes: ['profile'] }
      ]
    },
    admin: {
      title: 'Owner journey',
      steps: [
        { label: 'Dashboard', routes: ['admin'] },
        { label: 'Orders queue', routes: ['admin/orders'] },
        { label: 'Order detail', routes: ['admin/order'] },
        { label: 'Inventory', routes: ['admin/inventory', 'admin/product'] },
        { label: 'Hot sale', routes: ['admin/hot-sale'] },
        { label: 'Coins & coupons', routes: ['admin/coins', 'admin/coupons'] },
        { label: 'Reports & settings', routes: ['admin/reports', 'admin/more'] }
      ]
    }
  };

  function updateStage(seg) {
    const isAdmin = seg[0] === 'admin';
    const journey = isAdmin ? journeys.admin : journeys.customer;
    const routeKey = isAdmin ? seg.slice(0, 2).join('/') : seg[0];
    let active = 0;
    journey.steps.forEach((step, idx) => {
      if (step.routes.indexOf(routeKey) !== -1) active = idx;
    });
    const list = document.getElementById('journeyList');
    const title = document.getElementById('journeyTitle');
    const current = document.getElementById('journeyNow');
    if (title) title.textContent = journey.title;
    if (list) {
      list.innerHTML = journey.steps.map((step, idx) => {
        const state = idx < active ? 'is-done' : idx === active ? 'is-active' : '';
        const dot = idx < active ? I.icon('check', 9) : idx === active ? I.icon('arrow', 9) : '';
        return `<li class="${state}"><span class="j-dot">${dot}</span>${esc(step.label)}</li>`;
      }).join('');
    }
    if (current) current.textContent = journey.steps[active].label;
    document.querySelectorAll('[data-app-tab]').forEach((el) => {
      el.classList.toggle('is-active', el.dataset.appTab === (isAdmin ? 'admin' : 'customer'));
    });
  }

  /* ---------- toasts ---------- */
  let toastTimer = null;
  function showToast(message, type) {
    let el = document.getElementById('appToast');
    if (!el) {
      el = document.createElement('div');
      el.id = 'appToast';
      appEl.appendChild(el);
    }
    clearTimeout(toastTimer);
    el.className = `toast${type ? ` toast--${type}` : ''}`;
    el.innerHTML = `${I.icon(type === 'error' ? 'info' : 'check', 17)}<span>${esc(message)}</span>`;
    el.style.animation = 'none';
    void el.offsetWidth;
    el.style.animation = '';
    toastTimer = setTimeout(() => {
      el.classList.add('is-out');
      toastTimer = setTimeout(() => { el.remove(); }, 260);
    }, 2700);
  }

  /* ---------- shared UI ---------- */
  function statusbar(light, navy) {
    const color = light ? ' statusbar--light' : '';
    const bg = navy ? ' style="background:#121A47"' : '';
    return `<div class="statusbar${color}"${bg}>
      <span>9:41</span>
      <span class="statusbar__icons">
        <svg width="16" height="11" viewBox="0 0 16 11" fill="currentColor" aria-hidden="true"><rect x="0" y="7" width="2.6" height="4" rx="1"/><rect x="4" y="5" width="2.6" height="6" rx="1"/><rect x="8" y="2.5" width="2.6" height="8.5" rx="1"/><rect x="12" y="0" width="2.6" height="11" rx="1" opacity=".4"/></svg>
        <svg width="15" height="11" viewBox="0 0 15 11" fill="currentColor" aria-hidden="true"><path d="M7.5 9.7a1.4 1.4 0 1 0 0 .01ZM4.7 7.3a4 4 0 0 1 5.6 0l1.1-1.2a5.7 5.7 0 0 0-7.8 0l1.1 1.2Zm-3-3.1a8.3 8.3 0 0 1 11.6 0l1.1-1.2a10 10 0 0 0-13.8 0l1.1 1.2Z"/></svg>
        <svg width="23" height="11" viewBox="0 0 23 11" fill="none" aria-hidden="true"><rect x=".5" y=".5" width="19" height="10" rx="3" stroke="currentColor" opacity=".45"/><rect x="2" y="2" width="14.5" height="7" rx="1.6" fill="currentColor"/><path d="M21 4v3a2 2 0 0 0 0-3Z" fill="currentColor" opacity=".5"/></svg>
      </span>
    </div>`;
  }

  function appbar(opts) {
    const o = opts || {};
    const right = o.right || '';
    const back = o.back == null ? '' : o.back;
    return `<div class="appbar">
      ${back ? `<button class="icon-btn" type="button" data-back="${esc(back)}" aria-label="Back">${I.icon('back', 21)}</button>` : ''}
      <div class="appbar__text">
        <h1>${o.title || ''}</h1>
        ${o.sub ? `<p class="appbar__sub${o.subGu ? ' gu' : ''}">${o.sub}</p>` : ''}
      </div>
      ${right}
    </div>`;
  }

  function customerNav(active) {
    const count = cartCount();
    const tabs = [
      { key: 'home', icon: 'home', label: T('Home', 'હોમ'), href: '#/home' },
      { key: 'shop', icon: 'grid', label: T('Shop', 'દુકાન'), href: '#/shop' },
      { key: 'cart', icon: 'cart', label: T('Cart', 'કાર્ટ'), href: '#/cart', badge: count },
      { key: 'wallet', icon: 'wallet', label: T('Coins', 'કોઈન્સ'), href: '#/wallet' },
      { key: 'profile', icon: 'user', label: T('Profile', 'પ્રોફાઇલ'), href: '#/profile' }
    ];
    return `<nav class="tabbar" aria-label="Customer navigation">
      ${tabs.map((t) => `<a class="tab${active === t.key ? ' is-active' : ''}" href="${t.href}" data-nav="${t.href}">
        ${I.icon(t.icon, 21)}<span>${t.label}</span>${t.badge ? `<span class="tab__badge">${t.badge}</span>` : ''}
      </a>`).join('')}
    </nav>`;
  }

  function adminNav(active) {
    const tabs = [
      { key: 'dashboard', icon: 'home', label: 'Dashboard', href: '#/admin' },
      { key: 'orders', icon: 'box', label: 'Orders', href: '#/admin/orders', badge: STATE.orders.filter((o) => o.status === 'Placed').length },
      { key: 'inventory', icon: 'grid', label: 'Stock', href: '#/admin/inventory' },
      { key: 'coins', icon: 'coin', label: 'Rewards', href: '#/admin/coins' },
      { key: 'more', icon: 'more', label: 'More', href: '#/admin/more' }
    ];
    return `<nav class="tabbar tabbar--admin" aria-label="Admin navigation">
      ${tabs.map((t) => `<a class="tab${active === t.key ? ' is-active' : ''}" href="${t.href}" data-nav="${t.href}">
        ${I.icon(t.icon, 21)}<span>${t.label}</span>${t.badge ? `<span class="tab__badge">${t.badge}</span>` : ''}
      </a>`).join('')}
    </nav>`;
  }

  function adminHead(title, sub, opts) {
    const o = opts || {};
    return `<div class="admin-head">
      <span class="admin-head__logo">${I.logo(31)}</span>
      <div class="admin-head__text"><h1>${title}</h1><p>${sub}</p></div>
      <div class="admin-head__actions">
        ${o.bell === false ? '' : `<button class="admin-circle-btn" type="button" data-action="admin-notifications" aria-label="Notifications">${I.icon('bell', 18)}</button>`}
        <button class="admin-circle-btn" type="button" data-nav="#/admin/more" aria-label="Owner profile">${initials('Vijay')}</button>
      </div>
    </div>`;
  }

  function thumb(p, extra) {
    return `<span class="thumb ${extra || ''} tone-${p.tone || 'gold'}">${I.art(p.art || 'box')}</span>`;
  }

  function productCard(p) {
    const v = variantOf(p, p.defaultVariant);
    const off = discountPct(v);
    const saved = STATE.wishlist.indexOf(p.id) !== -1;
    const out = !p.available || variantStock(p, p.defaultVariant) <= 0;
    return `<article class="product-card" data-nav="#/product/${p.id}" role="link" tabindex="0" aria-label="${esc(pname(p))}">
      <div class="product-card__art tone-${p.tone}">
        ${I.art(p.art)}
        ${off ? `<span class="product-card__badge">${off}% off</span>` : ''}
        <button class="product-card__wish${saved ? ' is-active' : ''}" type="button" data-action="toggle-wish" data-id="${p.id}" aria-label="Save item">${I.icon('heart', 14)}</button>
      </div>
      <div class="product-card__body">
        <h3>${esc(pname(p))}</h3>
        <div class="product-card__meta">${I.icon('star', 10)}<b>${p.rating}</b><span>· ${esc(v.unit)}</span></div>
        <div class="product-card__bottom">
          <div>
            <div class="product-card__price">${money(v.price)}</div>
            ${v.mrp > v.price ? `<div class="product-card__mrp">${money(v.mrp)}</div>` : ''}
          </div>
          <button class="quick-add" type="button" data-action="quick-add" data-id="${p.id}" data-variant="${p.defaultVariant}" aria-label="Add ${esc(pname(p))} to cart" ${out ? 'disabled style="opacity:.4;pointer-events:none"' : ''}>${I.icon('plus', 16)}</button>
        </div>
      </div>
    </article>`;
  }

  function statusPill(status) {
    return `<span class="pill pill--${statusClass(status)}">${esc(statusLabel(status))}</span>`;
  }

  function payPill(state) {
    const cls = state === 'Paid' ? 'done' : state === 'Refunded' ? 'cancelled' : 'gold';
    return `<span class="pill pill--${cls}">${esc(state)}</span>`;
  }

  function billLines(t, localized = true) {
    const L = localized ? T : (en) => en;
    return `<div class="bill-lines">
      <div class="bill-line"><span>${L('Item total', 'વસ્તુ કુલ')}</span><b>${money(t.subtotal)}</b></div>
      ${t.discount ? `<div class="bill-line bill-line--green"><span>${L('Coupon', 'કૂપન')} ${t.couponCode ? `(${esc(t.couponCode)})` : ''}</span><b>− ${money(t.discount)}</b></div>` : ''}
      ${t.coinsUsed ? `<div class="bill-line bill-line--green"><span>${t.coinsUsed} ${L('coins', 'કોઈન્સ')}</span><b>− ${money(t.coinDiscount)}</b></div>` : ''}
      <div class="bill-line"><span>${L('Home delivery', 'હોમ ડિલિવરી')}</span><b class="green">${L('FREE', 'મફત')}</b></div>
      <div class="bill-line bill-line--total"><span>${L('To pay', 'ચૂકવવાનું')}</span><b>${money(t.total)}</b></div>
    </div>`;
  }

  function earnNote(coins, ruleName) {
    if (!coins) return '';
    return `<div class="earn-note">${I.icon('coin', 13)}<span>${T('Earn', 'કમાઓ')} <b>${coins} ${T('coins', 'કોઈન્સ')}</b> ${T(`worth ${money(coins)} after delivery`, `ડિલિવરી પછી ${money(coins)}ની કિંમત`)}${ruleName ? ` · ${esc(ruleName)}` : ''}</span></div>`;
  }

  function emptyState(icon, title, copy, actionHtml) {
    return `<div class="empty">
      <span class="empty__orb">${I.icon(icon, 34)}</span>
      <h3>${esc(title)}</h3>
      <p>${esc(copy)}</p>
      ${actionHtml || ''}
    </div>`;
  }

  function sheetShell(title, sub, body) {
    return `<div class="scrim">
      <div class="sheet" role="dialog" aria-modal="true" aria-label="${esc(title)}">
        <div class="sheet__grab"></div>
        <div class="sheet__head">
          <div><h2>${esc(title)}</h2>${sub ? `<p>${sub}</p>` : ''}</div>
          <button class="sheet__close" type="button" data-action="close-sheet" aria-label="Close">${I.icon('close', 16)}</button>
        </div>
        ${body}
      </div>
    </div>`;
  }

  const sheets = {};
  function renderSheet() {
    if (!ui.sheet) return '';
    const fn = sheets[ui.sheet.type];
    return fn ? fn(ui.sheet) : '';
  }

  function openSheet(type, extra) {
    ui.sheet = Object.assign({ type }, extra || {});
    render(true);
  }

  function closeSheet() {
    ui.sheet = null;
    render(true);
  }

  /* ---------- customer views ---------- */
  const views = {};
  const PICKUP_SLOTS = ['Today · 4:00 – 6:00 PM', 'Today · 6:00 – 8:00 PM', 'Tomorrow · 10:00 AM – 12:00 PM'];

  const selectedAddress = () => STATE.addresses.find((a) => a.id === STATE.selectedAddress) || STATE.addresses[0];
  const featuredProducts = () => STATE.hotSale.featured.map(productById).filter(Boolean);
  const sortedLedger = () => STATE.ledger.slice().sort((a, b) => new Date(b.date) - new Date(a.date));

  function missingScreen(message, backHref, backLabel) {
    return `<div class="screen">
      ${statusbar()}
      ${appbar({ title: backLabel || 'Not found', back: backHref || '#/home' })}
      <div class="screen-scroll screen-scroll--end">
        ${emptyState('box', 'We could not find that', message || 'The page you requested is not available in this demo.', `<button class="btn btn--primary btn--sm" data-nav="${backHref || '#/home'}">Go back</button>`)}
      </div>
    </div>`;
  }

  views.splash = function () {
    return `<div class="screen splash">
      <span class="splash-ring splash-ring--1"></span>
      <span class="splash-ring splash-ring--2"></span>
      <span class="splash-ring splash-ring--3"></span>
      <div class="splash-center">
        <div class="splash-logo">${I.logo(58)}</div>
        <div class="splash-word">VIJAY</div>
        <div class="splash-sub">SUPER MALL</div>
        <div class="splash-gu">વિજય સુપર મોલ · વડોદરા</div>
      </div>
      <div class="splash-bottom">
        <div class="splash-dots"><i></i><i></i><i></i></div>
        <p>${T('Fresh · Local · Delivered free', 'તાજું · સ્થાનિક · મફત ડિલિવરી')}</p>
      </div>
    </div>`;
  };

  views.welcome = function () {
    const langIsEn = STATE.lang === 'en';
    return `<div class="screen welcome">
      <div class="welcome-hero">
        <div class="welcome-brand">
          <span class="logo-badge">${I.logo(24)}</span>
          <div><b>VIJAY</b><small>SUPER MALL</small></div>
          <button class="welcome-lang" type="button" data-action="set-lang" data-lang="${langIsEn ? 'gu' : 'en'}">${langIsEn ? 'ગુજરાતી' : 'EN'}</button>
        </div>
        <div class="welcome-stage">
          <div class="welcome-art">${I.art('almonds')}</div>
          <div class="welcome-art">${I.art('pickle')}</div>
          <div class="welcome-art">${I.art('kulfi')}</div>
        </div>
        <div class="welcome-gu">વિજય સુપર મોલ · વડોદરા</div>
      </div>
      <div class="welcome-body">
        <div class="welcome-dots"><i></i><i></i><i></i></div>
        <h1 class="welcome-title">${T('Everyday essentials.', 'રોજની જરૂરિયાત.')}<br><em>${T('Delivered free.', 'મફત ડિલિવરી.')}</em></h1>
        <p class="welcome-copy">${T('Grocery, home-industry favourites, dry fruit, cosmetics and ice cream — from our Alkapuri store to your door.', 'કરિયાણું, ગૃહ ઉદ્યોગ, સૂકો ફળ, કોસ્મેટિક અને આઇસ્ક્રીમ — અલકાપુરીની દુકાનથી આપના ઘર સુધી.')} <b>${T('Earn coins on every order.', 'દરેક ઓર્ડર પર કોઈન્સ કમાઓ.')}</b></p>
        <div class="welcome-actions">
          <button class="btn btn--primary" type="button" data-nav="#/signin">${T('Get started', 'શરૂ કરો')} ${I.icon('arrow', 17)}</button>
          <button class="btn btn--secondary" type="button" data-nav="#/home">${T('Browse the store', 'દુકાન જુઓ')}</button>
        </div>
        <div class="welcome-signin">${T('Already have an account?', 'પહેલેથી એકાઉન્ટ છે?')}<button type="button" data-nav="#/signin">${T('Sign in', 'સાઇન ઇન')}</button></div>
      </div>
    </div>`;
  };

  views.signin = function () {
    return `<div class="screen auth">
      ${statusbar(true)}
      <div class="auth-top">
        <div class="auth-brand">
          <span class="logo-badge">${I.logo(26)}</span>
          <div><b>VIJAY</b><small>SUPER MALL</small></div>
        </div>
        <h1 class="auth-title">${T('Welcome back.', 'પાછા સ્વાગત છે.')}</h1>
        <p class="auth-sub">${T('Sign in with the number you use at the store.', 'દુકાનમાં વપરાતા નંબરથી સાઇન ઇન કરો.')}</p>
      </div>
      <div class="auth-body">
        <form class="auth-card" data-form="signin">
          <div class="field">
            <label for="signinPhone">${T('Mobile number', 'મોબાઇલ નંબર')}</label>
            <div class="phone-input"><span>+91</span><input id="signinPhone" name="phone" type="tel" inputmode="numeric" maxlength="10" value="${esc(STATE.user.phone.replace(/\D/g, '').slice(-10))}" placeholder="98765 43210" autocomplete="tel"></div>
          </div>
          <div class="field">
            <label>${T('One-time password', 'વન-ટાઇમ પાસવર્ડ')}</label>
            <div class="otp-row">
              ${[0, 1, 2, 3].map((i) => `<input class="otp" name="otp${i + 1}" type="text" inputmode="numeric" maxlength="1" data-otp="${i}" aria-label="OTP digit ${i + 1}">`).join('')}
            </div>
          </div>
          <div class="auth-resend">
            <span>${T('Didn’t receive the code?', 'કોડ નથી મળ્યો?')}</span>
            <button type="button" data-action="fill-otp">${T('Use demo OTP', 'ડેમો OTP વાપરો')}</button>
          </div>
          <button class="btn btn--primary btn--block" type="submit">${T('Verify & continue', 'ચકાસો અને આગળ વધો')} ${I.icon('arrow', 17)}</button>
        </form>
        <p class="auth-secure">${I.icon('shield', 12)} ${T('OTP protected · no password needed', 'OTP સુરક્ષિત · પાસવર્ડની જરૂર નથી')}</p>
        <div class="auth-owner">${T('Store owner?', 'દુકાનના માલિક?')}<button type="button" data-nav="#/admin">${T('Open admin panel', 'એડમિન પેનલ ખોલો')}</button></div>
        <div class="auth-demo"><b>DEMO</b><span>${T('Any 4-digit OTP signs you in', 'કોઈપણ 4-અંકનો OTP ચાલશે')}</span></div>
      </div>
    </div>`;
  };

  views.home = function () {
    const active = userOrders().find(isActiveOrder);
    const featured = featuredProducts();
    const best = STATE.products.filter((p) => p.available).slice(0, 4);
    const coins = coinBalance();
    const hot = STATE.hotSale;
    return `<div class="screen">
      ${statusbar()}
      <div class="screen-scroll">
        <div class="home-top">
          <div>
            <div class="deliver-label">${T('Deliver to', 'ડિલિવરી સરનામું')}</div>
            <button class="deliver-row" type="button" data-action="open-addresses">${I.icon('pin', 16)}<span>${esc(selectedAddress().label)} · ${esc(selectedAddress().detail.split(',')[0])}</span>${I.icon('down', 12)}</button>
          </div>
          <button class="icon-btn icon-btn--sm" type="button" data-action="open-notifications" aria-label="Notifications">${I.icon('bell', 18)}</button>
        </div>

        <form class="searchbar" data-form="home-search">
          <button type="submit" aria-label="Search" style="color:var(--ink-3)">${I.icon('search', 18)}</button>
          <input name="q" placeholder="${T('Search grocery, dry fruit, ice cream…', 'કરિયાણું, સૂકો ફળ, આઇસ્ક્રીમ શોધો…')}" aria-label="Search products" autocomplete="off">
          ${I.icon('filter', 17)}
        </form>

        ${hot.live ? `<button class="sale-banner" type="button" data-nav="#/shop?hot=1">
          <span class="eyebrow">${esc(hot.eyebrow)}</span>
          <h2>${esc(hot.title)}</h2>
          <span class="shop-now">${T('Shop the sale', 'સેલ ખરીદો')} ${I.icon('arrow', 14)}</span>
          <span class="sale-flame">${I.icon('flame', 34)}</span>
        </button>` : ''}

        <div class="home-cats">
          ${STATE.categories.filter((cat) => STATE.products.some((p) => p.category === cat.id)).map((cat) => `<button class="home-cat" type="button" data-nav="#/shop?cat=${cat.id}">
            <span class="home-cat__icon cat-${cat.tone}">${I.icon(cat.icon, 24)}</span>
            <b>${esc(STATE.lang === 'gu' ? cat.nameGu : cat.name)}</b>
            <small>${STATE.lang === 'gu' ? cat.name : cat.nameGu}</small>
          </button>`).join('')}
        </div>

        ${active ? `<button class="active-order" type="button" data-nav="#/track/${active.number}">
          <span class="active-order__pulse"></span>
          <div class="grow"><b>${T('Order', 'ઓર્ડર')} ${esc(active.number)} · ${esc(cStatus(active.status))}</b><span>${esc(orderEta(active))}</span></div>
          ${I.icon('right', 16)}
        </button>` : ''}

        <button class="coin-banner mt-12" type="button" data-nav="#/wallet">
          <span class="coin-orb coin-orb--sm">${I.icon('coin', 20)}</span>
          <div class="coin-banner__copy"><b>${coins} ${T('coins', 'કોઈન્સ')} · ${money(coins)}</b><span>${T('Use them on eligible items at checkout', 'ચેકઆઉટ પર માન્ય વસ્તુઓમાં વાપરો')}</span></div>
          ${I.icon('right', 16)}
        </button>

        <div class="section-head section-head--hot">
          <h2>${I.icon('flame', 18)} ${T('Hot right now', 'હમણાં હોટ')}</h2>
          <button class="link" type="button" data-nav="#/shop?hot=1">${T('See all', 'બધું જુઓ')}</button>
        </div>
        <div class="hot-scroll">${featured.map(productCard).join('')}</div>

        <div class="section-head">
          <h2>${T('Best of the mall', 'મોલની બેસ્ટ')}</h2>
          <button class="link" type="button" data-nav="#/shop">${T('View all', 'બધું જુઓ')}</button>
        </div>
        <div class="product-grid">${best.map(productCard).join('')}</div>

        <div class="card card--pad mt-16">
          <div class="row">
            <span class="info-card__icon">${I.icon('truck', 18)}</span>
            <div class="grow"><h3 style="font-size:12px;font-weight:800">${T('Free home delivery', 'મફત હોમ ડિલિવરી')}</h3><p style="font-size:10px;color:var(--ink-2);margin-top:2px">${T('On every order, all across Vadodara.', 'વડોદરામાં દરેક ઓર્ડર પર.')}</p></div>
            <a class="link" href="tel:${D.store.phoneHref}">${I.icon('phone', 14)}</a>
          </div>
        </div>
      </div>
      ${customerNav('home')}
    </div>`;
  };

  views.shop = function (route) {
    const params = route.params;
    const q = (params.get('q') || '').trim();
    const cat = params.get('cat') || '';
    const hot = params.get('hot') === '1';
    let list = STATE.products.slice();
    if (cat) list = list.filter((p) => p.category === cat);
    if (hot) list = list.filter((p) => STATE.hotSale.featured.indexOf(p.id) !== -1);
    if (q) {
      const needle = q.toLowerCase();
      list = list.filter((p) => `${p.name} ${p.nameGu} ${p.category}`.toLowerCase().indexOf(needle) !== -1);
    }
    if (ui.shop.stock) list = list.filter((p) => p.available && p.stock > 0);
    if (ui.shop.coins) list = list.filter((p) => p.allowCoins || p.earnsCoins);
    if (ui.shop.sort === 'price-low') list.sort((a, b) => variantOf(a, a.defaultVariant).price - variantOf(b, b.defaultVariant).price);
    else if (ui.shop.sort === 'price-high') list.sort((a, b) => variantOf(b, b.defaultVariant).price - variantOf(a, a.defaultVariant).price);
    else if (ui.shop.sort === 'rating') list.sort((a, b) => b.rating - a.rating);
    else list.sort((a, b) => b.reviews - a.reviews);
    const catName = STATE.categories.find((c) => c.id === cat);
    const title = q ? T('Search results', 'શોધ પરિણામ') : hot ? T('Hot sale', 'હોટ સેલ') : catName ? (STATE.lang === 'gu' ? catName.nameGu : catName.name) : T('All products', 'બધી વસ્તુઓ');
    const filterCount = (ui.shop.stock ? 1 : 0) + (ui.shop.coins ? 1 : 0);
    return `<div class="screen">
      ${statusbar()}
      <div class="appbar">
        <button class="icon-btn" type="button" data-back="#/home" aria-label="Back">${I.icon('back', 21)}</button>
        <div class="appbar__text"><h1>${esc(title)}</h1><p class="appbar__sub">${list.length} ${T('products', 'વસ્તુઓ')}${q ? ` for “${esc(q)}”` : ''} · ${T('free delivery', 'મફત ડિલિવરી')}</p></div>
        <button class="icon-btn" type="button" data-action="open-filters" aria-label="Filters" style="position:relative">${I.icon('filter', 19)}${filterCount ? `<span class="tab__badge" style="top:-3px;left:auto;right:-3px">${filterCount}</span>` : ''}</button>
      </div>
      <div class="screen-scroll">
        <form class="searchbar" data-form="shop-search">
          <button type="submit" aria-label="Search" style="color:var(--ink-3)">${I.icon('search', 18)}</button>
          <input name="q" value="${esc(q)}" placeholder="${T('Search this shelf…', 'આ શેલ્ફમાં શોધો…')}" aria-label="Search products" autocomplete="off">
          ${q ? `<button type="button" data-action="clear-search" aria-label="Clear search" style="color:var(--ink-3)">${I.icon('close', 15)}</button>` : ''}
        </form>
        <div class="chips">
          <button class="chip${!cat && !hot ? ' is-active' : ''}" type="button" data-nav="#/shop">${T('All', 'બધું')}</button>
          ${STATE.categories.filter((c) => STATE.products.some((p) => p.category === c.id)).map((c) => `<button class="chip${cat === c.id ? ' is-active' : ''}" type="button" data-nav="#/shop?cat=${c.id}">${esc(STATE.lang === 'gu' ? c.nameGu : c.name)}</button>`).join('')}
        </div>
        <div class="shop-count">${T('Showing', 'દર્શાવે છે')} ${list.length} ${T('of', '/')} ${STATE.products.length} ${T('items', 'વસ્તુઓ')}${ui.shop.sort !== 'popular' ? ` · ${ui.shop.sort === 'rating' ? 'Top rated' : ui.shop.sort === 'price-low' ? 'Price low to high' : 'Price high to low'}` : ''}</div>
        ${list.length
          ? `<div class="product-grid">${list.map(productCard).join('')}</div>`
          : emptyState('search', T('No products found', 'કોઈ વસ્તુ મળી નથી'), T('Try another category or clear your filters.', 'બીજી કેટેગરી અજમાવો અથવા ફિલ્ટર સાફ કરો.'), `<button class="btn btn--soft btn--sm" type="button" data-action="reset-shop">${T('Clear filters', 'ફિલ્ટર સાફ કરો')}</button>`)}
      </div>
      ${customerNav('shop')}
    </div>`;
  };

  views.product = function (route) {
    const p = productById(route.seg[1]);
    if (!p) return missingScreen('This product is no longer in the catalogue.', '#/shop', 'Product');
    if (ui.pdProduct !== p.id) {
      ui.pdProduct = p.id;
      const firstInStock = p.variants.findIndex((variant, i) => variantStock(p, i) > 0);
      ui.pdVariant = variantStock(p, p.defaultVariant) > 0 ? p.defaultVariant : firstInStock >= 0 ? firstInStock : p.defaultVariant;
      ui.pdQty = 1;
    }
    if (!p.variants[ui.pdVariant]) ui.pdVariant = p.defaultVariant;
    const v = variantOf(p, ui.pdVariant);
    const packStock = variantStock(p, ui.pdVariant);
    ui.pdQty = Math.min(Math.max(1, ui.pdQty), Math.max(1, packStock));
    const off = discountPct(v);
    const out = !p.available || packStock <= 0;
    const low = !out && packStock <= p.lowStock;
    const inCart = STATE.cart.items.filter((it) => it.productId === p.id).reduce((n, it) => n + it.qty, 0);
    return `<div class="screen">
      ${statusbar()}
      <div class="screen-scroll screen-scroll--flush" style="padding-bottom:132px">
        <div class="pd-hero tone-${p.tone}">
          <div class="pd-actions">
            <button class="icon-btn" type="button" data-back="#/shop" aria-label="Back">${I.icon('back', 21)}</button>
            <div class="pd-actions__right">
              <button class="icon-btn" type="button" data-action="toggle-wish" data-id="${p.id}" aria-label="Save item">${I.icon('heart', 19)}</button>
              <button class="icon-btn" type="button" data-action="share-product" data-id="${p.id}" aria-label="Share product">${I.icon('share', 18)}</button>
            </div>
          </div>
          ${I.art(p.art).replace('<svg ', '<svg class="pd-art" ')}
        </div>
        <div class="pd-body">
          <div class="pd-title-row">
            <div>
              <h1 class="pd-title">${esc(pname(p))}</h1>
              <p class="pd-gu">${esc(p.nameGu)}</p>
              <div class="pd-rating">${I.icon('star', 13)} <b>${p.rating}</b><span>· ${p.reviews} ${T('reviews', 'સમીક્ષાઓ')}</span></div>
            </div>
            ${out ? `<span class="pill pill--cancelled">${p.available ? T('Pack out of stock', 'પેક ખતમ') : T('Out of stock', 'સ્ટોકમાં નથી')}</span>` : low ? `<span class="pill pill--low">Only ${packStock} left</span>` : `<span class="pill pill--active">In stock</span>`}
          </div>
          <div class="pd-price-row">
            <span class="pd-price">${money(v.price)}</span>
            ${v.mrp > v.price ? `<span class="pd-mrp">${money(v.mrp)}</span><span class="pd-off">${off}% off</span>` : ''}
          </div>
          <div class="pd-tags">
            <span class="tag tag--green">${I.icon('truck', 11)} ${T('Free delivery', 'મફત ડિલિવરી')}</span>
            ${p.earnsCoins ? `<span class="tag tag--gold">${I.icon('coin', 11)} ${T('Earns coins', 'કોઈન્સ મળે')}</span>` : ''}
            ${p.allowCoins ? `<span class="tag tag--navy">${I.icon('wallet', 11)} ${T('Coins accepted', 'કોઈન્સ ચાલે')}</span>` : `<span class="tag">${T('No coin redemption', 'કોઈન્સ લાગુ નહીં')}</span>`}
            <span class="tag">${esc(p.unit)}</span>
          </div>
          <div class="pd-section">
            <h3>${T('Choose a pack', 'પેક પસંદ કરો')}</h3>
            <div class="size-row">
              ${p.variants.map((variant, i) => {
                const soldOut = variantStock(p, i) <= 0;
                return `<button class="size${i === ui.pdVariant ? ' is-selected' : ''}${soldOut ? ' is-soldout' : ''}" type="button" data-action="select-variant" data-index="${i}"${soldOut ? ' disabled' : ''}>${esc(variant.label)}<small>${soldOut ? T('Sold out', 'ખતમ') : money(variant.price)}</small></button>`;
              }).join('')}
            </div>
          </div>
          <div class="pd-section">
            <h3>${T('About this item', 'આ વસ્તુ વિશે')}</h3>
            <p class="pd-desc">${esc(pdesc(p))}</p>
          </div>
          <div class="pd-note">${I.icon('coin', 17)}<span>${p.allowCoins ? T(`Use your coins on this item — 1 coin = ₹1 at checkout.`, 'આ વસ્તુ પર કોઈન્સ વાપરો — ચેકઆઉટ પર 1 કોઈન = ₹1.') : T('Coins can’t be redeemed on this item, but it still counts toward delivery.', 'આ વસ્તુ પર કોઈન્સ વાપરી શકાય નહીં.')} ${p.earnsCoins ? T('It also earns coins after delivery.', 'ડિલિવરી પછી કોઈન્સ પણ મળે.') : ''}</span></div>
          <div class="pd-promise">
            <div>${I.icon('truck', 16)}<span>${T('Free home delivery', 'મફત હોમ ડિલિવરી')}</span></div>
            <div>${I.icon('store', 16)}<span>${T('Packed in Alkapuri', 'અલકાપુરીમાં પેક')}</span></div>
            <div>${I.icon('refresh', 16)}<span>${T('Easy replacements', 'સહેલું રિપ્લેસમેન્ટ')}</span></div>
          </div>
          ${inCart ? `<p class="hint mt-12">${inCart} ${T('in your cart', 'તમારી કાર્ટમાં')} · <button class="link" type="button" data-nav="#/cart">${T('View cart', 'કાર્ટ જુઓ')}</button></p>` : ''}
        </div>
      </div>
      <div class="actionbar actionbar--solid pd-actionbar">
        <div class="buy-stepper">
          <button type="button" data-action="pd-qty" data-delta="-1" aria-label="Decrease quantity">${I.icon('minus', 16)}</button>
          <b>${ui.pdQty}</b>
          <button type="button" data-action="pd-qty" data-delta="1" aria-label="Increase quantity">${I.icon('plus', 16)}</button>
        </div>
        <button class="btn btn--primary pd-add" type="button" data-action="add-pd" data-id="${p.id}" ${out ? 'disabled' : ''}>${I.icon('cart', 18)} ${out ? (p.available ? T('Pack sold out', 'પેક ખતમ') : T('Out of stock', 'સ્ટોક ખતમ')) : `${T('Add', 'ઉમેરો')} · ${money(v.price * ui.pdQty)}`}</button>
      </div>
    </div>`;
  };

  views.cart = function () {
    const t = cartTotals();
    const details = t.details;
    const ineligible = details.filter((it) => !it.p.allowCoins);
    if (!details.length) {
      return `<div class="screen">
        ${statusbar()}
        ${appbar({ title: T('My cart', 'મારી કાર્ટ'), sub: T('Free home delivery', 'મફત હોમ ડિલિવરી'), back: '#/home' })}
        <div class="screen-scroll screen-scroll--end">
          ${emptyState('cart', T('Your cart is empty', 'તમારી કાર્ટ ખાલી છે'), T('Add groceries, dry fruit or a treat from the freezer.', 'કરિયાણું, સૂકો ફળ કે આઇસ્ક્રીમ ઉમેરો.'), `<button class="btn btn--primary btn--sm" type="button" data-nav="#/shop">${T('Start shopping', 'ખરીદી શરૂ કરો')}</button>`)}
        </div>
      </div>`;
    }
    const coupon = t.coupon;
    const usableCoins = Math.min(t.balance, t.cap);
    return `<div class="screen">
      ${statusbar()}
      ${appbar({
        title: T('My cart', 'મારી કાર્ટ'),
        sub: `${cartCount()} ${cartCount() === 1 ? T('item', 'વસ્તુ') : T('items', 'વસ્તુઓ')} · ${T('free delivery', 'મફત ડિલિવરી')}`,
        back: '#/shop',
        right: `<button class="icon-btn icon-btn--sm" type="button" data-action="clear-cart" aria-label="${T('Clear cart', 'કાર્ટ ખાલી કરો')}">${I.icon('trash', 17)}</button>`
      })}
      <div class="screen-scroll screen-scroll--action">
        <div class="card cart-card">
          ${details.map((it, idx) => `<div class="cart-item">
            ${thumb(it.p, 'thumb--sm')}
            <div class="cart-item__body">
              <h3>${esc(pname(it.p))}</h3>
              <div class="cart-item__unit">${esc(it.v.unit)} · ${esc(categoryLabel(it.p.category))}</div>
              <div class="cart-item__price">${money(it.v.price)} ${it.p.allowCoins ? '' : `<span class="no-coins">${T('No coins', 'કોઈન્સ નહીં')}</span>`}</div>
            </div>
            <div class="stepper-pill">
              <button type="button" data-action="cart-qty" data-index="${idx}" data-delta="-1" aria-label="Decrease">${I.icon('minus', 14)}</button>
              <b>${it.qty}</b>
              <button type="button" data-action="cart-qty" data-index="${idx}" data-delta="1" aria-label="Increase">${I.icon('plus', 14)}</button>
            </div>
          </div>`).join('')}
        </div>

        <div class="mt-12">
          ${coupon && coupon.ok ? `<div class="coupon-row">
            <span class="coupon-row__icon">${I.icon('ticket', 16)}</span>
            <div class="grow"><b>${esc(coupon.coupon.code)} ${T('applied', 'લાગુ')}</b><span class="hint">${T(`You saved ${money(coupon.discount)}.`, `તમે ${money(coupon.discount)} બચાવ્યા.`)}</span></div>
            <button type="button" data-action="remove-coupon">${T('Remove', 'કાઢો')}</button>
          </div>` : `<button class="coupon-add" type="button" data-action="open-coupon-sheet">
            ${I.icon('ticket', 17)}<span>${T('Apply a coupon', 'કૂપન લગાવો')}</span><span style="margin-left:auto;color:var(--ink-3)">${T('View offers', 'ઓફર જુઓ')}</span>
          </button>`}
          ${coupon && !coupon.ok && STATE.cart.coupon ? `<p class="hint" style="margin:8px 2px 0;color:var(--red)">${esc(coupon.message)}</p>` : ''}
        </div>

        <div class="coins-panel mt-12">
          <span class="coin-orb coin-orb--sm">${I.icon('coin', 19)}</span>
          <div class="coins-panel__copy">
            <b>${t.coinsUsed ? `${t.coinsUsed} ${T('coins applied', 'કોઈન્સ લાગુ')} · ${money(t.coinDiscount)}` : `${t.balance} ${T('coins available', 'કોઈન્સ ઉપલબ્ધ')}`}</b>
            <span>${t.canUseCoins
              ? usableCoins > 0
                ? T(`1 coin = ₹1 · up to ${usableCoins} coins can be used on this order`, `1 કોઈન = ₹1 · આ ઓર્ડર પર ${usableCoins} કોઈન્સ સુધી વાપરી શકાય`)
                : T('No coins available to use on this order yet', 'આ ઓર્ડર પર હજી કોઈન્સ ઉપલબ્ધ નથી')
              : T(`${coupon && coupon.coupon ? coupon.coupon.code : 'This coupon'} can’t be combined with coins`, 'આ કૂપન સાથે કોઈન્સ લાગુ નહીં')}</span>
            ${ineligible.length ? `<span>${T('No coins on', 'કોઈન્સ નહીં')} ${ineligible.map((it) => esc(pname(it.p))).join(', ')}</span>` : ''}
            <button type="button" data-action="open-coins-sheet">${t.coinsUsed ? T('Change coins', 'કોઈન્સ બદલો') : T('Choose coins', 'કોઈન્સ પસંદ કરો')}</button>
          </div>
          <label class="switch" aria-label="Use coins">
            <input type="checkbox" data-change="toggle-coins" ${STATE.cart.useCoins ? 'checked' : ''} ${t.balance === 0 || !t.canUseCoins ? 'disabled' : ''}>
          </label>
        </div>

        <div class="card card--pad bill-card mt-12">
          ${billLines(t)}
          <div class="divider"></div>
          ${earnNote(t.coinsEarned, t.earnRule ? t.earnRule.name : '')}
        </div>
        <p class="hint mt-10" style="display:flex;align-items:center;gap:6px">${I.icon('shield', 13)} ${T('Secure checkout · free home delivery across Vadodara', 'સુરક્ષિત ચેકઆઉટ · વડોદરામાં મફત હોમ ડિલિવરી')}</p>
      </div>
      <div class="actionbar">
        <div class="actionbar__total"><small>${T('To pay', 'ચૂકવવાનું')}</small><strong>${money(t.total)}</strong></div>
        <button class="btn btn--primary" type="button" data-nav="#/checkout">${T('Checkout', 'ચેકઆઉટ')} ${I.icon('arrow', 17)}</button>
      </div>
    </div>`;
  };

  views.checkout = function () {
    const t = cartTotals();
    if (!t.details.length) {
      return `<div class="screen">
        ${statusbar()}
        ${appbar({ title: T('Checkout', 'ચેકઆઉટ'), back: '#/cart' })}
        <div class="screen-scroll screen-scroll--end">${emptyState('cart', T('Nothing to check out', 'ચેકઆઉટ માટે કંઈ નથી'), T('Your cart is empty. Add something from the store first.', 'તમારી કાર્ટ ખાલી છે.'), `<button class="btn btn--primary btn--sm" type="button" data-nav="#/shop">${T('Browse products', 'વસ્તુઓ જુઓ')}</button>`)}</div>
      </div>`;
    }
    const mode = ui.checkoutMode;
    const pay = mode === 'pickup' && ui.checkoutPayment === 'cod' ? 'store' : ui.checkoutPayment;
    const addr = selectedAddress();
    const payOptions = mode === 'pickup'
      ? [
        { key: 'upi', label: 'UPI / Card', sub: 'Pay now · secure prepaid', subGu: 'હમણાં ચૂકવો · સુરક્ષિત પ્રીપેઇડ', icon: 'card' },
        { key: 'store', label: 'Pay at store', labelGu: 'દુકાન પર ચૂકવો', sub: 'Pay when you collect', subGu: 'લેવા આવતી વખતે ચૂકવો', icon: 'store' }
      ]
      : [
        { key: 'upi', label: 'UPI / Card', sub: 'Google Pay, PhonePe, Paytm', subGu: 'Google Pay, PhonePe, Paytm', icon: 'card' },
        { key: 'cod', label: 'Cash on delivery', labelGu: 'ડિલિવરી પર રોકડ', sub: 'Pay our rider at your door', subGu: 'રાઇડરને ઘરે ચૂકવો', icon: 'cash' }
      ];
    const payLabel = pay === 'upi' ? T('Pay now', 'હમણાં ચૂકવો') : T('Place order', 'ઓર્ડર કરો');
    return `<div class="screen">
      ${statusbar()}
      ${appbar({ title: T('Checkout', 'ચેકઆઉટ'), sub: mode === 'delivery' ? T('Free home delivery', 'મફત હોમ ડિલિવરી') : T('Pickup from Alkapuri', 'અલકાપુરીથી પિકઅપ'), back: '#/cart' })}
      <div class="screen-scroll screen-scroll--action">
        <div class="segmented">
          <button class="seg${mode === 'delivery' ? ' is-active' : ''}" type="button" data-action="checkout-mode" data-mode="delivery">${I.icon('truck', 16)} ${T('Home delivery', 'હોમ ડિલિવરી')}</button>
          <button class="seg${mode === 'pickup' ? ' is-active' : ''}" type="button" data-action="checkout-mode" data-mode="pickup">${I.icon('store', 16)} ${T('Store pickup', 'સ્ટોર પિકઅપ')}</button>
        </div>

        ${mode === 'delivery' ? `<div class="card info-card mt-12">
          <span class="info-card__icon">${I.icon('pin', 18)}</span>
          <div class="grow"><h3>${T('Deliver to', 'ડિલિવરી સરનામું')} <span class="pill pill--grey">${esc(addr.label)}</span></h3><p>${esc(addr.detail)}<br>${esc(addr.phone)} · ${T('Free delivery by 8 PM', '8 વાગ્યા સુધી મફત ડિલિવરી')}</p></div>
          <button class="link" type="button" data-action="open-addresses">${T('Change', 'બદલો')}</button>
        </div>` : `<div class="card info-card mt-12">
          <span class="info-card__icon info-card__icon--navy">${I.icon('store', 18)}</span>
          <div class="grow"><h3>${T('Pickup store', 'પિકઅપ સ્ટોર')}</h3><p>${esc(D.store.address)}<br>${esc(D.store.phone)}</p></div>
          <a class="link" href="tel:${D.store.phoneHref}">${T('Call', 'કૉલ')}</a>
        </div>
        <div class="card card--pad mt-12">
          <h3 style="font-size:12px;font-weight:800">${T('Pick a pickup slot', 'પિકઅપ સમય પસંદ કરો')}</h3>
          <div class="pickup-slot">
            ${PICKUP_SLOTS.map((slot) => `<button class="slot${ui.selectedSlot === slot ? ' is-selected' : ''}" type="button" data-action="select-slot" data-slot="${esc(slot)}">${esc(slot)}</button>`).join('')}
          </div>
        </div>`}

        <div class="card order-items-card mt-12">
          <div class="between" style="padding:11px 0 2px"><h3 style="font-size:12px;font-weight:800">${T('Order summary', 'ઓર્ડર સારાંશ')}</h3><button class="link" type="button" data-nav="#/cart">${T('Edit', 'બદલો')}</button></div>
          ${t.details.map((it) => `<div class="order-item">
            ${thumb(it.p, 'thumb--xs')}
            <div class="grow"><h3>${esc(pname(it.p))}</h3><span>${esc(it.v.unit)} × ${it.qty}</span></div>
            <b>${money(it.lineTotal)}</b>
          </div>`).join('')}
        </div>

        <div class="section-head"><h2 style="font-size:15px">${T('Payment method', 'પેમેન્ટ પદ્ધતિ')}</h2><span class="pill pill--green">${I.icon('shield', 11)} ${T('Secure', 'સુરક્ષિત')}</span></div>
        <div class="card payment-card">
          ${payOptions.map((opt) => `<button class="pay-method${pay === opt.key ? ' is-selected' : ''}" type="button" data-action="set-payment" data-payment="${opt.key}">
            <span class="pay-method__icon">${I.icon(opt.icon, 17)}</span>
            <div class="grow"><b>${T(opt.label, opt.labelGu || opt.label)}</b><small>${T(opt.sub, opt.subGu || opt.sub)}</small></div>
            <span class="radio"></span>
          </button>`).join('')}
        </div>

        <div class="card card--pad bill-card mt-12">
          ${billLines(t)}
          <div class="divider"></div>
          <div class="row" style="justify-content:space-between">
            <button class="link--plain" type="button" data-nav="#/cart" style="font-size:10.5px">${couponText(t)}</button>
            ${earnNote(t.coinsEarned, t.earnRule ? t.earnRule.name : '')}
          </div>
        </div>
        <div class="pickup-note mt-12">${I.icon(mode === 'pickup' ? 'store' : 'truck', 16)}<span>${mode === 'delivery' ? T('Free home delivery. Our rider will call you before arriving.', 'મફત હોમ ડિલિવરી. રાઇડર આવતાં પહેલાં કૉલ કરશે.') : T('Your order will be packed and kept ready at the Alkapuri counter.', 'તમારો ઓર્ડર પેક થઈને અલકાપુરી કાઉન્ટર પર તૈયાર રહેશે.')}</span></div>
      </div>
      <div class="actionbar">
        <div class="actionbar__total"><small>${T('Total payable', 'કુલ ચૂકવવાનું')}</small><strong>${money(t.total)}</strong></div>
        <button class="btn btn--primary" type="button" data-action="place-order">${payLabel} · ${money(t.total)}</button>
      </div>
    </div>`;
  };

  function couponText(t) {
    if (t.couponOk) return T(`${t.coupon.coupon.code} · ${money(t.discount)} saved`, `${t.coupon.coupon.code} · ${money(t.discount)} બચ્યા`);
    if (STATE.cart.coupon) return T('Coupon unavailable', 'કૂપન ઉપલબ્ધ નથી');
    return t.coinsUsed ? T(`${t.coinsUsed} coins applied`, `${t.coinsUsed} કોઈન્સ લાગુ`) : T('No coupon applied', 'કોઈ કૂપન લાગુ નથી');
  }

  views.placed = function (route) {
    const order = orderByNumber(route.seg[1]);
    if (!order) return missingScreen('We could not find that order.', '#/orders', 'Order placed');
    const totals = orderTotals(order);
    const placedQty = order.items.reduce((n, it) => n + it.qty, 0);
    return `<div class="screen placed-screen">
      ${statusbar()}
      <div class="placed-body">
        <div class="placed-celebrate">
          <span class="success-orb">${I.icon('check', 40)}</span>
          <h1>${T('Order placed!', 'ઓર્ડર થઈ ગયો!')}</h1>
          <p>${order.mode === 'pickup' ? T('We’ll message you when it’s ready for pickup.', 'પિકઅપ માટે તૈયાર થાય ત્યારે સંદેશ મોકલીશું.') : T('Your order is with our Alkapuri store.', 'તમારો ઓર્ડર અમારી અલકાપુરી દુકાનમાં છે.')}</p>
        </div>

        <div class="card card--pad placed-summary">
          <div class="between">
            <div><div class="eyebrow eyebrow--red">${T('ORDER', 'ઓર્ડર')} ${esc(order.number)}</div><div class="strong" style="font-size:13px;margin-top:5px">${order.mode === 'pickup' ? esc(order.slot) : T('Arriving today by 8 PM', 'આજે 8 વાગ્યા સુધી')}</div></div>
            ${customerStatusPill(order.status)}
          </div>
          <div class="divider"></div>
          ${billLines(totals)}
          <div class="divider"></div>
          <div class="between">
            <div><span class="hint">${esc(paymentName(order.payment))}</span><div class="strong" style="margin-top:3px">${customerPayPill(order.paymentState)}</div></div>
            <div class="text-right"><span class="hint">${placedQty} ${placedQty === 1 ? T('item', 'વસ્તુ') : T('items', 'વસ્તુઓ')}</span><div class="strong" style="margin-top:3px">${money(order.bill.total)}</div></div>
          </div>
        </div>

        ${order.coinsEarned ? `<div class="coins-panel mt-12">
          <span class="coin-orb coin-orb--sm">${I.icon('coin', 19)}</span>
          <div class="coins-panel__copy"><b>${order.coinsEarned} ${T('coins on the way', 'કોઈન્સ રસ્તામાં')}</b><span>${T(`They’ll be credited to your wallet after ${order.mode === 'pickup' ? 'pickup' : 'delivery'}.`, `${order.mode === 'pickup' ? 'પિકઅપ' : 'ડિલિવરી'} પછી વોલેટમાં ઉમેરાશે.`)}</span></div>
        </div>` : ''}

        <div class="card info-card mt-12">
          <span class="info-card__icon info-card__icon--navy">${I.icon(order.mode === 'pickup' ? 'store' : 'pin', 17)}</span>
          <div class="grow"><h3>${order.mode === 'pickup' ? T('Pickup from', 'પિકઅપ સ્થળ') : T('Delivering to', 'ડિલિવરી સરનામું')}</h3><p>${esc(order.address)}</p></div>
        </div>

        <div class="placed-actions">
          <button class="btn btn--primary" type="button" data-nav="#/track/${order.number}">${I.icon('truck', 18)} ${T('Track my order', 'ઓર્ડર ટ્રેક કરો')}</button>
          <button class="btn btn--secondary" type="button" data-nav="#/shop">${T('Continue shopping', 'ખરીદી ચાલુ રાખો')}</button>
        </div>
      </div>
    </div>`;
  };

  views.track = function (route) {
    const order = orderByNumber(route.seg[1]);
    if (!order) return missingScreen('We could not find that order.', '#/orders', 'Tracking');
    const steps = orderSteps(order);
    const idx = currentStepIndex(order);
    const cancelled = order.status === 'Cancelled';
    const done = order.mode === 'pickup' ? ['Placed', 'Confirmed', 'Packed', 'Ready for Pickup', 'Picked Up'] : ['Placed', 'Confirmed', 'Packed', 'Out for Delivery', 'Delivered'];
    const stepCopy = {
      'Placed': T('Order received by the store', 'દુકાને ઓર્ડર મળ્યો'),
      'Confirmed': T('Store confirmed your items', 'દુકાને વસ્તુઓ કન્ફર્મ કરી'),
      'Packed': T('Packed and bill checked', 'પેક થયો અને બિલ ચકાસ્યું'),
      'Out for Delivery': T('Rider is on the way', 'રાઇડર રસ્તે છે'),
      'Ready for Pickup': T('Waiting at the store counter', 'દુકાન કાઉન્ટર પર તૈયાર'),
      'Delivered': T('Handed over at your door', 'તમારા ઘરે પહોંચાડ્યો'),
      'Picked Up': T('Collected from the store', 'દુકાનથી લઈ લીધો')
    };
    return `<div class="screen">
      ${statusbar()}
      ${appbar({ title: T('Track order', 'ઓર્ડર ટ્રેક કરો'), sub: `${order.number} · ${order.mode === 'pickup' ? T('Store pickup', 'સ્ટોર પિકઅપ') : T('Home delivery', 'હોમ ડિલિવરી')}`, back: '#/orders', right: `<button class="icon-btn icon-btn--sm" type="button" data-action="support" aria-label="Support">${I.icon('phone', 17)}</button>` })}
      <div class="screen-scroll screen-scroll--end">
        <div class="live-card">
          <span class="eyebrow">${cancelled ? T('ORDER CANCELLED', 'ઓર્ડર રદ') : order.mode === 'pickup' ? T('PICKUP ORDER', 'પિકઅપ ઓર્ડર') : T('LIVE DELIVERY', 'લાઇવ ડિલિવરી')}</span>
          <div class="live-status">${esc(cStatus(order.status))}</div>
          <div class="live-sub">${esc(orderEta(order))}</div>
          <span class="pill">${esc(timeOnly(order.updatedAt))}</span>
        </div>

        ${cancelled ? `<div class="card card--pad mt-12">
          <div class="row"><span class="info-card__icon">${I.icon('info', 18)}</span><div class="grow"><h3 style="font-size:12px;font-weight:800">${T('Why this was cancelled', 'કેમ રદ થયો')}</h3><p style="font-size:10.5px;color:var(--ink-2);margin-top:3px">${esc(reasonLabel(order.cancelReason) || T('Cancelled by the store', 'દુકાને ઓર્ડર રદ કર્યો'))}</p></div></div>
          ${order.coinsUsed ? `<div class="note-strip mt-12">${I.icon('coin', 14)}<span>${T(`${order.coinsUsed} coins have been returned to your wallet. Prepaid amounts are refunded in 3–5 working days.`, `${order.coinsUsed} કોઈન્સ તમારા વોલેટમાં પાછા મળ્યા છે. પ્રીપેઇડ રકમ 3–5 કાર્યકારી દિવસમાં પરત મળશે.`)}</span></div>` : ''}
        </div>` : `<div class="card timeline-card mt-12">
          ${steps.map((step, i) => {
            const entries = order.statusHistory.filter((h) => h.status === step);
            const entry = i <= idx ? entries[entries.length - 1] : null;
            let cls = 'is-todo';
            if (i < idx) cls = 'is-done';
            else if (i === idx) cls = order.status === 'Delivered' || order.status === 'Picked Up' ? 'is-done' : 'is-current';
            else if ((order.status === 'Delivered' || order.status === 'Picked Up') && i <= idx) cls = 'is-done';
            if (i === steps.length - 1) cls += ' is-last';
            return `<div class="tl ${cls}">
              <div class="tl__rail"><span class="tl__dot">${entry ? I.icon('check', 13) : i === idx ? I.icon('clock', 12) : ''}</span><span class="tl__line"></span></div>
              <div class="tl__body"><b>${esc(cStatus(step))}</b><span>${entry ? `${formatDate(entry.at)} · ${formatTime(entry.at)}` : stepCopy[step]}</span></div>
            </div>`;
          }).join('')}
        </div>`}

        ${order.mode === 'delivery' && order.partner ? `<div class="card partner mt-12">
          <span class="partner__avatar">${I.icon('user', 20)}</span>
          <div class="grow"><b>${esc(order.partner.name)}</b><span>${esc(order.partner.role)} · ${esc(order.partner.phone)}</span></div>
          <a class="call-round" href="tel:${String(order.partner.phone).replace(/\s/g, '')}" aria-label="Call rider">${I.icon('phone', 16)}</a>
        </div>` : ''}

        ${order.mode === 'pickup' && order.status !== 'Cancelled' ? `<div class="pickup-note mt-12">${I.icon('store', 16)}<span><b>${T('Pickup counter', 'પિકઅપ કાઉન્ટર')}</b><br>${esc(order.address)}<br>${esc(order.slot || 'Today · 6:00 – 8:00 PM')} · ${esc(D.store.phone)}</span></div>` : ''}

        <div class="card info-card mt-12">
          <span class="info-card__icon">${I.icon(order.mode === 'pickup' ? 'store' : 'pin', 17)}</span>
          <div class="grow"><h3>${order.mode === 'pickup' ? T('Collect from', 'અહીંથી લો') : T('Delivering to', 'ડિલિવરી સરનામું')}</h3><p>${esc(order.address)}</p></div>
        </div>

        <div class="card card--pad bill-card mt-12">
          <div class="between mb-12"><h3 style="font-size:12px;font-weight:800">${T('Order details', 'ઓર્ડર વિગત')}</h3>${customerStatusPill(order.status)}</div>
          ${order.items.map((it) => `<div class="order-item">
            <span class="thumb thumb--xs tone-${it.tone}">${I.art(it.art)}</span>
            <div class="grow"><h3>${esc(STATE.lang === 'gu' ? it.nameGu : it.name)}</h3><span>${esc(it.unit)} × ${it.qty}</span></div>
            <b>${money(it.price * it.qty)}</b>
          </div>`).join('')}
          <div class="divider"></div>
          ${billLines({ subtotal: order.bill.subtotal, discount: order.bill.couponDiscount, couponCode: order.bill.couponCode, coinsUsed: order.coinsUsed, coinDiscount: order.coinsUsed, total: order.bill.total })}
          <div class="divider"></div>
          <div class="between"><span class="hint">${esc(paymentName(order.payment))}</span>${customerPayPill(order.paymentState)}</div>
        </div>

        ${order.status === 'Placed' ? `<div class="cancel-row mt-12"><button class="btn btn--danger-soft btn--sm" type="button" data-action="cancel-order-sheet" data-number="${order.number}">${T('Cancel this order', 'આ ઓર્ડર રદ કરો')}</button></div>` : ''}

        <div class="admin-action-grid">
          <button class="btn btn--secondary btn--sm" type="button" data-action="support">${I.icon('phone', 15)} ${T('Call store', 'દુકાનને કૉલ')}</button>
          <button class="btn btn--secondary btn--sm" type="button" data-action="reorder" data-number="${order.number}">${I.icon('refresh', 15)} ${T('Order again', 'ફરી ઓર્ડર')}</button>
        </div>
        <p class="hint hint--center mt-16">${T('Need help with this order?', 'આ ઓર્ડરમાં મદદ જોઈએ?')} <a href="tel:${D.store.phoneHref}" class="link">${esc(D.store.phone)}</a></p>
      </div>
    </div>`;
  };

  views.orders = function () {
    const all = userOrders();
    const filter = ui.ordersFilter;
    const list = all.filter((o) => {
      if (filter === 'active') return isActiveOrder(o);
      if (filter === 'completed') return o.status === 'Delivered' || o.status === 'Picked Up';
      if (filter === 'cancelled') return o.status === 'Cancelled';
      return true;
    });
    const counts = {
      all: all.length,
      active: all.filter(isActiveOrder).length,
      completed: all.filter((o) => o.status === 'Delivered' || o.status === 'Picked Up').length,
      cancelled: all.filter((o) => o.status === 'Cancelled').length
    };
    return `<div class="screen">
      ${statusbar()}
      ${appbar({ title: T('My orders', 'મારા ઓર્ડર'), sub: `${all.length} ${all.length === 1 ? T('order from Vijay Super Mall', 'વિજય સુપર મોલમાંથી ઓર્ડર') : T('orders from Vijay Super Mall', 'વિજય સુપર મોલમાંથી ઓર્ડર')}`, back: '#/profile' })}
      <div class="screen-scroll screen-scroll--end">
        <div class="chips">
          ${[['all', 'All'], ['active', 'Active'], ['completed', 'Completed'], ['cancelled', 'Cancelled']].map(([key, label]) => `<button class="chip chip--sm${filter === key ? ' is-active' : ''}" type="button" data-action="orders-filter" data-filter="${key}">${T(label, label === 'All' ? 'બધા' : label === 'Active' ? 'ચાલુ' : label === 'Completed' ? 'પૂર્ણ' : 'રદ')} · ${counts[key]}</button>`).join('')}
        </div>
        ${list.length ? `<div class="stack">${list.map((order) => {
          const totalQty = order.items.reduce((n, it) => n + it.qty, 0);
          return `<article class="card customer-order">
            <div class="customer-order__head">
              <div><h3>${esc(order.number)}</h3><div class="customer-order__meta">${formatDate(order.placedAt)} · ${timeOnly(order.placedAt)} · ${order.mode === 'pickup' ? T('Store pickup', 'સ્ટોર પિકઅપ') : T('Home delivery', 'હોમ ડિલિવરી')}</div></div>
              ${customerStatusPill(order.status)}
            </div>
            <div class="customer-order__items">
              ${order.items.slice(0, 3).map((it) => `<span class="thumb tone-${it.tone}">${I.art(it.art)}</span>`).join('')}
              ${order.items.length > 3 ? `<span class="customer-order__more">+${order.items.length - 3} ${T('more', 'વધુ')}</span>` : `<span class="customer-order__more">${totalQty} ${totalQty === 1 ? T('item', 'વસ્તુ') : T('items', 'વસ્તુઓ')}</span>`}
            </div>
            <div class="customer-order__foot">
              <div><div class="hint">${order.coinsEarned && order.status !== 'Cancelled' ? `+${order.coinsEarned} ${T('coins', 'કોઈન્સ')} · ` : ''}${esc(paymentName(order.payment))}</div><div class="customer-order__total">${money(order.bill.total)}</div></div>
              <div class="customer-order__actions">
                ${order.status === 'Placed' ? `<button class="btn btn--danger-soft btn--xs" type="button" data-action="cancel-order-sheet" data-number="${order.number}">${T('Cancel', 'રદ કરો')}</button>` : ''}
                ${order.status === 'Delivered' || order.status === 'Picked Up' || order.status === 'Cancelled' ? `<button class="btn btn--secondary btn--xs" type="button" data-action="reorder" data-number="${order.number}">${T('Reorder', 'ફરી ઓર્ડર')}</button>` : ''}
                <button class="btn btn--primary btn--xs" type="button" data-nav="#/track/${order.number}">${isActiveOrder(order) ? T('Track', 'ટ્રેક કરો') : T('Details', 'વિગત')} ${I.icon('right', 12)}</button>
              </div>
            </div>
          </article>`;
        }).join('')}</div>` : emptyState('box', T('No orders here', 'અહીં કોઈ ઓર્ડર નથી'), T('Your orders will appear here once you place one.', 'ઓર્ડર કર્યા પછી અહીં દેખાશે.'), `<button class="btn btn--primary btn--sm" type="button" data-nav="#/shop">${T('Start shopping', 'ખરીદી શરૂ કરો')}</button>`)}
      </div>
    </div>`;
  };

  views.wallet = function () {
    const balance = coinBalance();
    const pending = coinPending();
    const ledger = ui.showAllLedger ? sortedLedger() : sortedLedger().slice(0, 5);
    const standard = bestEarnRule(1000).rule || STATE.coinRules[0];
    return `<div class="screen">
      ${statusbar()}
      <div class="appbar">
        <div class="appbar__text"><h1>${T('Coin wallet', 'કોઈન વોલેટ')}</h1><p class="appbar__sub">${T('1 coin = ₹1 at checkout', 'ચેકઆઉટ પર 1 કોઈન = ₹1')}</p></div>
        <button class="icon-btn icon-btn--sm" type="button" data-action="how-coins" aria-label="How coins work">${I.icon('info', 17)}</button>
      </div>
      <div class="screen-scroll">
        <div class="wallet-hero">
          <span class="eyebrow">${T('YOUR COINS', 'તમારા કોઈન્સ')}</span>
          <div class="wallet-balance">${balance}</div>
          <div class="wallet-worth">${T('Worth', 'કિંમત')} ${money(balance)}${pending ? ` · ${pending} ${T('coins pending', 'કોઈન્સ બાકી')}` : ''}</div>
          <span class="wallet-coin">${I.icon('coin', 30)}</span>
        </div>

        <div class="card earn-rule-card mt-12">
          <div class="between"><h3>${T('How you earn', 'કેવી રીતે કમાઓ')}</h3><button class="link" type="button" data-action="how-coins">${T('View rules', 'નિયમો જુઓ')}</button></div>
          <div class="rule-chips">
            <span class="rule-chip">₹${standard ? standard.spend : 1000}</span>${I.icon('arrow', 13)}<span class="rule-chip">${standard ? standard.coins : 10} ${T('coins', 'કોઈન્સ')}</span>
            <span class="hint">${standard && standard.mode === 'slab' ? T('on every slab', 'દરેક સ્લેબ પર') : T('pro-rata', 'પ્રમાણસર')}</span>
          </div>
          <p class="hint mt-8">${T('Coins are credited after delivery or pickup. Redeem them on eligible items at checkout.', 'ડિલિવરી કે પિકઅપ પછી કોઈન્સ મળે. ચેકઆઉટ પર માન્ય વસ્તુઓમાં વાપરો.')}</p>
        </div>

        <div class="admin-action-grid">
          <button class="btn btn--gold btn--sm" type="button" data-nav="#/shop">${I.icon('coin', 15)} ${T('Earn more', 'વધુ કમાઓ')}</button>
          <button class="btn btn--secondary btn--sm" type="button" data-nav="#/cart">${I.icon('cart', 15)} ${T('Spend coins', 'કોઈન્સ વાપરો')}</button>
        </div>

        <div class="section-head">
          <h2 style="font-size:16px">${T('Coin activity', 'કોઈન પ્રવૃત્તિ')}</h2>
          <span class="hint">${pending ? `${pending} ${T('pending', 'બાકી')}` : T('All settled', 'બધું પતી ગયું')}</span>
        </div>
        <div class="card wallet-list-card">
          ${ledger.length ? ledger.map((l) => `<div class="ledger-item">
            <span class="ledger-item__icon${l.coins < 0 ? ' ledger-item__icon--spend' : l.status === 'pending' ? ' ledger-item__icon--pending' : ''}">${I.icon(l.type === 'spend' ? 'cart' : l.type === 'bonus' ? 'gift' : 'coin', 17)}</span>
            <div class="grow"><b>${esc(l.title)}</b><span>${esc(l.sub)} · ${formatDate(l.date)}${l.status === 'pending' ? ` · ${T('Pending', 'બાકી')}` : ''}</span></div>
            <span class="ledger-coins ${l.coins < 0 ? 'ledger-coins--minus' : l.status === 'pending' ? 'ledger-coins--pending' : 'ledger-coins--plus'}">${l.coins > 0 ? '+' : ''}${l.coins}</span>
          </div>`).join('') : emptyState('coin', T('No coin activity yet', 'હજી કોઈ કોઈન પ્રવૃત્તિ નથી'), T('Place an order to start earning coins.', 'કોઈન્સ કમાવા ઓર્ડર કરો.'))}
        </div>
        ${sortedLedger().length > 5 ? `<div class="center mt-12"><button class="link" type="button" data-action="toggle-ledger">${ui.showAllLedger ? T('Show less', 'ઓછું બતાવો') : T('View all activity', 'બધી પ્રવૃત્તિ જુઓ')}</button></div>` : ''}
        <p class="hint hint--center mt-16">${I.icon('clock', 11)} ${T(`Coins expire ${STATE.coinSettings.expiryMonths} months after they’re earned. Oldest coins are used first.`, `કોઈન્સ મળ્યાના ${STATE.coinSettings.expiryMonths} મહિના પછી માન્ય રહેશે નહીં.`)}</p>
      </div>
      ${customerNav('wallet')}
    </div>`;
  };

  views.profile = function () {
    const orders = userOrders();
    const balance = coinBalance();
    const lang = STATE.lang;
    return `<div class="screen">
      ${statusbar()}
      <div class="appbar">
        <div class="appbar__text"><h1>${T('Profile', 'પ્રોફાઇલ')}</h1><p class="appbar__sub">${T('Account & preferences', 'એકાઉન્ટ અને પસંદગીઓ')}</p></div>
        <button class="icon-btn icon-btn--sm" type="button" data-action="support" aria-label="Support">${I.icon('phone', 17)}</button>
      </div>
      <div class="screen-scroll">
        <div class="profile-hero">
          <span class="avatar">${initials(STATE.user.name)}</span>
          <div class="grow">
            <h2>${esc(STATE.user.name)}</h2>
            <p>+91 ${esc(STATE.user.phone)} · ${T('Member since Nov 2025', 'નવેમ્બર 2025થી સભ્ય')}</p>
            <div class="profile-stat-row">
              <div class="profile-stat"><b>${orders.length}</b><span>${T('Orders', 'ઓર્ડર')}</span></div>
              <div class="profile-stat"><b>${balance}</b><span>${T('Coins', 'કોઈન્સ')}</span></div>
              <div class="profile-stat"><b>${STATE.wishlist.length}</b><span>${T('Saved', 'સેવ કરેલા')}</span></div>
            </div>
          </div>
        </div>

        <div class="section-head"><h2 style="font-size:16px">${T('My account', 'મારું એકાઉન્ટ')}</h2><span class="pill pill--gold">${I.icon('coin', 11)} ${balance} ${T('coins', 'કોઈન્સ')}</span></div>
        <div class="card menu-card">
          <button class="menu-item" type="button" data-nav="#/orders">
            <span class="menu-item__icon">${I.icon('box', 16)}</span>
            <div class="grow"><b>${T('My orders', 'મારા ઓર્ડર')}</b><small>${T('Track, cancel or reorder', 'ટ્રેક કરો, રદ કરો કે ફરી ઓર્ડર કરો')}</small></div>
            ${I.icon('right', 16)}
          </button>
          <button class="menu-item" type="button" data-action="open-wishlist">
            <span class="menu-item__icon menu-item__icon--red">${I.icon('heart', 16)}</span>
            <div class="grow"><b>${T('Saved items', 'સેવ કરેલી વસ્તુઓ')}</b><small>${STATE.wishlist.length} ${T('products from the mall', 'મોલની વસ્તુઓ')}</small></div>
            ${I.icon('right', 16)}
          </button>
          <button class="menu-item" type="button" data-action="open-addresses">
            <span class="menu-item__icon menu-item__icon--gold">${I.icon('pin', 16)}</span>
            <div class="grow"><b>${T('Delivery addresses', 'ડિલિવરી સરનામાં')}</b><small>${esc(selectedAddress().label)} · ${esc(selectedAddress().detail.slice(0, 30))}…</small></div>
            ${I.icon('right', 16)}
          </button>
          <button class="menu-item" type="button" data-nav="#/wallet">
            <span class="menu-item__icon menu-item__icon--gold">${I.icon('wallet', 16)}</span>
            <div class="grow"><b>${T('Coin wallet', 'કોઈન વોલેટ')}</b><small>${balance} ${T('coins worth', 'કોઈન્સની કિંમત')} ${money(balance)}</small></div>
            ${I.icon('right', 16)}
          </button>
        </div>

        <div class="section-head"><h2 style="font-size:16px">${T('Preferences', 'પસંદગીઓ')}</h2></div>
        <div class="card menu-card">
          <div class="menu-item">
            <span class="menu-item__icon">${I.icon('settings', 16)}</span>
            <div class="grow"><b>${T('App language', 'એપ ભાષા')}</b><small>${T('English & ગુજરાતી', 'અંગ્રેજી અને ગુજરાતી')}</small></div>
            <div class="lang-toggle">
              <button type="button" class="${lang === 'en' ? 'is-active' : ''}" data-action="set-lang" data-lang="en">EN</button>
              <button type="button" class="${lang === 'gu' ? 'is-active' : ''}" data-action="set-lang" data-lang="gu">ગુ</button>
            </div>
          </div>
          <div class="menu-item">
            <span class="menu-item__icon menu-item__icon--green">${I.icon('bell', 16)}</span>
            <div class="grow"><b>${T('Order notifications', 'ઓર્ડર સૂચનાઓ')}</b><small>${T('Status updates and coin alerts', 'સ્થિતિ અપડેટ અને કોઈન એલર્ટ')}</small></div>
            <label class="switch"><input type="checkbox" data-change="toggle-notifications" ${STATE.settings.notifications ? 'checked' : ''}></label>
          </div>
          <button class="menu-item" type="button" data-action="store-info">
            <span class="menu-item__icon">${I.icon('store', 16)}</span>
            <div class="grow"><b>${T('Store information', 'દુકાનની માહિતી')}</b><small>${esc(D.store.address)}</small></div>
            ${I.icon('right', 16)}
          </button>
          <button class="menu-item" type="button" data-action="how-coins">
            <span class="menu-item__icon menu-item__icon--gold">${I.icon('info', 16)}</span>
            <div class="grow"><b>${T('How coins work', 'કોઈન્સ કેવી રીતે ચાલે')}</b><small>${T('Earning, redemption and expiry', 'કમાણી, વપરાશ અને સમાપ્તિ')}</small></div>
            ${I.icon('right', 16)}
          </button>
        </div>

        <div class="section-head"><h2 style="font-size:16px">${T('Store access', 'સ્ટોર એક્સેસ')}</h2></div>
        <div class="card menu-card">
          <button class="menu-item" type="button" data-nav="#/admin">
            <span class="menu-item__icon">${I.icon('chart', 16)}</span>
            <div class="grow"><b>${T('Owner admin panel', 'માલિક એડમિન પેનલ')}</b><small>${T('Orders, stock, coins and reports', 'ઓર્ડર, સ્ટોક, કોઈન્સ અને રિપોર્ટ')}</small></div>
            ${I.icon('right', 16)}
          </button>
          <button class="menu-item" type="button" data-action="sign-out">
            <span class="menu-item__icon menu-item__icon--red">${I.icon('logout', 16)}</span>
            <div class="grow"><b class="red">${T('Sign out', 'સાઇન આઉટ')}</b><small>${T('Return to the welcome screen', 'વેલકમ સ્ક્રીન પર પાછા જાઓ')}</small></div>
            ${I.icon('right', 16)}
          </button>
        </div>

        <div class="card store-mini mt-12">
          <span class="thumb tone-gold" style="width:42px;height:42px;border-radius:13px">${I.logo(30)}</span>
          <div class="grow"><b>${D.store.name} · ${D.store.nameGu}</b><p>${esc(D.store.address)}<br>${T('FREE home delivery', 'મફત હોમ ડિલિવરી')} · ${esc(D.store.phone)}</p></div>
          <a class="call-round" href="tel:${D.store.phoneHref}" aria-label="Call store">${I.icon('phone', 15)}</a>
        </div>
        <p class="hint hint--center mt-16">Vijay Super Mall · App prototype v1.0<br>EN + ગુજરાતી · Free home delivery</p>
      </div>
      ${customerNav('profile')}
    </div>`;
  };

  /* ---------- customer sheets ---------- */
  sheets.notifications = function () {
    const feed = [];
    userOrders().slice(0, 4).forEach((order) => {
      feed.push({
        icon: order.status === 'Delivered' ? 'check' : 'box', tone: 'navy',
        title: `Order ${order.number} · ${statusLabel(order.status)}`,
        sub: `${orderEta(order)} · ${whenLabel(order.updatedAt)}`,
        href: `#/track/${order.number}`
      });
    });
    STATE.ledger.filter((l) => l.type === 'bonus' || l.type === 'refund').slice(0, 3).forEach((l) => {
      feed.push({ icon: 'gift', tone: 'gold', title: l.title, sub: `${l.coins > 0 ? '+' : ''}${l.coins} coins · ${whenLabel(l.date)}`, href: '#/wallet' });
    });
    return sheetShell('Notifications', STATE.settings.notifications ? 'Order updates and reward alerts' : 'Notifications are quiet in your profile', `
      ${!STATE.settings.notifications ? `<div class="sheet__note">${I.icon('bell', 13)} Order notifications are turned off. You can switch them back on from Profile.</div>` : ''}
      <div class="card wallet-list-card mt-8">
        ${feed.map((item) => `<div class="ledger-item" role="link" tabindex="0" data-nav="${item.href}">
          <span class="ledger-item__icon${item.tone === 'gold' ? '' : ''}">${I.icon(item.icon, 17)}</span>
          <div class="grow"><b>${esc(item.title)}</b><span>${esc(item.sub)}</span></div>
          ${I.icon('right', 14)}
        </div>`).join('')}
      </div>
      <div class="sheet__actions">
        <button class="btn btn--primary btn--block" type="button" data-nav="#/orders">View my orders</button>
        <button class="btn btn--soft btn--block" type="button" data-action="close-sheet">Done</button>
      </div>`);
  };

  sheets.addresses = function () {
    return sheetShell('Delivery address', 'Where should we deliver this order?', `
      <div class="stack">
        ${STATE.addresses.map((a) => `<button class="sheet-option${STATE.selectedAddress === a.id ? ' is-selected' : ''}" type="button" data-action="select-address" data-id="${a.id}">
          <div><b>${esc(a.label)}</b><small>${esc(a.detail)} · ${esc(a.phone)}</small></div>
          <span class="radio"></span>
        </button>`).join('')}
      </div>
      <form class="mt-16" data-form="add-address">
        <h3 style="font-size:11px;font-weight:800;color:var(--ink-2);margin-bottom:8px">Add another address</h3>
        <div class="field-row">
          <div class="field"><label>Label</label><input class="input" name="label" placeholder="Work" maxlength="20"></div>
          <div class="field"><label>Phone</label><input class="input" name="phone" placeholder="98765 43210" maxlength="12"></div>
        </div>
        <div class="field mt-8"><label>Full address</label><input class="input" name="detail" placeholder="Flat, street, area, city" maxlength="90"></div>
        <button class="btn btn--soft btn--block mt-12" type="submit">${I.icon('plus', 15)} Save address</button>
      </form>
      <div class="sheet__actions"><button class="btn btn--secondary btn--block" type="button" data-action="close-sheet">Done</button></div>`);
  };

  sheets.coupon = function () {
    const t = cartTotals();
    const offers = STATE.coupons.filter((c) => couponDateStatus(c) === 'active');
    return sheetShell('Coupons & offers', 'Discounts are applied before your coins', `
      ${STATE.cart.coupon && t.couponOk ? `<div class="coupon-row">
        <span class="coupon-row__icon">${I.icon('ticket', 16)}</span>
        <div class="grow"><b>${esc(t.coupon.coupon.code)} applied</b><span class="hint">You saved ${money(t.discount)}</span></div>
        <button type="button" data-action="remove-coupon">Remove</button>
      </div>` : ''}
      <form class="mt-12" data-form="apply-coupon">
        <div class="field"><label>Coupon code</label>
          <div class="row">
            <input class="input" name="code" placeholder="e.g. FESTIVE50" autocomplete="off" style="text-transform:uppercase">
            <button class="btn btn--primary btn--sm" type="submit" style="flex:none">Apply</button>
          </div>
        </div>
        ${ui.couponMsg ? `<div class="sheet__error">${esc(ui.couponMsg)}</div>` : ''}
      </form>
      <div class="section-head" style="margin-top:16px"><h2 style="font-size:14px">Live offers</h2><span class="hint">${offers.length} available</span></div>
      <div>
        ${offers.map((c) => {
          const check = couponCheck(c.code, t.details);
          return `<button class="sheet-offer" type="button" data-action="use-coupon" data-code="${esc(c.code)}" ${check.ok ? '' : 'style="opacity:.72"'}>
            <span class="sheet-offer__icon">${I.icon(c.type === 'percent' ? 'percent' : 'ticket', 17)}</span>
            <div class="grow"><b>${esc(c.code)}</b><span>${esc(c.desc)}${check.ok ? ` · Save ${money(check.discount)}` : ` · ${esc(check.message)}`}</span></div>
            ${check.ok ? I.icon('right', 15) : I.icon('info', 14)}
          </button>`;
        }).join('')}
      </div>
      <div class="sheet__note">${I.icon('info', 12)} Coupons apply to the eligible item value. Coins can be combined unless the offer says otherwise. Minimum cart value is checked before the discount.</div>
      <div class="sheet__actions">
        ${STATE.cart.coupon ? `<button class="btn btn--soft btn--block" type="button" data-action="remove-coupon">Remove coupon</button>` : ''}
        <button class="btn btn--secondary btn--block" type="button" data-action="close-sheet">Done</button>
      </div>`);
  };

  sheets.coins = function () {
    const t = cartTotals();
    const cap = Math.min(t.balance, t.cap);
    const percent = Math.min(Math.floor((t.balance * (Number(STATE.cart.coinPercent) || 50)) / 100), t.cap);
    return sheetShell('Use your coins', `${t.balance} coins = ${money(t.balance)}`, `
      <div class="coins-panel">
        <span class="coin-orb coin-orb--sm">${I.icon('coin', 19)}</span>
        <div class="coins-panel__copy">
          <b>${t.coinsUsed} coins applied</b>
          <span>Eligible value ${money(t.eligibleBase)} · up to ${t.cap} coins can be used on this order.</span>
        </div>
      </div>
      ${!t.canUseCoins ? `<div class="sheet__error mt-12">${t.coupon && t.coupon.coupon ? t.coupon.coupon.code : 'This coupon'} can’t be combined with coins. Remove the coupon to use coins.</div>` : ''}
      ${t.cap <= 0 ? `<div class="sheet__note mt-12">None of the items in this cart accept coins. Items like tea and oil can’t be paid for with coins.</div>` : `
        <div class="stack mt-12">
          <button class="sheet-option${STATE.cart.coinMode === 'all' ? ' is-selected' : ''}" type="button" data-action="set-coin-mode" data-mode="all">
            <div><b>Use all my coins</b><small>${cap} coins · save ${money(cap)}</small></div>
            <span class="radio"></span>
          </button>
          <button class="sheet-option${STATE.cart.coinMode === 'percent' ? ' is-selected' : ''}" type="button" data-action="set-coin-mode" data-mode="percent">
            <div><b>Use ${STATE.cart.coinPercent}% of my coins</b><small>${percent} coins · save ${money(percent)}</small></div>
            <span class="radio"></span>
          </button>
          <div class="sheet-option${STATE.cart.coinMode === 'custom' ? ' is-selected' : ''}" style="display:block">
            <div class="row" style="margin-bottom:8px"><div class="grow"><b>Choose an amount</b><small>Up to ${cap} coins</small></div><span class="radio"></span></div>
            <form class="row" data-form="coins-custom">
              <input class="input" name="coins" type="number" min="1" max="${Math.max(1, cap)}" value="${STATE.cart.coinMode === 'custom' ? esc(STATE.cart.coinCustom) : ''}" placeholder="Coins to use" style="height:42px">
              <button class="btn btn--primary btn--sm" type="submit" style="flex:none">Apply</button>
            </form>
          </div>
        </div>
        ${STATE.cart.useCoins && t.coinsUsed ? `<button class="btn btn--soft btn--block mt-12" type="button" data-action="stop-coins">Don’t use coins on this order</button>` : ''}
      `}
      <div class="sheet__note">1 coin = ₹1. A coupon discount is applied first, then coins against eligible items only. Coins are deducted immediately when you place the order.</div>
      <div class="sheet__actions"><button class="btn btn--secondary btn--block" type="button" data-action="close-sheet">Done</button></div>`);
  };

  sheets.filters = function () {
    const sorts = [
      ['popular', 'Most popular'],
      ['price-low', 'Price: low to high'],
      ['price-high', 'Price: high to low'],
      ['rating', 'Top rated']
    ];
    return sheetShell('Filter products', 'Find exactly what you need', `
      <div class="filter-group">
        <h3>Sort by</h3>
        <div class="sort-list">
          ${sorts.map(([key, label]) => `<button class="sort-option${ui.shop.sort === key ? ' is-selected' : ''}" type="button" data-action="set-sort" data-sort="${key}">${label}${ui.shop.sort === key ? I.icon('check', 15) : ''}</button>`).join('')}
        </div>
      </div>
      <div class="filter-group">
        <h3>Show only</h3>
        <div class="toggle-row">
          <div><b>In stock</b><small>Hide items that are sold out</small></div>
          <label class="switch"><input type="checkbox" data-change="filter-stock" ${ui.shop.stock ? 'checked' : ''}></label>
        </div>
        <div class="toggle-row">
          <div><b>Coins eligible</b><small>Earn or redeem coins on these items</small></div>
          <label class="switch"><input type="checkbox" data-change="filter-coins" ${ui.shop.coins ? 'checked' : ''}></label>
        </div>
      </div>
      <div class="sheet__actions">
        <button class="btn btn--primary btn--block" type="button" data-action="close-sheet">Show results</button>
        <button class="btn btn--soft btn--block" type="button" data-action="reset-shop">Clear all filters</button>
      </div>`);
  };

  sheets.cancel = function (s) {
    const order = orderByNumber(s.number);
    if (!order) return '';
    const reasons = ['Changed my mind', 'Ordered by mistake', 'Need a different address', 'Found a better price'];
    const by = s.by || 'customer';
    const isAdmin = by === 'admin';
    const L = isAdmin ? (en) => en : T;
    const modeLabel = order.mode === 'pickup' ? L('Store pickup', 'સ્ટોર પિકઅપ') : L('Home delivery', 'હોમ ડિલિવરી');
    const intro = isAdmin
      ? 'Tell us why you’re cancelling. Stock will be returned to inventory.'
      : `${L('Tell us why you’re cancelling.', 'રદ કરવાનું કારણ જણાવો.')} ${order.status === 'Placed' ? L('You can cancel while the order is still placed.', 'ઓર્ડર હજી પ્લેસ થયેલો હોય ત્યાં સુધી રદ કરી શકાય છે.') : ''}`;
    const prepaid = order.payment === 'UPI / Card' && order.paymentState === 'Paid';
    const note = isAdmin
      ? `${order.coinsUsed ? `${order.coinsUsed} coins used on this order will be returned to your wallet. ` : ''}${prepaid ? 'Your prepaid amount will be refunded in 3–5 working days. ' : ''}Stock is released back to the store immediately.`
      : `${order.coinsUsed ? L(`${order.coinsUsed} coins used on this order will be returned to your wallet. `, `${order.coinsUsed} કોઈન્સ તમારા વોલેટમાં પાછા મળશે. `) : ''}${prepaid ? L('Your prepaid amount will be refunded in 3–5 working days. ', 'તમારી પ્રીપેઇડ રકમ 3–5 કાર્યકારી દિવસમાં પરત મળશે. ') : ''}${L('Stock is released back to the store immediately.', 'સ્ટોક તરત જ દુકાનમાં પાછો ઉમેરાય છે.')}`;
    return sheetShell(L('Cancel order?', 'ઓર્ડર રદ કરવો છે?'), `${order.number} · ${modeLabel}`, `
      <p class="hint">${intro}</p>
      <div class="stack mt-12">
        ${reasons.map((r) => `<button class="sheet-option${ui.cancelReason === r ? ' is-selected' : ''}" type="button" data-action="set-cancel-reason" data-reason="${esc(r)}">
          <span>${esc(isAdmin ? r : reasonLabel(r))}</span><span class="radio"></span>
        </button>`).join('')}
      </div>
      <div class="sheet__note">${note}</div>
      <div class="sheet__actions">
        <button class="btn btn--danger-soft btn--block" type="button" data-action="confirm-cancel" data-number="${order.number}" data-by="${by}">${L('Cancel order', 'ઓર્ડર રદ કરો')}</button>
        <button class="btn btn--secondary btn--block" type="button" data-action="close-sheet">${isAdmin ? 'Keep order' : L('Keep my order', 'ઓર્ડર રાખો')}</button>
      </div>`);
  };

  sheets['order-stage'] = function (s) {
    const order = orderByNumber(s.number);
    if (!order) return '';
    const steps = orderSteps(order);
    const target = ui.stageTarget;
    const selected = steps.indexOf(target) !== -1 && target !== order.status;
    const modeLabel = order.mode === 'pickup' ? 'Store pickup' : 'Home delivery';
    const stageHint = {
      'Placed': 'Order received by the store',
      'Confirmed': 'Store accepted the order',
      'Packed': 'Items packed and bill checked',
      'Out for Delivery': 'Rider is on the way',
      'Delivered': 'Order completed and handed over',
      'Ready for Pickup': 'Waiting at the pickup counter',
      'Picked Up': 'Order collected from the store'
    };
    return sheetShell('Change order stage', `${order.number} · ${modeLabel}`, `
      <p class="hint">Advanced a stage by mistake? Move the order to the correct stage. The customer’s tracking and the status history update instantly.</p>
      <div class="stage-track mt-12">
        ${steps.map((step, i) => {
          const isCurrent = step === order.status;
          const isSelected = step === target && !isCurrent;
          return `<button class="stage-option${isCurrent ? ' is-current' : ''}${isSelected ? ' is-selected' : ''}" type="button" data-action="set-order-stage" data-stage="${esc(step)}"${isCurrent ? ' disabled' : ''}>
            <span class="stage-option__dot">${isCurrent ? I.icon('clock', 12) : isSelected ? I.icon('check', 12) : ''}</span>
            <span class="stage-option__body"><b>${statusLabel(step)}</b><small>${stageHint[step]} · Stage ${i + 1}</small></span>
            ${isCurrent ? `<span class="stage-option__tag">Current</span>` : `<span class="radio"></span>`}
          </button>`;
        }).join('')}
      </div>
      <div class="sheet__note stage-effect">${I.icon('info', 13)}<span>${selected ? orderStageEffect(order, target) : 'Choose the stage this order should be in.'}</span></div>
      <div class="sheet__actions">
        <button class="btn btn--primary btn--block" type="button" data-action="confirm-order-stage" data-number="${order.number}"${selected ? '' : ' disabled'}>${selected ? `Move to ${statusLabel(target)}` : 'Select a stage'}</button>
        <button class="btn btn--secondary btn--block" type="button" data-action="close-sheet">Keep current stage</button>
      </div>`);
  };

  sheets.restock = function (s) {
    const p = productById(s.id);
    if (!p) return '';
    return sheetShell('Add new stock', `${p.name} · ${p.stock} units on shelf`, `
      <p class="hint">Received a new purchase from the supplier? Enter the units received for each pack. We add it on top of the current shelf count.</p>
      <form class="restock-form" data-form="restock" data-id="${p.id}">
        <div class="restock-list mt-12">
          ${p.variants.map((v, i) => `<label class="restock-row">
            ${thumb(p, 'thumb--sm')}
            <div class="grow"><b>${esc(v.label)}</b><small>${money(v.price)} · ${variantStock(p, i)} on shelf</small></div>
            <span class="restock-field"><i>+</i><input class="input" name="add${i}" type="number" min="0" inputmode="numeric" placeholder="0" aria-label="Units received for ${esc(v.label)}"></span>
          </label>`).join('')}
        </div>
        <button class="restock-add" type="button" data-action="toggle-restock-pack">${I.icon('plus', 13)} Add a new pack</button>
        <div class="restock-new" hidden>
          <div class="field-row--4">
            <div class="field"><label>New pack</label><input class="input" name="newPackLabel" placeholder="2 kg"></div>
            <div class="field"><label>Price ₹</label><input class="input" name="newPackPrice" type="number" min="1" inputmode="numeric" placeholder="0"></div>
            <div class="field"><label>MRP ₹</label><input class="input" name="newPackMrp" type="number" min="1" inputmode="numeric" placeholder="0"></div>
            <div class="field"><label>Units in</label><input class="input" name="newPackStock" type="number" min="0" inputmode="numeric" placeholder="0"></div>
          </div>
          <p class="hint mt-8">New size or type? It is added to the product with the units received.</p>
        </div>
        <div class="sheet__note">${I.icon('info', 13)}<span>Only enter the new units received. Existing stock is not replaced.</span></div>
        <div class="sheet__actions">
          <button class="btn btn--primary btn--block" type="submit">Add to stock</button>
          <button class="btn btn--secondary btn--block" type="button" data-action="close-sheet">Cancel</button>
        </div>
      </form>`);
  };

  sheets['new-type'] = function () {
    return sheetShell('Add new type', 'Group products under a new type', `
      <form data-form="type-save">
        <div class="field"><label>Type name</label><input class="input" name="typeName" maxlength="32" placeholder="e.g. Dairy & eggs" required></div>
        <div class="field mt-8"><label>Gujarati name</label><input class="input gu" name="typeNameGu" maxlength="40" placeholder="દૂધ અને ઇંડા"></div>
        <p class="hint mt-8">This type will appear in the inventory filter, shop categories and add-product form.</p>
        <div class="sheet__actions">
          <button class="btn btn--primary btn--block" type="submit">Add type</button>
          <button class="btn btn--secondary btn--block" type="button" data-action="close-sheet">Cancel</button>
        </div>
      </form>`);
  };

  sheets['how-coins'] = function () {
    return sheetShell('How coins work', 'A simple rewards loop', `
      <div class="stack">
        <div class="card card--pad">
          <div class="form-card__title" style="margin-bottom:8px">${I.icon('coin', 15)} Earning</div>
          <p class="hint">Earn coins on delivered and picked-up orders. The best active rule is applied automatically — no stacking. A ₹1,000 order earns 10 coins at the standard rate.</p>
          <div class="rule-preview mt-8">Current rate: spend ₹1,000 → earn ${STATE.coinRules.find((r) => r.id === 'standard') ? STATE.coinRules.find((r) => r.id === 'standard').coins : 10} coins, pro-rata.</div>
        </div>
        <div class="card card--pad">
          <div class="form-card__title" style="margin-bottom:8px">${I.icon('cart', 15)} Redemption</div>
          <p class="hint">1 coin = ₹1. Use coins only on eligible products, after any coupon discount. Some items such as tea and oil do not accept coins. Each order has a per-order cap.</p>
        </div>
        <div class="card card--pad">
          <div class="form-card__title" style="margin-bottom:8px">${I.icon('clock', 15)} Expiry & cancellations</div>
          <p class="hint">Coins are credited after delivery or pickup and expire after ${STATE.coinSettings.expiryMonths} months. Oldest coins are used first. If an order is cancelled, redeemed coins are returned and pending coins are removed.</p>
        </div>
      </div>
      <div class="sheet__actions"><button class="btn btn--primary btn--block" type="button" data-action="close-sheet">Got it</button></div>`);
  };

  sheets['store-info'] = function () {
    return sheetShell(D.store.name, 'Alkapuri · Vadodara', `
      <div class="card card--pad">
        <div class="row">
          <span class="thumb tone-gold" style="width:54px;height:54px">${I.logo(38)}</span>
          <div class="grow"><b style="font-size:14px">${D.store.name}</b><div class="gu" style="font-size:11px;color:var(--ink-3)">${D.store.nameGu}</div><span class="pill pill--active mt-4">Open today · 9 AM – 9 PM</span></div>
        </div>
        <div class="divider"></div>
        <div class="stack stack--sm">
          <div class="row">${I.icon('pin', 15)}<span class="hint">${esc(D.store.address)}</span></div>
          <div class="row">${I.icon('phone', 15)}<a class="link" href="tel:${D.store.phoneHref}">${esc(D.store.phone)}</a></div>
          <div class="row">${I.icon('truck', 15)}<span class="hint">${esc(D.store.promise)} across Vadodara</span></div>
          <div class="row">${I.icon('coin', 15)}<span class="hint">Coins on every delivered order</span></div>
        </div>
      </div>
      <div class="admin-action-grid">
        <a class="btn btn--primary btn--sm" href="tel:${D.store.phoneHref}">${I.icon('phone', 14)} Call store</a>
        <a class="btn btn--secondary btn--sm" href="https://wa.me/919714000027" target="_blank" rel="noopener">${I.icon('whatsapp', 15)} WhatsApp</a>
      </div>
      <div class="sheet__note">Free home delivery on every order. Pickup is available from the Alkapuri counter during store hours.</div>
      <div class="sheet__actions"><button class="btn btn--soft btn--block" type="button" data-action="close-sheet">Done</button></div>`);
  };

  sheets.wishlist = function () {
    const saved = STATE.wishlist.map(productById).filter(Boolean);
    return sheetShell('Saved items', `${saved.length} product${saved.length === 1 ? '' : 's'}`, `
      ${saved.length ? `<div class="stack">${saved.map((p) => {
        const v = variantOf(p, p.defaultVariant);
        return `<button class="inventory-row" type="button" data-nav="#/product/${p.id}">
          ${thumb(p, 'thumb--sm')}
          <div class="inventory-row__body"><h3>${esc(pname(p))}</h3><span>${esc(v.unit)} · ${money(v.price)}</span></div>
          <div class="inventory-row__side">${I.icon('right', 15)}</div>
        </button>`;
      }).join('')}</div>` : emptyState('heart', 'Nothing saved yet', 'Tap the heart on any product to save it for later.', `<button class="btn btn--soft btn--sm" type="button" data-nav="#/shop">Browse products</button>`)}
      <div class="sheet__actions"><button class="btn btn--secondary btn--block" type="button" data-action="close-sheet">Done</button></div>`);
  };

  /* ---------- admin views ---------- */
  const ADMIN_STATUS_TABS = [
    ['new', 'New', ['Placed', 'Confirmed']],
    ['preparing', 'Preparing', ['Packed', 'Ready for Pickup']],
    ['delivery', 'On the way', ['Out for Delivery']],
    ['completed', 'Completed', ['Delivered', 'Picked Up']],
    ['cancelled', 'Cancelled', ['Cancelled']],
    ['all', 'All orders', activeStatuses.concat(['Delivered', 'Picked Up', 'Cancelled'])]
  ];
  const STEP_SHORT = { 'Placed': 'Placed', 'Confirmed': 'Confirmed', 'Packed': 'Packed', 'Out for Delivery': 'Out', 'Delivered': 'Delivered', 'Ready for Pickup': 'Ready', 'Picked Up': 'Picked up' };
  const priority = { 'Placed': 0, 'Confirmed': 1, 'Packed': 2, 'Ready for Pickup': 3, 'Out for Delivery': 4 };

  function sameLocalDay(iso, dateStr) {
    const d = new Date(iso);
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` === dateStr;
  }

  function liveOrders() {
    return STATE.orders.filter(isActiveOrder).sort((a, b) => (priority[a.status] - priority[b.status]) || (new Date(b.placedAt) - new Date(a.placedAt)));
  }

  function lowStockProducts() {
    return STATE.products.filter((p) => !p.available || p.stock <= p.lowStock);
  }

  function inventoryStatus(p) {
    if (!p.available || p.stock <= 0) return { label: 'Out of stock', cls: 'cancelled' };
    if (p.stock <= p.lowStock) return { label: 'Low stock', cls: 'low' };
    if (STATE.hotSale.featured.indexOf(p.id) !== -1) return { label: 'Hot sale', cls: 'hot' };
    return { label: 'Active', cls: 'active' };
  }

  function adminOrderCard(order) {
    const action = primaryAction(order);
    const totalQty = order.items.reduce((n, it) => n + it.qty, 0);
    const names = order.items.slice(0, 2).map((it) => it.name).join(', ');
    return `<article class="card admin-order-card" role="link" tabindex="0" data-nav="#/admin/order/${order.number}">
      <div class="admin-order-card__head">
        <div><h3>${esc(order.number)}</h3><div class="admin-order-card__meta">${esc(order.customer)} · ${order.mode === 'pickup' ? 'Pickup' : 'Delivery'}<br>${esc(names)}${order.items.length > 2 ? ` +${order.items.length - 2} more` : ''} · ${totalQty} ${totalQty === 1 ? 'item' : 'items'}</div></div>
        ${statusPill(order.status)}
      </div>
      <div class="admin-order-card__foot">
        <div><div class="hint">${timeOnly(order.placedAt)} · ${esc(order.payment)}</div><div class="admin-order-card__total">${money(order.bill.total)}</div></div>
        ${action
          ? `<button class="btn btn--primary btn--xs" type="button" data-action="advance-order" data-number="${order.number}">${esc(action.short)} ${I.icon('right', 12)}</button>`
          : `<button class="btn btn--secondary btn--xs" type="button" data-nav="#/admin/order/${order.number}">View ${I.icon('right', 12)}</button>`}
      </div>
    </article>`;
  }

  function adminStepper(order) {
    const steps = orderSteps(order);
    const idx = currentStepIndex(order);
    const completed = order.status === 'Delivered' || order.status === 'Picked Up';
    const progress = completed ? 100 : Math.round((idx / (steps.length - 1)) * 100);
    return `<div class="card stepper-card">
      <div class="between mb-12">
        <span class="hint">Order progress</span>
        <div class="stepper-tools">
          <span class="hint">${idx + 1} / ${steps.length}</span>
          <button class="stage-edit" type="button" data-action="order-stage-sheet" data-number="${order.number}">${I.icon('refresh', 11)} Change stage</button>
        </div>
      </div>
      <div class="stepper">
        <span class="stepper__line"><i style="width:${progress}%"></i></span>
        ${steps.map((step, i) => {
          let cls = '';
          if (i < idx || completed) cls = 'is-done';
          else if (i === idx) cls = 'is-current';
          return `<div class="step ${cls}">
            <span class="step__dot">${i < idx || completed ? I.icon('check', 12) : i === idx ? I.icon('clock', 11) : ''}</span>
            <span>${STEP_SHORT[step]}</span>
          </div>`;
        }).join('')}
      </div>
    </div>`;
  }

  views.admin = function () {
    const today = todayISO();
    const todayOrders = STATE.orders.filter((o) => sameLocalDay(o.placedAt, today) && o.status !== 'Cancelled');
    const sales = todayOrders.reduce((sum, o) => sum + o.bill.total, 0);
    const newCount = STATE.orders.filter((o) => o.status === 'Placed').length;
    const live = liveOrders();
    const low = lowStockProducts();
    const maxSale = Math.max.apply(null, STATE.weekSales.map((d) => d.amount).concat([1]));
    const weekTotal = STATE.weekSales.reduce((sum, d) => sum + d.amount, 0);
    const dateLabel = new Date().toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long' });
    return `<div class="screen screen--admin">
      ${statusbar(true, true)}
      ${adminHead('Dashboard', `${D.store.name} · Alkapuri, Vadodara`)}
      <div class="screen-scroll">
        <div class="admin-body-pad">
          <div class="between mb-12">
            <div><div class="eyebrow eyebrow--red">STORE OVERVIEW</div><div class="strong" style="font-size:13px;margin-top:4px">${dateLabel}</div></div>
            <span class="pill pill--active"><span style="width:5px;height:5px;border-radius:50%;background:currentColor"></span> Open · 9–9</span>
          </div>

          <div class="admin-metrics">
            <div class="metric">
              <span class="metric__icon metric__icon--green">${I.icon('chart', 15)}</span>
              <b>${money(sales)}</b><span>Sales today</span>
            </div>
            <div class="metric">
              <span class="metric__icon metric__icon--navy">${I.icon('box', 15)}</span>
              <b>${todayOrders.length}</b><span>Orders today</span>
            </div>
            <div class="metric">
              <span class="metric__icon metric__icon--gold">${I.icon('bolt', 15)}</span>
              <b>${newCount}</b><span>Need action</span>
            </div>
          </div>

          <div class="chart-card card mt-12">
            <div class="chart-head"><div><b>This week’s sales</b><br><span>Free delivery · 7 day view</span></div><span class="pill pill--green">${money(weekTotal)}</span></div>
            <div class="chart-bars">
              ${STATE.weekSales.map((d, i) => `<div class="chart-bar${i === STATE.weekSales.length - 1 ? ' is-today' : ''}">
                <i style="height:${Math.max(12, Math.round((d.amount / maxSale) * 100))}%"></i>
                <small>${d.day}</small>
              </div>`).join('')}
            </div>
          </div>

          <div class="quick-grid mt-12">
            <button class="quick" type="button" data-nav="#/admin/orders"><span class="quick__icon">${I.icon('box', 16)}</span>New orders</button>
            <button class="quick" type="button" data-nav="#/admin/hot-sale"><span class="quick__icon quick__icon--orange">${I.icon('flame', 16)}</span>Hot sale</button>
            <button class="quick" type="button" data-nav="#/admin/coupons"><span class="quick__icon quick__icon--gold">${I.icon('ticket', 16)}</span>Coupons</button>
            <button class="quick" type="button" data-nav="#/admin/reports"><span class="quick__icon quick__icon--navy">${I.icon('chart', 16)}</span>Reports</button>
          </div>

          <div class="section-head"><h2 style="font-size:16px">Orders needing action</h2><button class="link" type="button" data-nav="#/admin/orders">All orders</button></div>
          ${live.length ? `<div class="stack">${live.slice(0, 3).map(adminOrderCard).join('')}</div>` : `<div class="card admin-empty"><b>All caught up</b>No orders waiting right now.</div>`}

          <div class="section-head"><h2 style="font-size:16px">Stock alerts</h2><button class="link" type="button" data-nav="#/admin/inventory">Inventory</button></div>
          ${low.length ? `<div class="card wallet-list-card">
            ${low.slice(0, 3).map((p) => `<button class="inventory-row" type="button" data-nav="#/admin/product/${p.id}">
              ${thumb(p, 'thumb--sm')}
              <div class="inventory-row__body"><h3>${esc(p.name)}</h3><span>${p.stock} in stock · reorder at ${p.lowStock}</span></div>
              <div class="inventory-row__side"><span class="pill pill--${p.stock <= 0 ? 'cancelled' : 'low'}">${p.stock <= 0 ? 'Out' : 'Low'}</span></div>
            </button>`).join('')}
          </div>` : `<div class="card admin-empty"><b>Shelves are healthy</b>No low stock items today.</div>`}

          <div class="card card--pad mt-12">
            <div class="row"><span class="coin-orb coin-orb--sm">${I.icon('coin', 18)}</span>
              <div class="grow"><b style="font-size:12px">${STATE.ledger.filter((l) => l.status === 'credited' && l.coins > 0).reduce((sum, l) => sum + l.coins, 0)} coins issued</b><div class="hint">Across delivered orders and bonuses</div></div>
              <button class="link" type="button" data-nav="#/admin/coins">Manage</button>
            </div>
          </div>
          <div style="height:8px"></div>
        </div>
      </div>
      ${adminNav('dashboard')}
    </div>`;
  };

  views['admin-orders'] = function () {
    const filter = ui.adminOrderFilter;
    const activeTab = ADMIN_STATUS_TABS.find((t) => t[0] === filter) || ADMIN_STATUS_TABS[0];
    const list = STATE.orders
      .filter((o) => activeTab[2].indexOf(o.status) !== -1)
      .sort((a, b) => {
        if (filter === 'all' || filter === 'completed' || filter === 'cancelled') return new Date(b.placedAt) - new Date(a.placedAt);
        return (priority[a.status] || 0) - (priority[b.status] || 0) || new Date(b.placedAt) - new Date(a.placedAt);
      });
    const newCount = STATE.orders.filter((o) => o.status === 'Placed').length;
    const sum = list.reduce((s, o) => s + o.bill.total, 0);
    return `<div class="screen screen--admin">
      ${statusbar(true, true)}
      ${adminHead('Orders', `${newCount} new · ${liveOrders().length} in progress`)}
      <div class="screen-scroll">
        <div class="admin-body-pad">
          <div class="status-tabs">
            ${ADMIN_STATUS_TABS.map(([key, label, statuses]) => {
              const count = STATE.orders.filter((o) => statuses.indexOf(o.status) !== -1).length;
              return `<button class="chip chip--status${filter === key ? ' is-active' : ''}" type="button" data-action="admin-filter" data-filter="${key}">${label} · ${count}</button>`;
            }).join('')}
          </div>
          <div class="shop-count">${list.length} orders · ${money(sum)} · ${activeTab[1]}</div>
          ${list.length ? `<div class="stack">${list.map(adminOrderCard).join('')}</div>` : `<div class="card admin-empty"><b>Nothing here</b>No orders in this bucket right now.</div>`}
          <div style="height:12px"></div>
        </div>
      </div>
      ${adminNav('orders')}
    </div>`;
  };

  views['admin-order'] = function (route) {
    const order = orderByNumber(route.seg[2]);
    if (!order) {
      return `<div class="screen screen--admin">
        ${statusbar()}
        ${appbar({ title: 'Order', back: '#/admin/orders' })}
        <div class="screen-scroll screen-scroll--end">${emptyState('box', 'Order not found', 'This order is not in the store records.', `<button class="btn btn--primary btn--sm" data-nav="#/admin/orders">Back to orders</button>`)}</div>
      </div>`;
    }
    const action = primaryAction(order);
    const cancellable = ['Delivered', 'Picked Up', 'Cancelled'].indexOf(order.status) === -1;
    const pendingCoin = STATE.ledger.find((l) => l.orderNumber === order.number && l.status === 'pending');
    const coinState = order.status === 'Delivered' || order.status === 'Picked Up' ? 'Credited' : order.status === 'Cancelled' ? 'Removed' : 'Credits on delivery';
    const orderQty = order.items.reduce((n, it) => n + it.qty, 0);
    return `<div class="screen screen--admin">
      ${statusbar()}
      ${appbar({ title: `#${order.number}`, sub: `${formatDate(order.placedAt)} · ${timeOnly(order.placedAt)} · ${order.mode === 'pickup' ? 'Store pickup' : 'Home delivery'}`, back: '#/admin/orders', right: statusPill(order.status) })}
      <div class="screen-scroll screen-scroll--action">
        ${order.status === 'Cancelled' ? `<div class="card card--pad mb-12">
          <div class="row"><span class="info-card__icon">${I.icon('info', 18)}</span><div class="grow"><h3 style="font-size:12px;font-weight:800">Order cancelled</h3><p class="hint" style="margin-top:3px">${esc(order.cancelReason || 'No reason recorded')} · ${whenLabel(order.updatedAt)}</p></div></div>
        </div>` : adminStepper(order)}

        ${action ? `<div class="card card--pad mt-12" style="background:linear-gradient(125deg,#FFF7E0,#FFF1C8);border-color:#F8E4A5">
          <div class="between">
            <div><b style="font-size:12.5px">Next: ${esc(action.next)}</b><div class="hint" style="margin-top:3px">${order.mode === 'pickup' && action.next === 'Ready for Pickup' ? 'Notify the customer that the order is ready.' : action.next === 'Delivered' ? 'Cash collected? Mark this order delivered.' : 'Keep the customer updated as this order moves.'}</div></div>
            <button class="btn btn--primary btn--xs" type="button" data-action="advance-order" data-number="${order.number}">${esc(action.short)}</button>
          </div>
        </div>` : ''}

        <div class="card customer-strip mt-12">
          <span class="customer-avatar">${initials(order.customer)}</span>
          <div class="grow"><b>${esc(order.customer)}</b><span>${esc(order.phone)} · ${esc(order.address)}</span></div>
          <div class="customer-strip__actions">
            <a class="mini-round" href="tel:${String(order.phone).replace(/\s/g, '')}" aria-label="Call customer">${I.icon('phone', 15)}</a>
            <a class="mini-round mini-round--red" href="https://wa.me/91${String(order.phone).replace(/\D/g, '')}" target="_blank" rel="noopener" aria-label="WhatsApp customer">${I.icon('whatsapp', 15)}</a>
          </div>
        </div>

        <div class="section-head"><h2 style="font-size:15px">Items</h2><span class="hint">${orderQty} ${orderQty === 1 ? 'unit' : 'units'}</span></div>
        <div class="card order-items-card">
          ${order.items.map((it) => `<div class="order-item">
            <span class="thumb thumb--xs tone-${it.tone || 'gold'}">${I.art(it.art)}</span>
            <div class="grow"><h3>${esc(it.name)}</h3><span>${esc(it.unit)} × ${it.qty} · ${it.earnsCoins ? 'Earns coins' : 'No coins'}</span></div>
            <b>${money(it.price * it.qty)}</b>
          </div>`).join('')}
        </div>

        <div class="card card--pad bill-card mt-12">
          ${billLines({ subtotal: order.bill.subtotal, discount: order.bill.couponDiscount, couponCode: order.bill.couponCode, coinsUsed: order.coinsUsed, coinDiscount: order.coinsUsed, total: order.bill.total }, false)}
          <div class="divider"></div>
          <div class="between"><span class="hint">${esc(order.payment)}</span>${payPill(order.paymentState)}</div>
        </div>

        <div class="card card--pad mt-12">
          <div class="row">
            <span class="coin-orb coin-orb--sm">${I.icon('coin', 18)}</span>
            <div class="grow"><b style="font-size:12px">${order.coinsEarned} coins earned · ${order.coinsUsed} used</b><div class="hint">${order.coinRule} · ${coinState}</div></div>
            ${pendingCoin ? `<span class="pill pill--gold">Pending</span>` : order.status === 'Cancelled' ? `<span class="pill pill--grey">Removed</span>` : `<span class="pill pill--done">${order.coinsEarned ? 'Credited' : 'None'}</span>`}
          </div>
          ${pendingCoin ? `<div class="coin-side-note">${I.icon('info', 12)} Coins credit to the customer after ${order.mode === 'pickup' ? 'pickup' : 'delivery'}.</div>` : ''}
        </div>

        <div class="card info-card mt-12">
          <span class="info-card__icon info-card__icon--navy">${I.icon(order.mode === 'pickup' ? 'store' : 'pin', 17)}</span>
          <div class="grow"><h3>${order.mode === 'pickup' ? 'Store pickup' : 'Home delivery'}</h3><p>${esc(order.address)}${order.slot ? `<br>${esc(order.slot)}` : ''} · Free delivery</p></div>
        </div>

        ${order.partner ? `<div class="card partner mt-12">
          <span class="partner__avatar">${I.icon('truck', 20)}</span>
          <div class="grow"><b>${esc(order.partner.name)}</b><span>${esc(order.partner.role)} · ${esc(order.partner.phone)}</span></div>
          <a class="call-round" href="tel:${String(order.partner.phone).replace(/\s/g, '')}" aria-label="Call rider">${I.icon('phone', 15)}</a>
        </div>` : ''}

        <div class="section-head"><h2 style="font-size:15px">Status history</h2><span class="hint">${order.statusHistory.length} updates</span></div>
        <div class="card timeline-card">
          ${order.statusHistory.map((h, i) => {
            const isLast = i === order.statusHistory.length - 1;
            const correction = !!h.note;
            return `<div class="tl is-done${isLast ? ' is-last' : ''}${order.status === 'Cancelled' && isLast ? ' is-current' : ''}${correction ? ' is-correction' : ''}">
              <div class="tl__rail"><span class="tl__dot">${I.icon(order.status === 'Cancelled' && isLast ? 'close' : correction ? 'refresh' : 'check', 12)}</span><span class="tl__line"></span></div>
              <div class="tl__body"><b>${statusLabel(h.status)}${correction ? '<span class="tl__tag">Owner change</span>' : ''}</b><span>${formatDate(h.at)} · ${formatTime(h.at)}${correction ? ` · ${esc(h.note)}` : ''}</span></div>
            </div>`;
          }).join('')}
        </div>

        ${cancellable ? `<div class="mt-16"><button class="btn btn--danger-soft btn--sm btn--block" type="button" data-action="cancel-order-sheet" data-number="${order.number}" data-by="admin">${I.icon('close', 14)} Cancel order & release stock</button></div>` : ''}
        <div style="height:8px"></div>
      </div>
      <div class="savebar">
        ${cancellable ? `<button class="btn btn--secondary" type="button" data-action="cancel-order-sheet" data-number="${order.number}" data-by="admin">Cancel</button>` : `<button class="btn btn--secondary" type="button" data-nav="#/admin/orders">Back to orders</button>`}
        ${action ? `<button class="btn btn--primary" type="button" data-action="advance-order" data-number="${order.number}">${esc(action.label)}</button>` : `<button class="btn btn--primary" type="button" data-nav="#/admin/orders">Done</button>`}
      </div>
    </div>`;
  };

  views['admin-inventory'] = function () {
    const q = ui.invQuery.trim().toLowerCase();
    const low = lowStockProducts();
    let list = STATE.products.slice();
    if (ui.invCat !== 'all') list = list.filter((p) => p.category === ui.invCat);
    if (q) list = list.filter((p) => `${p.name} ${p.nameGu}`.toLowerCase().indexOf(q) !== -1);
    return `<div class="screen screen--admin">
      ${statusbar(true, true)}
      ${adminHead('Inventory', `${STATE.products.length} products · ${low.length} need attention`)}
      <div class="screen-scroll">
        <div class="admin-body-pad">
          <form class="searchbar" data-form="inv-search">
            <button type="submit" aria-label="Search" style="color:var(--ink-3)">${I.icon('search', 18)}</button>
            <input name="q" value="${esc(ui.invQuery)}" placeholder="Search products or stock…" autocomplete="off">
            ${ui.invQuery ? `<button type="button" data-action="clear-inv-search" aria-label="Clear search" style="color:var(--ink-3)">${I.icon('close', 15)}</button>` : ''}
          </form>
          <div class="chips chips--rail">
            <button class="chip chip--sm${ui.invCat === 'all' ? ' is-active' : ''}" type="button" data-action="inv-cat" data-cat="all">All · ${STATE.products.length}</button>
            ${STATE.categories.map((c) => {
              const count = STATE.products.filter((p) => p.category === c.id).length;
              return `<button class="chip chip--sm${ui.invCat === c.id ? ' is-active' : ''}" type="button" data-action="inv-cat" data-cat="${c.id}">${esc(c.name)} · ${count}</button>`;
            }).join('')}
          </div>
          <div class="inv-meta">
            <div class="shop-count">${list.length} products${ui.invCat !== 'all' ? ` in ${esc(STATE.categories.find((c) => c.id === ui.invCat).name)}` : ''}</div>
            <button class="inv-type-add" type="button" data-action="new-type-sheet">${I.icon('plus', 12)} New type</button>
          </div>
          ${list.length ? list.map((p) => {
            const v = variantOf(p, p.defaultVariant);
            const status = inventoryStatus(p);
            return `<div class="inventory-line">
              <button class="inventory-row" type="button" data-nav="#/admin/product/${p.id}">
                ${thumb(p, 'thumb--sm')}
                <div class="inventory-row__body">
                  <h3>${esc(p.name)}</h3>
                  <span>${esc(p.unit)} · ${p.variants.length} ${p.variants.length === 1 ? 'pack' : 'packs'} · ${money(v.price)}</span>
                  <div class="inventory-row__packs">${p.variants.map((variant, i) => `<span class="${variantStock(p, i) <= 0 ? 'is-out' : ''}">${esc(variant.label)} · ${variantStock(p, i)}</span>`).join('')}</div>
                </div>
                <div class="inventory-row__side">
                  <b style="font-size:10px;color:var(--ink-3)">${p.stock} in stock</b>
                  <span class="pill pill--${status.cls}">${status.label}</span>
                </div>
              </button>
              <button class="inventory-restock" type="button" data-action="restock-sheet" data-id="${p.id}" aria-label="Add stock to ${esc(p.name)}" title="Add stock">${I.icon('plus', 17)}</button>
            </div>`;
          }).join('') : emptyState('search', 'No products found', 'Try a different category or search term.', `<button class="btn btn--soft btn--sm" data-action="clear-inv-filters">Clear filters</button>`)}
          <div style="height:34px"></div>
        </div>
      </div>
      <button class="add-fab" type="button" data-nav="#/admin/product/new" aria-label="Add product">${I.icon('plus', 22)}</button>
      ${adminNav('inventory')}
    </div>`;
  };

  const TONE_BY_CAT = { grocery: 'mint', home: 'peach', dry: 'gold', cosmetic: 'rose', icecream: 'sky' };
  const ART_BY_CAT = { grocery: 'rice', home: 'pickle', dry: 'almonds', cosmetic: 'cream', icecream: 'kulfi' };

  function packRowHtml(index, v, number) {
    const val = v || {};
    return `<div class="pack-row${index ? ' mt-12' : ''}" data-pack-row>
      <div class="field-row--4">
        <div class="field"><label>Pack ${number}</label><input class="input" name="vlabel${index}" value="${esc(val.label || '')}" placeholder="500 g"></div>
        <div class="field"><label>Price ₹</label><input class="input" name="vprice${index}" type="number" min="1" inputmode="numeric" value="${val.price || ''}" placeholder="0"></div>
        <div class="field"><label>MRP ₹</label><input class="input" name="vmrp${index}" type="number" min="1" inputmode="numeric" value="${val.mrp || ''}" placeholder="0"></div>
        <div class="field"><label>Stock</label><input class="input" name="vstock${index}" type="number" min="0" inputmode="numeric" value="${val.stock != null ? val.stock : ''}" placeholder="0"></div>
      </div>
    </div>`;
  }

  views['admin-product'] = function (route) {
    const key = route.seg[2];
    const isNew = key === 'new';
    const p = isNew ? null : productById(key);
    if (!isNew && !p) {
      return `<div class="screen screen--admin">
        ${statusbar()}${appbar({ title: 'Product', back: '#/admin/inventory' })}
        <div class="screen-scroll screen-scroll--end">${emptyState('box', 'Product not found', 'This product may have been removed from the catalogue.', `<button class="btn btn--primary btn--sm" data-nav="#/admin/inventory">Back to inventory</button>`)}</div>
      </div>`;
    }
    const cat = p ? p.category : 'grocery';
    const variants = p ? p.variants : [{ label: '', price: '', mrp: '', stock: 20 }, { label: '', price: '', mrp: '', stock: '' }, { label: '', price: '', mrp: '', stock: '' }];
    const rows = variants.map((_, i) => i);
    return `<div class="screen screen--admin">
      ${statusbar()}
      ${appbar({
        title: isNew ? 'Add product' : 'Edit product',
        sub: isNew ? 'Create a shelf item' : `${p.name} · ${p.unit}`,
        back: '#/admin/inventory',
        right: `<span class="pill ${isNew ? 'pill--navy' : p.available ? 'pill--active' : 'pill--cancelled'}">${isNew ? 'New' : p.available ? 'Active' : 'Hidden'}</span>`
      })}
      <div class="screen-scroll screen-scroll--action">
        <div class="card product-hero-card">
          <span class="thumb tone-${p ? p.tone : TONE_BY_CAT[cat]}" style="width:58px;height:58px">${I.art(p ? p.art : ART_BY_CAT[cat])}</span>
          <div class="grow">
            <h3>${esc(p ? p.name : 'New shelf item')}</h3>
            <p>${p ? `${p.rating} ★ · ${p.reviews} reviews · ${inventoryStatus(p).label}` : 'Fill in the basics to list it in the customer app.'}</p>
          </div>
          ${p ? `<span class="pill pill--${inventoryStatus(p).cls}">${inventoryStatus(p).label}</span>` : ''}
        </div>

        <form id="productForm" data-form="product-save" data-id="${isNew ? '' : p.id}" data-new="${isNew ? '1' : '0'}" data-pack-seq="${rows.length}">
          <div class="card form-card mt-12">
            <div class="form-card__title">${I.icon('edit', 14)} Basics</div>
            <div class="field"><label>Product name</label><input class="input" name="name" value="${esc(p ? p.name : '')}" placeholder="e.g. Premium Almonds" required></div>
            <div class="field mt-8"><label>Gujarati name</label><input class="input gu" name="nameGu" value="${esc(p ? p.nameGu : '')}" placeholder="ગુજરાતી નામ"></div>
            <div class="field-row mt-8">
              <div class="field">
                <div class="field__top"><label>Category</label><button class="field__link" type="button" data-action="toggle-type-create">${I.icon('plus', 11)} New type</button></div>
                <select class="input select" name="category">${STATE.categories.map((c) => `<option value="${c.id}" ${c.id === cat ? 'selected' : ''}>${esc(c.name)}</option>`).join('')}</select>
                <div class="type-create" hidden>
                  <div class="field-row mt-8">
                    <div class="field"><label>New type</label><input class="input" name="newType" maxlength="32" placeholder="e.g. Dairy"></div>
                    <div class="field"><label>Gujarati</label><input class="input gu" name="newTypeGu" maxlength="40" placeholder="ગુજરાતી"></div>
                  </div>
                  <button class="btn btn--soft btn--sm btn--block mt-8" type="button" data-action="create-type-inline">Add this type</button>
                </div>
              </div>
              <div class="field"><label>Primary pack</label><input class="input" name="unit" value="${esc(p ? p.unit : '500 g')}" placeholder="500 g"></div>
            </div>
            <div class="field mt-8"><label>Description</label><textarea class="input" name="desc" placeholder="A short, honest description for the product page…">${esc(p ? p.desc : '')}</textarea></div>
            <div class="field mt-8"><label>Gujarati description</label><textarea class="input gu" name="descGu" placeholder="ગુજરાતી વર્ણન">${esc(p ? p.descGu : '')}</textarea></div>
          </div>

          <div class="card form-card">
            <div class="form-card__title">${I.icon('bag', 14)} Packs, pricing & stock</div>
            <div data-pack-rows>
              ${rows.map((i) => packRowHtml(i, variants[i], i + 1)).join('')}
            </div>
            <button class="pack-add" type="button" data-action="add-pack">${I.icon('plus', 14)} Add pack</button>
            <p class="hint mt-8">Add a pack for each size or type you sell. At least one pack with a price is required. Each pack keeps its own stock count. MRP must be equal to or above the selling price.</p>
          </div>

          <div class="card form-card">
            <div class="form-card__title">${I.icon('grid', 14)} Stock</div>
            ${p ? `<div class="stock-summary">
              <div class="stock-summary__top">
                <div class="grow"><b>${p.stock} units in stock</b><span>Across ${p.variants.length} ${p.variants.length === 1 ? 'pack' : 'packs'} · reorder at ${p.lowStock}</span></div>
                <button class="btn btn--soft btn--sm stock-add" type="button" data-action="restock-sheet" data-id="${p.id}">${I.icon('plus', 13)} Add stock</button>
              </div>
              <div class="stock-pack-list">
                ${p.variants.map((variant, i) => `<span class="stock-pack${variantStock(p, i) <= 0 ? ' is-out' : ''}"><b>${esc(variant.label)}</b><i>${variantStock(p, i)}</i></span>`).join('')}
              </div>
              <p class="hint">Bought fresh stock? Add received units per pack — the shelf count goes up without retyping the total.</p>
            </div>` : `<p class="hint">Set the opening stock for each pack above. After the product is created you can add a new purchase from inventory.</p>`}
            <div class="field mt-12"><label>Low stock alert at</label><input class="input" name="lowStock" type="number" min="0" value="${p ? p.lowStock : 5}"></div>
            <div class="form-toggle-row mt-12">
              <div class="form-toggle-row__copy"><b>Visible in the customer app</b><small>Hide this product without deleting it</small></div>
              <label class="switch"><input type="checkbox" name="available" ${!p || p.available ? 'checked' : ''}></label>
            </div>
          </div>

          <div class="card form-card">
            <div class="form-card__title">${I.icon('coin', 14)} Coins</div>
            <div class="form-toggle-row">
              <div class="form-toggle-row__copy"><b>Earns coins after delivery</b><small>Customer accrues coins when this item is paid for</small></div>
              <label class="switch"><input type="checkbox" name="earnsCoins" ${!p || p.earnsCoins ? 'checked' : ''}></label>
            </div>
            <div class="form-toggle-row">
              <div class="form-toggle-row__copy"><b>Coins can be redeemed</b><small>Let customers pay part of this item with coins</small></div>
              <label class="switch"><input type="checkbox" name="allowCoins" ${!p || p.allowCoins ? 'checked' : ''}></label>
            </div>
            <p class="hint mt-8">Changing these switches only affects future orders. Existing orders keep their coin calculations.</p>
          </div>
        </form>
        <div style="height:8px"></div>
      </div>
      <div class="savebar">
        <button class="btn btn--secondary" type="button" data-back="#/admin/inventory">Cancel</button>
        <button class="btn btn--primary" type="submit" form="productForm">${isNew ? 'Add product' : 'Save changes'}</button>
      </div>
    </div>`;
  };

  views['admin-hot-sale'] = function () {
    const hot = STATE.hotSale;
    const featured = hot.featured.map(productById).filter(Boolean);
    return `<div class="screen screen--admin">
      ${statusbar()}
      ${appbar({
        title: 'Hot sale', sub: 'Banner, timing and featured products', back: '#/admin',
        right: `<span class="pill ${hot.live ? 'pill--active' : 'pill--grey'}">${hot.live ? 'Live' : 'Draft'}</span>`
      })}
      <div class="screen-scroll screen-scroll--action">
        <div class="hot-preview">
          <span class="eyebrow">${esc(hot.eyebrow)}</span>
          <h2>${esc(hot.title)}</h2>
          <p>${formatDate(hot.starts)} – ${formatDate(hot.ends)} · ${featured.length} products featured</p>
          <span class="hot-preview__flame">${I.icon('flame', 30)}</span>
        </div>

        <form id="hotForm" data-form="hot-save">
          <div class="card form-card mt-12">
            <div class="form-card__title">${I.icon('flame', 14)} Banner content</div>
            <div class="field"><label>Eyebrow</label><input class="input" name="eyebrow" value="${esc(hot.eyebrow)}" maxlength="40"></div>
            <div class="field mt-8"><label>Headline</label><input class="input" name="title" value="${esc(hot.title)}" maxlength="60"></div>
            <div class="field-row mt-8">
              <div class="field"><label>Starts</label><input class="input" type="date" name="starts" value="${esc(hot.starts)}"></div>
              <div class="field"><label>Ends</label><input class="input" type="date" name="ends" value="${esc(hot.ends)}"></div>
            </div>
            <div class="form-toggle-row mt-12">
              <div class="form-toggle-row__copy"><b>Show on customer home</b><small>Publish the banner on the storefront</small></div>
              <label class="switch switch--red"><input type="checkbox" name="live" ${hot.live ? 'checked' : ''}></label>
            </div>
          </div>
        </form>

        <div class="section-head"><h2 style="font-size:15px">Featured products</h2><button class="link" type="button" data-action="product-picker">Add product</button></div>
        <div class="featured-grid">
          ${featured.map((p) => {
            const v = variantOf(p, p.defaultVariant);
            return `<div class="featured-card">
              <button class="featured-card__remove" type="button" data-action="remove-featured" data-id="${p.id}" aria-label="Remove ${esc(p.name)}">${I.icon('close', 11)}</button>
              <span class="thumb tone-${p.tone}">${I.art(p.art)}</span>
              <b>${esc(p.name)}</b>
              <span class="pill pill--hot">${money(v.price)}</span>
            </div>`;
          }).join('')}
          <button class="add-featured" type="button" data-action="product-picker">${I.icon('plus', 20)}<span>Add a product</span></button>
        </div>
        <p class="hint mt-12">${I.icon('info', 11)} Sale prices come from each product’s selling price. Keep at least two products featured to fill the home banner rail.</p>
        <div style="height:8px"></div>
      </div>
      <div class="savebar">
        <button class="btn btn--secondary" type="button" data-nav="#/home">${T('Preview', 'પ્રીવ્યૂ')}</button>
        <button class="btn btn--primary" type="submit" form="hotForm">Publish hot sale</button>
      </div>
    </div>`;
  };

  views['admin-coins'] = function () {
    const settings = STATE.coinSettings;
    const activeRules = STATE.coinRules.filter((r) => ruleWindowStatus(r) === 'active');
    const credited = STATE.ledger.filter((l) => l.status === 'credited' && l.coins > 0).reduce((sum, l) => sum + l.coins, 0);
    const sample = bestEarnRule(2000);
    return `<div class="screen screen--admin">
      ${statusbar(true, true)}
      ${adminHead('Coins & rewards', `${credited} coins issued · ${activeRules.length} active earning ${activeRules.length === 1 ? 'rule' : 'rules'}`)}
      <div class="screen-scroll">
        <div class="admin-body-pad">
          <form class="card form-card" data-form="coin-settings">
            <div class="form-card__title">${I.icon('coin', 14)} Redemption settings</div>
            <div class="rule-settings">
              <div class="field"><label>Coin value ₹</label><input class="input" name="coinValue" type="number" min="1" value="${settings.coinValue}"></div>
              <div class="field"><label>Max % / order</label><input class="input" name="maxPercent" type="number" min="1" max="100" value="${settings.maxPercent}"></div>
              <div class="field"><label>Expiry months</label><input class="input" name="expiryMonths" type="number" min="1" value="${settings.expiryMonths}"></div>
            </div>
            <p class="hint mt-8">1 coin = ${money(settings.coinValue)}. Customers can pay up to ${settings.maxPercent}% of an eligible order with coins. Coins expire after ${settings.expiryMonths} months, oldest first.</p>
            <button class="btn btn--primary btn--sm btn--block mt-12" type="submit">Save redemption settings</button>
          </form>

          <div class="section-head">
            <h2 style="font-size:15px">Earning rules</h2>
            <button class="link" type="button" data-action="new-rule">+ Add rule</button>
          </div>
          <div class="stack">
            ${STATE.coinRules.map((rule) => {
              const status = ruleWindowStatus(rule);
              const statusLabelText = status === 'active' ? 'Active' : status === 'scheduled' ? 'Scheduled' : status === 'expired' ? 'Expired' : 'Paused';
              const sampleCoins = ruleCoins(rule, 2000);
              return `<div class="card rule-card">
                <div class="rule-card__head">
                  <div><h3>${esc(rule.name)}</h3><span>${esc(rule.scope || 'All items')} · ${rule.mode === 'slab' ? 'Slab payout' : 'Pro-rata payout'}</span></div>
                  <label class="switch switch--sm"><input type="checkbox" data-change="toggle-rule" data-id="${rule.id}" ${rule.active ? 'checked' : ''}></label>
                </div>
                <div class="rule-big">
                  <span class="rule-chip">₹${rule.spend.toLocaleString('en-IN')}</span>${I.icon('arrow', 13)}<span class="rule-chip">${rule.coins} coins</span>
                  <span class="pill pill--${status === 'active' ? 'active' : status === 'scheduled' ? 'scheduled' : status === 'expired' ? 'expired' : 'grey'}">${statusLabelText}</span>
                </div>
                <div class="rule-meta">
                  <span class="hint">${rule.everGreen ? 'Evergreen' : `${formatDate(rule.starts)} – ${formatDate(rule.expires)}`}</span>
                  <button class="link" type="button" data-action="edit-rule" data-id="${rule.id}">Edit rule</button>
                </div>
                <div class="rule-preview">₹2,000 order → ${sampleCoins} coins (${rule.mode === 'slab' ? `${Math.floor(2000 / rule.spend)} × ${rule.coins}` : `${Math.round((2000 / rule.spend) * rule.coins)} pro-rata`})</div>
              </div>`;
            }).join('')}
          </div>
          <button class="add-rule-card mt-12" type="button" data-action="new-rule">${I.icon('plus', 17)}<span>Create a bonus or festive rule</span>${I.icon('right', 15)}</button>

          <div class="card card--pad mt-12">
            <div class="form-card__title" style="margin-bottom:6px">${I.icon('spark', 14)} At checkout today</div>
            <p class="hint">The best active rule wins — rules never stack. A ₹2,000 order currently earns <b>${sample.coins} coins</b> through ${esc(sample.rule ? sample.rule.name : 'the standard rule')}. Cancelled orders return redeemed coins and remove pending earnings.</p>
          </div>

          <button class="card card--pad mt-12 w-100" type="button" data-nav="#/admin/coupons" style="text-align:left">
            <div class="row"><span class="quick__icon quick__icon--gold">${I.icon('ticket', 17)}</span><div class="grow"><b style="font-size:12px">Coupon rules live separately</b><div class="hint">Manage flat and percent offers, scope and limits.</div></div>${I.icon('right', 15)}</div>
          </button>
          <div style="height:6px"></div>
        </div>
      </div>
      ${adminNav('coins')}
    </div>`;
  };

  function couponDisplayStatus(c) {
    const today = todayISO();
    if (c.expires && today > c.expires) return { label: 'Expired', cls: 'expired' };
    if (c.starts && today < c.starts) return { label: 'Scheduled', cls: 'scheduled' };
    if (!c.active) return { label: 'Paused', cls: 'grey' };
    return { label: 'Active', cls: 'active' };
  }

  views['admin-coupons'] = function () {
    const active = STATE.coupons.filter((c) => couponDisplayStatus(c).label === 'Active').length;
    return `<div class="screen screen--admin">
      ${statusbar()}
      ${appbar({
        title: 'Coupons', sub: `${active} active · flat & percentage offers`, back: '#/admin',
        right: `<button class="icon-btn icon-btn--sm${ui.couponFormOpen ? ' icon-btn--navy' : ''}" type="button" data-action="toggle-coupon-form" aria-label="New coupon">${I.icon(ui.couponFormOpen ? 'close' : 'plus', 18)}</button>`
      })}
      <div class="screen-scroll screen-scroll--end">
        ${ui.couponFormOpen ? `<form class="card coupon-form" data-form="coupon-save">
          <h3>Create a coupon</h3>
          <div class="field"><label>Coupon code</label><input class="input" name="code" placeholder="e.g. DIWALI25" maxlength="16" style="text-transform:uppercase" required></div>
          <div class="coupon-form__row">
            <div class="field"><label>Type</label><select class="input select" name="type"><option value="flat">Flat ₹ off</option><option value="percent">Percent off</option></select></div>
            <div class="field"><label>Value</label><input class="input" name="value" type="number" min="1" placeholder="50" required></div>
          </div>
          <div class="coupon-form__row">
            <div class="field"><label>Min cart ₹</label><input class="input" name="min" type="number" min="0" value="499"></div>
            <div class="field"><label>Max discount ₹</label><input class="input" name="maxDiscount" type="number" min="0" placeholder="For % only"></div>
          </div>
          <div class="coupon-form__row">
            <div class="field"><label>Scope</label><select class="input select" name="scope"><option value="all">All items</option>${STATE.categories.map((c) => `<option value="${c.id}">${esc(c.name)}</option>`).join('')}</select></div>
            <div class="field"><label>Expires</label><input class="input" name="expires" type="date" value="2026-12-31"></div>
          </div>
          <div class="coupon-form__row">
            <div class="field"><label>Total uses</label><input class="input" name="maxUses" type="number" min="1" value="100"></div>
            <div class="field"><label>Starts</label><input class="input" name="starts" type="date" value="${todayISO()}"></div>
          </div>
          <div class="form-toggle-row mt-12">
            <div class="form-toggle-row__copy"><b>Can combine with coins</b><small>Let customers use coins after the coupon discount</small></div>
            <label class="switch"><input type="checkbox" name="worksWithCoins" checked></label>
          </div>
          <div class="form-toggle-row">
            <div class="form-toggle-row__copy"><b>First order only</b><small>Valid only for customers with no earlier orders</small></div>
            <label class="switch"><input type="checkbox" name="firstOrderOnly"></label>
          </div>
          <div class="row mt-12">
            <button class="btn btn--secondary btn--sm grow" type="button" data-action="toggle-coupon-form">Cancel</button>
            <button class="btn btn--primary btn--sm grow" type="submit">Create coupon</button>
          </div>
        </form>` : ''}

        <div class="section-head"><h2 style="font-size:15px">All coupons</h2><span class="hint">${STATE.coupons.length} total</span></div>
        <div class="card wallet-list-card">
          ${STATE.coupons.map((c) => {
            const status = couponDisplayStatus(c);
            return `<div class="coupon-item">
              <span class="coupon-item__icon">${I.icon(c.type === 'percent' ? 'percent' : 'ticket', 18)}</span>
              <div class="grow"><b>${esc(c.code)}</b><small>${esc(c.desc)}<br>${c.uses}/${c.maxUses} used · ends ${formatDate(c.expires)}${c.firstOrderOnly ? ' · first order' : ''}</small></div>
              <div class="coupon-item__side">
                <span class="pill pill--${status.cls}">${status.label}</span>
                <label class="switch"><input type="checkbox" data-change="toggle-coupon" data-code="${esc(c.code)}" ${c.active ? 'checked' : ''} aria-label="Toggle ${esc(c.code)}"></label>
              </div>
            </div>`;
          }).join('')}
        </div>
        <div class="sheet__note mt-12">${I.icon('info', 12)} Coupons apply to eligible item value before coins. Flat discounts are capped at the eligible cart value. First-order coupons are checked against the customer’s order history.</div>
        <div style="height:8px"></div>
      </div>
    </div>`;
  };

  const reportDayCounts = { week: 7, month: 30, quarter: 90 };

  function reportOrders() {
    const days = reportDayCounts[ui.reportPeriod] || 7;
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - days);
    return STATE.orders.filter((o) => o.status !== 'Cancelled' && new Date(o.placedAt) >= cutoff);
  }

  function stockDayMeta(key) {
    const parts = String(key || '').split('-').map(Number);
    const date = parts.length === 3 && parts[0] && parts[1] && parts[2] ? new Date(parts[0], parts[1] - 1, parts[2]) : new Date();
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    return {
      key,
      title: key === todayISO() ? 'Today' : key === localDayKey(yesterday) ? 'Yesterday' : date.toLocaleDateString('en-IN', { weekday: 'long' }),
      full: date.toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }),
      short: date.toLocaleDateString('en-IN', { weekday: 'short' }),
      dayNum: date.getDate(),
      isToday: key === todayISO()
    };
  }

  function stockDayOptions(count) {
    const out = [];
    for (let i = 0; i < count; i += 1) {
      const d = new Date();
      d.setHours(12, 0, 0, 0);
      d.setDate(d.getDate() - i);
      out.push(stockDayMeta(localDayKey(d)));
    }
    return out;
  }

  function orderItemVariantIndex(p, item) {
    if (!p) return Number.isInteger(item.variantIndex) ? item.variantIndex : 0;
    if (Number.isInteger(item.variantIndex) && p.variants[item.variantIndex]) return item.variantIndex;
    const match = p.variants.findIndex((v) => v.unit === item.unit || v.label === item.unit);
    return match >= 0 ? match : p.defaultVariant;
  }

  function stockDayData(day, includeAll) {
    const items = {};
    const ensureItem = (productId, snapshot) => {
      if (!items[productId]) {
        const p = productById(productId);
        items[productId] = {
          id: productId,
          product: p || null,
          name: p ? p.name : (snapshot.name || 'Product'),
          art: p ? p.art : (snapshot.art || 'box'),
          tone: p ? p.tone : (snapshot.tone || 'gold'),
          inQty: 0, soldQty: 0, shelf: p ? p.stock : 0,
          packs: {}
        };
      }
      return items[productId];
    };
    const ensurePack = (item, label, variantIndex, p) => {
      const key = label || (p && p.variants[variantIndex] ? p.variants[variantIndex].label : `pack-${variantIndex}`);
      if (!item.packs[key]) {
        const pv = p && p.variants[variantIndex] ? p.variants[variantIndex] : null;
        item.packs[key] = { label: key, inQty: 0, soldQty: 0, shelf: pv ? variantStock(p, variantIndex) : null };
      }
      return item.packs[key];
    };
    (STATE.stockMoves || []).forEach((m) => {
      if (!m || !m.qty || localDayKey(m.at) !== day) return;
      const p = productById(m.productId) || null;
      const vi = Number.isInteger(m.variantIndex) ? m.variantIndex : -1;
      const pv = p && p.variants[vi] ? p.variants[vi] : null;
      const label = m.variantLabel || (pv ? pv.label : 'Pack');
      const item = ensureItem(m.productId, { name: m.productName, art: 'box', tone: 'gold' });
      item.inQty += m.qty;
      ensurePack(item, label, vi, p).inQty += m.qty;
    });
    STATE.orders.forEach((o) => {
      if (!o || o.status === 'Cancelled' || localDayKey(o.placedAt) !== day) return;
      o.items.forEach((it) => {
        const p = productById(it.productId) || null;
        const vi = orderItemVariantIndex(p, it);
        const pv = p && p.variants[vi] ? p.variants[vi] : null;
        const label = it.unit || (pv ? pv.label : 'Pack');
        const item = ensureItem(it.productId, it);
        item.soldQty += it.qty;
        ensurePack(item, label, vi, p).soldQty += it.qty;
      });
    });
    if (includeAll) STATE.products.forEach((p) => ensureItem(p.id, p));
    const rows = Object.values(items);
    const moved = rows.filter((item) => item.inQty > 0 || item.soldQty > 0)
      .sort((a, b) => (b.inQty + b.soldQty) - (a.inQty + a.soldQty) || a.name.localeCompare(b.name));
    const idle = rows.filter((item) => !item.inQty && !item.soldQty).sort((a, b) => a.name.localeCompare(b.name));
    return {
      rows: moved.concat(idle),
      inTotal: moved.reduce((sum, item) => sum + item.inQty, 0),
      soldTotal: moved.reduce((sum, item) => sum + item.soldQty, 0),
      shelfTotal: STATE.products.reduce((sum, p) => sum + p.stock, 0),
      movedCount: moved.length
    };
  }

  function stockPackSummary(item) {
    return Object.values(item.packs)
      .filter((pack) => pack.inQty || pack.soldQty)
      .map((pack) => {
        const flow = [];
        if (pack.inQty) flow.push(`+${pack.inQty}`);
        if (pack.soldQty) flow.push(`−${pack.soldQty}`);
        return `${pack.label} ${flow.join(' ')}`;
      })
      .join(' · ');
  }

  function stockRowHtml(item) {
    const moved = item.inQty > 0 || item.soldQty > 0;
    const packText = stockPackSummary(item);
    const sub = packText || (item.product ? `${item.product.variants.length} pack${item.product.variants.length === 1 ? '' : 's'} · no movement` : 'No movement');
    return `<button class="stock-row${moved ? '' : ' is-idle'}" type="button" data-action="stock-item" data-id="${esc(item.id)}" data-day="${esc(ui.stockDay)}" aria-label="Review stock movement for ${esc(item.name)}">
      ${item.product ? thumb(item.product, 'thumb--xs') : `<span class="thumb thumb--xs tone-${esc(item.tone)}">${I.art(item.art)}</span>`}
      <span class="stock-row__body"><b>${esc(item.name)}</b><small>${esc(sub)}</small></span>
      <span class="stock-num stock-num--in">${item.inQty ? `+${item.inQty}` : '—'}</span>
      <span class="stock-num stock-num--out">${item.soldQty ? `−${item.soldQty}` : '—'}</span>
      <span class="stock-num stock-num--shelf">${item.product ? item.shelf : '—'}</span>
    </button>`;
  }

  function reportTabs(active) {
    const tabs = [['sales', 'Sales', 'chart', '#/admin/reports'], ['stock', 'Stock movement', 'box', '#/admin/stock-report']];
    return `<div class="report-tabs" role="tablist" aria-label="Report type">
      ${tabs.map(([key, label, icon, href]) => `<button class="report-tab${active === key ? ' is-active' : ''}" type="button" role="tab" aria-selected="${active === key}" data-nav="${href}">${I.icon(icon, 14)}<span>${label}</span></button>`).join('')}
    </div>`;
  }

  views['admin-reports'] = function () {
    const rel = reportOrders();
    const revenue = rel.reduce((sum, o) => sum + o.bill.total, 0);
    const count = rel.length;
    const avg = count ? Math.round(revenue / count) : 0;
    const coins = rel.reduce((sum, o) => sum + o.coinsEarned, 0);
    const completed = rel.filter((o) => o.status === 'Delivered' || o.status === 'Picked Up').length;
    const delivery = rel.filter((o) => o.mode === 'delivery').length;
    const pickup = count - delivery;
    const prepaid = rel.filter((o) => o.payment === 'UPI / Card').length;
    const cod = count - prepaid;
    const maxSale = Math.max.apply(null, STATE.weekSales.map((d) => d.amount).concat([1]));
    const weekTotal = STATE.weekSales.reduce((sum, d) => sum + d.amount, 0);
    const productMap = {};
    rel.forEach((o) => o.items.forEach((it) => {
      if (!productMap[it.productId]) productMap[it.productId] = { name: it.name, art: it.art, tone: it.tone, qty: 0, revenue: 0 };
      productMap[it.productId].qty += it.qty;
      productMap[it.productId].revenue += it.price * it.qty;
    }));
    const top = Object.values(productMap).sort((a, b) => b.revenue - a.revenue).slice(0, 4);
    const topMax = top.length ? top[0].revenue : 1;
    const catMap = {};
    rel.forEach((o) => o.items.forEach((it) => {
      const p = productById(it.productId);
      const cat = p ? p.category : 'other';
      catMap[cat] = (catMap[cat] || 0) + it.price * it.qty;
    }));
    const catRows = Object.entries(catMap).sort((a, b) => b[1] - a[1]);
    const catTotal = catRows.reduce((sum, row) => sum + row[1], 0) || 1;
    const periodLabel = ui.reportPeriod === 'week' ? 'Last 7 days' : ui.reportPeriod === 'month' ? 'Last 30 days' : 'Last 90 days';
    return `<div class="screen screen--admin">
      ${statusbar()}
      ${appbar({
        title: 'Reports', sub: `${periodLabel} · ${count} orders`, back: '#/admin',
        right: `<button class="icon-btn icon-btn--sm" type="button" data-action="export-report" aria-label="Export CSV">${I.icon('arrow', 17)}</button>`
      })}
      <div class="screen-scroll screen-scroll--end">
        ${reportTabs('sales')}
        <div class="chips">
          ${[['week', 'Week'], ['month', 'Month'], ['quarter', 'Quarter']].map(([key, label]) => `<button class="chip chip--sm${ui.reportPeriod === key ? ' is-active' : ''}" type="button" data-action="report-period" data-period="${key}">${label}</button>`).join('')}
        </div>
        <div class="report-metrics">
          <div class="report-metric"><div class="m-label">Revenue</div><b>${money(revenue)}</b><span>${completed} completed orders</span></div>
          <div class="report-metric"><div class="m-label">Orders</div><b>${count}</b><span>${delivery} delivery · ${pickup} pickup</span></div>
          <div class="report-metric"><div class="m-label">Avg order</div><b>${money(avg)}</b><span>Across paid orders</span></div>
          <div class="report-metric"><div class="m-label">Coins issued</div><b>${coins}</b><span>Worth ${money(coins)}</span></div>
        </div>

        <div class="chart-card card mt-12">
          <div class="chart-head"><div><b>Sales rhythm</b><br><span>Last 7 trading days</span></div><span class="pill pill--green">${money(weekTotal)}</span></div>
          <div class="chart-bars">
            ${STATE.weekSales.map((d, i) => `<div class="chart-bar${i === STATE.weekSales.length - 1 ? ' is-today' : ''}">
              <i style="height:${Math.max(12, Math.round((d.amount / maxSale) * 100))}%"></i><small>${d.day}</small>
            </div>`).join('')}
          </div>
        </div>

        <div class="section-head"><h2 style="font-size:15px">Top products</h2><span class="hint">By revenue</span></div>
        <div class="card card--pad">
          ${top.length ? top.map((p) => `<div class="top-product">
            ${`<span class="thumb thumb--xs tone-${p.tone || 'gold'}">${I.art(p.art)}</span>`}
            <div class="top-product__body"><b>${esc(p.name)}</b><div class="top-product__bar"><i style="width:${Math.max(8, Math.round((p.revenue / topMax) * 100))}%"></i></div></div>
            <span class="top-product__value">${money(p.revenue)}</span>
          </div>`).join('') : `<div class="admin-empty"><b>No sales yet</b>This period has no orders.</div>`}
        </div>

        <div class="section-head"><h2 style="font-size:15px">Order mix</h2><span class="hint">${count} orders</span></div>
        <div class="report-split">
          <div class="report-mini"><span class="report-mini__icon metric__icon--navy">${I.icon('truck', 15)}</span><b>${delivery}</b><span>Home deliveries</span></div>
          <div class="report-mini"><span class="report-mini__icon metric__icon--gold">${I.icon('store', 15)}</span><b>${pickup}</b><span>Store pickups</span></div>
          <div class="report-mini"><span class="report-mini__icon metric__icon--green">${I.icon('card', 15)}</span><b>${prepaid}</b><span>Prepaid orders</span></div>
          <div class="report-mini"><span class="report-mini__icon metric__icon--green">${I.icon('cash', 15)}</span><b>${cod}</b><span>Cash / pay at store</span></div>
        </div>

        <div class="section-head"><h2 style="font-size:15px">Category split</h2><span class="hint">Revenue</span></div>
        <div class="card card--pad">
          ${catRows.length ? catRows.map(([cat, amount]) => {
            const c = STATE.categories.find((x) => x.id === cat);
            return `<div class="top-product" style="padding:9px 0">
              <div class="top-product__body"><b>${esc(c ? c.name : 'Other')}</b><div class="top-product__bar"><i style="width:${Math.max(6, Math.round((amount / catTotal) * 100))}%"></i></div></div>
              <span class="top-product__value">${money(amount)}</span>
            </div>`;
          }).join('') : `<div class="admin-empty"><b>Nothing to chart</b>No product sales in this period.</div>`}
        </div>

        <button class="btn btn--secondary btn--sm btn--block mt-12" type="button" data-action="export-report">${I.icon('arrow', 15)} Download ${periodLabel.toLowerCase()} report (CSV)</button>
        <p class="hint hint--center mt-12">Reports exclude cancelled orders. Free home delivery means delivery fees are always ₹0.</p>
        <div style="height:8px"></div>
      </div>
    </div>`;
  };

  views['admin-stock-report'] = function () {
    const stock = stockDayData(ui.stockDay, ui.stockShowAll);
    const stockMeta = stockDayMeta(ui.stockDay);
    const stockDays = stockDayOptions(7);
    if (!stockDays.some((day) => day.key === stockMeta.key)) stockDays.unshift(stockMeta);
    return `<div class="screen screen--admin">
      ${statusbar()}
      ${appbar({
        title: 'Stock movement',
        sub: 'Purchases vs sold · item wise',
        back: '#/admin/reports'
      })}
      <div class="screen-scroll screen-scroll--end">
        ${reportTabs('stock')}
        <div class="stock-card card">
          <div class="stock-head">
            <div class="stock-head__copy"><b>${stockMeta.title}</b><span>${esc(stockMeta.full)}</span></div>
            <input class="stock-date" type="date" value="${esc(stockMeta.key)}" max="${todayISO()}" data-change="stock-day" aria-label="Choose the stock report day">
          </div>
          <div class="chips stock-days">
            ${stockDays.map((d) => `<button class="chip chip--sm stock-day${d.key === stockMeta.key ? ' is-active' : ''}" type="button" data-action="stock-day" data-day="${d.key}" aria-label="${esc(d.full)}"><span>${d.isToday ? 'Today' : d.short}</span><b>${d.dayNum}</b></button>`).join('')}
          </div>
          <div class="stock-stats">
            <div class="stock-stat stock-stat--in"><span>Stock in</span><b>+${stock.inTotal}</b><small>units received</small></div>
            <div class="stock-stat stock-stat--out"><span>Sold</span><b>${stock.soldTotal ? `−${stock.soldTotal}` : '0'}</b><small>units in orders</small></div>
            <div class="stock-stat"><span>On shelf</span><b>${stock.shelfTotal}</b><small>all packs now</small></div>
          </div>
          <div class="stock-table-head"><span></span><span>Item</span><span>In</span><span>Sold</span><span>Shelf</span></div>
          ${stock.movedCount || ui.stockShowAll
            ? (stock.rows.length ? `<div class="stock-rows">${stock.rows.map(stockRowHtml).join('')}</div>` : `<div class="admin-empty"><b>No items in the catalogue</b>Add a product to start tracking stock movement.</div>`)
            : `<div class="stock-empty"><span class="stock-empty__icon">${I.icon('box', 19)}</span><div><b>No movement on this day</b><span>No purchases or sales were recorded. Pick another date or show all shelf items.</span></div></div>`}
          <div class="stock-foot">
            <div class="stock-all">
              <div class="grow"><b>Show all items</b><small>Include items with no movement</small></div>
              <label class="switch switch--sm"><input type="checkbox" data-change="stock-all" ${ui.stockShowAll ? 'checked' : ''} aria-label="Show all items"></label>
            </div>
            <p class="hint">Tap an item to review each receipt and sold order pack by pack. Sold uses non-cancelled orders placed that day; direct pack edits are not counted as purchases.</p>
          </div>
        </div>
        <p class="hint hint--center mt-12">Every receipt and order line stays visible inside an item, so a wrong entry can be traced to its source.</p>
        <div style="height:8px"></div>
      </div>
    </div>`;
  };

  views['admin-more'] = function () {
    return `<div class="screen screen--admin">
      ${statusbar(true, true)}
      ${adminHead('More', 'Store settings, reports and shortcuts')}
      <div class="screen-scroll">
        <div class="admin-body-pad">
          <div class="more-hero">
            <span class="avatar">V</span>
            <div class="grow"><h2>${D.store.name}</h2><p>Owner console · Alkapuri, Vadodara · ${D.store.phone}</p></div>
            <span class="pill" style="background:rgba(255,255,255,.12);color:#fff">Owner</span>
          </div>

          <div class="section-head"><h2 style="font-size:15px">Store operations</h2></div>
          <div class="card menu-card">
            <button class="menu-item" type="button" data-nav="#/admin/inventory"><span class="menu-item__icon">${I.icon('grid', 16)}</span><div class="grow"><b>Inventory</b><small>Stock levels, pricing and product visibility</small></div>${I.icon('right', 16)}</button>
            <button class="menu-item" type="button" data-nav="#/admin/hot-sale"><span class="menu-item__icon menu-item__icon--red">${I.icon('flame', 16)}</span><div class="grow"><b>Hot sale manager</b><small>Banner, featured products and timing</small></div>${I.icon('right', 16)}</button>
            <button class="menu-item" type="button" data-nav="#/admin/coupons"><span class="menu-item__icon menu-item__icon--gold">${I.icon('ticket', 16)}</span><div class="grow"><b>Coupons</b><small>${STATE.coupons.filter((c) => couponDisplayStatus(c).label === 'Active').length} active offers</small></div>${I.icon('right', 16)}</button>
            <button class="menu-item" type="button" data-nav="#/admin/coins"><span class="menu-item__icon menu-item__icon--gold">${I.icon('coin', 16)}</span><div class="grow"><b>Coin rules</b><small>Earning, redemption limits and expiry</small></div>${I.icon('right', 16)}</button>
            <button class="menu-item" type="button" data-nav="#/admin/reports"><span class="menu-item__icon">${I.icon('chart', 16)}</span><div class="grow"><b>Reports</b><small>Revenue, stock movement and top products</small></div>${I.icon('right', 16)}</button>
            <button class="menu-item" type="button" data-action="store-info"><span class="menu-item__icon menu-item__icon--green">${I.icon('store', 16)}</span><div class="grow"><b>Store information</b><small>Address, phone and delivery promise</small></div>${I.icon('right', 16)}</button>
          </div>

          <div class="section-head"><h2 style="font-size:15px">Preferences</h2></div>
          <div class="card menu-card">
            <div class="menu-item">
              <span class="menu-item__icon menu-item__icon--green">${I.icon('bell', 16)}</span>
              <div class="grow"><b>Store notifications</b><small>Order alerts, low stock and coin payouts</small></div>
              <label class="switch"><input type="checkbox" data-change="toggle-notifications" ${STATE.settings.notifications ? 'checked' : ''}></label>
            </div>
            <button class="menu-item" type="button" data-nav="#/home"><span class="menu-item__icon">${I.icon('user', 16)}</span><div class="grow"><b>Switch to customer app</b><small>See the storefront as Mahipal</small></div>${I.icon('right', 16)}</button>
            <button class="menu-item" type="button" data-action="reset-confirm"><span class="menu-item__icon menu-item__icon--red">${I.icon('refresh', 16)}</span><div class="grow"><b class="red">Reset demo data</b><small>Restore original orders, stock and coins</small></div>${I.icon('right', 16)}</button>
          </div>

          <div class="card card--pad mt-12 center">
            <div class="strong">Vijay Super Mall · Owner console</div>
            <p class="hint mt-4">Prototype v1.0 · Alkapuri, Vadodara<br>Free home delivery · EN + ગુજરાતી</p>
          </div>
          <div style="height:6px"></div>
        </div>
      </div>
      ${adminNav('more')}
    </div>`;
  };

  /* ---------- admin sheets ---------- */
  sheets['admin-notifications'] = function () {
    const newOrders = STATE.orders.filter((o) => o.status === 'Placed');
    const low = lowStockProducts();
    const pending = STATE.ledger.filter((l) => l.status === 'pending').length;
    return sheetShell('Store alerts', `${newOrders.length} new ${newOrders.length === 1 ? 'order' : 'orders'} · ${low.length} stock ${low.length === 1 ? 'alert' : 'alerts'}`, `
      <div class="section-head" style="margin-top:2px"><h2 style="font-size:14px">New orders</h2><span class="hint">Need confirming</span></div>
      <div class="card wallet-list-card">
        ${newOrders.length ? newOrders.slice(0, 4).map((o) => `<div class="ledger-item" role="link" tabindex="0" data-nav="#/admin/order/${o.number}">
          <span class="ledger-item__icon">${I.icon('box', 17)}</span>
          <div class="grow"><b>${esc(o.number)} · ${esc(o.customer)}</b><span>${money(o.bill.total)} · ${whenLabel(o.placedAt)} · ${o.mode === 'pickup' ? 'Pickup' : 'Delivery'}</span></div>
          <span class="pill pill--placed">New</span>
        </div>`).join('') : `<div class="admin-empty"><b>No new orders</b>Everything is confirmed.</div>`}
      </div>
      <div class="section-head"><h2 style="font-size:14px">Stock alerts</h2><span class="hint">${low.length} ${low.length === 1 ? 'item' : 'items'}</span></div>
      <div class="card wallet-list-card">
        ${low.length ? low.slice(0, 4).map((p) => `<div class="ledger-item" role="link" tabindex="0" data-nav="#/admin/product/${p.id}">
          <span class="ledger-item__icon ledger-item__icon--spend">${I.icon('info', 17)}</span>
          <div class="grow"><b>${esc(p.name)}</b><span>${p.stock} left · low stock threshold ${p.lowStock}</span></div>
          <span class="pill pill--${p.stock <= 0 ? 'cancelled' : 'low'}">${p.stock <= 0 ? 'Out' : 'Low'}</span>
        </div>`).join('') : `<div class="admin-empty"><b>All stocked up</b>No low stock items.</div>`}
      </div>
      ${pending ? `<div class="note-strip mt-12">${I.icon('coin', 14)}<span>${pending} order coin payout is pending until delivery or pickup.</span></div>` : ''}
      <div class="sheet__actions">
        <button class="btn btn--primary btn--block" type="button" data-nav="#/admin/orders">Open orders queue</button>
        <button class="btn btn--secondary btn--block" type="button" data-nav="#/admin/inventory">Review inventory</button>
        <button class="btn btn--soft btn--block" type="button" data-action="close-sheet">Done</button>
      </div>`);
  };

  sheets['stock-item'] = function (s) {
    const p = productById(s.id);
    if (!p) return '';
    const day = s.day || ui.stockDay || todayISO();
    const meta = stockDayMeta(day);
    const moves = (STATE.stockMoves || [])
      .filter((m) => m && m.productId === p.id && localDayKey(m.at) === day)
      .sort((a, b) => new Date(b.at) - new Date(a.at));
    const sales = [];
    STATE.orders.forEach((o) => {
      if (o.status === 'Cancelled' || localDayKey(o.placedAt) !== day) return;
      o.items.forEach((it) => {
        if (it.productId !== p.id) return;
        const vi = orderItemVariantIndex(p, it);
        const pv = p.variants[vi];
        sales.push({
          order: o,
          qty: it.qty,
          label: it.unit || (pv ? pv.label : 'Pack'),
          variantIndex: vi
        });
      });
    });
    sales.sort((a, b) => new Date(b.order.placedAt) - new Date(a.order.placedAt));
    const inQty = moves.reduce((sum, m) => sum + m.qty, 0);
    const soldQty = sales.reduce((sum, line) => sum + line.qty, 0);
    const packs = p.variants.map((v, i) => ({
      label: v.label,
      stock: variantStock(p, i),
      inQty: moves.filter((m) => m.variantIndex === i || m.variantLabel === v.label).reduce((sum, m) => sum + m.qty, 0),
      soldQty: sales.filter((line) => line.variantIndex === i || line.label === v.label).reduce((sum, line) => sum + line.qty, 0)
    }));
    return sheetShell(p.name, `${meta.full} · stock check`, `
      <div class="stock-sheet-stats">
        <div class="stock-stat stock-stat--in"><span>Stock in</span><b>+${inQty}</b><small>units received</small></div>
        <div class="stock-stat stock-stat--out"><span>Sold</span><b>${soldQty ? `−${soldQty}` : '0'}</b><small>units in orders</small></div>
        <div class="stock-stat"><span>On shelf</span><b>${p.stock}</b><small>all packs now</small></div>
      </div>

      <div class="section-head"><h2 style="font-size:14px">Stock in</h2><span class="hint">${moves.length} ${moves.length === 1 ? 'receipt' : 'receipts'}</span></div>
      <div class="card wallet-list-card">
        ${moves.length ? moves.map((m) => {
          const label = m.variantLabel || (p.variants[m.variantIndex] ? p.variants[m.variantIndex].label : 'Pack');
          return `<div class="ledger-item">
            <span class="ledger-item__icon stock-sheet-icon stock-sheet-icon--in">${I.icon('plus', 16)}</span>
            <div class="grow"><b>+${m.qty} × ${esc(label)}</b><span>${formatTime(m.at)} · ${esc(m.note || 'Stock received')}</span></div>
          </div>`;
        }).join('') : `<div class="stock-sheet-empty">No stock received on this day.</div>`}
      </div>

      <div class="section-head"><h2 style="font-size:14px">Sold</h2><span class="hint">${sales.length} ${sales.length === 1 ? 'order line' : 'order lines'}</span></div>
      <div class="card wallet-list-card">
        ${sales.length ? sales.map((line) => `<div class="ledger-item stock-sale-link" role="link" tabindex="0" data-nav="#/admin/order/${line.order.number}">
          <span class="ledger-item__icon stock-sheet-icon stock-sheet-icon--out">${I.icon('cart', 15)}</span>
          <div class="grow"><b>−${line.qty} × ${esc(line.label)}</b><span>${esc(line.order.number)} · ${esc(line.order.customer)} · ${formatTime(line.order.placedAt)} · ${esc(statusLabel(line.order.status))}</span></div>
          ${I.icon('right', 14)}
        </div>`).join('') : `<div class="stock-sheet-empty">No orders for this item on this day.</div>`}
      </div>

      <div class="section-head"><h2 style="font-size:14px">On shelf now</h2><span class="hint">${packs.length} ${packs.length === 1 ? 'pack' : 'packs'}</span></div>
      <div class="card stock-shelf-card">
        ${packs.map((pack) => `<div class="stock-shelf-row">
          <div class="grow"><b>${esc(pack.label)}</b><small>In +${pack.inQty} · Sold −${pack.soldQty}</small></div>
          <span class="stock-shelf-row__stock">${pack.stock}<small>on shelf</small></span>
        </div>`).join('')}
      </div>

      <div class="sheet__note">${I.icon('info', 13)} Sales count every non-cancelled order placed on this day. Stock in only includes supplier receipts, new packs and product opening stock.</div>
      <div class="sheet__actions">
        <button class="btn btn--primary btn--block" type="button" data-action="close-sheet">Done</button>
      </div>`);
  };

  sheets['product-picker'] = function () {
    const others = STATE.products.filter((p) => STATE.hotSale.featured.indexOf(p.id) === -1);
    return sheetShell('Add to hot sale', `${STATE.hotSale.featured.length} products featured`, `
      ${others.length ? `<div class="stack">${others.map((p) => {
        const v = variantOf(p, p.defaultVariant);
        return `<button class="inventory-row" type="button" data-action="add-featured" data-id="${p.id}">
          ${thumb(p, 'thumb--sm')}
          <div class="inventory-row__body"><h3>${esc(p.name)}</h3><span>${esc(v.unit)} · ${money(v.price)} · ${p.stock} in stock</span></div>
          <div class="inventory-row__side"><span class="pill pill--hot">Add</span></div>
        </button>`;
      }).join('')}</div>` : emptyState('flame', 'Everything is featured', 'All products in the catalogue are already in this hot sale.')}
      <div class="sheet__actions">
        <button class="btn btn--primary btn--block" type="button" data-action="close-sheet">Done</button>
      </div>`);
  };

  sheets['rule-form'] = function (s) {
    const rule = s.id ? STATE.coinRules.find((r) => r.id === s.id) : null;
    return sheetShell(rule ? 'Edit earning rule' : 'New earning rule', rule ? rule.name : 'Rules apply to all coin-eligible items', `
      <form data-form="rule-save" data-id="${rule ? rule.id : ''}">
        <div class="field"><label>Rule name</label><input class="input" name="name" value="${esc(rule ? rule.name : '')}" placeholder="e.g. Diwali bonus" required></div>
        <div class="field-row mt-8">
          <div class="field"><label>Spend ₹</label><input class="input" name="spend" type="number" min="1" value="${rule ? rule.spend : 1000}" required></div>
          <div class="field"><label>Earn coins</label><input class="input" name="coins" type="number" min="1" value="${rule ? rule.coins : 10}" required></div>
        </div>
        <div class="field mt-8"><label>Calculation</label>
          <select class="input select" name="mode">
            <option value="pro-rata" ${rule && rule.mode === 'pro-rata' ? 'selected' : ''}>Pro-rata · every rupee counts</option>
            <option value="slab" ${rule && rule.mode === 'slab' ? 'selected' : ''}>Slab · full blocks only</option>
          </select>
        </div>
        <div class="field-row mt-8">
          <div class="field"><label>Starts (optional)</label><input class="input" name="starts" type="date" value="${esc(rule && rule.starts ? rule.starts : '')}"></div>
          <div class="field"><label>Ends (optional)</label><input class="input" name="expires" type="date" value="${esc(rule && rule.expires ? rule.expires : '')}"></div>
        </div>
        <div class="form-toggle-row mt-12">
          <div class="form-toggle-row__copy"><b>Rule active</b><small>Pause it without deleting the setup</small></div>
          <label class="switch"><input type="checkbox" name="active" ${!rule || rule.active ? 'checked' : ''}></label>
        </div>
        <div class="sheet__note">Leave both dates blank for an evergreen rule. When several rules apply, the one giving the most coins wins; rules do not stack.</div>
        <div class="sheet__actions">
          <button class="btn btn--primary btn--block" type="submit">Save rule</button>
          <button class="btn btn--secondary btn--block" type="button" data-action="close-sheet">Cancel</button>
        </div>
      </form>`);
  };

  sheets['reset-confirm'] = function () {
    return sheetShell('Reset the demo?', 'This restores the original store data', `
      <div class="danger-note" style="margin-top:0">${I.icon('info', 15)}<span>Any orders you place, stock edits or coupons you create will be removed. The demo returns to its first-run state.</span></div>
      <div class="sheet__actions">
        <button class="btn btn--danger-soft btn--block" type="button" data-action="reset-demo">Reset demo data</button>
        <button class="btn btn--secondary btn--block" type="button" data-action="close-sheet">Keep my changes</button>
      </div>`);
  };

  /* ---------- routing ---------- */
  let splashTimer = null;

  function adminMissing() {
    return `<div class="screen screen--admin">
      ${statusbar()}
      ${appbar({ title: 'Admin', back: '#/admin' })}
      <div class="screen-scroll screen-scroll--end">
        ${emptyState('box', 'Page not found', 'That admin screen is not part of this demo.', `<button class="btn btn--primary btn--sm" type="button" data-nav="#/admin">Back to dashboard</button>`)}
      </div>
    </div>`;
  }

  function screenForRoute(route) {
    const seg = route.seg;
    if (!seg.length) return views.welcome();
    if (seg[0] === 'admin') {
      switch (seg[1] || '') {
        case '': return views.admin();
        case 'orders': return views['admin-orders']();
        case 'order': return views['admin-order'](route);
        case 'inventory': return views['admin-inventory']();
        case 'product': return views['admin-product'](route);
        case 'hot-sale': return views['admin-hot-sale']();
        case 'coins': return views['admin-coins']();
        case 'coupons': return views['admin-coupons']();
        case 'reports': return views['admin-reports']();
        case 'stock-report': return views['admin-stock-report']();
        case 'more': return views['admin-more']();
        default: return adminMissing();
      }
    }
    switch (seg[0]) {
      case 'splash': return views.splash();
      case 'welcome': return views.welcome();
      case 'signin': return views.signin();
      case 'home': return views.home();
      case 'shop': return views.shop(route);
      case 'product': return views.product(route);
      case 'cart': return views.cart();
      case 'checkout': return views.checkout();
      case 'placed': return views.placed(route);
      case 'track': return views.track(route);
      case 'orders': return views.orders();
      case 'wallet': return views.wallet();
      case 'profile': return views.profile();
      default: return missingScreen('That page is not part of this demo.', '#/home', 'Page');
    }
  }

  function render(keepScroll) {
    const route = parseRoute();
    const previous = keepScroll ? appEl.querySelector('.screen-scroll') : null;
    const scrollTop = previous ? previous.scrollTop : 0;
    const toast = document.getElementById('appToast');
    appEl.innerHTML = screenForRoute(route);
    const sheet = renderSheet();
    if (sheet) appEl.insertAdjacentHTML('beforeend', sheet);
    if (toast) appEl.appendChild(toast);
    if (keepScroll) {
      const next = appEl.querySelector('.screen-scroll');
      if (next) {
        const auto = next.style.scrollBehavior;
        next.style.scrollBehavior = 'auto';
        next.scrollTop = scrollTop;
        next.style.scrollBehavior = auto;
      }
    }
    updateStage(route.seg);
    syncRails();
    clearTimeout(splashTimer);
    if (route.seg[0] === 'splash') {
      splashTimer = setTimeout(() => {
        go(STATE.signedIn ? '#/home' : '#/welcome');
      }, 1800);
    }
  }

  /* ---------- UI actions ---------- */
  function clearCart() {
    if (!STATE.cart.items.length) return;
    STATE.cart.items = [];
    STATE.cart.coupon = '';
    STATE.cart.useCoins = false;
    STATE.cart.coinCustom = '';
    save();
    render(true);
    showToast('Cart cleared', 'success');
  }

  function removeCoupon() {
    STATE.cart.coupon = '';
    ui.couponMsg = '';
    save();
    render(true);
    showToast('Coupon removed', 'success');
  }

  function selectAddress(id) {
    const address = STATE.addresses.find((a) => a.id === id);
    if (!address) return;
    STATE.selectedAddress = id;
    save();
    ui.sheet = null;
    render(true);
    showToast(`Delivering to ${address.label}`, 'success');
  }

  function setCoinMode(mode) {
    if (['all', 'percent', 'custom'].indexOf(mode) === -1) return;
    STATE.cart.coinMode = mode;
    STATE.cart.useCoins = true;
    save();
    render(true);
    if (mode === 'custom') {
      const input = appEl.querySelector('form[data-form="coins-custom"] input[name="coins"]');
      if (input) input.focus();
    }
  }

  function stopCoins() {
    STATE.cart.useCoins = false;
    save();
    ui.sheet = null;
    render(true);
    showToast('Coins removed from this order');
  }

  function shareProduct(id) {
    const p = productById(id);
    if (!p) return;
    const url = `${location.origin === 'null' ? '' : location.origin}${location.pathname}#/product/${p.id}`;
    if (navigator.share) {
      navigator.share({ title: p.name, text: `${p.name} at Vijay Super Mall`, url }).catch(() => {});
      return;
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(url)
        .then(() => showToast('Product link copied', 'success'))
        .catch(() => showToast(url));
      return;
    }
    showToast(url);
  }

  function signOut() {
    STATE.signedIn = false;
    save();
    ui.sheet = null;
    go('#/welcome');
    showToast('Signed out', 'success');
  }

  function addFeatured(id) {
    if (!productById(id) || STATE.hotSale.featured.indexOf(id) !== -1) return;
    STATE.hotSale.featured.push(id);
    save();
    render(true);
    showToast('Added to hot sale', 'success');
  }

  function removeFeatured(id) {
    STATE.hotSale.featured = STATE.hotSale.featured.filter((x) => x !== id);
    save();
    render(true);
    showToast('Removed from hot sale');
  }

  function clearShopSearch() {
    const { params } = parseRoute();
    const cat = params.get('cat');
    go(cat ? `#/shop?cat=${encodeURIComponent(cat)}` : '#/shop');
  }

  function resetShopFilters() {
    ui.shop = { sort: 'popular', stock: false, coins: false };
    ui.sheet = null;
    const { params } = parseRoute();
    if (params.get('q')) go('#/shop');
    else render(true);
    showToast('Filters cleared', 'success');
  }

  function fillDemoOtp() {
    const inputs = appEl.querySelectorAll('[data-otp]');
    ['1', '2', '3', '4'].forEach((value, i) => {
      if (inputs[i]) inputs[i].value = value;
    });
    if (inputs[0]) inputs[0].focus();
    showToast('Demo OTP filled · tap verify', 'success');
  }

  function exportReport() {
    const rows = reportOrders();
    const header = ['Order', 'Date', 'Customer', 'Phone', 'Mode', 'Status', 'Payment', 'Payment state', 'Item total', 'Coupon', 'Coupon discount', 'Coins used', 'Coin discount', 'Total', 'Coins earned'];
    const cell = (value) => {
      let s = String(value == null ? '' : value);
      if (/^[=+\-@]/.test(s)) s = `'${s}`;
      return `"${s.replace(/"/g, '""')}"`;
    };
    const csv = [header.map(cell).join(',')].concat(rows.map((o) => [
      o.number, new Date(o.placedAt).toLocaleString('en-IN'), o.customer, o.phone,
      o.mode === 'pickup' ? 'Store pickup' : 'Home delivery', o.status, o.payment, o.paymentState,
      o.bill.subtotal, o.bill.couponCode || '—', o.bill.couponDiscount, o.coinsUsed,
      o.coinsUsed, o.bill.total, o.coinsEarned
    ].map(cell).join(','))).join('\r\n');
    const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `vijay-super-mall-report-${todayISO()}.csv`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(link.href), 1500);
    showToast(`${rows.length} orders exported`, 'success');
  }

  function handleAction(action, el) {
    switch (action) {
      case 'set-lang': setLang(el.dataset.lang); break;
      case 'fill-otp': fillDemoOtp(); break;
      case 'open-addresses': openSheet('addresses'); break;
      case 'open-notifications': openSheet('notifications'); break;
      case 'open-coupon-sheet': ui.couponMsg = ''; openSheet('coupon'); break;
      case 'open-coins-sheet': openSheet('coins'); break;
      case 'open-filters': openSheet('filters'); break;
      case 'open-wishlist': openSheet('wishlist'); break;
      case 'how-coins': openSheet('how-coins'); break;
      case 'store-info':
      case 'support': openSheet('store-info'); break;
      case 'close-sheet': closeSheet(); break;
      case 'toggle-wish': toggleWishlist(el.dataset.id); break;
      case 'share-product': shareProduct(el.dataset.id); break;
      case 'quick-add': addToCart(el.dataset.id, Number(el.dataset.variant || 0), 1); break;
      case 'select-variant':
        ui.pdVariant = Number(el.dataset.index) || 0;
        render(true);
        break;
      case 'pd-qty': {
        const p = productById(parseRoute().seg[1]);
        if (p) {
          const max = Math.max(1, variantStock(p, ui.pdVariant));
          ui.pdQty = Math.min(max, Math.max(1, ui.pdQty + Number(el.dataset.delta || 0)));
          render(true);
        }
        break;
      }
      case 'add-pd': {
        const qty = ui.pdQty;
        ui.pdQty = 1;
        addToCart(el.dataset.id, ui.pdVariant, qty);
        break;
      }
      case 'cart-qty': setQty(Number(el.dataset.index), Number(el.dataset.delta)); break;
      case 'clear-cart': clearCart(); break;
      case 'remove-coupon': removeCoupon(); break;
      case 'checkout-mode':
        ui.checkoutMode = el.dataset.mode === 'pickup' ? 'pickup' : 'delivery';
        if (ui.checkoutMode === 'pickup' && ui.checkoutPayment === 'cod') ui.checkoutPayment = 'store';
        if (ui.checkoutMode === 'delivery' && ui.checkoutPayment === 'store') ui.checkoutPayment = 'cod';
        render(true);
        break;
      case 'set-payment': ui.checkoutPayment = el.dataset.payment; render(true); break;
      case 'select-slot': ui.selectedSlot = el.dataset.slot; render(true); break;
      case 'place-order': placeOrder(); break;
      case 'select-address': selectAddress(el.dataset.id); break;
      case 'set-coin-mode': setCoinMode(el.dataset.mode); break;
      case 'stop-coins': stopCoins(); break;
      case 'orders-filter': ui.ordersFilter = el.dataset.filter; render(true); break;
      case 'toggle-ledger': ui.showAllLedger = !ui.showAllLedger; render(true); break;
      case 'set-sort': ui.shop.sort = el.dataset.sort; render(true); break;
      case 'reset-shop': resetShopFilters(); break;
      case 'clear-search': clearShopSearch(); break;
      case 'cancel-order-sheet':
        ui.cancelReason = 'Changed my mind';
        openSheet('cancel', { number: el.dataset.number, by: el.dataset.by || 'customer' });
        break;
      case 'set-cancel-reason': ui.cancelReason = el.dataset.reason; render(true); break;
      case 'confirm-cancel': {
        const number = el.dataset.number;
        const by = el.dataset.by || 'customer';
        const reason = ui.cancelReason;
        ui.sheet = null;
        cancelOrder(number, reason, by);
        break;
      }
      case 'reorder': {
        const number = el.dataset.number;
        ui.sheet = null;
        reorder(number);
        break;
      }
      case 'sign-out': signOut(); break;
      case 'advance-order':
        ui.sheet = null;
        advanceOrder(el.dataset.number);
        break;
      case 'order-stage-sheet':
        ui.stageTarget = '';
        openSheet('order-stage', { number: el.dataset.number });
        break;
      case 'set-order-stage':
        ui.stageTarget = el.dataset.stage || '';
        render(true);
        break;
      case 'confirm-order-stage': {
        const number = el.dataset.number;
        const target = ui.stageTarget;
        if (!target) break;
        ui.sheet = null;
        ui.stageTarget = '';
        changeOrderStage(number, target);
        break;
      }
      case 'admin-filter': ui.adminOrderFilter = el.dataset.filter; render(true); break;
      case 'report-period': ui.reportPeriod = el.dataset.period; render(true); break;
      case 'stock-day': ui.stockDay = el.dataset.day || todayISO(); render(true); break;
      case 'stock-item': openSheet('stock-item', { id: el.dataset.id, day: el.dataset.day || ui.stockDay }); break;
      case 'admin-notifications': openSheet('admin-notifications'); break;
      case 'inv-cat': ui.invCat = el.dataset.cat; render(true); break;
      case 'restock-sheet': openSheet('restock', { id: el.dataset.id }); break;
      case 'add-pack': {
        const form = el.closest('form[data-form="product-save"]');
        const rows = form ? form.querySelector('[data-pack-rows]') : null;
        if (rows) {
          const next = Number(form.dataset.packSeq || rows.children.length);
          form.dataset.packSeq = String(next + 1);
          rows.insertAdjacentHTML('beforeend', packRowHtml(next, {}, rows.children.length + 1));
          const input = rows.lastElementChild.querySelector('input');
          if (input) input.focus();
        }
        break;
      }
      case 'toggle-restock-pack': {
        const wrap = el.closest('.restock-form').querySelector('.restock-new');
        if (!wrap) break;
        wrap.hidden = !wrap.hidden;
        el.classList.toggle('is-open', !wrap.hidden);
        if (!wrap.hidden) {
          wrap.querySelector('input').focus();
          wrap.scrollIntoView({ block: 'nearest' });
        }
        break;
      }
      case 'new-type-sheet': openSheet('new-type'); break;
      case 'toggle-type-create': {
        const wrap = el.closest('.field').querySelector('.type-create');
        if (!wrap) break;
        wrap.hidden = !wrap.hidden;
        if (!wrap.hidden) {
          wrap.querySelector('input').focus();
          wrap.scrollIntoView({ block: 'nearest' });
        }
        break;
      }
      case 'create-type-inline': {
        const wrap = el.closest('.type-create');
        const form = el.closest('form');
        if (!wrap) break;
        const nameInput = wrap.querySelector('[name="newType"]');
        const nameGuInput = wrap.querySelector('[name="newTypeGu"]');
        const name = nameInput.value.trim();
        if (!name) {
          showToast('Give the new type a name', 'error');
          nameInput.focus();
          break;
        }
        const cat = createCategory(name, nameGuInput.value);
        if (!cat) {
          showToast('That type already exists', 'error');
          break;
        }
        const select = form ? form.querySelector('select[name="category"]') : null;
        if (select) {
          const option = document.createElement('option');
          option.value = cat.id;
          option.textContent = cat.name;
          option.selected = true;
          select.appendChild(option);
        }
        wrap.hidden = true;
        nameInput.value = '';
        nameGuInput.value = '';
        showToast(`${cat.name} type added`, 'success');
        break;
      }
      case 'clear-inv-search': ui.invQuery = ''; render(true); break;
      case 'clear-inv-filters': ui.invCat = 'all'; ui.invQuery = ''; render(true); break;
      case 'product-picker': openSheet('product-picker'); break;
      case 'add-featured': addFeatured(el.dataset.id); break;
      case 'remove-featured': removeFeatured(el.dataset.id); break;
      case 'new-rule': openSheet('rule-form', { id: null }); break;
      case 'edit-rule': openSheet('rule-form', { id: el.dataset.id }); break;
      case 'export-report': exportReport(); break;
      case 'reset-confirm': openSheet('reset-confirm'); break;
      case 'reset-demo': resetDemo(); break;
      case 'toggle-coupon-form': ui.couponFormOpen = !ui.couponFormOpen; render(true); break;
      default: break;
    }
  }

  /* ---------- events ---------- */
  function onDocumentClick(e) {
    const actionEl = e.target.closest('[data-action]');
    if (actionEl) {
      e.preventDefault();
      handleAction(actionEl.dataset.action, actionEl);
      return;
    }
    const backEl = e.target.closest('[data-back]');
    if (backEl) {
      e.preventDefault();
      ui.sheet = null;
      go(backEl.dataset.back || '#/home');
      return;
    }
    const navEl = e.target.closest('[data-nav]');
    if (navEl) {
      e.preventDefault();
      ui.sheet = null;
      go(navEl.dataset.nav);
      return;
    }
    if (e.target.classList && e.target.classList.contains('scrim')) closeSheet();
  }

  function onSubmit(e) {
    const form = e.target.closest('form[data-form]');
    if (!form) return;
    e.preventDefault();
    const type = form.dataset.form;
    const fd = new FormData(form);
    const val = (name) => String(fd.get(name) == null ? '' : fd.get(name)).trim();

    if (type === 'signin') {
      const phone = digits(val('phone'));
      const otp = [1, 2, 3, 4].map((i) => val(`otp${i}`)).join('');
      if (phone.length !== 10) {
        showToast('Enter a 10-digit mobile number', 'error');
        return;
      }
      if (!/^\d{4}$/.test(otp)) {
        showToast('Enter the 4-digit OTP', 'error');
        return;
      }
      STATE.user.phone = `${phone.slice(0, 5)} ${phone.slice(5)}`;
      STATE.signedIn = true;
      save();
      ui.sheet = null;
      go('#/home');
      showToast('Signed in · welcome back', 'success');
      return;
    }

    if (type === 'home-search') {
      const q = val('q');
      go(q ? `#/shop?q=${encodeURIComponent(q)}` : '#/shop');
      return;
    }

    if (type === 'shop-search') {
      const q = val('q');
      const { params } = parseRoute();
      const next = new URLSearchParams();
      if (q) next.set('q', q);
      if (params.get('cat')) next.set('cat', params.get('cat'));
      if (params.get('hot')) next.set('hot', '1');
      go(`#/shop${next.toString() ? `?${next}` : ''}`);
      return;
    }

    if (type === 'apply-coupon') {
      const code = val('code').toUpperCase();
      const check = couponCheck(code);
      if (!check.ok) {
        ui.couponMsg = check.message;
        render(true);
        return;
      }
      STATE.cart.coupon = code;
      ui.couponMsg = '';
      save();
      ui.sheet = null;
      render(true);
      showToast(`Coupon ${code} applied · saved ${money(check.discount)}`, 'success');
      return;
    }

    if (type === 'coins-custom') {
      const t = cartTotals();
      const requested = parseInt(val('coins'), 10);
      const usable = Math.max(0, Math.min(t.balance, t.cap));
      if (!Number.isFinite(requested) || requested <= 0) {
        showToast('Enter how many coins to use', 'error');
        return;
      }
      if (usable <= 0) {
        showToast('No coins can be used on this order', 'error');
        return;
      }
      const coins = Math.min(requested, usable);
      STATE.cart.coinMode = 'custom';
      STATE.cart.coinCustom = String(coins);
      STATE.cart.useCoins = true;
      save();
      render(true);
      showToast(`${coins} coins applied · save ${money(coins * t.coinValue)}`, 'success');
      return;
    }

    if (type === 'add-address') {
      const detail = val('detail');
      const phone = digits(val('phone')) || digits(STATE.user.phone);
      if (!detail) {
        showToast('Add the full delivery address', 'error');
        return;
      }
      if (phone.length !== 10) {
        showToast('Enter a valid 10-digit phone number', 'error');
        return;
      }
      const address = {
        id: `addr-${Date.now().toString(36)}`,
        label: val('label') || 'Address',
        detail,
        phone: `${phone.slice(0, 5)} ${phone.slice(5)}`
      };
      STATE.addresses.push(address);
      STATE.selectedAddress = address.id;
      save();
      ui.sheet = null;
      render(true);
      showToast('Address saved', 'success');
      return;
    }

    if (type === 'inv-search') {
      ui.invQuery = val('q');
      render(true);
      return;
    }

    if (type === 'product-save') {
      const isNew = form.dataset.new === '1';
      const id = form.dataset.id;
      const name = val('name');
      if (!name) {
        showToast('Give this product a name', 'error');
        return;
      }
      const variants = [];
      const packRows = form.querySelectorAll('[data-pack-row]');
      for (let r = 0; r < packRows.length; r += 1) {
        const row = packRows[r];
        const read = (name) => {
          const input = row.querySelector(`[name^="${name}"]`);
          return input ? String(input.value || '').trim() : '';
        };
        const label = read('vlabel');
        const price = Math.round(Number(read('vprice')) || 0);
        const mrp = Math.round(Number(read('vmrp')) || 0);
        const packStock = Math.max(0, Math.round(Number(read('vstock')) || 0));
        if (!label && !price && !mrp && !packStock) continue;
        if (!label || price <= 0) {
          showToast('Add a pack name and selling price for each pack', 'error');
          return;
        }
        if (variants.some((v) => v.label.toLowerCase() === label.toLowerCase())) {
          showToast(`“${label}” is already a pack on this product`, 'error');
          return;
        }
        if (mrp > 0 && mrp < price) {
          showToast(`MRP for ${label} must be at least the selling price`, 'error');
          return;
        }
        variants.push({ label, price, mrp: mrp > 0 ? mrp : price, unit: label, stock: packStock });
      }
      if (!variants.length) {
        showToast('Add at least one pack with a price', 'error');
        return;
      }
      const category = val('category') || 'grocery';
      const stock = variants.reduce((sum, v) => sum + v.stock, 0);
      const lowStock = Math.max(0, Math.round(Number(val('lowStock')) || 0));
      const nameGu = val('nameGu') || name;
      const unit = val('unit') || variants[0].label;
      const patch = {
        name, nameGu, category, unit,
        desc: val('desc') || 'Fresh from Vijay Super Mall, delivered free to your door.',
        descGu: val('descGu') || '',
        stock, lowStock,
        available: fd.get('available') === 'on',
        earnsCoins: fd.get('earnsCoins') === 'on',
        allowCoins: fd.get('allowCoins') === 'on',
        variants
      };
      if (isNew) {
        const base = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'item';
        let pid = base;
        let n = 2;
        while (productById(pid)) {
          pid = `${base}-${n}`;
          n += 1;
        }
        const created = Object.assign({
          id: pid, rating: 4.6, reviews: 0,
          art: ART_BY_CAT[category] || 'box', tone: TONE_BY_CAT[category] || 'gold',
          defaultVariant: 0
        }, patch);
        STATE.products.push(created);
        created.variants.forEach((v, i) => {
          if (v.stock > 0) logStockMove(created, i, v.stock, 'Opening stock');
        });
      } else {
        const p = productById(id);
        if (!p) return;
        Object.assign(p, patch, { defaultVariant: Math.min(p.defaultVariant, variants.length - 1) });
      }
      save();
      go('#/admin/inventory');
      showToast(isNew ? (stock > 0 ? 'Product added to the shelf' : 'Product added · add stock before selling') : 'Product updated', 'success');
      return;
    }

    if (type === 'type-save') {
      const rawName = val('typeName');
      if (!rawName) {
        showToast('Give the new type a name', 'error');
        return;
      }
      const cat = createCategory(rawName, val('typeNameGu'));
      if (!cat) {
        showToast('That type already exists', 'error');
        return;
      }
      ui.sheet = null;
      render(true);
      requestAnimationFrame(() => {
        const rail = appEl.querySelector('.chips--rail');
        if (rail) rail.scrollLeft = rail.scrollWidth;
      });
      showToast(`${cat.name} type added`, 'success');
      return;
    }

    if (type === 'restock') {
      const p = productById(form.dataset.id);
      if (!p) return;
      const wasOut = p.stock <= 0;
      let added = 0;
      const additions = [];
      p.variants.forEach((v, i) => {
        const qty = Math.max(0, Math.round(Number(val(`add${i}`)) || 0));
        if (!qty) return;
        additions.push({ index: i, qty });
        added += qty;
      });
      const newLabel = val('newPackLabel');
      const newPrice = Math.round(Number(val('newPackPrice')) || 0);
      const newMrp = Math.round(Number(val('newPackMrp')) || 0);
      const newQty = Math.max(0, Math.round(Number(val('newPackStock')) || 0));
      const newTouched = newLabel || newPrice || newMrp || newQty;
      if (newTouched) {
        if (!newLabel || newPrice <= 0) {
          showToast('Add a name and price for the new pack', 'error');
          return;
        }
        if (!newQty) {
          showToast('Add the units received for the new pack', 'error');
          return;
        }
        if (p.variants.some((v) => v.label.toLowerCase() === newLabel.toLowerCase())) {
          showToast(`“${newLabel}” already exists on this product`, 'error');
          return;
        }
        if (newMrp > 0 && newMrp < newPrice) {
          showToast('New pack MRP must be at least the selling price', 'error');
          return;
        }
        added += newQty;
      }
      if (!added) {
        showToast('Enter the quantity received', 'error');
        return;
      }
      additions.forEach(({ index, qty }) => {
        p.variants[index].stock = variantStock(p, index) + qty;
        logStockMove(p, index, qty, 'Supplier purchase');
      });
      if (newTouched) {
        p.variants.push({ label: newLabel, price: newPrice, mrp: newMrp > 0 ? newMrp : newPrice, unit: newLabel, stock: newQty });
        logStockMove(p, p.variants.length - 1, newQty, 'New pack received');
      }
      syncProductStock(p);
      if (wasOut && p.stock > 0) p.available = true;
      save();
      ui.sheet = null;
      render(true);
      showToast(newTouched ? `${newLabel} pack added · +${added} unit${added === 1 ? '' : 's'}` : `Stock updated · +${added} unit${added === 1 ? '' : 's'}`, 'success');
      return;
    }

    if (type === 'hot-save') {
      const title = val('title');
      const starts = val('starts');
      const ends = val('ends');
      if (!title) {
        showToast('Add a headline for the sale banner', 'error');
        return;
      }
      if (starts && ends && ends < starts) {
        showToast('The sale end date must be after the start date', 'error');
        return;
      }
      STATE.hotSale.eyebrow = val('eyebrow') || 'HOT SALE';
      STATE.hotSale.title = title;
      STATE.hotSale.starts = starts;
      STATE.hotSale.ends = ends;
      STATE.hotSale.live = fd.get('live') === 'on';
      save();
      render(true);
      showToast(STATE.hotSale.live ? 'Hot sale published' : 'Hot sale saved as draft', 'success');
      return;
    }

    if (type === 'coin-settings') {
      STATE.coinSettings = {
        coinValue: Math.max(1, Math.round(Number(val('coinValue')) || 1)),
        maxPercent: Math.min(100, Math.max(1, Math.round(Number(val('maxPercent')) || 100))),
        expiryMonths: Math.max(1, Math.round(Number(val('expiryMonths')) || 12))
      };
      save();
      render(true);
      showToast('Redemption settings saved', 'success');
      return;
    }

    if (type === 'rule-save') {
      const ruleId = form.dataset.id;
      const name = val('name');
      const spend = Math.round(Number(val('spend')) || 0);
      const coins = Math.round(Number(val('coins')) || 0);
      const starts = val('starts');
      const expires = val('expires');
      if (!name || spend <= 0 || coins <= 0) {
        showToast('Add a name, spend amount and coin payout', 'error');
        return;
      }
      if (starts && expires && expires < starts) {
        showToast('The rule end date must be after its start date', 'error');
        return;
      }
      const patch = {
        name, spend, coins,
        mode: val('mode') === 'slab' ? 'slab' : 'pro-rata',
        starts, expires, everGreen: !starts && !expires,
        active: fd.get('active') === 'on'
      };
      if (ruleId) {
        const rule = STATE.coinRules.find((r) => r.id === ruleId);
        if (!rule) return;
        Object.assign(rule, patch);
      } else {
        STATE.coinRules.push(Object.assign({
          id: `rule-${Date.now().toString(36)}`, scope: 'All items'
        }, patch));
      }
      save();
      ui.sheet = null;
      render(true);
      showToast('Earning rule saved', 'success');
      return;
    }

    if (type === 'coupon-save') {
      const code = val('code').toUpperCase().replace(/\s+/g, '');
      if (!/^[A-Z0-9]{3,16}$/.test(code)) {
        showToast('Use 3–16 letters or numbers for the coupon code', 'error');
        return;
      }
      if (STATE.coupons.some((c) => c.code === code)) {
        showToast('That coupon code already exists', 'error');
        return;
      }
      const couponType = val('type') === 'percent' ? 'percent' : 'flat';
      const value = Math.round(Number(val('value')) || 0);
      if (value <= 0 || (couponType === 'percent' && value > 100)) {
        showToast('Enter a valid discount value', 'error');
        return;
      }
      const starts = val('starts');
      const expires = val('expires');
      if (starts && expires && expires < starts) {
        showToast('The coupon end date must be after its start date', 'error');
        return;
      }
      const min = Math.max(0, Math.round(Number(val('min')) || 0));
      const maxDiscountRaw = Math.round(Number(val('maxDiscount')) || 0);
      const scope = val('scope') || 'all';
      const coupon = {
        code, type: couponType, value, min, scope, active: true, starts, expires,
        uses: 0,
        maxUses: Math.max(1, Math.round(Number(val('maxUses')) || 1)),
        worksWithCoins: fd.get('worksWithCoins') === 'on',
        firstOrderOnly: fd.get('firstOrderOnly') === 'on',
        desc: couponType === 'flat'
          ? `₹${value} off on orders above ₹${min}`
          : `${value}% off ${scopeLabel(scope)}${maxDiscountRaw > 0 ? ` · max ₹${maxDiscountRaw}` : ''}`
      };
      if (couponType === 'percent' && maxDiscountRaw > 0) coupon.maxDiscount = maxDiscountRaw;
      STATE.coupons.unshift(coupon);
      save();
      ui.couponFormOpen = false;
      render(true);
      showToast(`Coupon ${code} created`, 'success');
    }
  }

  function onChange(e) {
    const el = e.target.closest('[data-change]');
    if (!el) return;
    switch (el.dataset.change) {
      case 'toggle-coins':
        STATE.cart.useCoins = el.checked;
        save();
        render(true);
        break;
      case 'filter-stock':
        ui.shop.stock = el.checked;
        render(true);
        break;
      case 'filter-coins':
        ui.shop.coins = el.checked;
        render(true);
        break;
      case 'stock-day':
        if (/^\d{4}-\d{2}-\d{2}$/.test(el.value)) {
          ui.stockDay = el.value;
          render(true);
        }
        break;
      case 'stock-all':
        ui.stockShowAll = el.checked;
        render(true);
        break;
      case 'toggle-notifications':
        STATE.settings.notifications = el.checked;
        save();
        render(true);
        showToast(el.checked ? 'Order notifications on' : 'Order notifications off');
        break;
      case 'toggle-rule': {
        const rule = STATE.coinRules.find((r) => r.id === el.dataset.id);
        if (!rule) return;
        rule.active = el.checked;
        save();
        render(true);
        showToast(rule.active ? `${rule.name} activated` : `${rule.name} paused`, 'success');
        break;
      }
      case 'toggle-coupon': {
        const coupon = STATE.coupons.find((c) => c.code === el.dataset.code);
        if (!coupon) return;
        coupon.active = el.checked;
        save();
        render(true);
        showToast(coupon.active ? `${coupon.code} activated` : `${coupon.code} paused`, 'success');
        break;
      }
      default: break;
    }
  }

  function onInput(e) {
    const otp = e.target.closest('[data-otp]');
    if (otp) {
      otp.value = otp.value.replace(/\D/g, '').slice(0, 1);
      if (otp.value) {
        const inputs = appEl.querySelectorAll('[data-otp]');
        const next = inputs[Number(otp.dataset.otp) + 1];
        if (next) next.focus();
      }
      return;
    }
    if (e.target.id === 'signinPhone') {
      e.target.value = e.target.value.replace(/\D/g, '').slice(0, 10);
    }
  }

  function onKeydown(e) {
    if (e.key === 'Escape' && ui.sheet) {
      closeSheet();
      return;
    }
    if (e.key === 'Backspace' && e.target.matches && e.target.matches('[data-otp]') && !e.target.value) {
      const inputs = Array.from(appEl.querySelectorAll('[data-otp]'));
      const prev = inputs[inputs.indexOf(e.target) - 1];
      if (prev) {
        prev.focus();
        prev.value = '';
        e.preventDefault();
      }
      return;
    }
    if (e.key === 'Enter' && e.target.closest) {
      const link = e.target.closest('[role="link"][data-nav]');
      if (link && link.tagName !== 'A' && link.tagName !== 'BUTTON') {
        e.preventDefault();
        ui.sheet = null;
        go(link.dataset.nav);
      }
    }
  }

  /* ---------- drag-to-scroll for horizontal chip rails ---------- */
  let railDrag = null;
  let railSuppressClick = false;

  function beginRailDrag(e) {
    if (e.pointerType !== 'mouse' || e.button !== 0 || !e.target.closest) return;
    const rail = e.target.closest('.status-tabs, .chips');
    if (!rail || rail.scrollWidth <= rail.clientWidth + 2) return;
    railDrag = { rail, pointerId: e.pointerId, startX: e.clientX, startLeft: rail.scrollLeft, moved: false };
  }

  function syncRail(rail) {
    if (!rail) return;
    const max = rail.scrollWidth - rail.clientWidth;
    rail.classList.toggle('is-scrollable', max > 2);
    rail.classList.toggle('is-scrolled', rail.scrollLeft > 2);
    rail.classList.toggle('is-at-end', max <= 2 || rail.scrollLeft >= max - 2);
  }

  function syncRails() {
    appEl.querySelectorAll('.status-tabs, .chips--rail').forEach(syncRail);
    appEl.querySelectorAll('.chips--rail').forEach((rail) => {
      const active = rail.querySelector('.chip.is-active');
      if (!active) return;
      const max = rail.scrollWidth - rail.clientWidth;
      if (max <= 2) return;
      const railRect = rail.getBoundingClientRect();
      const chipRect = active.getBoundingClientRect();
      const centered = rail.scrollLeft + (chipRect.left - railRect.left) - (rail.clientWidth - chipRect.width) / 2;
      const target = Math.max(0, Math.min(centered, max));
      if (Math.abs(rail.scrollLeft - target) > 1) rail.scrollLeft = target;
      syncRail(rail);
    });
  }

  function moveRailDrag(e) {
    if (!railDrag || e.pointerId !== railDrag.pointerId) return;
    const dx = e.clientX - railDrag.startX;
    if (!railDrag.moved) {
      if (Math.abs(dx) < 6) return;
      railDrag.moved = true;
      railDrag.rail.classList.add('is-dragging');
      try { railDrag.rail.setPointerCapture(e.pointerId); } catch (err) {}
    }
    if (e.cancelable) e.preventDefault();
    railDrag.rail.scrollLeft = railDrag.startLeft - dx;
    syncRail(railDrag.rail);
  }

  function endRailDrag(e) {
    if (!railDrag || (e && e.pointerId !== railDrag.pointerId)) return;
    const { rail, moved, pointerId } = railDrag;
    if (rail.hasPointerCapture && rail.hasPointerCapture(pointerId)) rail.releasePointerCapture(pointerId);
    rail.classList.remove('is-dragging');
    railDrag = null;
    syncRail(rail);
    if (moved) {
      railSuppressClick = true;
      setTimeout(() => { railSuppressClick = false; }, 0);
    }
  }

  function blockRailClick(e) {
    if (!railSuppressClick) return;
    railSuppressClick = false;
    e.preventDefault();
    e.stopPropagation();
  }

  /* ---------- boot ---------- */
  function boot() {
    const stocksChanged = ensureVariantStocks();
    const typesChanged = ensureCategories();
    const movesChanged = ensureStockMoves();
    if (stocksChanged || typesChanged || movesChanged) save();
    const logo = document.getElementById('sideLogo');
    if (logo) logo.innerHTML = I.logo(30);
    const reset = document.getElementById('resetDemo');
    if (reset) reset.addEventListener('click', resetDemo);

    document.addEventListener('click', onDocumentClick);
    document.addEventListener('submit', onSubmit);
    document.addEventListener('change', onChange);
    document.addEventListener('input', onInput);
    document.addEventListener('keydown', onKeydown);
    document.addEventListener('pointerdown', beginRailDrag);
    document.addEventListener('pointermove', moveRailDrag, { passive: false });
    document.addEventListener('pointerup', endRailDrag);
    document.addEventListener('pointercancel', endRailDrag);
    document.addEventListener('click', blockRailClick, true);
    document.addEventListener('scroll', (e) => {
      if (!e.target.closest) return;
      const rail = e.target.closest('.status-tabs, .chips--rail');
      if (rail) syncRail(rail);
    }, true);
    window.addEventListener('resize', syncRails);
    window.addEventListener('blur', () => endRailDrag());
    window.addEventListener('hashchange', () => {
      ui.sheet = null;
      render(false);
    });

    if (!location.hash) {
      try {
        history.replaceState(null, '', `${location.pathname}${location.search}#/splash`);
      } catch (err) {
        location.hash = '#/splash';
      }
    }
    render();
  }

  boot();
})();
