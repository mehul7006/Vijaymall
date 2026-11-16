/// DTOs for the admin push-notification module
/// (`60-admin-push-notifications.md`): broadcasts, segments, the condition
/// catalog and the audience/segment previews.
library;

import '../../state/gu_strings.dart';
import '../ist.dart';

int _i(dynamic v, [int d = 0]) =>
    v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? d);

/// Audience values of `POST /broadcast`.
const List<String> pushAudiences = [
  'ALL',
  'CUSTOMERS',
  'STAFF',
  'ADMINS',
  'CASHIERS',
  'USERS',
  'SEGMENT',
];

/// Role audiences that can be sized with `GET /audience-size`.
const List<String> pushRoleAudiences = [
  'ALL',
  'CUSTOMERS',
  'STAFF',
  'ADMINS',
  'CASHIERS',
];

String pushAudienceLabel(String a) {
  switch (a.toUpperCase()) {
    case 'ALL':
      return 'Everyone';
    case 'CUSTOMERS':
      return 'All customers';
    case 'STAFF':
      return 'All staff';
    case 'ADMINS':
      return 'Admins';
    case 'CASHIERS':
      return 'Cashiers';
    case 'USERS':
      return 'Chosen people';
    case 'SEGMENT':
      return 'Customer segment';
  }
  return a;
}

// ---------------------------------------------------------------------------
// Condition (rule)
// ---------------------------------------------------------------------------

/// One segment condition. Only the fields of its `type` are filled; they live
/// in [params] keyed by the JSON field name (`op`, `paise`, `withinDays`, ...),
/// so the editor can be rendered straight from the condition catalog.
class PushCondition {
  String type;
  bool negate;
  final Map<String, dynamic> params;

  /// Editor-only: what the admin typed (rupees text, comma list, ...) and the
  /// display name of a picked product/category. Never sent.
  final Map<String, String> raw = {};
  final Map<String, String> labels = {};
  final Map<String, String> errors = {};

  PushCondition({
    this.type = '',
    this.negate = false,
    Map<String, dynamic>? params,
  }) : params = params ?? <String, dynamic>{};

  PushCondition.fromJson(Map<String, dynamic> j)
      : type = (j['type'] ?? '').toString(),
        negate = j['negate'] == true,
        params = {
          for (final e in j.entries)
            if (e.key != 'type' && e.key != 'negate' && e.value != null)
              e.key: e.value is List ? List<String>.from(e.value as List) : e.value,
        };

  /// Request body: `null` fields are left out.
  Map<String, dynamic> toJson() => {
        'type': type,
        'negate': negate,
        for (final e in params.entries)
          if (e.value != null) e.key: e.value,
      };

  PushCondition copy() {
    final c = PushCondition(
        type: type, negate: negate, params: Map<String, dynamic>.from(params));
    c.raw.addAll(raw);
    c.labels.addAll(labels);
    return c;
  }
}

class SegmentSpec {
  final String match;
  final List<PushCondition> rules;
  SegmentSpec({this.match = 'ALL', this.rules = const []});

