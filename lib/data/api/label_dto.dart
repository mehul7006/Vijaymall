/// DTOs for barcode generation and label printing (`72-barcode-labels.md`).
/// Sizes are millimetres (decimal numbers); instants are UTC ISO strings.
library;

int _i(dynamic v, [int d = 0]) => (v as num?)?.toInt() ?? d;
double _d(dynamic v, [double d = 0]) => (v as num?)?.toDouble() ?? d;
String _s(dynamic v) => v?.toString() ?? '';
bool _b(dynamic v) => v == true;

/// The digit that would make [c] (8, 12 or 13 digits) valid, or null when the
/// length is not checked by the server (other lengths and text codes).
int? expectedCheckDigit(String c) {
  if (!RegExp(r'^(\d{8}|\d{12}|\d{13})$').hasMatch(c)) return null;
  var sum = 0;
  for (var i = 0; i < c.length - 1; i++) {
    sum += int.parse(c[c.length - 2 - i]) * (i.isEven ? 3 : 1);
  }
  return (10 - sum % 10) % 10;
}

/// Same rule as the server: EAN-8, UPC-A and EAN-13 need a correct last digit.
bool validGtin(String c) {
  final e = expectedCheckDigit(c);
  return e == null || e == int.parse(c[c.length - 1]);
}

/// Message for a barcode typed by a person, or null when fine.
String? barcodeError(String c) {
  final t = c.trim();
  if (t.isEmpty || validGtin(t)) return null;
  return 'Barcode $t has a wrong last digit: for these digits it should be '
      '${expectedCheckDigit(t)}. Check that the code was typed or scanned '
      'correctly';
}

class LabelFields {
  bool shopName;
  bool packSize;
  bool mrp;
  bool price;
  bool packedOn;
  bool bestBefore;
  bool batchNo;
  bool pricePerUnit;
  String productName; // NONE, EN, GU, BOTH
  int fontSize; // 4..24
  String alignment; // LEFT, CENTER, RIGHT

  LabelFields({
    this.shopName = false,
    this.packSize = true,
    this.mrp = true,
    this.price = true,
    this.packedOn = false,
    this.bestBefore = false,
    this.batchNo = false,
    this.pricePerUnit = false,
    this.productName = 'EN',
    this.fontSize = 7,
    this.alignment = 'CENTER',
  });

  factory LabelFields.fromJson(Map<String, dynamic> j) => LabelFields(
        shopName: _b(j['shopName']),
        packSize: _b(j['packSize']),
        mrp: _b(j['mrp']),
        price: _b(j['price']),
        packedOn: _b(j['packedOn']),
        bestBefore: _b(j['bestBefore']),
        batchNo: _b(j['batchNo']),
        pricePerUnit: _b(j['pricePerUnit']),
        productName:
            _s(j['productName']).isEmpty ? 'NONE' : _s(j['productName']),
        fontSize: _i(j['fontSize'], 7) == 0 ? 7 : _i(j['fontSize'], 7),
        alignment: _s(j['alignment']).isEmpty ? 'CENTER' : _s(j['alignment']),
      );

  /// Every key is always sent (the guide says a missing key may be a 400).
  Map<String, dynamic> toJson() => {
        'shopName': shopName,
        'productName': productName,
        'packSize': packSize,
        'mrp': mrp,
        'price': price,
        'packedOn': packedOn,
        'bestBefore': bestBefore,
        'batchNo': batchNo,
        'pricePerUnit': pricePerUnit,
        'fontSize': fontSize,
        'alignment': alignment,
      };

  LabelFields copy() => LabelFields.fromJson(toJson());
}

class LabelTemplate {
  final String id;
  final String name;
  final String kind; // THERMAL | SHEET
  final double widthMm;
  final double heightMm;
  final int columns;
  final int rows;
  final double gapXMm;
  final double gapYMm;
  final double marginLeftMm;
  final double marginTopMm;
  final String barcodeType; // EAN13 | CODE128 | QR
  final LabelFields fields;
  final bool builtIn;

