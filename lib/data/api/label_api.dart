import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'label_dto.dart';
import 'session_store.dart';

/// Barcode generation, label templates, label printing and history
/// (`72-barcode-labels.md`, playbook P2 sections 11 to 13).
///
/// Printing goes through the plain HTTP client because every mode must come
/// back as bytes (TSPL can hold raw bitmap data, ESC/POS is binary), and
/// error bodies then have to be decoded by hand.
class LabelApi {
  LabelApi(this._client);

  final ApiClient _client;

  Map<String, dynamic> _m(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);

  // ---- barcode ---------------------------------------------------------------

  Future<GeneratedBarcode> generateBarcode(String variantId) async =>
      GeneratedBarcode.fromJson(_m(
          await _client.post('/admin/variants/$variantId/barcode/generate')));

  // ---- templates -------------------------------------------------------------

  Future<LabelPage<LabelTemplate>> templates(
          {int page = 0, int size = 50}) async =>
      LabelPage.from(
          await _client.get('/admin/label-templates',
              query: {'page': '$page', 'size': '$size'}),
          LabelTemplate.fromJson);

  Future<LabelTemplate> createTemplate(Map<String, dynamic> body) async =>
      LabelTemplate.fromJson(
          _m(await _client.post('/admin/label-templates', body: body)));

  Future<LabelTemplate> updateTemplate(
          String id, Map<String, dynamic> body) async =>
      LabelTemplate.fromJson(
          _m(await _client.put('/admin/label-templates/$id', body: body)));

  Future<void> deleteTemplate(String id) =>
      _client.delete('/admin/label-templates/$id');

  // ---- history ---------------------------------------------------------------

  Future<LabelPage<LabelHistoryRow>> history(
          {String? variantId, int page = 0, int size = 20}) async =>
      LabelPage.from(
          await _client.get('/admin/labels/history', query: {
            if (variantId != null && variantId.isNotEmpty)
              'variantId': variantId,
            'page': '$page',
            'size': '$size',
          }),
          LabelHistoryRow.fromJson);

  // ---- print -----------------------------------------------------------------

  Future<LabelPrintResult> print(Map<String, dynamic> body) async {
    Future<http.Response> send() => http
        .post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.path('/admin/labels')}'),
          headers: {
            'Authorization':
                'Bearer ${SessionStore.instance.accessToken ?? ''}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));
    http.Response r;
    try {
      r = await send();
      if (r.statusCode == 401) {
        // Any authenticated call refreshes an expired token first.
        await _client.get('/admin/label-templates',
            query: {'page': '0', 'size': '1'});
        r = await send();
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
          0, 'Could not reach the server. Check your connection.');
    }
    if (r.statusCode != 200) throw _error(r);
    return LabelPrintResult(
      r.bodyBytes,
      r.headers['content-type'] ?? 'application/octet-stream',
      int.tryParse(r.headers['x-label-count'] ?? ''),
      int.tryParse(r.headers['x-label-pages'] ?? ''),
      '${body['mode']}',
    );
  }

  ApiException _error(http.Response r) {
    var msg = 'Could not print the labels (${r.statusCode}).';
    String? code;
    String? trace;
    Object? payload;
    final fields = <String, String>{};
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      payload = j;
      if (j is Map) {
        if (j['message'] != null) msg = '${j['message']}';
        code = j['code']?.toString();
        trace = j['traceId']?.toString();
        final d = j['details'];
        if (d is Map && d['fields'] is Map) {
          (d['fields'] as Map).forEach((k, v) => fields['$k'] = '$v');
        }
      }
    } catch (_) {}
    ApiException.recordFields(fields);
    return ApiException(r.statusCode, msg,
        code: code, payload: payload, traceId: trace, fields: fields);
  }
}
