/// New till DTOs (guide 74 lots, P3 F5/F6/F9): lot notice, payment channels,
/// card/UPI machine session, credit picker rows and the return preview.
/// Kept apart from `dto.dart` so the older POS classes stay untouched.
library;

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
String? _s(dynamic v) => v?.toString();

/// `LotInfo.nextPriceChange`: after [afterQty] more units the price becomes
/// [newPricePaise] (guide 74 section 3).
class NextPriceChangeDto {
  final int afterQty;
  final int newPricePaise;
  final int newMrpPaise;
  const NextPriceChangeDto(this.afterQty, this.newPricePaise, this.newMrpPaise);

  factory NextPriceChangeDto.fromJson(Map<String, dynamic> j) =>
      NextPriceChangeDto(_i(j['afterQty']), _i(j['newPricePaise']), _i(j['newMrpPaise']));
}

/// The lot the next unit comes from (`Scan.lot`, `PosProduct.lot`).
class LotInfoDto {
  final String? lotId;
  final int qtyLeftInLot;
  final String? batchNo;
  final String? expiryDate;
  final NextPriceChangeDto? nextPriceChange;
  const LotInfoDto(
      {this.lotId,
      this.qtyLeftInLot = 0,
      this.batchNo,
      this.expiryDate,
      this.nextPriceChange});

  factory LotInfoDto.fromJson(Map<String, dynamic> j) => LotInfoDto(
        lotId: _s(j['lotId']),
        qtyLeftInLot: _i(j['qtyLeftInLot']),
        batchNo: _s(j['batchNo']),
        expiryDate: _s(j['expiryDate']),
        nextPriceChange: j['nextPriceChange'] is Map
            ? NextPriceChangeDto.fromJson(
                Map<String, dynamic>.from(j['nextPriceChange'] as Map))
            : null,
      );
}

/// `GET /pos/payment-channels` row: one way of taking a CASH / UPI / CARD
/// amount (a Paytm machine, a manual bank machine, a QR account ...).
class PayChannelDto {
  final String mode;
  final String? moneyAccountId;
  final String provider;
  final String name;
  final String? terminalId;
  final String? kind;
  final bool isDefault;
  const PayChannelDto({
    required this.mode,
    this.moneyAccountId,
    this.provider = '',
    this.name = '',
    this.terminalId,
    this.kind,
    this.isDefault = false,
  });

  factory PayChannelDto.fromJson(Map<String, dynamic> j) => PayChannelDto(
        mode: (_s(j['mode']) ?? '').toUpperCase(),
        moneyAccountId: _s(j['moneyAccountId']),
        provider: _s(j['provider']) ?? '',
        name: _s(j['name']) ?? '',
        terminalId: _s(j['terminalId']),
        kind: _s(j['kind']),
        isDefault: j['default'] as bool? ?? false,
      );

  /// A channel that talks to a machine (`CARD_TERMINAL`), as opposed to a
  /// plain account the cashier confirms by typing a reference.
  bool get isMachine => (kind ?? '') == 'CARD_TERMINAL';
  bool get isManual => provider.toLowerCase() == 'manual';

  String get label {
    final n = name.trim().isEmpty ? provider : name.trim();
    return terminalId == null || terminalId!.isEmpty ? n : '$n ($terminalId)';
  }
}

/// `TerminalPaymentRow`: a card/UPI machine payment session (`/pos/terminal/payments`).
class TerminalSessionDto {
  final String id;
  final String reference;
  final String provider;
  final int amountPaise;
  final String state; // PENDING APPROVED DECLINED CANCELLED EXPIRED
  final String providerStatus;
  final String? mode;
  final bool open;
  final String? instructions;
  final String message;
  final String? qrPayload;
  final String? moneyAccountId;
  final String? terminalId;
  final String? terminalName;
  final String? payMethod;
  final String? cardScheme;
  final String? maskedCard;
  final String? rrn;
  final String? approvalCode;
  final String? issuingBank;
  final String? upiVpa;
  final bool canCancel;
  final bool cancelOnMachine;
  final bool canVoid;
  final int pollAfterSeconds;
  final String? posSaleId;

