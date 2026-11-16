/// The store's identity as served by the public `GET /api/v1/shop-settings`.
///
/// This is the single source of truth for everything the app shows about the
/// shop (name, logo, address, phone, hours, links). It is cached on the client
/// by `store_profile_cache.dart`; the legacy `seed.store` reads are fed from
/// it so older call sites keep working.
library;

import 'api/api_config.dart';
import 'ist.dart';
import 'models.dart' show StoreInfo;

/// One weekday row of the opening-hours table (`day` is MON..SUN).
class StoreHoursRow {
  const StoreHoursRow({
    required this.day,
    this.open = '',
    this.close = '',
    this.closed = false,
  });

  final String day;
  final String open;
  final String close;
  final bool closed;

  factory StoreHoursRow.fromJson(Map<String, dynamic> j) => StoreHoursRow(
        day: (j['day'] ?? '').toString().toUpperCase(),
        open: (j['open'] ?? '').toString(),
        close: (j['close'] ?? '').toString(),
        closed: j['closed'] == true,
      );

  Map<String, dynamic> toJson() =>
      {'day': day, 'open': open, 'close': close, 'closed': closed};

  /// "09:00 - 21:00" or "Closed".
  String get label => closed ? 'Closed' : '$open - $close';
}

const List<String> kStoreDays = [
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN'
];

class StoreProfile {
  const StoreProfile({
    this.shopName = '',
    this.phone = '',
    this.address = '',
    this.promise = '',
    this.details = '',
    this.logoPath = '',
    this.email = '',
    this.whatsapp = '',
    this.mapUrl = '',
    this.website = '',
    this.instagram = '',
    this.facebook = '',
    this.hours = const <StoreHoursRow>[],
    this.holidayNote = '',
    this.openNow,
    this.todayHours = '',
    this.onlineOrdersOpen = true,
    this.onlineOrdersMessage = '',
    this.timezone = 'Asia/Kolkata',
    this.shopNameGu = '',
    this.addressGu = '',
    this.promiseGu = '',
    this.detailsGu = '',
    this.holidayNoteGu = '',
    this.iconUrlPath = '',
    this.icon192UrlPath = '',
  });

  /// App icons the server made from the logo (`iconUrl` 512, `icon192Url`);
  /// '' until an admin creates them. Used for favicon / web manifest.
  final String iconUrlPath;
  final String icon192UrlPath;

  String _abs(String p) {
    p = p.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    if (p.startsWith('/')) return '${ApiConfig.baseUrl}$p';
    return p;
  }

  String get iconResolved => _abs(iconUrlPath);
  String get icon192Resolved => _abs(icon192UrlPath);

  /// Gujarati texts (`...Gu` fields); empty = fall back to English.
  final String shopNameGu;
  final String addressGu;
  final String promiseGu;
  final String detailsGu;
  final String holidayNoteGu;

  String addressFor(bool gu) => gu && addressGu.isNotEmpty ? addressGu : address;
  String promiseFor(bool gu) => gu && promiseGu.isNotEmpty ? promiseGu : promise;
  String detailsFor(bool gu) => gu && detailsGu.isNotEmpty ? detailsGu : details;
  String holidayNoteFor(bool gu) =>
      gu && holidayNoteGu.isNotEmpty ? holidayNoteGu : holidayNote;

  final String shopName;
  final String phone;
  final String address;

  /// Tagline.
  final String promise;

  /// About text.
  final String details;

  /// Server-relative logo path (`/img/shop/<uuid>_400.jpg`) or ''.
  final String logoPath;
  final String email;
  final String whatsapp;
  final String mapUrl;
  final String website;
  final String instagram;
  final String facebook;
  final List<StoreHoursRow> hours;
  final String holidayNote;

  /// Server-computed; null when the server did not say.
  final bool? openNow;

  /// Server-computed, `09:00-21:00` (or `Closed`).
  final String todayHours;
  final bool onlineOrdersOpen;
  final String onlineOrdersMessage;
  final String timezone;

  static String _s(Object? v) => (v ?? '').toString().trim();

  factory StoreProfile.fromJson(Map<String, dynamic> j) => StoreProfile(
        shopName: _s(j['shopName']),
        phone: _s(j['phone']),
        address: _s(j['address']),
        promise: _s(j['promise']),
        details: _s(j['details']),
        logoPath: _s(j['logoUrl']),
        email: _s(j['email']),
        whatsapp: _s(j['whatsapp']),
        mapUrl: _s(j['mapUrl']),
        website: _s(j['website']),
        instagram: _s(j['instagram']),
        facebook: _s(j['facebook']),
        hours: [
          for (final h in (j['hours'] as List? ?? const []))
            if (h is Map)
              StoreHoursRow.fromJson(Map<String, dynamic>.from(h)),
        ],
        holidayNote: _s(j['holidayNote']),
        openNow: j['openNow'] as bool?,
        todayHours: _s(j['todayHours']),
        onlineOrdersOpen: j['onlineOrdersOpen'] as bool? ?? true,
        onlineOrdersMessage: _s(j['onlineOrdersMessage']),
        timezone:
            _s(j['timezone']).isEmpty ? 'Asia/Kolkata' : _s(j['timezone']),
        shopNameGu: _s(j['shopNameGu']),
        addressGu: _s(j['addressGu']),
        promiseGu: _s(j['promiseGu']),
        detailsGu: _s(j['detailsGu']),
        holidayNoteGu: _s(j['holidayNoteGu']),
        iconUrlPath: _s(j['iconUrl']),
        icon192UrlPath: _s(j['icon192Url']),
      );

