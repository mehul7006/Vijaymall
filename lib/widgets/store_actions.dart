import 'package:flutter/services.dart';

import '../data/open_link.dart';
import '../data/seed_data.dart' as seed;
import '../data/store_profile.dart';
import '../data/store_profile_cache.dart';
import '../state/gu_strings.dart';
import 'toast.dart';

/// Contact actions driven by the store profile (phone, whatsapp, map, e-mail,
/// website, Instagram, Facebook). Where the platform cannot open a link, the
/// value is copied instead.
class StoreActions {
  StoreActions._();

  static StoreProfile? get _p => StoreProfileHub.instance.profile;

  static String get phone =>
      (_p?.phone.isNotEmpty ?? false) ? _p!.phone : seed.store.phone;

  static Future<void> _go(String url, String copyText, String copied) async {
    if (url.isNotEmpty && openLink(url)) return;
    await Clipboard.setData(ClipboardData(text: copyText));
    showToast(gt(copied));
  }

  static Future<void> call() {
    final digits = (_p?.phoneDigits.isNotEmpty ?? false)
        ? _p!.phoneDigits
        : seed.store.phoneHref;
    return _go(digits.isEmpty ? '' : 'tel:$digits', phone,
        'Phone number copied · $phone');
  }

  static Future<void> whatsapp() {
    final link = _p?.whatsappLink ?? '';
    return _go(link, link.isEmpty ? phone : link, 'WhatsApp link copied');
  }

  static Future<void> map() {
    final u = _p?.mapUrl ?? '';
    return _go(u, u.isEmpty ? seed.store.address : u, 'Map link copied');
  }

  static Future<void> email() {
    final e = _p?.email ?? '';
    return _go(e.isEmpty ? '' : 'mailto:$e', e, 'E-mail address copied');
  }

  static Future<void> web(String url) => _go(url, url, 'Link copied');
}
