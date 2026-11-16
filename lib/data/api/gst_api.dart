import 'api_client.dart';
import 'gst_dto.dart';

/// GST and HSN master (`GET /gst/suggest`, `/gst/hsn`, `/gst/hsn/{hsn}`,
/// `/gst/rates`). ADMIN and CASHIER may read. The app bundles no GST data.
class GstApi {
  GstApi(this._client);

  final ApiClient _client;

  Map<String, dynamic> _m(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);

  /// Best HSN and rate for a product name. [price] is in rupees; [packed]
  /// true = packed and labelled, false = loose, null = let the server choose.
  Future<GstSuggestion?> suggest(
    String name, {
    String? category,
    double? price,
    bool? packed,
    int limit = 5,
  }) async {
    final body = _m(await _client.get('/gst/suggest', query: {
      'name': name,
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (price != null && price > 0 && price <= 10000000)
        'price': price == price.roundToDouble()
            ? '${price.round()}'
            : price.toStringAsFixed(2),
      if (packed != null) 'packed': '$packed',
      'limit': '$limit',
    }));
    return GstSuggestion.fromResponse(body);
  }

  Future<GstHsnPage> hsn({
    String? q,
    String? verification,
    String? taxType,
    int page = 0,
    int size = 20,
  }) async =>
      GstHsnPage.fromJson(_m(await _client.get('/gst/hsn', query: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (verification != null && verification.isNotEmpty)
          'verification': verification,
        if (taxType != null && taxType.isNotEmpty) 'taxType': taxType,
        'page': '$page',
        'size': '$size',
      })));

  /// All rows of one 4, 6 or 8 digit HSN code; 404 when unknown.
  Future<List<GstHsnRow>> hsnRows(String hsn) async {
    final raw = await _client.get('/gst/hsn/${Uri.encodeComponent(hsn)}');
    final list = raw is List
        ? raw
        : (raw is Map && raw['items'] is List ? raw['items'] as List : const []);
    return [
      for (final e in list)
        if (e is Map) GstHsnRow.fromJson(Map<String, dynamic>.from(e))
    ];
  }

  Future<List<GstRateOption>> rates() async {
    final raw = await _client.get('/gst/rates');
    final list = raw is List
        ? raw
        : (raw is Map && raw['items'] is List ? raw['items'] as List : const []);
    return [
      for (final e in list)
        if (e is Map) GstRateOption.fromJson(Map<String, dynamic>.from(e))
    ];
  }
}
