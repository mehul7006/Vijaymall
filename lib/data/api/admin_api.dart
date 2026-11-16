import 'api_client.dart';
import 'customer_admin_dto.dart';
import 'dto.dart';
import 'dto_ops.dart';

/// Typed wrapper over every `/api/v1/admin/*` endpoint plus the POS-adjacent
/// admin calls. Request bodies are built inline as Maps whose keys match the
/// Swagger schemas exactly.
class AdminApi {
  AdminApi(this._client);

  final ApiClient _client;

  // ---------------------------------------------------------------------------
  // Shop settings
  // ---------------------------------------------------------------------------

  Future<ShopSettingDto> getShop() async {
    final raw = await _client.get('/admin/shop-settings');
    return ShopSettingDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<ShopSettingDto> saveShop({
    required String shopName,
    String? address,
    String? phone,
    String? gstin,
    String? stateCode,
    String? upiId,
    String? invoicePrefix,
    String? receiptFooter,
    String? weighedPrefix,
    String? weighedMode,
    String? details,
    String? promise,
    String? shortName,
    String? shopNameGu,
    String? addressGu,
    String? promiseGu,
    String? detailsGu,
  }) async {
    final raw = await _client.put(
      '/admin/shop-settings',
      body: {
        'shopName': shopName,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (gstin != null) 'gstin': gstin,
        if (stateCode != null) 'stateCode': stateCode,
        if (upiId != null) 'upiId': upiId,
        if (invoicePrefix != null) 'invoicePrefix': invoicePrefix,
        if (receiptFooter != null) 'receiptFooter': receiptFooter,
        if (weighedPrefix != null) 'weighedPrefix': weighedPrefix,
        if (weighedMode != null) 'weighedMode': weighedMode,
        if (details != null) 'details': details,
        if (promise != null) 'promise': promise,
        if (shortName != null) 'shortName': shortName,
        if (shopNameGu != null) 'shopNameGu': shopNameGu,
        if (addressGu != null) 'addressGu': addressGu,
        if (promiseGu != null) 'promiseGu': promiseGu,
        if (detailsGu != null) 'detailsGu': detailsGu,
      },
    );
    return ShopSettingDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // ---------------------------------------------------------------------------
  // Counter desk (read-mostly): shifts, controls, low stock, audit, anomalies
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _map(Future<dynamic> f) async =>
      Map<String, dynamic>.from(await f as Map);

  /// `GET /admin/pos/shifts` (paged, newest opened first).
  Future<Map<String, dynamic>> listPosShifts(
          {String? cashierId, int page = 0, int size = 20}) =>
      _map(_client.get('/admin/pos/shifts', query: {
        if (cashierId != null && cashierId.isNotEmpty) 'cashierId': cashierId,
        'page': '$page',
        'size': '${size.clamp(1, 50)}',
      }));

  /// `GET /admin/reports/counter-controls`: `period` week|month|quarter, or
  /// an explicit `from` (+ optional `to`) as `yyyy-MM-dd` (wins over period;
  /// at most 366 days, else 400 `fields.to`).
  Future<Map<String, dynamic>> counterControls(
          {String? period, String? from, String? to}) =>
      _map(_client.get('/admin/reports/counter-controls', query: {
        if (from != null && from.isNotEmpty) ...{
          'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
        } else
          'period': period ?? 'week',
      }));

  /// `GET /admin/stock/low` -> `[ {productId, name, qty} ]` (not paged).
  Future<List<Map<String, dynamic>>> lowStock({int limit = 200}) async {
    // The server silently clamps `limit` to 1..200 (never an error).
    final raw = await _client
        .get('/admin/stock/low', query: {'limit': '${limit.clamp(1, 200)}'});
    return (raw as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// `GET /admin/audit-log` (paged, newest first; all filters optional).
  /// Filters: `actorId` (uuid), `action`, `entity`, `entityId`, `from`/`to`
  /// (`yyyy-MM-dd`, both days included; with both given the range is limited
  /// to 93 days, else 400 `fields.to`). `size` is clamped to 1..50.
  Future<Map<String, dynamic>> auditLog({
    String? actorId,
    String? action,
    String? entity,
    String? entityId,
    String? from,
    String? to,
    int page = 0,
    int size = 20,
  }) {
    String? v(String? x) => (x == null || x.trim().isEmpty) ? null : x.trim();
    return _map(_client.get('/admin/audit-log', query: {
      if (v(actorId) != null) 'actorId': v(actorId)!,
      if (v(action) != null) 'action': v(action)!,
      if (v(entity) != null) 'entity': v(entity)!,
      if (v(entityId) != null) 'entityId': v(entityId)!,
      if (v(from) != null) 'from': v(from)!,
      if (v(to) != null) 'to': v(to)!,
      'page': '$page',
      'size': '${size.clamp(1, 50)}',
    }));
  }

  /// `GET /admin/payments/anomalies` (paged, newest first).
  Future<Map<String, dynamic>> paymentAnomalies({int page = 0, int size = 20}) =>
      _map(_client.get('/admin/payments/anomalies',
          query: {'page': '$page', 'size': '$size'}));

  /// `GET /admin/pos/offline-exceptions?status=OPEN|REVIEWED` (paged).
  Future<Map<String, dynamic>> offlineExceptions(
          {String status = 'OPEN', int page = 0, int size = 20}) =>
      _map(_client.get('/admin/pos/offline-exceptions', query: {
        'status': status,
        'page': '$page',
        'size': '${size.clamp(1, 50)}'
      }));

  /// `POST /admin/pos/offline-exceptions/{id}/review` (409 ALREADY_REVIEWED).
  Future<Map<String, dynamic>> reviewOfflineException(String id,
          {String? note}) =>
      _map(_client.post('/admin/pos/offline-exceptions/$id/review', body: {
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }));

  /// `GET /admin/stock/defective` (all statuses unless [status] is given).
  Future<Map<String, dynamic>> defectiveReport(
          {String? status, String? productId, int page = 0, int size = 20}) =>
      _map(_client.get('/admin/stock/defective', query: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (productId != null && productId.isNotEmpty) 'productId': productId,
        'page': '$page',
        'size': '$size',
      }));

  /// `GET /admin/stock/defective/summary` ->
  /// `[ {productId, productName, heldQty, pendingReviewQty, batches} ]`.
  Future<List<Map<String, dynamic>>> defectiveSummary() async {
    final raw = await _client.get('/admin/stock/defective/summary');
    return (raw as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// `POST /admin/stock/defective/{id}/resolve` with `WRITE_OFF` or
  /// `RETURN_TO_SUPPLIER` (409 DEFECTIVE_NOT_HELD).
  Future<Map<String, dynamic>> resolveDefective(String id, String action,
          {String? note}) =>
      _map(_client.post('/admin/stock/defective/$id/resolve', body: {
        'action': action,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }));

  /// `PUT /admin/me/approval-pin` (4-8 digits, 204).
  Future<void> setApprovalPin(String pin) async {
    await _client.put('/admin/me/approval-pin', body: {'pin': pin});
  }

  // ---------------------------------------------------------------------------
  // Catalog: products
  // ---------------------------------------------------------------------------

  /// `PATCH /admin/products/hot-sale` - set the flag and window on up to 200
  /// products in one transaction (all or nothing). A null window end means no
  /// limit; the window replaces each product's old one. Returns the ids changed.
  Future<List<String>> bulkHotSale(
    List<String> ids, {
    required bool hotSale,
    String? hotStart,
    String? hotEnd,
  }) async {
    final raw = await _client.patch('/admin/products/hot-sale',
        headers: {'Idempotency-Key': newIdempotencyKey()},
        body: {
          'ids': ids,
          'hotSale': hotSale,
          'hotStart': hotStart,
          'hotEnd': hotEnd,
        });
    final m = Map<String, dynamic>.from(raw as Map);
    return [for (final e in (m['ids'] as List? ?? const [])) e.toString()];
  }

  /// `GET /admin/products` (filters: [hotSale], [active], [lowStock], [sort]
  /// = name | lowStock | updated).
  Future<PageAdminProductDto> listProducts({
    String? q,
    String? categoryId,
    bool? hotSale,
    bool? active,
    bool? lowStock,
    String? sort,
    int page = 0,
    int size = 50,
  }) async {
    final raw = await _client.get('/admin/products', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      if (hotSale != null) 'hotSale': '$hotSale',
      if (active != null) 'active': '$active',
      if (lowStock == true) 'lowStock': 'true',
      if (sort != null && sort.isNotEmpty) 'sort': sort,
      'page': '$page',
      'size': '$size',
    });
    return PageAdminProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<AdminProductDto> getProduct(String id) async {
    final raw = await _client.get('/admin/products/$id');
    return AdminProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<AdminProductDto> createProduct({
    required String categoryId,
    required String nameEn,
    required String nameGu,
    String? description,
    required int mrpPaise,
    required int pricePaise,
    String? unit,
    String? packSize,
    bool active = true,
    bool hotSale = false,
    String? hotStart,
    String? hotEnd,
    bool earnsCoins = true,
    bool coinRedeemable = true,
    int qtyOnHand = 0,
    int lowThreshold = 0,
  }) async {
    final raw = await _client.post('/admin/products', idempotency: true, body: {
      'categoryId': categoryId,
      'nameEn': nameEn,
      'nameGu': nameGu,
      if (description != null) 'description': description,
      'mrpPaise': mrpPaise,
      'pricePaise': pricePaise,
      if (unit != null) 'unit': unit,
      if (packSize != null) 'packSize': packSize,
      'active': active,
      'hotSale': hotSale,
      if (hotStart != null) 'hotStart': hotStart,
      if (hotEnd != null) 'hotEnd': hotEnd,
      'earnsCoins': earnsCoins,
      'coinRedeemable': coinRedeemable,
      'qtyOnHand': qtyOnHand,
      'lowThreshold': lowThreshold,
    });
    return AdminProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// Adds a pack/size/flavour to an existing product
  /// (`POST /admin/products/{id}/variants`). The backend copies the name,
  /// description and category from the anchor product, so only the pack-level
  /// fields are sent here.
  ///
  /// [id] may be the group id or any variant id of the product.
  Future<AdminProductDto> addVariant(
    String id, {
    String? variantName,
    String? packSize,
    String? unit,
    required int mrpPaise,
    required int pricePaise,
    bool active = true,
    int qtyOnHand = 0,
    int lowThreshold = 0,
    int? variantOrder,
  }) async {
    final raw = await _client.post('/admin/products/$id/variants', body: {
      if (variantName != null) 'variantName': variantName,
      if (packSize != null) 'packSize': packSize,
      if (unit != null) 'unit': unit,
      'mrpPaise': mrpPaise,
      'pricePaise': pricePaise,
      'active': active,
      'qtyOnHand': qtyOnHand,
      'lowThreshold': lowThreshold,
      if (variantOrder != null) 'variantOrder': variantOrder,
    });
    return AdminProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<AdminProductDto> updateProduct(
    String id, {
    required String categoryId,
    required String nameEn,
    required String nameGu,
    String? description,
    required int mrpPaise,
    required int pricePaise,
    String? unit,
    String? packSize,
    bool active = true,
    bool hotSale = false,
    String? hotStart,
    String? hotEnd,
    bool earnsCoins = true,
    bool coinRedeemable = true,
    int qtyOnHand = 0,
    int lowThreshold = 0,
  }) async {
    final raw = await _client.put(
      '/admin/products/$id',
      body: {
        'categoryId': categoryId,
        'nameEn': nameEn,
        'nameGu': nameGu,
        if (description != null) 'description': description,
        'mrpPaise': mrpPaise,
        'pricePaise': pricePaise,
        if (unit != null) 'unit': unit,
        if (packSize != null) 'packSize': packSize,
        'active': active,
        'hotSale': hotSale,
        if (hotStart != null) 'hotStart': hotStart,
        if (hotEnd != null) 'hotEnd': hotEnd,
        'earnsCoins': earnsCoins,
        'coinRedeemable': coinRedeemable,
        'qtyOnHand': qtyOnHand,
        'lowThreshold': lowThreshold,
      },
    );
    return AdminProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `PATCH /admin/products/{id}` — changes only the keys in [fields]; stock
  /// is never touched (a `qtyOnHand` key is a 400: use [adjustStock]). Explicit
  /// null clears `hotStart` / `hotEnd` / `description`.
  Future<AdminProductDto> patchProduct(
      String id, Map<String, Object?> fields) async {
    final raw = await _client.patch('/admin/products/$id', body: fields);
    return AdminProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `DELETE /admin/products/{id}` — always `200 {deleted, deactivated,
  /// reason}`: hard delete when never used, otherwise switched off.
  Future<ProductDeleteResult> deleteProduct(String id) async {
    final raw = await _client.deleteJson('/admin/products/$id');
    if (raw is Map) {
      return ProductDeleteResult(
        deleted: raw['deleted'] == true,
        deactivated: raw['deactivated'] == true,
        reason: raw['reason']?.toString() ?? '',
      );
    }
    // Pre-release servers answered 204 with no body.
    return const ProductDeleteResult(deleted: true, deactivated: false, reason: '');
  }

  /// `POST /admin/products/{id}/stock` — adjust on-hand by [delta].
  Future<AdminProductDto> adjustStock(String id, int delta, {String? reason}) async {
    final raw = await _client.post(
      '/admin/products/$id/stock',
      idempotency: true,
      body: {
        'delta': delta,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return AdminProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /admin/products/{id}/image` — multipart upload, field `file`.
  ///
  /// [variants] is the backend's spread rule for the uploaded picture
  /// (server default `one`): `all` (our default) replaces every pack's
  /// picture, `missing` fills this pack and the packs without one, `one`
  /// touches only this pack.
  Future<AdminProductDto> uploadProductImage(
      String id, List<int> bytes, String filename,
      {String variants = 'all'}) async {
    final raw = await _client.postMultipart(
      '/admin/products/$id/image',
      fileField: 'file',
      bytes: bytes,
      filename: filename,
      query: {'variants': variants},
    );
    return AdminProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<PosAttributesDto> getPosAttributes(String id) async {
    final raw = await _client.get('/admin/products/$id/pos');
    return PosAttributesDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<PosAttributesDto> savePosAttributes(
    String id, {
    required String soldBy,
    String? plu,
    int? gstPercent,
    String? hsn,
    List<String>? barcodes,
  }) async {
    final raw = await _client.put(
      '/admin/products/$id/pos',
      body: {
        'soldBy': soldBy,
        if (plu != null) 'plu': plu,
        if (gstPercent != null) 'gstPercent': gstPercent,
        if (hsn != null) 'hsn': hsn,
        if (barcodes != null) 'barcodes': barcodes,
      },
    );
    return PosAttributesDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  /// `GET /admin/categories` — every category including hidden ones.
  Future<List<CategoryDto>> listCategories() async {
    final raw = await _client.get('/admin/categories') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => CategoryDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CategoryDto> createCategory({
    required String nameEn,
    required String nameGu,
    int? sortOrder,
    bool active = true,
  }) async {
    final raw = await _client.post('/admin/categories', idempotency: true, body: {
      'nameEn': nameEn,
      'nameGu': nameGu,
      if (sortOrder != null) 'sortOrder': sortOrder,
      'active': active,
    });
    return CategoryDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<CategoryDto> updateCategory(
    String id, {
    required String nameEn,
    required String nameGu,
    int? sortOrder,
    bool active = true,
  }) async {
    final raw = await _client.put(
      '/admin/categories/$id',
      body: {
        'nameEn': nameEn,
        'nameGu': nameGu,
        if (sortOrder != null) 'sortOrder': sortOrder,
        'active': active,
      },
    );
    return CategoryDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `DELETE /admin/categories/{id}` — 204; 409 `CATEGORY_IN_USE` while a
  /// product or coupon still refers to it.
  Future<void> deleteCategory(String id) =>
      _client.delete('/admin/categories/$id');

  /// `POST /admin/categories/{id}/image` — multipart field `file`.
  Future<CategoryDto> uploadCategoryImage(
      String id, List<int> bytes, String filename) async {
    final raw = await _client.postMultipart(
      '/admin/categories/$id/image',
      fileField: 'file',
      bytes: bytes,
      filename: filename,
    );
    return CategoryDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

  /// `GET /admin/orders`. [status] may be a comma-separated list; [needsAction]
  /// (the five still-to-work statuses) cannot be combined with it. [from] /
  /// [to] / [date] take plain `YYYY-MM-DD` days (India time; a plain `to`
  /// covers the whole day; [date] cannot be combined with from/to).
  Future<PageAdminSummaryDto> listOrders({
    String? status,
    bool needsAction = false,
    String? from,
    String? to,
    String? date,
    String? q,
    int page = 0,
    int size = 50,
  }) async {
    final raw = await _client.get('/admin/orders', query: {
      if (status != null && status.isNotEmpty && !needsAction) 'status': status,
      if (needsAction) 'needsAction': 'true',
      if (date != null && date.isNotEmpty)
        'date': date
      else ...{
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
      // Server-side search: order number, customer name or phone — the same
      // `q` the products list already uses.
      if (q != null && q.isNotEmpty) 'q': q,
      'page': '$page',
      'size': '$size',
    });
    return PageAdminSummaryDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<AdminViewDto> getOrder(String id) async {
    final raw = await _client.get('/admin/orders/$id');
    return AdminViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<AdminViewDto> setOrderStatus(String id, String status, {String? note}) async {
    final raw = await _client.post(
      '/admin/orders/$id/status',
      body: {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return AdminViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /admin/orders/{id}/reject` - staff turn an order down. `reason`
  /// is required (1..200 chars). The customer sees it as `cancelReason`
  /// ("Rejected by shop: <reason>"); stock, coupon, coins and any online
  /// payment are given back. Cancelling through `/status` keeps the remark
  /// in the internal timeline only, so staff cancels must come through here.
  Future<AdminViewDto> rejectOrder(String id, String reason) async {
    final raw = await _client.post(
      '/admin/orders/$id/reject',
      body: {'reason': reason},
    );
    return AdminViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /admin/orders/{id}/returns` - returns already recorded.
  Future<List<OrderReturnDto>> listOrderReturns(String id) async {
    final raw = await _client.get('/admin/orders/$id/returns') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => OrderReturnDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `POST /admin/orders/{id}/returns/preview` - the exact refund, coupon and
  /// coin shares per line, before anything is recorded.
  Future<ReturnPreviewDto> previewOrderReturn(
    String id, {
    required List<Map<String, dynamic>> items,
  }) async {
    final raw = await _client.post(
      '/admin/orders/$id/returns/preview',
      body: {'items': items},
    );
    return ReturnPreviewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /admin/orders/{id}/returns` (needs `Idempotency-Key`). [items] are
  /// `{productId, qty, restock}`; only DELIVERED / PICKED_UP orders.
  Future<OrderReturnDto> recordOrderReturn(
    String id, {
    required String reason,
    required List<Map<String, dynamic>> items,
  }) async {
    final raw = await _client.post(
      '/admin/orders/$id/returns',
      idempotency: true,
      body: {'reason': reason, 'items': items},
    );
    return OrderReturnDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Dashboard + period reports
  // ---------------------------------------------------------------------------

  Future<DashboardDto> dashboard() async {
    final raw = await _client.get('/admin/dashboard');
    return DashboardDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /admin/reports/summary?period=|from=|to=` — orders (and optionally
  /// aggregates) for a period. `period` is week | month | quarter; [from]/[to]
  /// are `yyyy-MM-dd` for a custom range. The payload is parsed defensively
  /// (array, page or single object) — see [ReportSummaryDto].
  Future<ReportSummaryDto> reportSummary({
    String? period,
    String? from,
    String? to,
  }) async {
    final raw = await _client.get('/admin/reports/summary', query: {
      if (period != null && period.isNotEmpty) 'period': period,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    });
    return ReportSummaryDto.fromAny(raw);
  }

  /// Raw `GET /admin/reports/summary` for the Reports screen: `period` or an
  /// explicit `from`/`to` (`yyyy-MM-dd`; `from` wins; at most 366 days).
  /// Keeps `byDay`, `topProducts` (with `salesPaise`) and `from`/`to` that
  /// [ReportSummaryDto] drops.
  Future<Map<String, dynamic>> reportSummaryRaw(
          {String? period, String? from, String? to}) =>
      _map(_client.get('/admin/reports/summary', query: {
        if (from != null && from.isNotEmpty) ...{
          'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
        } else
          'period': period ?? 'week',
      }));

  // ---------------------------------------------------------------------------
  // Stock movements
  // ---------------------------------------------------------------------------

  /// `GET /admin/stock-movements` — paged movement history. [productId]
  /// narrows to one pack.
  Future<PageStockMovementDto> stockMovements({
    String? productId,
    int page = 0,
    int size = 50,
  }) async {
    final raw = await _client.get('/admin/stock-movements', query: {
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      'page': '$page',
      'size': '$size',
    });
    return PageStockMovementDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // ---------------------------------------------------------------------------
  // Coupons
  // ---------------------------------------------------------------------------

  Future<List<CouponDto>> listCoupons() async {
    final raw = await _client.get('/admin/coupons') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => CouponDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CouponDto> createCoupon({
    required String code,
    required String kind,
    required int value,
    int? minOrderPaise,
    int? maxDiscountPaise,
    String? categoryId,
    List<String>? categoryIds,
    List<String>? productIds,
    List<String>? productGroupIds,
    int? perUserLimit,
    int? totalLimit,
    String? startAt,
    String? endAt,
    bool active = true,
    bool worksWithCoins = true,
    bool firstOrderOnly = false,
  }) async {
    // Backend: `categoryIds` is the list (empty = every category) and
    // `categoryId` stays as the first entry for older readers.
    final ids = categoryIds ?? (categoryId == null ? null : [categoryId]);
    final raw = await _client.post('/admin/coupons', body: {
      'code': code,
      'kind': kind,
      'value': value,
      if (minOrderPaise != null) 'minOrderPaise': minOrderPaise,
      if (maxDiscountPaise != null) 'maxDiscountPaise': maxDiscountPaise,
      if (ids != null) 'categoryIds': ids,
      if (ids != null && ids.isNotEmpty) 'categoryId': ids.first,
      if (productIds != null) 'productIds': productIds,
      if (productGroupIds != null) 'productGroupIds': productGroupIds,
      if (ids == null && categoryId != null) 'categoryId': categoryId,
      if (perUserLimit != null) 'perUserLimit': perUserLimit,
      if (totalLimit != null) 'totalLimit': totalLimit,
      if (startAt != null) 'startAt': startAt,
      if (endAt != null) 'endAt': endAt,
      'active': active,
      'worksWithCoins': worksWithCoins,
      'firstOrderOnly': firstOrderOnly,
    });
    return CouponDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<CouponDto> updateCoupon(
    String id, {
    required String code,
    required String kind,
    required int value,
    int? minOrderPaise,
    int? maxDiscountPaise,
    String? categoryId,
    List<String>? categoryIds,
    List<String>? productIds,
    List<String>? productGroupIds,
    int? perUserLimit,
    int? totalLimit,
    String? startAt,
    String? endAt,
    bool active = true,
    bool worksWithCoins = true,
    bool firstOrderOnly = false,
  }) async {
    final ids = categoryIds ?? (categoryId == null ? null : [categoryId]);
    final raw = await _client.put(
      '/admin/coupons/$id',
      body: {
        'code': code,
        'kind': kind,
        'value': value,
        if (minOrderPaise != null) 'minOrderPaise': minOrderPaise,
        if (maxDiscountPaise != null) 'maxDiscountPaise': maxDiscountPaise,
        if (ids != null) 'categoryIds': ids,
        if (ids != null && ids.isNotEmpty) 'categoryId': ids.first,
        if (productIds != null) 'productIds': productIds,
        if (productGroupIds != null) 'productGroupIds': productGroupIds,
        if (ids == null && categoryId != null) 'categoryId': categoryId,
        if (perUserLimit != null) 'perUserLimit': perUserLimit,
        if (totalLimit != null) 'totalLimit': totalLimit,
        if (startAt != null) 'startAt': startAt,
        if (endAt != null) 'endAt': endAt,
        'active': active,
        'worksWithCoins': worksWithCoins,
        'firstOrderOnly': firstOrderOnly,
      },
    );
    return CouponDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> deleteCoupon(String id) => _client.delete('/admin/coupons/$id');

  // ---------------------------------------------------------------------------
  // Units of measure (`/admin/units`)
  // ---------------------------------------------------------------------------

  /// Every unit row, active or not — the admin list shows both, the product
  /// picker only the active ones.
  Future<List<UnitDto>> listUnits() async {
    final raw = await _client.get('/admin/units') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => UnitDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<UnitDto> createUnit({
    required String code,
    required String nameEn,
    String nameGu = '',
    String soldBy = 'UNIT',
    int sortOrder = 0,
    bool active = true,
  }) async {
    final raw = await _client.post('/admin/units', body: {
      'code': code,
      'nameEn': nameEn,
      'nameGu': nameGu,
      'soldBy': soldBy,
      'sortOrder': sortOrder,
      'active': active,
    });
    return UnitDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<UnitDto> updateUnit(
    String code, {
    String? newCode,
    required String nameEn,
    String nameGu = '',
    String soldBy = 'UNIT',
    int sortOrder = 0,
    bool active = true,
  }) async {
    final raw = await _client.put(
      '/admin/units/${Uri.encodeComponent(code)}',
      body: {
        'code': newCode ?? code,
        'nameEn': nameEn,
        'nameGu': nameGu,
        'soldBy': soldBy,
        'sortOrder': sortOrder,
        'active': active,
      },
    );
    return UnitDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> deleteUnit(String code) => _client.delete('/admin/units/${Uri.encodeComponent(code)}');

  // ---------------------------------------------------------------------------
  // Coins: settings + rules
  // ---------------------------------------------------------------------------

  Future<CoinSettingsDto> getCoinSettings() async {
    final raw = await _client.get('/admin/coin-settings');
    return CoinSettingsDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<CoinSettingsDto> saveCoinSettings({
    required int paisePerCoin,
    required int maxRedeemPercent,
    required int expiryMonths,
  }) async {
    final raw = await _client.put('/admin/coin-settings', body: {
      'paisePerCoin': paisePerCoin,
      'maxRedeemPercent': maxRedeemPercent,
      'expiryMonths': expiryMonths,
    });
    return CoinSettingsDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<List<RuleViewDto>> listCoinRules() async {
    final raw = await _client.get('/admin/coin-rules') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => RuleViewDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<RuleViewDto> createCoinRule({
    required String name,
    required int spendPaise,
    required int coins,
    required String mode, // PRO_RATA | SLAB
    int? minOrderPaise,
    String? startAt,
    String? endAt,
    bool active = true,
  }) async {
    final raw = await _client.post('/admin/coin-rules', idempotency: true, body: {
      'name': name,
      'spendPaise': spendPaise,
      'coins': coins,
      'mode': mode,
      if (minOrderPaise != null) 'minOrderPaise': minOrderPaise,
      if (startAt != null) 'startAt': startAt,
      if (endAt != null) 'endAt': endAt,
      'active': active,
    });
    return RuleViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<RuleViewDto> updateCoinRule(
    String id, {
    required String name,
    required int spendPaise,
    required int coins,
    required String mode,
    int? minOrderPaise,
    String? startAt,
    String? endAt,
    bool active = true,
  }) async {
    final raw = await _client.put(
      '/admin/coin-rules/$id',
      body: {
        'name': name,
        'spendPaise': spendPaise,
        'coins': coins,
        'mode': mode,
        if (minOrderPaise != null) 'minOrderPaise': minOrderPaise,
        if (startAt != null) 'startAt': startAt,
        if (endAt != null) 'endAt': endAt,
        'active': active,
      },
    );
    return RuleViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> deleteCoinRule(String id) => _client.delete('/admin/coin-rules/$id');

  // ---------------------------------------------------------------------------
  // Hot banners
  // ---------------------------------------------------------------------------

  Future<List<HotBannerDto>> listBanners() async {
    final raw = await _client.get('/admin/hot-banners') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => HotBannerDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<HotBannerDto> createBanner({
    required String title,
    String? subtitle,
    String? imageUrl,
    String? startAt,
    String? endAt,
    bool active = true,
  }) async {
    final raw = await _client.post('/admin/hot-banners', body: {
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (startAt != null) 'startAt': startAt,
      if (endAt != null) 'endAt': endAt,
      'active': active,
    });
    return HotBannerDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<HotBannerDto> updateBanner(
    String id, {
    required String title,
    String? subtitle,
    String? imageUrl,
    String? startAt,
    String? endAt,
    bool active = true,
  }) async {
    final raw = await _client.put(
      '/admin/hot-banners/$id',
      body: {
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (startAt != null) 'startAt': startAt,
        if (endAt != null) 'endAt': endAt,
        'active': active,
      },
    );
    return HotBannerDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> deleteBanner(String id) => _client.delete('/admin/hot-banners/$id');

  // ---------------------------------------------------------------------------
  // Payment methods
  // ---------------------------------------------------------------------------

  Future<List<SettingDto>> listPaymentMethods() async {
    final raw = await _client.get('/admin/payment-methods') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => SettingDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<SettingDto>> savePaymentMethods(List<SettingDto> methods) async {
    final raw = await _client.put(
      '/admin/payment-methods',
      body: methods.map((m) => {'code': m.code, 'enabled': m.enabled}).toList(),
    );
    return (raw as List? ?? [])
        .whereType<Map>()
        .map((e) => SettingDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Staff
  // ---------------------------------------------------------------------------

  Future<List<StaffViewDto>> listStaff() async {
    final raw = await _client.get('/admin/staff') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => StaffViewDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<StaffViewDto> createStaff({
    required String email,
    String? name,
    String? mobile,
    bool confirmPromote = false,
  }) async {
    final raw = await _client.post('/admin/staff', body: {
      'email': email,
      if (name != null && name.isNotEmpty) 'name': name,
      if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
      if (confirmPromote) 'confirmPromote': true,
    });
    return StaffViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> setStaffActive(String id, bool active) =>
      _client.patch('/admin/staff/$id', body: {'active': active});

  // ---------------------------------------------------------------------------
  // Credit (udhar) - `/admin/credit/*` and `/admin/reports/credit`
  // ---------------------------------------------------------------------------

  /// `GET /admin/credit/accounts` - debtors, biggest first (paged).
  ///
  /// [q] (name or mobile part, at most 100 characters) and [eligibleOnly]
  /// (limit above zero) are applied by the server. Each row carries
  /// `availablePaise` and `blocked`.
  Future<PageDebtorDto> getCreditAccounts({
    bool outstandingOnly = true,
    bool eligibleOnly = false,
    String? q,
    int page = 0,
    int size = 50,
  }) async {
    final qt = (q ?? '').trim();
    final raw = await _client.get('/admin/credit/accounts', query: {
      'outstandingOnly': '$outstandingOnly',
      if (eligibleOnly) 'eligibleOnly': 'true',
      if (qt.isNotEmpty) 'q': qt.length > 100 ? qt.substring(0, 100) : qt,
      'page': '$page',
      'size': '${size.clamp(1, 50)}',
    });
    return PageDebtorDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /admin/credit/accounts/{customerId}`.
  Future<CreditAccountDto> getCreditAccount(String customerId) async {
    final raw = await _client.get('/admin/credit/accounts/$customerId');
    return CreditAccountDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /admin/credit/accounts/{customerId}/ledger` - newest first.
  Future<PageCreditLedgerDto> getCreditLedger(String customerId,
      {int page = 0, int size = 50}) async {
    final raw = await _client.get('/admin/credit/accounts/$customerId/ledger',
        query: {'page': '$page', 'size': '$size'});
    return PageCreditLedgerDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `PUT /admin/credit/accounts/{customerId}/limit`.
  Future<CreditAccountDto> setCreditLimit(
      String customerId, int limitPaise) async {
    final raw = await _client.put('/admin/credit/accounts/$customerId/limit',
        body: {'limitPaise': limitPaise});
    return CreditAccountDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `PUT /admin/credit/limit` - approve credit for a customer by mobile.
  ///
  /// [name] is sent when given. The server does not store a name on this call
  /// yet (backend gap), so callers read `name` back from the answer.
  Future<CreditAccountDto> approveCreditLimit(String mobile, int limitPaise,
      {String? name}) async {
    final raw = await _client.put('/admin/credit/limit', body: {
      'mobile': mobile,
      'limitPaise': limitPaise,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
    return CreditAccountDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /admin/credit/accounts/{customerId}/adjust` - [amountPaise] > 0
  /// adds to what they owe, < 0 writes some off. [note] is required.
  ///
  /// Sends an `Idempotency-Key` (optional on the server): pass the same
  /// [idempotencyKey] when retrying the same adjustment so it is applied once.
  Future<CreditAccountDto> adjustCredit(
      String customerId, int amountPaise, String note,
      {String? idempotencyKey}) async {
    final raw = await _client.post('/admin/credit/accounts/$customerId/adjust',
        headers: idempotencyKey == null
            ? null
            : {'Idempotency-Key': idempotencyKey},
        idempotency: idempotencyKey == null,
        body: {'amountPaise': amountPaise, 'note': note});
    return CreditAccountDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // ---------------------------------------------------------------------------
  // Customers (`/admin/customers`)
  // ---------------------------------------------------------------------------

  /// `GET /admin/customers?q=&page=&size=` - search by name, email or mobile.
  Future<PageCustomerRowDto> searchCustomers(
      {String? q, int page = 0, int size = 20}) async {
    final raw = await _client.get('/admin/customers', query: {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      'page': '$page',
      'size': '$size',
    });
    return PageCustomerRowDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /admin/customers/{id}` - coins, credit owed, open orders.
  Future<CustomerViewDto> getCustomer(String id) async {
    final raw = await _client.get('/admin/customers/$id');
    return CustomerViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /admin/customers/{id}/wallet-ledger` - the customer's coin history,
  /// newest first, paged. (Rows carry `orderId`, no "remaining" field.)
  Future<PageLedgerViewDto> customerWalletLedger(String id,
      {int page = 0, int size = 10}) async {
    final raw = await _client.get('/admin/customers/$id/wallet-ledger',
        query: {'page': '$page', 'size': '$size'});
    return PageLedgerViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /admin/customers/{id}/orders` - the customer's orders, newest
  /// first, paged (same summary rows as `/admin/orders`).
  Future<PageAdminSummaryDto> customerOrders(String id,
      {int page = 0, int size = 10}) async {
    final raw = await _client.get('/admin/customers/$id/orders',
        query: {'page': '$page', 'size': '$size'});
    return PageAdminSummaryDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `PATCH /admin/customers/{id}` - block (`false`) / unblock (`true`).
  /// `active` is always sent: an omitted value would block the customer.
  Future<CustomerViewDto> setCustomerActive(String id, bool active) async {
    final raw =
        await _client.patch('/admin/customers/$id', body: {'active': active});
    return CustomerViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /admin/customers/{id}/coins` - give (+) or take back (-) coins.
  /// Errors come back on `fields.coins` / `fields.reason`.
  Future<CustomerViewDto> adjustCustomerCoins(
      String id, int delta, String reason) async {
    final raw = await _client.post('/admin/customers/$id/coins',
        idempotency: true, body: {'delta': delta, 'reason': reason});
    return CustomerViewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /admin/reports/credit?period=|from=|to=`.
  /// Raw `GET /admin/reports/credit` (keeps `salesByPaymentType`, `byDay`
  /// and the `blocked`/`availablePaise` of the debtors).
  Future<Map<String, dynamic>> creditReportRaw(
          {String? period, String? from, String? to}) =>
      _map(_client.get('/admin/reports/credit', query: {
        if (from != null && from.isNotEmpty) ...{
          'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
        } else
          'period': period ?? 'week',
      }));

  Future<CreditReportDto> getCreditReport(
      {String? period, String? from, String? to}) async {
    final raw = await _client.get('/admin/reports/credit', query: {
      if (period != null && period.isNotEmpty) 'period': period,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    });
    return CreditReportDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  // ---------------------------------------------------------------------------
  // Purchasing + stock takes (`/admin/purchases`, `/admin/stock-takes`)
  // ---------------------------------------------------------------------------

  /// `POST /admin/purchases` (GRN) - needs an `Idempotency-Key`; pass the key
  /// the form created when it was opened so a retry cannot double-receive.
  /// [items] are `{productId, qty, unitCostPaise}`.
  Future<Map<String, dynamic>> createPurchase({
    required String idempotencyKey,
    required String supplierName,
    String? invoiceNo,
    String? note,
    required List<Map<String, dynamic>> items,
  }) async {
    final raw = await _client.post(
      '/admin/purchases',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'supplierName': supplierName,
        if (invoiceNo != null && invoiceNo.isNotEmpty) 'invoiceNo': invoiceNo,
        if (note != null && note.isNotEmpty) 'note': note,
        'items': items,
      },
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  /// `GET /admin/purchases` - page object `{items, page, size, total}`.
  Future<Map<String, dynamic>> listPurchases({int page = 0, int size = 20}) async {
    final raw = await _client
        .get('/admin/purchases', query: {'page': '$page', 'size': '$size'});
    return Map<String, dynamic>.from(raw as Map);
  }

  /// `POST /admin/stock-takes` - [items] are `{productId, countedQty}`.
  /// Returns `{changes: [{productId, name, before, counted, delta}], unchanged}`.
  /// [idempotencyKey] (optional header): a repeat with the same key returns
  /// the first result and changes nothing; same key + another body is 409
  /// `IDEMPOTENCY_KEY_REUSED`.
  Future<Map<String, dynamic>> createStockTake({
    String? note,
    String? idempotencyKey,
    required List<Map<String, dynamic>> items,
  }) async {
    final raw = await _client.post('/admin/stock-takes',
        headers: idempotencyKey == null
            ? null
            : {'Idempotency-Key': idempotencyKey},
        body: {
          if (note != null && note.isNotEmpty) 'note': note,
          'items': items,
        });
    return Map<String, dynamic>.from(raw as Map);
  }
}

/// Answer of `DELETE /admin/products/{id}`.
class ProductDeleteResult {
  final bool deleted;
  final bool deactivated;
  final String reason;
  const ProductDeleteResult(
      {required this.deleted, required this.deactivated, required this.reason});
}