  SegmentSpec.fromJson(Map<String, dynamic> j)
      : match = (j['match'] ?? 'ALL').toString().toUpperCase(),
        rules = (j['rules'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PushCondition.fromJson(Map<String, dynamic>.from(e)))
            .toList();

  Map<String, dynamic> toJson() => {
        'match': match,
        'rules': [for (final r in rules) r.toJson()],
      };
}

// ---------------------------------------------------------------------------
// Segment
// ---------------------------------------------------------------------------

class PushSegment {
  final String id;
  final String name;
  final String description;
  final String match;
  final List<PushCondition> rules;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PushSegment.fromJson(Map<String, dynamic> j)
      : id = (j['id'] ?? '').toString(),
        name = (j['name'] ?? '').toString(),
        description = (j['description'] ?? '').toString(),
        match = (j['match'] ?? 'ALL').toString().toUpperCase(),
        rules = (j['rules'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PushCondition.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt = parseIst(j['createdAt']?.toString()),
        updatedAt = parseIst(j['updatedAt']?.toString());
}

class PushPage<T> {
  final List<T> items;
  final int page;
  final int size;
  final int total;
  final bool totalExact;
  final bool hasMore;

  PushPage(this.items, this.page, this.size, this.total, this.totalExact,
      this.hasMore);

  factory PushPage.fromJson(
      Map<String, dynamic> j, T Function(Map<String, dynamic>) f) {
    final items = (j['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => f(Map<String, dynamic>.from(e)))
        .toList();
    return PushPage(items, _i(j['page']), _i(j['size'], 20),
        _i(j['total'], items.length), j['totalExact'] != false,
        j['hasMore'] == true);
  }
}

// ---------------------------------------------------------------------------
// Broadcast
// ---------------------------------------------------------------------------

class PushBroadcast {
  final String id;
  final String audience;
  final String title;
  final String body;
  final String? ref;
  final String status;
  final int recipients;
  final bool recipientsExact;
  final int delivered;
  final int pushed;
  final int pushFailedBatches;
  final bool pushConfigured;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<String> skipped;
  final String? segmentId;
  final SegmentSpec? segment;

  PushBroadcast.fromJson(Map<String, dynamic> j)
      : id = (j['id'] ?? '').toString(),
        audience = (j['audience'] ?? '').toString().toUpperCase(),
        title = (j['title'] ?? '').toString(),
        body = (j['body'] ?? '').toString(),
        ref = j['ref']?.toString(),
        status = (j['status'] ?? '').toString().toUpperCase(),
        recipients = _i(j['recipients']),
        recipientsExact = j['recipientsExact'] != false,
        delivered = _i(j['delivered']),
        pushed = _i(j['pushed']),
        pushFailedBatches = _i(j['pushFailedBatches']),
        pushConfigured = j['pushConfigured'] == true,
        createdAt = parseIst(j['createdAt']?.toString()),
        startedAt = parseIst(j['startedAt']?.toString()),
        finishedAt = parseIst(j['finishedAt']?.toString()),
        skipped = (j['skipped'] as List? ?? []).map((e) => '$e').toList(),
        segmentId = j['segmentId']?.toString(),
        segment = j['segment'] is Map
            ? SegmentSpec.fromJson(Map<String, dynamic>.from(j['segment'] as Map))
            : null;

  bool get isFinal => status == 'DONE' || status == 'FAILED';
  bool get isRunning => status == 'QUEUED' || status == 'SENDING';
}

// ---------------------------------------------------------------------------
// Previews
// ---------------------------------------------------------------------------

class PushAudienceSize {
  final int recipients;
  final int withDevices;
  PushAudienceSize.fromJson(Map<String, dynamic> j)
      : recipients = _i(j['recipients']),
        withDevices = _i(j['withDevices']);
}

class PushPreviewSample {
  final String id;
  final String? name;
  final String? mobile;
  PushPreviewSample.fromJson(Map<String, dynamic> j)
      : id = (j['id'] ?? '').toString(),
        name = j['name']?.toString(),
        mobile = j['mobile']?.toString();
}

class PushPreview {
  final int recipients;
  final bool totalExact;
  final int withDevices;
  final List<PushPreviewSample> sample;
  PushPreview.fromJson(Map<String, dynamic> j)
      : recipients = _i(j['recipients']),
        totalExact = j['totalExact'] != false,
        withDevices = _i(j['withDevices']),
        sample = (j['sample'] as List? ?? [])
            .whereType<Map>()
            .map((e) =>
                PushPreviewSample.fromJson(Map<String, dynamic>.from(e)))
            .toList();
}

// ---------------------------------------------------------------------------
// Condition catalog
// ---------------------------------------------------------------------------

class PushConditionParam {
  final String name;
  final String kind;
  final String label;
  final bool required;
  final int? min;
  final int? max;
  final List<String> options;
  final String? pattern;
  final String? pickFrom;
  final String labelGu;
  final Map<String, String> optionLabelsGu;

  /// Gujarati caption when the admin's language is Gujarati and the server
  /// sent one (60 section 6.3), else the English label.
  String get shownLabel => GuLang.active && labelGu.trim().isNotEmpty ? labelGu : '';

  /// Gujarati caption of an ENUM option, or '' (caller falls back).
  String optionGu(String o) => GuLang.active ? (optionLabelsGu[o] ?? '') : '';

  PushConditionParam.fromJson(Map<String, dynamic> j)
      : labelGu = (j['labelGu'] ?? '').toString(),
        optionLabelsGu = {
          if (j['optionLabelsGu'] is Map)
            for (final e in (j['optionLabelsGu'] as Map).entries)
              '${e.key}': '${e.value}'
        },
        name = (j['name'] ?? '').toString(),
        kind = (j['kind'] ?? '').toString().toUpperCase(),
        label = (j['label'] ?? j['name'] ?? '').toString(),
        required = j['required'] == true,
        min = j['min'] is num ? (j['min'] as num).toInt() : null,
        max = j['max'] is num ? (j['max'] as num).toInt() : null,
        options = (j['options'] as List? ?? []).map((e) => '$e').toList(),
        pattern = j['pattern']?.toString(),
        pickFrom = j['pickFrom']?.toString();
}

class PushConditionType {
  final String type;
  final String label;
  final String description;
  final String group;
  final List<PushConditionParam> params;
  final bool supportsNegate;
  final String labelGu;
  final String descriptionGu;

  String get shownLabel =>
      GuLang.active && labelGu.trim().isNotEmpty ? labelGu : '';
  String get shownDescription =>
      GuLang.active && descriptionGu.trim().isNotEmpty ? descriptionGu : '';

  PushConditionType.fromJson(Map<String, dynamic> j)
      : labelGu = (j['labelGu'] ?? '').toString(),
        descriptionGu = (j['descriptionGu'] ?? '').toString(),
        type = (j['type'] ?? '').toString(),
        label = (j['label'] ?? j['type'] ?? '').toString(),
        description = (j['description'] ?? '').toString(),
        group = (j['group'] ?? '').toString(),
        params = (j['params'] as List? ?? [])
            .whereType<Map>()
            .map((e) =>
                PushConditionParam.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        supportsNegate = j['supportsNegate'] != false;
}
