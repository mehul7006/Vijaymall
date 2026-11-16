/// DTOs for `20-orders-payments-admin-config.md`: order returns, reorder,
/// refunds, shop profile, the generic configuration screen, caches and logs.
/// Kept apart from `dto.dart` so the order/payment/admin-ops wire shapes live
/// in one place.
library;

import '../ist.dart';

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
String _s(Object? v) => v?.toString() ?? '';
List<Map<String, dynamic>> _maps(Object? v) => [
      for (final e in (v as List? ?? const []))
        if (e is Map) Map<String, dynamic>.from(e)
    ];

// ---------------------------------------------------------------------------
// Returns + reorder
// ---------------------------------------------------------------------------

class OrderReturnItemDto {
  final String productId;
  final String name;
  final int qty;
  final int refundPaise;
  final bool restocked;

  /// Coupon discount that sat on these units and is not refunded.
  final int couponSharePaise;

  OrderReturnItemDto.fromJson(Map<String, dynamic> j)
      : productId = _s(j['productId']),
        name = _s(j['name']),
        qty = _i(j['qty']),
        refundPaise = _i(j['refundPaise']),
        restocked = j['restocked'] as bool? ?? false,
        couponSharePaise = _i(j['couponSharePaise']);
}

/// `ReturnPreviewItem` of `POST /admin/orders/{id}/returns/preview`.
class ReturnPreviewItemDto {
  final String productId;
  final String name;
  final int qty;
  final int grossPaise;
  final int couponSharePaise;
  final int coinSharePaise;
  final int clawbackPaise;
  final int refundPaise;

  ReturnPreviewItemDto.fromJson(Map<String, dynamic> j)
      : productId = _s(j['productId']),
        name = _s(j['name']),
        qty = _i(j['qty']),
        grossPaise = _i(j['grossPaise']),
        couponSharePaise = _i(j['couponSharePaise']),
        coinSharePaise = _i(j['coinSharePaise']),
        clawbackPaise = _i(j['clawbackPaise']),
        refundPaise = _i(j['refundPaise']);
}

/// `ReturnPreview`: the exact refund before the return is confirmed.
class ReturnPreviewDto {
  final String couponPolicy;
  final int refundPaise;
  final int couponShareRemovedPaise;
  final int coinShareRemovedPaise;
  final int couponClawbackPaise;
  final int deliveryFeeRefundedPaise;
  final List<ReturnPreviewItemDto> items;

  ReturnPreviewDto.fromJson(Map<String, dynamic> j)
      : couponPolicy = _s(j['couponPolicy']),
        refundPaise = _i(j['refundPaise']),
        couponShareRemovedPaise = _i(j['couponShareRemovedPaise']),
        coinShareRemovedPaise = _i(j['coinShareRemovedPaise']),
        couponClawbackPaise = _i(j['couponClawbackPaise']),
        deliveryFeeRefundedPaise = _i(j['deliveryFeeRefundedPaise']),
        items = _maps(j['items']).map(ReturnPreviewItemDto.fromJson).toList();
}

/// `ReturnView`: goods returned on a delivered order and the refund recorded.
class OrderReturnDto {
  final String id;
  final String orderId;
  final String orderNo;
  final String reason;
  final int refundPaise;

  /// `ONLINE` (back to the payment method), `CASH` (the shop hands cash) or
  /// `NONE` (nothing to refund).
  final String refundMode;
  final int coinsClawedBack;
  final int coinsRestored;

  /// Coupon benefit taken back from this refund (policy
  /// `CLAWBACK_BELOW_MINIMUM`); 0 otherwise.
  final int couponClawbackPaise;
  final DateTime? createdAt;
  final List<OrderReturnItemDto> items;

  OrderReturnDto.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        orderId = _s(j['orderId']),
        orderNo = _s(j['orderNo']),
        reason = _s(j['reason']),
        refundPaise = _i(j['refundPaise']),
        refundMode = _s(j['refundMode']),
        coinsClawedBack = _i(j['coinsClawedBack']),
        coinsRestored = _i(j['coinsRestored']),
        couponClawbackPaise = _i(j['couponClawbackPaise']),
        createdAt = parseIst(_s(j['createdAt'])),
        items = _maps(j['items']).map(OrderReturnItemDto.fromJson).toList();
}

class ReorderLineDto {
  final String productId;
  final String name;
  final int requestedQty;
  final int qty;
  final int unitPricePaise;
  final bool priceChanged;
  final bool available;

  /// null = full quantity; `LOW_STOCK`, `OUT_OF_STOCK` or `UNAVAILABLE`.
  final String? reason;