  const TerminalSessionDto({
    required this.id,
    this.reference = '',
    this.provider = '',
    this.amountPaise = 0,
    this.state = 'PENDING',
    this.providerStatus = '',
    this.mode,
    this.open = true,
    this.instructions,
    this.message = '',
    this.qrPayload,
    this.moneyAccountId,
    this.terminalId,
    this.terminalName,
    this.payMethod,
    this.cardScheme,
    this.maskedCard,
    this.rrn,
    this.approvalCode,
    this.issuingBank,
    this.upiVpa,
    this.canCancel = false,
    this.cancelOnMachine = false,
    this.canVoid = false,
    this.pollAfterSeconds = 3,
    this.posSaleId,
  });

  factory TerminalSessionDto.fromJson(Map<String, dynamic> j) =>
      TerminalSessionDto(
        id: _s(j['id']) ?? '',
        reference: _s(j['reference']) ?? '',
        provider: _s(j['provider']) ?? '',
        amountPaise: _i(j['amountPaise']),
        state: (_s(j['state']) ?? 'PENDING').toUpperCase(),
        providerStatus: _s(j['providerStatus']) ?? '',
        mode: _s(j['mode']),
        open: j['open'] as bool? ?? false,
        instructions: _s(j['instructions']),
        message: _s(j['message']) ?? '',
        qrPayload: _s(j['qrPayload']),
        moneyAccountId: _s(j['moneyAccountId']),
        terminalId: _s(j['terminalId']),
        terminalName: _s(j['terminalName']),
        payMethod: _s(j['payMethod']),
        cardScheme: _s(j['cardScheme']),
        maskedCard: _s(j['maskedCard']),
        rrn: _s(j['rrn']),
        approvalCode: _s(j['approvalCode']),
        issuingBank: _s(j['issuingBank']),
        upiVpa: _s(j['upiVpa']),
        canCancel: j['canCancel'] as bool? ?? false,
        cancelOnMachine: j['cancelOnMachine'] as bool? ?? false,
        canVoid: j['canVoid'] as bool? ?? false,
        pollAfterSeconds: _i(j['pollAfterSeconds']) <= 0 ? 3 : _i(j['pollAfterSeconds']),
        posSaleId: _s(j['posSaleId']),
      );

  bool get paid => state == 'APPROVED';
  bool get needsManualConfirm => provider.toLowerCase() == 'manual' && open;

  /// The bill line mode: UPI when the machine says UPI, CARD when it says
  /// anything else, and the cashier's own choice for a manual session.
  String billMode(String chosen) {
    final pm = (payMethod ?? '').toUpperCase();
    if (pm.isEmpty) return chosen;
    return pm.contains('UPI') ? 'UPI' : 'CARD';
  }
}

/// `GET /pos/credit/customers` row. Only a masked mobile: the cashier still
/// types the full number (P3 F5).
class CreditPickDto {
  final String? customerId;
  final String name;
  final String maskedMobile;
  final int limitPaise;
  final int balancePaise;
  final int availablePaise;
  final bool blocked;
  const CreditPickDto({
    this.customerId,
    this.name = '',
    this.maskedMobile = '',
    this.limitPaise = 0,
    this.balancePaise = 0,
    this.availablePaise = 0,
    this.blocked = false,
  });

  factory CreditPickDto.fromJson(Map<String, dynamic> j) => CreditPickDto(
        customerId: _s(j['customerId']),
        name: _s(j['name']) ?? '',
        maskedMobile: _s(j['maskedMobile']) ?? '',
        limitPaise: _i(j['limitPaise']),
        balancePaise: _i(j['balancePaise']),
        availablePaise: _i(j['availablePaise']),
        blocked: j['blocked'] as bool? ?? false,
      );

  /// Whether a typed full [mobile] fits the mask (`98XXXXXX10`): same length,
  /// same visible digits.
  bool matches(String mobile) {
    final m = maskedMobile.trim();
    if (m.isEmpty || m.length != mobile.length) return m.isEmpty;
    for (var i = 0; i < m.length; i++) {
      final c = m[i];
      if (c == 'X' || c == 'x' || c == '*') continue;
      if (c != mobile[i]) return false;
    }
    return true;
  }
}

class ReturnPreviewLineDto {
  final String? saleItemId;
  final String name;
  final int qty;
  final int grossPaise;
  final int couponSharePaise;
  final int otherSharePaise;
  final int clawbackPaise;
  final int refundPaise;
  final int taxablePaise;
  final int cgstPaise;
  final int sgstPaise;
  const ReturnPreviewLineDto({
    this.saleItemId,
    this.name = '',
    this.qty = 0,
    this.grossPaise = 0,
    this.couponSharePaise = 0,
    this.otherSharePaise = 0,
    this.clawbackPaise = 0,
    this.refundPaise = 0,
    this.taxablePaise = 0,
    this.cgstPaise = 0,
    this.sgstPaise = 0,
  });

