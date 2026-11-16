/// DTOs for the admin customer tools (`/admin/customers*`), guide 10.
library;

/// One line of `GET /admin/customers`. `active == false` means blocked.
class CustomerRowDto {
  String? id;
  String? name;
  String? email;
  String? mobile;
  bool active;
  String? createdAt;

  CustomerRowDto({
    this.id,
    this.name,
    this.email,
    this.mobile,
    this.active = true,
    this.createdAt,
  });

  CustomerRowDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        name = j['name']?.toString(),
        email = j['email']?.toString(),
        mobile = j['mobile']?.toString(),
        active = j['active'] != false,
        createdAt = j['createdAt']?.toString();

  /// Best label for the row: name, else mobile, else email.
  String get title {
    if ((name ?? '').trim().isNotEmpty) return name!.trim();
    if ((mobile ?? '').isNotEmpty) return mobile!;
    return email ?? 'Customer';
  }
}

class PageCustomerRowDto {
  List<CustomerRowDto> items;
  int page;
  int size;
  int total;

  /// `false` => total is capped (show \"10,000+\"); `hasMore` is exact.
  bool totalExact = true;
  bool? hasMore;

  PageCustomerRowDto(
      {this.items = const [], this.page = 0, this.size = 20, this.total = 0});

  PageCustomerRowDto.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => CustomerRowDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        page = (j['page'] as num?)?.toInt() ?? 0,
        size = (j['size'] as num?)?.toInt() ?? 20,
        total = (j['total'] as num?)?.toInt() ?? 0,
        totalExact = j['totalExact'] != false,
        hasMore = j['hasMore'] is bool ? j['hasMore'] as bool : null;
}

/// `GET /admin/customers/{id}` (also the reply of PATCH and the coins call).
class CustomerViewDto {
  String? id;
  String? name;
  String? email;
  String? mobile;
  bool mobileVerified;
  bool active;

  /// `APP` (signed up in the app) or `POS` (created at the counter).
  String? source;
  String? createdAt;
  int coinBalance;
  int creditBalancePaise;
  int openOrders;

  CustomerViewDto({
    this.id,
    this.name,
    this.email,
    this.mobile,
    this.mobileVerified = false,
    this.active = true,
    this.source,
    this.createdAt,
    this.coinBalance = 0,
    this.creditBalancePaise = 0,
    this.openOrders = 0,
  });

  CustomerViewDto.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString(),
        name = j['name']?.toString(),
        email = j['email']?.toString(),
        mobile = j['mobile']?.toString(),
        mobileVerified = j['mobileVerified'] == true,
        active = j['active'] != false,
        source = j['source']?.toString(),
        createdAt = j['createdAt']?.toString(),
        coinBalance = (j['coinBalance'] as num?)?.toInt() ?? 0,
        creditBalancePaise = (j['creditBalancePaise'] as num?)?.toInt() ?? 0,
        openOrders = (j['openOrders'] as num?)?.toInt() ?? 0;
}