  ReorderLineDto.fromJson(Map<String, dynamic> j)
      : productId = _s(j['productId']),
        name = _s(j['name']),
        requestedQty = _i(j['requestedQty']),
        qty = _i(j['qty']),
        unitPricePaise = _i(j['unitPricePaise']),
        priceChanged = j['priceChanged'] as bool? ?? false,
        available = j['available'] as bool? ?? false,
        reason = j['reason']?.toString();
}

class ReorderDto {
  final String orderNo;
  final bool allAvailable;
  final List<ReorderLineDto> items;

  ReorderDto.fromJson(Map<String, dynamic> j)
      : orderNo = _s(j['orderNo']),
        allAvailable = j['allAvailable'] as bool? ?? false,
        items = _maps(j['items']).map(ReorderLineDto.fromJson).toList();
}

// ---------------------------------------------------------------------------
// Refunds
// ---------------------------------------------------------------------------

class RefundDto {
  final String id;
  final String orderId;
  final int amountPaise;

  /// `PENDING` | `PROCESSING` | `ISSUED` | `FAILED`.
  final String status;
  final int attempts;
  final String lastError;
  final String reason;
  final DateTime? createdAt;

  RefundDto.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        orderId = _s(j['orderId']),
        amountPaise = _i(j['amountPaise']),
        status = _s(j['status']).toUpperCase(),
        attempts = _i(j['attempts']),
        lastError = _s(j['lastError']),
        reason = _s(j['reason']),
        createdAt = parseIst(_s(j['createdAt']));
}

class RefundPageDto {
  final List<RefundDto> items;
  final int page;
  final int total;
  final bool hasMore;

  RefundPageDto.fromJson(Map<String, dynamic> j)
      : items = _maps(j['items']).map(RefundDto.fromJson).toList(),
        page = _i(j['page']),
        total = _i(j['total']),
        hasMore = j['hasMore'] as bool? ?? false;
}

// ---------------------------------------------------------------------------
// Shop profile
// ---------------------------------------------------------------------------

class DayHoursDto {
  String day; // MON..SUN
  String open;
  String close;
  bool closed;

  DayHoursDto(
      {required this.day,
      this.open = '09:00',
      this.close = '21:00',
      this.closed = false});

  DayHoursDto.fromJson(Map<String, dynamic> j)
      : day = _s(j['day']).toUpperCase(),
        open = _s(j['open']).isEmpty ? '09:00' : _s(j['open']),
        close = _s(j['close']).isEmpty ? '21:00' : _s(j['close']),
        closed = j['closed'] as bool? ?? false;

  Map<String, dynamic> toJson() => {
        'day': day,
        'open': closed ? '00:00' : open,
        'close': closed ? '00:00' : close,
        'closed': closed,
      };
}

const kWeekDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// `GET/PUT /admin/shop-profile`: logo, contact links, hours, pause switch.
class ShopProfileDto {
  String logoUrl;
  String email;
  String whatsapp;
  String mapUrl;
  String website;
  String instagram;
  String facebook;
  List<DayHoursDto> hours;
  String holidayNote;
  String holidayNoteGu;
  String iconUrl;
  String icon192Url;
  bool onlineOrdersEnabled;
  String onlineOrdersMessage;

  ShopProfileDto.fromJson(Map<String, dynamic> j)
      : logoUrl = _s(j['logoUrl']),
        email = _s(j['email']),
        whatsapp = _s(j['whatsapp']),
        mapUrl = _s(j['mapUrl']),
        website = _s(j['website']),
        instagram = _s(j['instagram']),
        facebook = _s(j['facebook']),
        hours = _fullWeek(_maps(j['hours']).map(DayHoursDto.fromJson).toList()),
        holidayNote = _s(j['holidayNote']),
        holidayNoteGu = _s(j['holidayNoteGu']),
        iconUrl = _s(j['iconUrl']),
        icon192Url = _s(j['icon192Url']),
        onlineOrdersEnabled = j['onlineOrdersEnabled'] as bool? ?? true,
        onlineOrdersMessage = _s(j['onlineOrdersMessage']);

  /// `hours` is empty until first saved; the editor needs all seven days.
  static List<DayHoursDto> _fullWeek(List<DayHoursDto> got) => [
        for (final d in kWeekDays)
          got.firstWhere((h) => h.day == d,
              orElse: () => DayHoursDto(day: d, closed: d == 'SUN')),
      ];

  /// Full-replace body: every text field and all seven days are sent.
  Map<String, dynamic> toJson() => {
        'email': email.trim(),
        'whatsapp': whatsapp.trim(),
        'mapUrl': mapUrl.trim(),
        'website': website.trim(),
        'instagram': instagram.trim(),
        'facebook': facebook.trim(),
        'hours': hours.map((h) => h.toJson()).toList(),
        'holidayNote': holidayNote.trim(),
        'holidayNoteGu': holidayNoteGu.trim(),
        'onlineOrdersEnabled': onlineOrdersEnabled,
        'onlineOrdersMessage': onlineOrdersMessage.trim(),
      };
}

