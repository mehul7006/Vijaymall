/// DTOs for purchases v2 (`70-purchases.md`, playbook P2). Money is integer
/// paise; only the landed unit costs are fractional (`double`).
library;

int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
int? _in(dynamic v) => v == null ? null : _i(v);
double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
double? _dn(dynamic v) => v == null ? null : _d(v);
String _s(dynamic v) => v == null ? '' : '$v';
String? _sn(dynamic v) => v == null ? null : '$v';
bool _b(dynamic v) => v == true;
Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from(v as Map);
List<Map<String, dynamic>> _l(dynamic v) =>
    (v as List? ?? const []).whereType<Map>().map(_m).toList();

/// Standard page: `{items, page, size, total, totalExact, hasMore}`.
class PPage<T> {
  final List<T> items;
  final int page, size, total;
  final bool totalExact, hasMore;
  const PPage(this.items, this.page, this.size, this.total, this.totalExact,
      this.hasMore);

  static PPage<T> from<T>(dynamic raw, T Function(Map<String, dynamic>) f) {
    final j = _m(raw);
    return PPage<T>(
      _l(j['items']).map(f).toList(),
      _i(j['page']),
      _i(j['size']),
      _i(j['total']),
      j['totalExact'] != false,
      _b(j['hasMore']),
    );
  }

  String get totalLabel => totalExact ? '$total' : '10,000+';
}

class SupplierDto {
  final String id, name, phone, gstin, stateCode, address, lastInvoiceNo;
  final int paymentTermsDays, purchaseCount, totalDuePaise, balancePaise,
      creditPaise;
  final bool active;
  final String createdAt;
  final String? lastPurchaseAt;

  SupplierDto.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        name = _s(j['name']),
        phone = _s(j['phone']),
        gstin = _s(j['gstin']),
        stateCode = _s(j['stateCode']),
        address = _s(j['address']),
        lastInvoiceNo = _s(j['lastInvoiceNo']),
        paymentTermsDays = _i(j['paymentTermsDays']),
        purchaseCount = _i(j['purchaseCount']),
        totalDuePaise = _i(j['totalDuePaise']),
        balancePaise = _i(j['balancePaise']),
        creditPaise = _i(j['creditPaise']),
        active = j['active'] != false,
        createdAt = _s(j['createdAt']),
        lastPurchaseAt = _sn(j['lastPurchaseAt']);
}

class PurchaseLookupDto {
  final String productId, name, hsn;
  final int gstPercent, mrpPaise, pricePaise, qtyOnHand;
  final int? lastPurchaseCostPaise;
  final double? lastLandedUnitCostPaise;
  final String? lastSupplierName, lastInvoiceDate, lastPurchaseId;

  PurchaseLookupDto.fromJson(Map<String, dynamic> j)
      : productId = _s(j['productId']),
        name = _s(j['name']),
        hsn = _s(j['hsn']),
        gstPercent = _i(j['gstPercent']),
        mrpPaise = _i(j['mrpPaise']),
        pricePaise = _i(j['pricePaise']),
        qtyOnHand = _i(j['qtyOnHand']),
        lastPurchaseCostPaise = _in(j['lastPurchaseCostPaise']),
        lastLandedUnitCostPaise = _dn(j['lastLandedUnitCostPaise']),
        lastSupplierName = _sn(j['lastSupplierName']),
        lastInvoiceDate = _sn(j['lastInvoiceDate']),
        lastPurchaseId = _sn(j['lastPurchaseId']);
}

class PurchaseLineDto {
  final String id, productId, name, hsn, batchNo;
  final int qty,
      freeQty,
      unitCostPaise,
      lineCostPaise,
      lineDiscountPaise,
      docDiscountSharePaise,
      taxablePaise,
      gstPercent,
      cgstPaise,
      sgstPaise,
      igstPaise,
      cessPaise,
      lineTotalPaise,
      returnedQty,
      landedTotalPaise;
  final double? discountPercent;
  final double cessPercent, landedUnitCostPaise, landedUnitCostRoundedPaise;
  final int? mrpPaise, sellingPricePaise;
  final String? expiryDate;
  final bool applyToVariant;