  Map<String, dynamic> toJson() => {
        'shopName': shopName,
        'phone': phone,
        'address': address,
        'promise': promise,
        'details': details,
        'logoUrl': logoPath,
        'email': email,
        'whatsapp': whatsapp,
        'mapUrl': mapUrl,
        'website': website,
        'instagram': instagram,
        'facebook': facebook,
        'hours': [for (final h in hours) h.toJson()],
        'holidayNote': holidayNote,
        'openNow': openNow,
        'todayHours': todayHours,
        'onlineOrdersOpen': onlineOrdersOpen,
        'onlineOrdersMessage': onlineOrdersMessage,
        'timezone': timezone,
        'shopNameGu': shopNameGu,
        'addressGu': addressGu,
        'promiseGu': promiseGu,
        'detailsGu': detailsGu,
        'holidayNoteGu': holidayNoteGu,
        'iconUrl': iconUrlPath,
        'icon192Url': icon192UrlPath,
      };

  bool get hasName => shopName.isNotEmpty;
  bool get hasLogo => logoPath.isNotEmpty;

  /// First word of the name, or its first 12 characters when that is longer.
  String get shortName {
    final n = shopName.trim();
    if (n.isEmpty) return '';
    final first = n.split(RegExp(r'\s+')).first;
    if (first.length <= 12) return first;
    return n.length <= 12 ? n : n.substring(0, 12);
  }

  /// One upper-case letter for the generated logo badge.
  String get monogram {
    final n = shopName.trim();
    if (n.isEmpty) return '?';
    return String.fromCharCode(n.runes.first).toUpperCase();
  }

  /// Logo resolved against the API origin (same-origin through the dev proxy),
  /// like product images. [size] swaps the `_400` suffix for another variant
  /// (e.g. 1000).
  String logoUrlResolved({int? size}) {
    var p = logoPath.trim();
    if (p.isEmpty) return '';
    if (size != null) {
      p = p.replaceFirstMapped(RegExp(r'_\d+(\.[A-Za-z0-9]+)$'),
          (m) => '_$size${m.group(1)}');
    }
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    if (p.startsWith('/')) return '${ApiConfig.baseUrl}$p';
    return p;
  }

  String get logoUrl => logoUrlResolved();

  /// WhatsApp digits (falls back to the phone number).
  String get whatsappDigits {
    final src = whatsapp.isNotEmpty ? whatsapp : phone;
    return src.replaceAll(RegExp(r'\D'), '');
  }

  /// `https://wa.me/<digits>`; a bare 10-digit Indian number gets 91 added.
  String get whatsappLink {
    final d = whatsappDigits;
    if (d.isEmpty) return '';
    return 'https://wa.me/${d.length == 10 ? '91$d' : d}';
  }

  String get phoneDigits => phone.replaceAll(RegExp(r'[^\d+]'), '');

  /// The row for today in the shop's time zone (IST).
  StoreHoursRow? get todayRow {
    if (hours.isEmpty) return null;
    final day = kStoreDays[istNow().weekday - 1];
    for (final h in hours) {
      if (h.day == day) return h;
    }
    return null;
  }

  /// Server-computed status: "Open now · 09:00 - 21:00", "Closed now" ...
  /// Empty when the server gave neither flag nor hours.
  String get openLabel {
    final t = todayHours.isEmpty || todayHours == 'Closed'
        ? ''
        : todayHours.replaceAll('-', ' - ');
    if (openNow == true) return t.isEmpty ? 'Open now' : 'Open now · $t';
    if (openNow == false) {
      return t.isEmpty ? 'Closed now' : 'Closed now · today $t';
    }
    return t.isEmpty ? '' : 'Today $t';
  }

  /// Legacy view used by every older reader (`seed.store`).
  StoreInfo toStoreInfo() => StoreInfo(
        name: shopName,
        nameGu: shopNameGu.isNotEmpty ? shopNameGu : shopName,
        addressGu: addressGu,
        promiseGu: promiseGu,
        phone: phone,
        phoneHref: phone.replaceAll(RegExp(r'\D'), ''),
        address: address,
        promise: promise,
        logo: logoUrl,
        openHours: todayHours.isEmpty || todayHours == 'Closed'
            ? ''
            : todayHours.replaceAll('-', ' - '),
      );
}