// ---------------------------------------------------------------------------
// Admin configuration (generic, server-described form)
// ---------------------------------------------------------------------------

class ConfigItemDto {
  final String key;
  final String group;
  final String groupLabel;

  /// `STRING` | `SECRET` | `INT` | `BOOLEAN` | `ENUM`.
  final String type;
  final String label;
  final String help;
  final bool secret;
  final bool isSet;

  /// Effective value as text; always null for secrets.
  final String? value;

  /// `DATABASE` | `ENVIRONMENT` | `DEFAULT`.
  final String source;
  final List<String> allowed;
  final int? min;
  final int? max;
  final bool restart;

  ConfigItemDto.fromJson(Map<String, dynamic> j)
      : key = _s(j['key']),
        group = _s(j['group']),
        groupLabel = _s(j['groupLabel']),
        type = _s(j['type']).toUpperCase(),
        label = _s(j['label']),
        help = _s(j['help']),
        secret = j['secret'] as bool? ?? false,
        isSet = j['set'] as bool? ?? false,
        value = j['value']?.toString(),
        source = _s(j['source']),
        allowed = [for (final a in (j['allowed'] as List? ?? const [])) '$a'],
        min = (j['min'] as num?)?.toInt(),
        max = (j['max'] as num?)?.toInt(),
        restart = j['restart'] as bool? ?? false;
}

class ConfigGroupDto {
  final String group;
  final String label;
  final List<ConfigItemDto> items;

  ConfigGroupDto.fromJson(Map<String, dynamic> j)
      : group = _s(j['group']),
        label = _s(j['label']),
        items = _maps(j['items']).map(ConfigItemDto.fromJson).toList();
}

class ConfigViewDto {
  final List<ConfigGroupDto> groups;
  final List<String> issues;

  ConfigViewDto.fromJson(Map<String, dynamic> j)
      : groups = _maps(j['groups']).map(ConfigGroupDto.fromJson).toList(),
        issues = [for (final a in (j['issues'] as List? ?? const [])) '$a'];
}

class BootstrapItemDto {
  final String name;
  final String setBy;

  /// `OK` | `DEFAULT` | `MISSING` | `UNSAFE`.
  final String state;
  final String detail;

  BootstrapItemDto.fromJson(Map<String, dynamic> j)
      : name = _s(j['name']),
        setBy = _s(j['setBy']),
        state = _s(j['state']).toUpperCase(),
        detail = _s(j['detail']);

  bool get needsAction => state == 'UNSAFE' || state == 'MISSING';
}

class TestResultDto {
  final bool ok;
  final String message;

  TestResultDto.fromJson(Map<String, dynamic> j)
      : ok = j['ok'] as bool? ?? false,
        message = _s(j['message']);
}

// ---------------------------------------------------------------------------
// Caches + logs
// ---------------------------------------------------------------------------

class CacheStatDto {
  final String name;
  final String description;
  final int ttlSeconds;
  final int entries;
  final int hits;
  final int misses;
  final int bypassed;
  final int clears;
  final DateTime? lastClearedAt;

  CacheStatDto.fromJson(Map<String, dynamic> j)
      : name = _s(j['name']),
        description = _s(j['description']),
        ttlSeconds = _i(j['ttlSeconds']),
        entries = _i(j['entries']),
        hits = _i(j['hits']),
        misses = _i(j['misses']),
        bypassed = _i(j['bypassed']),
        clears = _i(j['clears']),
        lastClearedAt = j['lastClearedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(_i(j['lastClearedAt']));

  /// Share of reads served from memory, 0..100 (null before any read).
  int? get hitPercent {
    final t = hits + misses;
    return t == 0 ? null : (hits * 100 / t).round();
  }
}

class LogFileDto {
  final String name;
  final int sizeBytes;
  final DateTime? lastModified;

  LogFileDto.fromJson(Map<String, dynamic> j)
      : name = _s(j['name']),
        sizeBytes = _i(j['sizeBytes']),
        lastModified = parseIst(_s(j['lastModified']));
}

class LogStatusDto {
  final String levelApp;
  final String levelRoot;
  final String levelSql;
  final int retentionDays;
  final bool fileLogging;
  final String folder;
  final List<LogFileDto> files;

  LogStatusDto.fromJson(Map<String, dynamic> j)
      : levelApp = _s(j['levelApp']),
        levelRoot = _s(j['levelRoot']),
        levelSql = _s(j['levelSql']),
        retentionDays = _i(j['retentionDays']),
        fileLogging = j['fileLogging'] as bool? ?? false,
        folder = _s(j['folder']),
        files = _maps(j['files']).map(LogFileDto.fromJson).toList();
}