  PurchaseLineDto.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        productId = _s(j['productId']),
        name = _s(j['name']),
        hsn = _s(j['hsn']),
        batchNo = _s(j['batchNo']),
        qty = _i(j['qty']),
        freeQty = _i(j['freeQty']),
        unitCostPaise = _i(j['unitCostPaise']),
        lineCostPaise = _i(j['lineCostPaise']),
        lineDiscountPaise = _i(j['lineDiscountPaise']),
        docDiscountSharePaise = _i(j['docDiscountSharePaise']),
        taxablePaise = _i(j['taxablePaise']),
        gstPercent = _i(j['gstPercent']),
        cgstPaise = _i(j['cgstPaise']),
        sgstPaise = _i(j['sgstPaise']),
        igstPaise = _i(j['igstPaise']),
        cessPaise = _i(j['cessPaise']),
        lineTotalPaise = _i(j['lineTotalPaise']),
        returnedQty = _i(j['returnedQty']),
        landedTotalPaise = _i(j['landedTotalPaise']),
        discountPercent = _dn(j['discountPercent']),
        cessPercent = _d(j['cessPercent']),
        landedUnitCostPaise = _d(j['landedUnitCostPaise']),
        landedUnitCostRoundedPaise = _d(j['landedUnitCostRoundedPaise']),
        mrpPaise = _in(j['mrpPaise']),
        sellingPricePaise = _in(j['sellingPricePaise']),
        expiryDate = _sn(j['expiryDate']),
        applyToVariant = _b(j['applyToVariant']);

  /// Units that came into stock.
  int get received => qty + freeQty;
  int get returnable => received - returnedQty;
}

class PurchasePaymentDto {
  final String id, mode, reference, note, paidAt;
  final int amountPaise;

  PurchasePaymentDto.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        mode = _s(j['mode']),
        reference = _s(j['reference']),
        note = _s(j['note']),
        paidAt = _s(j['paidAt']),
        amountPaise = _i(j['amountPaise']);
}

class PurchaseDto {
  final String id, supplierId, supplierName, supplierPhone, supplierGstin,
      supplierStateCode, gstMode, invoiceNo, invoiceDate, receivedDate, note,
      attachmentNote, paymentStatus, rounding, createdAt;
  final bool interState, overdue, hasAttachment;
  final String? dueDate, attachmentUrl;
  final int lineDiscountPaise,
      docDiscountPaise,
      taxablePaise,
      cgstPaise,
      sgstPaise,
      igstPaise,
      cessPaise,
      freightPaise,
      freightGstPercent,
      freightGstPaise,
      roundOffPaise,
      totalCostPaise,
      paidPaise,
      returnedPaise,
      duePaise;
  final double? docDiscountPercent;
  final List<PurchasePaymentDto> payments;
  final List<PurchaseLineDto> items;
  final List<String> warnings;

  PurchaseDto.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        supplierId = _s(j['supplierId']),
        supplierName = _s(j['supplierName']),
        supplierPhone = _s(j['supplierPhone']),
        supplierGstin = _s(j['supplierGstin']),
        supplierStateCode = _s(j['supplierStateCode']),
        gstMode = _s(j['gstMode']),
        invoiceNo = _s(j['invoiceNo']),
        invoiceDate = _s(j['invoiceDate']),
        receivedDate = _s(j['receivedDate']),
        note = _s(j['note']),
        attachmentNote = _s(j['attachmentNote']),
        paymentStatus = _s(j['paymentStatus']),
        rounding = _s(j['rounding']),
        createdAt = _s(j['createdAt']),
        interState = _b(j['interState']),
        overdue = _b(j['overdue']),
        hasAttachment = _b(j['hasAttachment']),
        dueDate = _sn(j['dueDate']),
        attachmentUrl = _sn(j['attachmentUrl']),
        lineDiscountPaise = _i(j['lineDiscountPaise']),
        docDiscountPaise = _i(j['docDiscountPaise']),
        taxablePaise = _i(j['taxablePaise']),
        cgstPaise = _i(j['cgstPaise']),
        sgstPaise = _i(j['sgstPaise']),
        igstPaise = _i(j['igstPaise']),
        cessPaise = _i(j['cessPaise']),
        freightPaise = _i(j['freightPaise']),
        freightGstPercent = _i(j['freightGstPercent']),
        freightGstPaise = _i(j['freightGstPaise']),
        roundOffPaise = _i(j['roundOffPaise']),
        totalCostPaise = _i(j['totalCostPaise']),
        paidPaise = _i(j['paidPaise']),
        returnedPaise = _i(j['returnedPaise']),
        duePaise = _i(j['duePaise']),
        docDiscountPercent = _dn(j['docDiscountPercent']),
        payments = _l(j['payments']).map(PurchasePaymentDto.fromJson).toList(),
        items = _l(j['items']).map(PurchaseLineDto.fromJson).toList(),
        warnings = (j['warnings'] as List? ?? const [])
            .map((e) => '$e')
            .toList();