  factory ReturnPreviewLineDto.fromJson(Map<String, dynamic> j) =>
      ReturnPreviewLineDto(
        saleItemId: _s(j['saleItemId']),
        name: _s(j['name']) ?? '',
        qty: _i(j['qty']),
        grossPaise: _i(j['grossPaise']),
        couponSharePaise: _i(j['couponSharePaise']),
        otherSharePaise: _i(j['otherSharePaise']),
        clawbackPaise: _i(j['clawbackPaise']),
        refundPaise: _i(j['refundPaise']),
        taxablePaise: _i(j['taxablePaise']),
        cgstPaise: _i(j['cgstPaise']),
        sgstPaise: _i(j['sgstPaise']),
      );
}

/// `POST /pos/sales/{id}/returns/preview`: what the refund will be, before
/// it is confirmed.
class ReturnPreviewDto {
  final String? invoiceNo;
  final String couponPolicy;
  final int refundPaise;
  final int couponShareRemovedPaise;
  final int otherShareRemovedPaise;
  final int couponClawbackPaise;
  final int taxablePaise;
  final int cgstPaise;
  final int sgstPaise;
  final List<ReturnPreviewLineDto> lines;
  const ReturnPreviewDto({
    this.invoiceNo,
    this.couponPolicy = '',
    this.refundPaise = 0,
    this.couponShareRemovedPaise = 0,
    this.otherShareRemovedPaise = 0,
    this.couponClawbackPaise = 0,
    this.taxablePaise = 0,
    this.cgstPaise = 0,
    this.sgstPaise = 0,
    this.lines = const [],
  });

  factory ReturnPreviewDto.fromJson(Map<String, dynamic> j) => ReturnPreviewDto(
        invoiceNo: _s(j['invoiceNo']),
        couponPolicy: _s(j['couponPolicy']) ?? '',
        refundPaise: _i(j['refundPaise']),
        couponShareRemovedPaise: _i(j['couponShareRemovedPaise']),
        otherShareRemovedPaise: _i(j['otherShareRemovedPaise']),
        couponClawbackPaise: _i(j['couponClawbackPaise']),
        taxablePaise: _i(j['taxablePaise']),
        cgstPaise: _i(j['cgstPaise']),
        sgstPaise: _i(j['sgstPaise']),
        lines: (j['lines'] as List? ?? [])
            .whereType<Map>()
            .map((e) => ReturnPreviewLineDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// One GST slab row: [gross] (GST included) split into taxable + CGST + SGST.
class GstSlabRow {
  final int percent;
  int grossPaise = 0;
  int taxablePaise = 0;
  int cgstPaise = 0;
  int sgstPaise = 0;
  GstSlabRow(this.percent);
}

/// One bill/sale line as the GST table needs it. [taxable]/[cgst]/[sgst] are
/// the server's own figures for a recorded sale line; leave them null for a
/// quote line (the quote carries only the rate and the net amount).
class GstLine {
  final int percent;
  final int net;
  final int? taxable;
  final int? cgst;
  final int? sgst;
  const GstLine(this.percent, this.net, {this.taxable, this.cgst, this.sgst});
}

/// Groups lines by GST slab. Recorded sale lines are summed exactly. For a
/// quote the split is an ESTIMATE using the server's own rule (taxable =
/// round(net*100/(100+g)), CGST = floor(tax/2), SGST = rest) and must be
/// labelled as such.
List<GstSlabRow> gstSlabs(Iterable<GstLine> lines) {
  final by = <int, GstSlabRow>{};
  for (final l in lines) {
    final r = by.putIfAbsent(l.percent, () => GstSlabRow(l.percent));
    r.grossPaise += l.net;
    if (l.taxable != null) {
      r.taxablePaise += l.taxable!;
      r.cgstPaise += l.cgst ?? 0;
      r.sgstPaise += l.sgst ?? 0;
    } else {
      final t = (l.net * 100 / (100 + l.percent)).round();
      final tax = l.net - t;
      r.taxablePaise += t;
      r.cgstPaise += tax ~/ 2;
      r.sgstPaise += tax - tax ~/ 2;
    }
  }
  final rows = by.values.toList()..sort((a, b) => a.percent.compareTo(b.percent));
  return rows;
}
