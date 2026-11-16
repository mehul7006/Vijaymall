import 'api_client.dart';
import 'api_config.dart';
import 'dto.dart';

/// Public (customer) catalog: `/categories`, `/products`, `/products/{id}`,
/// `/hot-sale`, `/coupons` and `/products/{id}/reviews`. The backend made the
/// catalog readable without a token (guest browsing), so every call here
/// passes `authRequired: false` — a signed-in session still attaches its JWT,
/// but guests get the same data.
class CatalogApi {
  CatalogApi(this._client);

  final ApiClient _client;

  /// ETag cache for the public lists (`/categories`, `/product-groups`,
  /// `/units`, `/hot-sale`): key = path + query -> (etag, last body). A 304
  /// re-uses the body, so a refresh costs almost nothing.
  final Map<String, ({String etag, dynamic body})> _condCache = {};

  Future<dynamic> _getCached(String path, {Map<String, String>? query}) async {
    final key = '$path?${(query ?? const {}).entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final hit = _condCache[key];
    final r = await _client.getConditional(path,
        etag: hit?.etag, query: query);
    if (r.notModified && hit != null) return hit.body;
    final tag = r.etag;
    if (tag != null && tag.isNotEmpty) {
      _condCache[key] = (etag: tag, body: r.body);
    } else {
      _condCache.remove(key);
    }
    return r.body;
  }