  /// Units still returnable on any line.
  bool get canReturn => items.any((l) => l.returnable > 0);
}

class SupplierDueDto {
  final String supplierId, name;
  final int totalPurchasedPaise,
      totalPaidPaise,
      totalDuePaise,
      overduePaise,
      overdueCount;
  SupplierDueDto.fromJson(Map<String, dynamic> j)
      : supplierId = _s(j['supplierId']),
        name = _s(j['name']),
        totalPurchasedPaise = _i(j['totalPurchasedPaise']),
        totalPaidPaise = _i(j['totalPaidPaise']),
        totalDuePaise = _i(j['totalDuePaise']),
        overduePaise = _i(j['overduePaise']),
        overdueCount = _i(j['overdueCount']);
}

class PayablesDto {
  final int totalPurchasedPaise,
      totalReturnedPaise,
      totalPaidPaise,
      totalDuePaise,
      overduePaise,
      overdueCount;
  final List<SupplierDueDto> bySupplier;
  PayablesDto.fromJson(Map<String, dynamic> j)
      : totalPurchasedPaise = _i(j['totalPurchasedPaise']),
        totalReturnedPaise = _i(j['totalReturnedPaise']),
        totalPaidPaise = _i(j['totalPaidPaise']),
        totalDuePaise = _i(j['totalDuePaise']),
        overduePaise = _i(j['overduePaise']),
        overdueCount = _i(j['overdueCount']),
        bySupplier = _l(j['bySupplier']).map(SupplierDueDto.fromJson).toList();
}

class ReturnLineDto {
  final String purchaseItemId, productId, name;
  final int qty, taxablePaise, cgstPaise, sgstPaise, igstPaise, cessPaise,
      totalPaise;
  ReturnLineDto.fromJson(Map<String, dynamic> j)
      : purchaseItemId = _s(j['purchaseItemId']),
        productId = _s(j['productId']),
        name = _s(j['name']),
        qty = _i(j['qty']),
        taxablePaise = _i(j['taxablePaise']),
        cgstPaise = _i(j['cgstPaise']),
        sgstPaise = _i(j['sgstPaise']),
        igstPaise = _i(j['igstPaise']),
        cessPaise = _i(j['cessPaise']),
        totalPaise = _i(j['totalPaise']);
}

class PurchaseReturnDto {
  final String id, purchaseId, supplierId, supplierName, invoiceNo, noteNo,
      reason, createdAt;
  final int taxablePaise, cgstPaise, sgstPaise, igstPaise, cessPaise, totalPaise;
  final List<ReturnLineDto> items;
  PurchaseReturnDto.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        purchaseId = _s(j['purchaseId']),
        supplierId = _s(j['supplierId']),
        supplierName = _s(j['supplierName']),
        invoiceNo = _s(j['invoiceNo']),
        noteNo = _s(j['noteNo']),
        reason = _s(j['reason']),
        createdAt = _s(j['createdAt']),
        taxablePaise = _i(j['taxablePaise']),
        cgstPaise = _i(j['cgstPaise']),
        sgstPaise = _i(j['sgstPaise']),
        igstPaise = _i(j['igstPaise']),
        cessPaise = _i(j['cessPaise']),
        totalPaise = _i(j['totalPaise']),
        items = _l(j['items']).map(ReturnLineDto.fromJson).toList();
}

