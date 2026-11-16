/// Small text helpers over the live store identity (`seed.store`, which is fed
/// by the cached store profile). Nothing here is hardcoded brand copy.
library;

import 'seed_data.dart' as seed;

/// Upper-case first word of the shop name (splash / sign-in wordmark).
String brandTop() {
  final n = seed.store.name.trim();
  if (n.isEmpty) return '';
  return n.split(RegExp(r'\s+')).first.toUpperCase();
}

/// Upper-case remainder of the name; falls back to the locality for a
/// single-word name so the second wordmark line is never a stale brand.
String brandBottom() {
  final n = seed.store.name.trim();
  final parts = n.split(RegExp(r'\s+'));
  if (parts.length > 1) return parts.sublist(1).join(' ').toUpperCase();
  return seed.storeLocality().toUpperCase();
}

/// "Name · locality" line used under wordmarks.
String brandLocalityLine() {
  final loc = seed.storeLocality();
  final n = seed.store.name;
  return loc.isEmpty ? n : '$n · $loc';
}
