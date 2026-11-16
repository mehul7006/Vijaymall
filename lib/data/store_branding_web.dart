import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Pushes the store identity into the host page: `document.title`, favicon,
/// apple-touch-icon, meta description, `apple-mobile-web-app-title` and a
/// Blob-URL web manifest. Best-effort: nothing here may ever break boot.
class StoreBranding {
  StoreBranding._();

  static String _last = '';
  static String? _manifestUrl;

  static void apply({
    required String name,
    required String tagline,
    required String logoUrl,
    String iconUrl = '',
    String icon192Url = '',
  }) {
    final key = '$name\u0001$tagline\u0001$logoUrl|$iconUrl|$icon192Url';
    if (key == _last) return;
    _last = key;
    try {
      if (name.isNotEmpty) {
        web.document.title = name;
        _meta('apple-mobile-web-app-title', name);
      }
      if (tagline.isNotEmpty) _meta('description', tagline);
      // The server-made app icons win over the raw logo when they exist.
      final fav = icon192Url.isNotEmpty ? icon192Url : logoUrl;
      final touch = iconUrl.isNotEmpty ? iconUrl : fav;
      if (fav.isNotEmpty) _link('icon', fav);
      if (touch.isNotEmpty) _link('apple-touch-icon', touch);
    } catch (_) {}
    try {
      if (logoUrl.isNotEmpty && name.isNotEmpty) {
        _manifest(name, tagline, logoUrl, iconUrl, icon192Url);
      }
    } catch (_) {}
  }

  static void _meta(String name, String content) {
    var el = web.document.querySelector('meta[name="$name"]');
    if (el == null) {
      el = web.document.createElement('meta')..setAttribute('name', name);
      web.document.head?.appendChild(el);
    }
    el.setAttribute('content', content);
  }

  static void _link(String rel, String href) {
    var el = web.document.querySelector('link[rel="$rel"]');
    if (el == null) {
      el = web.document.createElement('link')..setAttribute('rel', rel);
      web.document.head?.appendChild(el);
    }
    el.removeAttribute('type');
    el.removeAttribute('sizes');
    el.setAttribute('href', href);
  }

  static void _manifest(String name, String tagline, String logoUrl,
      String iconUrl, String icon192Url) {
    final short = () {
      final first = name.trim().split(RegExp(r'\s+')).first;
      return first.length <= 12 ? first : name.trim().substring(0, 12);
    }();
    final base = web.document.baseURI;
    final json = jsonEncode({
      'name': name,
      'short_name': short,
      'description': tagline,
      'start_url': base,
      'scope': base,
      'display': 'standalone',
      'background_color': '#F4F5FB',
      'theme_color': '#D3202B',
      'icons': [
        {
          'src': icon192Url.isNotEmpty ? icon192Url : logoUrl,
          'sizes': '192x192',
          'type': icon192Url.isNotEmpty ? 'image/png' : 'image/jpeg'
        },
        {
          'src': iconUrl.isNotEmpty ? iconUrl : logoUrl,
          'sizes': '512x512',
          'type': iconUrl.isNotEmpty ? 'image/png' : 'image/jpeg'
        },
      ],
    });
    final blob = web.Blob([json.toJS].toJS,
        web.BlobPropertyBag(type: 'application/manifest+json'));
    final url = web.URL.createObjectURL(blob);
    _link('manifest', url);
    final old = _manifestUrl;
    _manifestUrl = url;
    if (old != null) web.URL.revokeObjectURL(old);
  }
}