class StatementRowDto {
  final String date, at, kind, invoiceNo, mode, reference;
  final String? purchaseId;
  final int amountPaise, balancePaise;
  StatementRowDto.fromJson(Map<String, dynamic> j)
      : date = _s(j['date']),
        at = _s(j['at']),
        kind = _s(j['kind']),
        invoiceNo = _s(j['invoiceNo']),
        mode = _s(j['mode']),
        reference = _s(j['reference']),
        purchaseId = _sn(j['purchaseId']),
        amountPaise = _i(j['amountPaise']),
        balancePaise = _i(j['balancePaise']);
}

class StatementDto {
  final String supplierId, supplierName;
  final int openingBalancePaise, closingBalancePaise;
  final PPage<StatementRowDto> rows;
  StatementDto.fromJson(Map<String, dynamic> j)
      : supplierId = _s(j['supplierId']),
        supplierName = _s(j['supplierName']),
        openingBalancePaise = _i(j['openingBalancePaise']),
        closingBalancePaise = _i(j['closingBalancePaise']),
        rows = PPage.from(j['rows'], StatementRowDto.fromJson);
}

class SupplierRefundDto {
  final String id, mode, reference, receivedAt;
  final int amountPaise, creditPaise, balancePaise;
  SupplierRefundDto.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        mode = _s(j['mode']),
        reference = _s(j['reference']),
        receivedAt = _s(j['receivedAt']),
        amountPaise = _i(j['amountPaise']),
        creditPaise = _i(j['creditPaise']),
        balancePaise = _i(j['balancePaise']);
}

class RegisterRowDto {
  final String purchaseId, invoiceNo, invoiceDate, supplierName, gstMode,
      productName;
  final int qty, freeQty, unitCostPaise, discountPaise, taxablePaise,
      gstPercent, cgstPaise, sgstPaise, igstPaise, cessPaise, lineTotalPaise;
  final double landedUnitCostPaise;
  RegisterRowDto.fromJson(Map<String, dynamic> j)
      : purchaseId = _s(j['purchaseId']),
        invoiceNo = _s(j['invoiceNo']),
        invoiceDate = _s(j['invoiceDate']),
        supplierName = _s(j['supplierName']),
        gstMode = _s(j['gstMode']),
        productName = _s(j['productName']),
        qty = _i(j['qty']),
        freeQty = _i(j['freeQty']),
        unitCostPaise = _i(j['unitCostPaise']),
        discountPaise = _i(j['discountPaise']),
        taxablePaise = _i(j['taxablePaise']),
        gstPercent = _i(j['gstPercent']),
        cgstPaise = _i(j['cgstPaise']),
        sgstPaise = _i(j['sgstPaise']),
        igstPaise = _i(j['igstPaise']),
        cessPaise = _i(j['cessPaise']),
        lineTotalPaise = _i(j['lineTotalPaise']),
        landedUnitCostPaise = _d(j['landedUnitCostPaise']);
}

class InputGstLineDto {
  final String gstMode;
  final int gstPercent, taxablePaise, cgstPaise, sgstPaise, igstPaise,
      cessPaise, creditablePaise, nonCreditablePaise;
  InputGstLineDto.fromJson(Map<String, dynamic> j)
      : gstMode = _s(j['gstMode']),
        gstPercent = _i(j['gstPercent']),
        taxablePaise = _i(j['taxablePaise']),
        cgstPaise = _i(j['cgstPaise']),
        sgstPaise = _i(j['sgstPaise']),
        igstPaise = _i(j['igstPaise']),
        cessPaise = _i(j['cessPaise']),
        creditablePaise = _i(j['creditablePaise']),
        nonCreditablePaise = _i(j['nonCreditablePaise']);
}

class InputGstDto {
  final String from, to;
  final List<InputGstLineDto> lines;
  final int taxablePaise, cgstPaise, sgstPaise, igstPaise, cessPaise,
      creditablePaise, nonCreditablePaise;
  InputGstDto.fromJson(Map<String, dynamic> j)
      : from = _s(j['from']),
        to = _s(j['to']),
        lines = _l(j['lines']).map(InputGstLineDto.fromJson).toList(),
        taxablePaise = _i(j['taxablePaise']),
        cgstPaise = _i(j['cgstPaise']),
        sgstPaise = _i(j['sgstPaise']),
        igstPaise = _i(j['igstPaise']),
        cessPaise = _i(j['cessPaise']),
        creditablePaise = _i(j['creditablePaise']),
        nonCreditablePaise = _i(j['nonCreditablePaise']);
}

