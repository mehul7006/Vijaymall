import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/api/api_config.dart';
import '../data/seed_data.dart' as seed;
import '../data/store_profile_cache.dart';
import '../icons/app_icons.dart';
import '../icons/product_art.dart';

/// `currentColor` → hex, for passing colours into the ported SVG strings.
String colorHex(Color c) {
  final v = c.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${v.substring(2)}';
}

/// The prototype's `icon(name, size)` helper — stroke SVG from `AppIcons`.
class AppIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  final double sw;

  const AppIcon(
    this.name, {
    super.key,
    this.size = 20,
    this.color = const Color(0xFF14162B),
    this.sw = 1.8,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      AppIcons.svg(name, size: size, sw: sw, color: colorHex(color)),
      width: size,
      height: size,
      semanticsLabel: name,
    );
  }
}

/// Store logo: the profile's logo image (cached bytes first, network second)
/// or, when the shop has no logo, a generated monogram badge. Reads the live
/// [StoreProfileHub], so it repaints by itself when the profile changes.
/// [color] is kept for the old call sites; the badge uses the brand red.
class LogoMark extends StatelessWidget {
  final double size;
  final Color color;

  const LogoMark({
    super.key,
    this.size = 44,
    this.color = const Color(0xFFD3202B),
  });

  @override
  Widget build(BuildContext context) {
    final hub = StoreProfileHub.instance;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final p = hub.profile;
        final name = (p?.shopName.isNotEmpty ?? false)
            ? p!.shopName
            : seed.store.name;
        final letter = name.trim().isEmpty
            ? '?'
            : String.fromCharCode(name.trim().runes.first).toUpperCase();
        final radius = BorderRadius.circular(size * 0.24);
        Widget badge() => Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFD3202B),
                borderRadius: radius,
              ),
              child: Text(
                letter,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.56,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            );
        Widget child;
        if (p != null && p.hasLogo) {
          final bytes = hub.logoBytes;
          child = ClipRRect(
            borderRadius: radius,
            child: bytes != null
                ? Image.memory(bytes,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => badge())
                : Image.network(p.logoUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => badge(),
                    loadingBuilder: (c, w, prog) =>
                        prog == null ? w : badge()),
          );
        } else {
          child = badge();
        }
        return Semantics(
          label: name,
          image: true,
          child: ExcludeSemantics(child: child),
        );
      },
    );
  }
}

/// Product illustration (`art(key)` — 140×140 SVG), or an uploaded photo
/// (any `http(s)://` URL → network image with an SVG fallback while loading).
class ProductArtView extends StatelessWidget {
  final String art;
  final double size;

  const ProductArtView(this.art, {super.key, this.size = 140});

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl(art);
    if (url != null) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _svg(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : SizedBox(width: size, height: size),
      );
    }
    return _svg();
  }

  /// Uploaded photos come back either as an absolute URL or as a
  /// backend-relative path (`/img/products/…`). Resolve the relative form
  /// against the configured API origin so the browser fetches it same-origin
  /// (the backend sends no CORS headers, so a cross-origin fetch would be
  /// blocked). Anything else is an illustration key.
  static String? _imageUrl(String art) {
    final url = art.trim();
    if (url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiConfig.baseUrl}$url';
    return null;
  }

  Widget _svg() => SvgPicture.string(
        ProductArtRegistry.svg(art),
        width: size,
        height: size,
        semanticsLabel: '',
      );
}

/// Small indirection so screens don't import product_art directly.
class ProductArtRegistry {
  ProductArtRegistry._();

  static const Set<String> keys = {
    'almonds',
    'rice',
    'cream',
    'kulfi',
    'pickle',
    'tea',
    'cashew',
    'oil',
    'fafda',
    'facewash',
    'icecream-tub',
    'flour',
  };

  static String svg(String key) => ProductArt.svg(key);
}
