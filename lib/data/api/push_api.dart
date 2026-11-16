import 'api_client.dart';
import 'push_dto.dart';

/// Admin push notifications (`60-admin-push-notifications.md`). ADMIN only.
class PushApi {
  PushApi(this._client);

  final ApiClient _client;

  static const _base = '/admin/notifications';

  Map<String, dynamic> _m(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);

  /// `POST /broadcast` (202). [idempotencyKey] is kept by the caller for the
  /// whole "Send" action so a retry never messages people twice.
  Future<PushBroadcast> broadcast(
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) async =>
      PushBroadcast.fromJson(_m(await _client.post('$_base/broadcast',
          body: body, headers: {'Idempotency-Key': idempotencyKey})));

  Future<PushAudienceSize> audienceSize(String audience) async =>
      PushAudienceSize.fromJson(_m(await _client
          .get('$_base/audience-size', query: {'audience': audience})));

  Future<PushPage<PushBroadcast>> broadcasts(
          {int page = 0, int size = 20}) async =>
      PushPage.fromJson(
          _m(await _client.get('$_base/broadcasts',
              query: {'page': '$page', 'size': '$size'})),
          PushBroadcast.fromJson);

  Future<PushBroadcast> broadcastById(String id) async =>
      PushBroadcast.fromJson(_m(await _client.get('$_base/broadcasts/$id')));

  Future<List<PushConditionType>> conditionTypes() async {
    final raw = await _client.get('$_base/segments/condition-types') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => PushConditionType.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Either a saved segment (`segmentId`) or inline `{match, rules}`.
  Future<PushPreview> preview(Map<String, dynamic> body) async =>
      PushPreview.fromJson(
          _m(await _client.post('$_base/segments/preview', body: body)));

  Future<PushPage<PushSegment>> segments({int page = 0, int size = 50}) async =>
      PushPage.fromJson(
          _m(await _client.get('$_base/segments',
              query: {'page': '$page', 'size': '$size'})),
          PushSegment.fromJson);

  Future<PushSegment> segment(String id) async =>
      PushSegment.fromJson(_m(await _client.get('$_base/segments/$id')));

  Future<PushSegment> createSegment(Map<String, dynamic> body) async =>
      PushSegment.fromJson(
          _m(await _client.post('$_base/segments', body: body)));

  Future<PushSegment> updateSegment(String id, Map<String, dynamic> body) async =>
      PushSegment.fromJson(
          _m(await _client.put('$_base/segments/$id', body: body)));

  Future<void> deleteSegment(String id) =>
      _client.delete('$_base/segments/$id');
}
