import 'api/api_exception.dart';
import 'api/api_service.dart';
import 'api/gst_api.dart';
import 'api/gst_dto.dart';
import 'validators.dart';

export 'api/gst_dto.dart';

/// Thin client of the server's GST and HSN master. The rates, HSN codes and
/// matching all live in the backend; this class only asks, caches the rate
/// card and remembers that the server has no master (or is down) so a missing
/// endpoint is not hammered.
class GstCatalog {
  GstCatalog._();
  static final GstCatalog instance = GstCatalog._();

  /// How long a "not available" answer is trusted before asking again.
  static const _downFor = Duration(minutes: 5);

  GstApi? _api;
  GstApi get _gst => _api ??= GstApi(Api.instance.client);

  List<GstRateOption> _rates = const [];
  Future<void>? _loading;
  DateTime? _downUntil;
  bool _hintClaimed = false;

  /// True when the rate card was read from the server.
  bool loaded = false;

  /// True while a recent call showed the endpoints missing or failing (cached
  /// for about five minutes).
  bool get unavailable {
    final d = _downUntil;
    if (d == null) return false;
    if (DateTime.now().isBefore(d)) return true;
    _downUntil = null;
    return false;
  }

  /// The "suggestions come from the server" hint is shown once per session:
  /// returns true only the first time it is asked.
  bool claimUnavailableHint() {
    if (_hintClaimed) return false;
    _hintClaimed = true;
    return true;
  }

  void _markDown() => _downUntil = DateTime.now().add(_downFor);

  /// Runs [call]; any failure other than a rejected input marks the master
  /// unavailable and yields null.
  Future<T?> _try<T>(Future<T> Function() call, {bool force = false}) async {
    if (!force && unavailable) return null;
    try {
      final r = await call();
      _downUntil = null;
      return r;
    } on ApiException catch (e) {
      // 400/422: this input was refused, the master itself is fine.
      if (e.statusCode == 400 || e.statusCode == 422) return null;
      _markDown();
      return null;
    } catch (_) {
      _markDown();
      return null;
    }
  }

  /// Loads the rate card once (safe to call repeatedly). Never throws.
  Future<void> load() {
    if (loaded) return Future.value();
    if (unavailable) return Future.value();
    return _loading ??= _doLoad().whenComplete(() => _loading = null);
  }

  Future<void> _doLoad() async {
    final r = await _try(_gst.rates);
    if (r != null) {
      _rates = r;
      loaded = r.isNotEmpty;
    }
  }

  // ---------------------------------------------------------------------------
  // Rates
  // ---------------------------------------------------------------------------

  /// Rates from `/gst/rates`, one per distinct percent, ascending. Use
  /// [GstRateOption.serverAccepts] to decide selectability. Empty until
  /// [load] succeeded.
  List<GstRateOption> get selectableRates {
    final out = <GstRateOption>[];
    final seen = <double>{};
    for (final r in _rates) {
      if (r.isSpecial) continue;
      if (seen.add(r.percent)) out.add(r);
    }
    out.sort((a, b) => a.percent.compareTo(b.percent));
    return out;
  }

  /// True when [percent] is one of the server's rates.
  bool rateInMaster(double percent) =>
      _rates.any((r) => !r.isSpecial && r.percent == percent);

  /// Whether billing can store [percent]: the server's `acceptedForBilling`
  /// when the rate card has it, else the client list of accepted slabs.
  bool rateAccepted(double? percent) {
    if (percent == null) return false;
    for (final r in _rates) {
      if (!r.isSpecial && r.percent == percent) return r.serverAccepts;
    }
    return percent == percent.roundToDouble() &&
        Validators.gstSlabs.contains(percent.round());
  }

  // ---------------------------------------------------------------------------
  // Suggestions and search (all answered by the server)
  // ---------------------------------------------------------------------------

  /// Best guess for [productName], narrowed by [category] and the sale
  /// [price] (rupees). Null when nothing matches or the master is not
  /// available (check [unavailable]). [condition] `PACKED_LABELLED` / `LOOSE`
  /// maps to the server's `packed` flag.
  Future<GstSuggestion?> suggest(String productName,
      {String? category, double? price, String? condition}) async {
    var name = productName.trim();
    if (name.isEmpty) return null;
    if (name.length > 120) name = name.substring(0, 120);
    final c = (condition ?? '').toUpperCase();
    final packed = c.contains('PACKED') || c.contains('PREPACK')
        ? true
        : (c == 'LOOSE' ? false : null);
    final r = await _try(() => _gst.suggest(name,
        category: category, price: price, packed: packed));
    if (r == null || r.hsn.isEmpty) return null;
    return r;
  }

  /// HSN list for the "Find an HSN code" box: code prefix, description or
  /// item keyword.
  Future<List<GstHsnHit>> searchHsn(String query, {int limit = 25}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final p = await _try(() => _gst.hsn(q: q, size: limit > 50 ? 50 : limit));
    if (p == null) return const [];
    return [for (final h in p.items) GstHsnHit.fromRow(h)];
  }

  /// One page of the master for the review screen. Always asks the server
  /// (an explicit visit ignores the "not available" cache); null when it is
  /// not available.
  Future<GstHsnPage?> hsnPage(
          {String? q,
          String? verification,
          String? taxType,
          int page = 0,
          int size = 50}) =>
      _try(
          () => _gst.hsn(
              q: q,
              verification: verification,
              taxType: taxType,
              page: page,
              size: size),
          force: true);

  /// All rows (conditions and rates) of one HSN code; empty when unknown.
  Future<List<GstHsnRow>> rowsForHsn(String hsn) async {
    final h = hsn.trim();
    if (hsnError(h) != null || h.isEmpty) return const [];
    return await _try(() => _gst.hsnRows(h)) ?? const [];
  }

  /// The single rate of [hsn] when its rows agree on one, else null.
  Future<double?> rateForHsn(String hsn) async {
    final rates = {for (final r in await rowsForHsn(hsn)) r.rate};
    return rates.length == 1 ? rates.first : null;
  }

  /// "5", "0.25", "1.5" (no trailing zeros).
  static String fmt(double v) => fmtPercent(v);

  /// HSN is optional; when given it must be 4, 6 or 8 digits. Null when fine.
  static String? hsnError(String v) {
    final h = v.trim();
    if (h.isEmpty) return null;
    return RegExp(r'^(\d{4}|\d{6}|\d{8})$').hasMatch(h)
        ? null
        : 'HSN code must be 4, 6 or 8 digits';
  }
}
