/// Client-side cache + live holder for the [StoreProfile].
///
/// Design
/// * Persisted in [LocalStore] (web localStorage) under [cacheKey] as
///   `{etag, fetchedAt, payload, logo:{path, b64}}`. The logo bytes are kept
///   (base64) only when <= 200 KB; the backend serves images `no-store`, so
///   the app caches the logo itself.
/// * [loadCache] is synchronous and runs before the first frame, so name,
///   logo and address paint immediately.
/// * [refresh] revalidates with a conditional GET (`If-None-Match`); a 304
///   keeps the cache and only bumps `fetchedAt`. A network failure keeps
///   whatever is cached.
/// * `refresh(force: true)` is the hard refresh: it drops the persisted
///   payload, ETag and logo bytes and refetches without `If-None-Match`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api/api_service.dart';
import 'local_store.dart';
import 'store_branding.dart';
import 'store_profile.dart';

class StoreProfileHub extends ChangeNotifier {
  StoreProfileHub._();

  static final StoreProfileHub instance = StoreProfileHub._();

  static const String cacheKey = 'store.profile.v1';
  static const int maxLogoCacheBytes = 200 * 1024;
  static const Duration staleAfter = Duration(minutes: 30);

  StoreProfile? profile;
  Uint8List? logoBytes;
  String _logoFor = '';
  String? _etag;
  DateTime? fetchedAt;
  Future<bool>? _inflight;
  bool refreshing = false;

  /// True once any profile (cached or fetched) is available.
  bool get loaded => profile != null;

  /// Reads the persisted entry. Synchronous; never throws.
  void loadCache() {
    try {
      final raw = LocalStore.get(cacheKey);
      if (raw == null || raw.isEmpty) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final payload = m['payload'];
      if (payload is! Map) return;
      profile = StoreProfile.fromJson(Map<String, dynamic>.from(payload));
      _etag = m['etag']?.toString();
      final at = m['fetchedAt'];
      if (at is num) {
        fetchedAt = DateTime.fromMillisecondsSinceEpoch(at.toInt());
      }
      final logo = m['logo'];
      if (logo is Map && logo['b64'] is String) {
        final path = (logo['path'] ?? '').toString();
        if (path == profile!.logoPath && path.isNotEmpty) {
          logoBytes = base64Decode(logo['b64'] as String);
          _logoFor = path;
        }
      }
      _publish();
    } catch (_) {
      profile = null;
      logoBytes = null;
    }
  }

  void _persist() {
    final p = profile;
    if (p == null) return;
    try {
      LocalStore.set(
        cacheKey,
        jsonEncode({
          'etag': _etag,
          'fetchedAt': (fetchedAt ?? DateTime.now()).millisecondsSinceEpoch,
          'payload': p.toJson(),
          if (logoBytes != null &&
              logoBytes!.length <= maxLogoCacheBytes &&
              _logoFor == p.logoPath)
            'logo': {'path': _logoFor, 'b64': base64Encode(logoBytes!)},
        }),
      );
    } catch (_) {}
  }

  void _publish() {
    final p = profile;
    if (p != null) {
      StoreBranding.apply(
          name: p.shopName,
          tagline: p.promise,
          logoUrl: p.logoUrl,
          iconUrl: p.iconResolved,
          icon192Url: p.icon192Resolved);
    }
    notifyListeners();
  }

  bool get isStale =>
      fetchedAt == null || DateTime.now().difference(fetchedAt!) > staleAfter;

  /// Revalidate only when the cache is older than [staleAfter].
  Future<bool> revalidateIfStale() => isStale ? refresh() : Future.value(false);

  /// Fetches the public profile. Returns true when the data changed (or was
  /// hard-refreshed). Never throws; on failure the cache keeps showing.
  Future<bool> refresh({bool force = false}) {
    final running = _inflight;
    if (running != null && !force) return running;
    Future<bool> run() async {
      if (running != null) {
        try {
          await running;
        } catch (_) {}
      }
      return _doRefresh(force);
    }

    final f = run().whenComplete(() {
      _inflight = null;
      refreshing = false;
      notifyListeners();
    });
    _inflight = f;
    return f;
  }

  Future<bool> _doRefresh(bool force) async {
    refreshing = true;
    notifyListeners();
    if (force) {
      // Hard refresh: forget the persisted copy, the ETag and the logo bytes.
      // The in-memory profile stays on screen until the new one lands, so a
      // failed fetch never blanks the UI.
      try {
        LocalStore.remove(cacheKey);
      } catch (_) {}
      _etag = null;
      logoBytes = null;
      _logoFor = '';
    }
    try {
      final r = await Api.instance.client.getConditional(
        '/shop-settings',
        etag: force ? null : _etag,
      );
      if (r.notModified && profile != null) {
        fetchedAt = DateTime.now();
        _persist();
        if (logoBytes == null) await _fetchLogo();
        return false;
      }
      if (r.body is! Map) return false;
      final next = StoreProfile.fromJson(Map<String, dynamic>.from(r.body as Map));
      final logoChanged = next.logoPath != _logoFor;
      final changed = profile == null ||
          jsonEncode(profile!.toJson()) != jsonEncode(next.toJson());
      profile = next;
      _etag = r.etag;
      fetchedAt = DateTime.now();
      if (logoChanged) {
        logoBytes = null;
        _logoFor = '';
      }
      _persist();
      _publish();
      await _fetchLogo();
      return changed || force;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchLogo() async {
    final p = profile;
    if (p == null || !p.hasLogo) {
      if (logoBytes != null) {
        logoBytes = null;
        _logoFor = '';
        notifyListeners();
      }
      return;
    }
    if (logoBytes != null && _logoFor == p.logoPath) return;
    try {
      final resp = await http
          .get(Uri.parse(p.logoUrl))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        logoBytes = resp.bodyBytes;
        _logoFor = p.logoPath;
        _persist();
        notifyListeners();
      }
    } catch (_) {
      // The image widget falls back to the network / monogram.
    }
  }

  /// Size of what is stored on this device, for the admin System screen.
  String describeCache() {
    final raw = LocalStore.get(cacheKey);
    if (raw == null) return 'Nothing stored on this device';
    final kb = (raw.length / 1024).toStringAsFixed(1);
    final age = fetchedAt == null
        ? ''
        : ' · checked ${DateTime.now().difference(fetchedAt!).inMinutes} min ago';
    return '$kb KB${logoBytes != null ? ' incl. logo' : ''}$age';
  }
}