  const LabelTemplate({
    required this.id,
    required this.name,
    required this.kind,
    required this.widthMm,
    required this.heightMm,
    required this.columns,
    required this.rows,
    required this.gapXMm,
    required this.gapYMm,
    required this.marginLeftMm,
    required this.marginTopMm,
    required this.barcodeType,
    required this.fields,
    required this.builtIn,
  });

  bool get isSheet => kind == 'SHEET';
  int get perPage => columns * rows;

  factory LabelTemplate.fromJson(Map<String, dynamic> j) => LabelTemplate(
        id: _s(j['id']),
        name: _s(j['name']),
        kind: _s(j['kind']).isEmpty ? 'THERMAL' : _s(j['kind']),
        widthMm: _d(j['widthMm']),
        heightMm: _d(j['heightMm']),
        columns: _i(j['columns'], 1),
        rows: _i(j['rows'], 1),
        gapXMm: _d(j['gapXMm']),
        gapYMm: _d(j['gapYMm']),
        marginLeftMm: _d(j['marginLeftMm']),
        marginTopMm: _d(j['marginTopMm']),
        barcodeType:
            _s(j['barcodeType']).isEmpty ? 'EAN13' : _s(j['barcodeType']),
        fields: LabelFields.fromJson(
            Map<String, dynamic>.from((j['fields'] as Map?) ?? const {})),
        builtIn: _b(j['builtIn']),
      );

  static String mm(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  String get sizeText {
    final base = '${mm(widthMm)} x ${mm(heightMm)} mm';
    return isSheet ? '$base cell, $columns x $rows per A4 sheet' : base;
  }
}

class LabelPage<T> {
  final List<T> items;
  final int page;
  final int total;
  final bool hasMore;
  const LabelPage(this.items, this.page, this.total, this.hasMore);

  static LabelPage<T> from<T>(
      dynamic raw, T Function(Map<String, dynamic>) f) {
    final m = Map<String, dynamic>.from(raw as Map);
    final list = (m['items'] as List? ?? const [])
        .map((e) => f(Map<String, dynamic>.from(e as Map)))
        .toList();
    return LabelPage(
        list, _i(m['page']), _i(m['total'], list.length), _b(m['hasMore']));
  }
}

class LabelHistoryRow {
  final String id;
  final DateTime? printedAt;
  final String actorName;
  final String templateName;
  final String variantId;
  final String variantName;
  final int copies;
  final String mode;

  const LabelHistoryRow({
    required this.id,
    required this.printedAt,
    required this.actorName,
    required this.templateName,
    required this.variantId,
    required this.variantName,
    required this.copies,
    required this.mode,
  });

  factory LabelHistoryRow.fromJson(Map<String, dynamic> j) => LabelHistoryRow(
        id: _s(j['id']),
        printedAt: DateTime.tryParse(_s(j['printedAt'])),
        actorName: _s(j['actorName']),
        templateName: _s(j['templateName']),
        variantId: _s(j['variantId']),
        variantName: _s(j['variantName']),
        copies: _i(j['copies']),
        mode: _s(j['mode']),
      );
}

class GeneratedBarcode {
  final String variantId;
  final String barcode;
  final bool created;
  final List<String> barcodes;
  const GeneratedBarcode(
      this.variantId, this.barcode, this.created, this.barcodes);

  factory GeneratedBarcode.fromJson(Map<String, dynamic> j) => GeneratedBarcode(
        _s(j['variantId']),
        _s(j['barcode']),
        _b(j['created']),
        (j['barcodes'] as List? ?? const []).map((e) => '$e').toList(),
      );
}

/// One entry of a print request.
class LabelPrintItem {
  final String variantId;
  final String name;
  int copies;
  bool fromStock;
  final int stock;
  LabelPrintItem(this.variantId, this.name,
      {this.copies = 1, this.fromStock = false, this.stock = 0});

  Map<String, dynamic> toJson() =>
      {'variantId': variantId, 'copies': fromStock ? 'fromStock' : copies};
}

/// Raw answer of `POST /admin/labels`.
class LabelPrintResult {
  final List<int> bytes;
  final String contentType;
  final int? count;
  final int? pages;
  final String mode;
  const LabelPrintResult(
      this.bytes, this.contentType, this.count, this.pages, this.mode);
}