class DiscountRowDto {
  final String supplierId, supplierName;
  final int purchaseCount, grossPaise, lineDiscountPaise, docDiscountPaise;
  DiscountRowDto.fromJson(Map<String, dynamic> j)
      : supplierId = _s(j['supplierId']),
        supplierName = _s(j['supplierName']),
        purchaseCount = _i(j['purchaseCount']),
        grossPaise = _i(j['grossPaise']),
        lineDiscountPaise = _i(j['lineDiscountPaise']),
        docDiscountPaise = _i(j['docDiscountPaise']);
}

class DiscountsDto {
  final String from, to;
  final int grossPaise, lineDiscountPaise, docDiscountPaise;
  final List<DiscountRowDto> bySupplier;
  DiscountsDto.fromJson(Map<String, dynamic> j)
      : from = _s(j['from']),
        to = _s(j['to']),
        grossPaise = _i(j['grossPaise']),
        lineDiscountPaise = _i(j['lineDiscountPaise']),
        docDiscountPaise = _i(j['docDiscountPaise']),
        bySupplier = _l(j['bySupplier']).map(DiscountRowDto.fromJson).toList();
}

class AgeingRowDto {
  final String supplierId, supplierName;
  final int days0to30Paise, days31to60Paise, days61PlusPaise, creditPaise,
      totalDuePaise;
  AgeingRowDto.fromJson(Map<String, dynamic> j)
      : supplierId = _s(j['supplierId']),
        supplierName = _s(j['supplierName']),
        days0to30Paise = _i(j['days0to30Paise']),
        days31to60Paise = _i(j['days31to60Paise']),
        days61PlusPaise = _i(j['days61PlusPaise']),
        creditPaise = _i(j['creditPaise']),
        totalDuePaise = _i(j['totalDuePaise']);
}

class AgeingDto {
  final String asOf;
  final int days0to30Paise, days31to60Paise, days61PlusPaise, creditPaise,
      totalDuePaise;
  final List<AgeingRowDto> bySupplier;
  AgeingDto.fromJson(Map<String, dynamic> j)
      : asOf = _s(j['asOf']),
        days0to30Paise = _i(j['days0to30Paise']),
        days31to60Paise = _i(j['days31to60Paise']),
        days61PlusPaise = _i(j['days61PlusPaise']),
        creditPaise = _i(j['creditPaise']),
        totalDuePaise = _i(j['totalDuePaise']),
        bySupplier = _l(j['bySupplier']).map(AgeingRowDto.fromJson).toList();
}

class PriceRowDto {
  final String purchaseId, supplierName, invoiceNo, invoiceDate;
  final int qty, freeQty, unitCostPaise;
  final double landedUnitCostPaise, landedUnitCostRoundedPaise;
  final int? mrpPaise, sellingPricePaise;
  PriceRowDto.fromJson(Map<String, dynamic> j)
      : purchaseId = _s(j['purchaseId']),
        supplierName = _s(j['supplierName']),
        invoiceNo = _s(j['invoiceNo']),
        invoiceDate = _s(j['invoiceDate']),
        qty = _i(j['qty']),
        freeQty = _i(j['freeQty']),
        unitCostPaise = _i(j['unitCostPaise']),
        landedUnitCostPaise = _d(j['landedUnitCostPaise']),
        landedUnitCostRoundedPaise = _d(j['landedUnitCostRoundedPaise']),
        mrpPaise = _in(j['mrpPaise']),
        sellingPricePaise = _in(j['sellingPricePaise']);
}

/// Pack data of a product, enough to print `+10 x 500 g`.
///
/// [weighed] is `soldBy == WEIGHT` from `GET /admin/products/{id}/pos`: only
/// then is the stock counted in grams (ml). A pack sold by count (even with
/// unit `kg`, pack `1 kg`) is `10 x 1 kg`.
class PackInfo {
  final String unit, packSize;
  final bool weighed;
  const PackInfo(this.unit, this.packSize, {this.weighed = false});
}