  Future<List<CategoryDto>> getCategories() async {
    final raw = await _getCached('/categories') as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => CategoryDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PageProductDto> getProducts({
    String? categoryId,
    String? q,
    bool hot = false,
    // Backend default is `false`, which drops every out-of-stock pack, so
    // shoppers never saw "Out of stock" items. The app greys them out, so
    // ask for them explicitly.
    bool includeOutOfStock = true,
    int page = 0,
    int size = 50,
  }) async {
    final raw = await _client.get('/products', authRequired: false, query: {
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      if (q != null && q.isNotEmpty) 'q': q,
      if (hot) 'hot': 'true',
      'includeOutOfStock': '$includeOutOfStock',
      'page': '$page',
      'size': '$size',
    });
    return PageProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<PublicProductDto> getProduct(String id) async {
    final raw = await _client.get('/products/$id', authRequired: false);
    return PublicProductDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /hot-sale?page&size`: banners plus the hot products, which are
  /// paged (default 20, max 50, soonest `hotEnd` first). Pages are followed
  /// until `total` products are in (bounded), then merged into one result.
  Future<PublicHotSaleDto> getHotSale() async {
    const size = 50;
    var raw = await _getCached('/hot-sale', query: {'page': '0', 'size': '$size'});
    final first = PublicHotSaleDto.fromJson(Map<String, dynamic>.from(raw as Map));
    final all = [...first.products];
    var page = 0;
    var more = first.hasMore ?? (all.length < first.total);
    while (more && page < 19) {
      page++;
      raw = await _getCached('/hot-sale',
          query: {'page': '$page', 'size': '$size'});
      final next =
          PublicHotSaleDto.fromJson(Map<String, dynamic>.from(raw as Map));
      if (next.products.isEmpty) break;
      all.addAll(next.products);
      more = next.hasMore ?? (all.length < first.total);
    }
    first.products = all;
    return first;
  }

  /// `GET /shop-settings` — the public store card (name, phone, address,
  /// promise, about-text). No GSTIN, UTR or invoice settings in the payload,
  /// so it is mapped onto [ShopSettingDto] with `promise` as the footer line
  /// (`storeFromShop` reads that field) and everything else left null.
  ///
  /// This is what a customer session re-reads when the live stream reports a
  /// `catalog` frame with `area: SHOP`.
  Future<ShopSettingDto> getPublicShop() async {
    // Conditional GET: send the last ETag in If-None-Match; a 304 means the
    // cached copy is still current.
    final cached = _shopCache;
    final r = await _client.getConditional('/shop-settings',
        etag: cached == null ? null : _shopEtag);
    if (r.notModified && cached != null) return cached;
    final j = Map<String, dynamic>.from(r.body as Map);
    final dto = _publicShopFromJson(j);
    _shopCache = dto;
    _shopEtag = r.etag;
    return dto;
  }

  ShopSettingDto? _shopCache;
  String? _shopEtag;

  ShopSettingDto _publicShopFromJson(Map<String, dynamic> j) {
    String? logo = j['logoUrl']?.toString();
    // `logoUrl` is a server-relative path (`/img/shop/..._400.webp`).
    if (logo != null && logo.startsWith('/')) {
      logo = '${ApiConfig.baseUrl}$logo';
    }
    // Opening hours are computed by the server in shop time: `todayHours` is
    // "09:00-21:00" or "Closed", `openNow` says whether it is open this
    // minute. Nothing is recomputed on the device.
    final today = j['todayHours']?.toString() ?? '';
    final dto = ShopSettingDto(
      shopName: j['shopName']?.toString(),
      phone: j['phone']?.toString(),
      address: j['address']?.toString(),
      receiptFooter: j['promise']?.toString(),
      promise: j['promise']?.toString(),
      details: j['details']?.toString(),
      logoUrl: logo,
      openHours: today.isNotEmpty && today != 'Closed'
          ? today.replaceAll('-', ' - ')
          : (j['openHours']?.toString() ?? ''),
    );
    dto.shopNameGu = j['shopNameGu']?.toString();
    dto.shortName = j['shortName']?.toString();
    dto.addressGu = j['addressGu']?.toString();
    dto.promiseGu = j['promiseGu']?.toString();
    dto.detailsGu = j['detailsGu']?.toString();
    dto.iconUrl = j['iconUrl']?.toString();
    dto.icon192Url = j['icon192Url']?.toString();
    dto.email = j['email']?.toString();
    dto.whatsapp = j['whatsapp']?.toString();
    dto.mapUrl = j['mapUrl']?.toString();
    dto.holidayNote = j['holidayNote']?.toString();
    dto.openNow = j['openNow'] as bool?;
    dto.onlineOrdersOpen = j['onlineOrdersOpen'] as bool? ?? true;
    dto.onlineOrdersMessage = j['onlineOrdersMessage']?.toString() ?? '';
    return dto;
  }

  /// `GET /units` — every active unit of measure, public (no token needed).
  ///
  /// The product editor and the POS read this so `product.unit` always holds
  /// a real unit code: the backend rejects an unknown one with
  /// "unknown unit 'X'; add it under units first".
  Future<List<UnitDto>> getUnits() async {
    final raw = await _getCached('/units') as List? ?? [];
    final units = raw
        .whereType<Map>()
        .map((e) => UnitDto.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) {
        final s = a.sortOrder.compareTo(b.sortOrder);
        return s != 0 ? s : a.code.compareTo(b.code);
      });
    return units;
  }

  /// `GET /coupons` → the coupons the store is offering right now.
  ///
  /// Public (no token needed) and filtered server-side: inactive,
  /// not-yet-started, ended and used-up codes are withheld. Applying one
  /// still goes through `POST /cart/quote`, which is what proves a code is
  /// usable for *this* customer.
  Future<List<PublicCouponDto>> listOffers() async {
    final raw = await _client.get('/coupons', authRequired: false) as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => PublicCouponDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Reviews (`/products/{productId}/reviews`)
  // ---------------------------------------------------------------------------

  /// `GET /products/{productId}/reviews` → paged reviews + aggregate rating.
  /// [productId] is a backend pack id.
  Future<ReviewListDto> getReviews(String productId,
      {int page = 0, int size = 20}) async {
    final raw = await _client.get(
      '/products/$productId/reviews',
      authRequired: false,
      query: {
        'page': '$page',
        'size': '$size',
      },
    );
    return ReviewListDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /product-groups/{id}/reviews` → reviews of every pack of a product
  /// together. [id] is the group id or any pack id.
  Future<ReviewListDto> getGroupReviews(String id,
      {int page = 0, int size = 20}) async {
    final raw = await _client.get(
      '/product-groups/$id/reviews',
      authRequired: false,
      query: {'page': '$page', 'size': '$size'},
    );
    return ReviewListDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `POST /products/{productId}/reviews` → the created review.
  /// [rating] is 1–5; [comment] up to 1000 characters.
  Future<ReviewDto> postReview(String productId,
      {required int rating, String? comment}) async {
    final raw = await _client.post(
      '/products/$productId/reviews',
      body: {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    return ReviewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// `GET /products/{productId}/reviews/mine` - the caller's own review (if
  /// any) and whether they may review at all.
  Future<MyReviewDto> getMyReview(String productId) async {
    final raw = await _client.get('/products/$productId/reviews/mine');
    return MyReviewDto.fromJson(Map<String, dynamic>.from(raw as Map));
  }
}
