import 'package:flutter/material.dart';

import '../data/api/api_exception.dart';
import '../data/api/bank_dto.dart';
import '../data/bank_store.dart';
import '../screens/admin/admin_bank_common.dart';
import '../state/gu_strings.dart';
import '../theme/app_colors.dart';
import 'panels.dart';

/// Read-only "how was this paid" block for ADMIN screens.
///
/// * `PayerDetail.order(orderId)` -> `GET /admin/payments/by-order/{orderId}`
///   (one card per online payment attempt; hidden when there are none, e.g.
///   cash on delivery).
/// * `PayerDetail.sale(saleId)` -> `GET /admin/payments/by-sale/{saleId}`
///   (one card per payment line of a counter bill).
///
/// Fee, GST, net, UTR and settlement date are null until the provider or a
/// statement import reports them: shown as "Pending", never 0. Card numbers
/// are masked by the server; nothing is rebuilt here. Shows nothing for a
/// non-admin (403) and a small retry line on other errors.
class PayerDetail extends StatefulWidget {
  final String? orderId;
  final String? saleId;

  const PayerDetail.order(String this.orderId, {super.key}) : saleId = null;
  const PayerDetail.sale(String this.saleId, {super.key}) : orderId = null;

  @override
  State<PayerDetail> createState() => _PayerDetailState();
}

class _PayerDetailState extends State<PayerDetail> {
  List<OrderPayerRow> _orders = const [];
  List<SalePayerRow> _sales = const [];
  bool _loading = true;
  bool _hidden = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PayerDetail old) {
    super.didUpdateWidget(old);
    if (old.orderId != widget.orderId || old.saleId != widget.saleId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BankStore.instance.api;
      if (widget.orderId != null) {
        final r = await api.payersByOrder(widget.orderId!);
        if (!mounted) return;
        setState(() {
          _orders = r;
          _loading = false;
        });
      } else {
        final r = await api.payersBySale(widget.saleId!);
        if (!mounted) return;
        setState(() {
          _sales = r;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.isForbidden || e.isUnauthorized) {
          _hidden = true;
        } else {
          _error = bankError(e);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = bankError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return GestureDetector(
        onTap: _load,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('${gt('Payment detail could not load')}: $_error. ${gt('Tap to retry')}',
              style: bankStyle(12, FontWeight.w700, AppColors.red)),
        ),
      );
    }
    final isOrder = widget.orderId != null;
    final cards = isOrder
        ? [for (final r in _orders) _orderCard(r)]
        : [for (final r in _sales) _saleCard(r)];
    if (cards.isEmpty) return const SizedBox.shrink();
    return CardPanel(
      title: gt(isOrder ? 'How it was paid' : 'Payment detail'),
      child: Column(children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const Divider(color: AppColors.line, height: 20),
          cards[i],
        ],
      ]),
    );
  }

  Widget _kv(String k, String? v, {bool strong = false}) {
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return BankKv(k, v, strong: strong);
  }

  Widget _orderCard(OrderPayerRow r) {
    final instrument = [
      if (r.instrument != null) r.instrument!,
      if (r.cardNetwork != null) r.cardNetwork!,
      if (r.cardLast4 != null) '**** ${r.cardLast4}',
    ].join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Text('${r.provider} · ${r.status}',
                  style: bankStyle(13.5, FontWeight.w800, AppColors.ink))),
          Text(bankMoney(r.amountPaise),
              style: bankStyle(14, FontWeight.w800, AppColors.ink)),
        ]),
        const SizedBox(height: 4),
        _kv('Method', instrument),
        _kv('UPI id', r.upiVpa),
        _kv('Bank', r.bank),
        _kv('Account', r.accountName),
        _kv('Provider ref', r.providerRef),
        _kv('Captured', r.capturedAt == null ? null : bankWhen(r.capturedAt)),
        BankKv('Fee', bankMoneyOrPending(r.feePaise)),
        BankKv('GST on fee', bankMoneyOrPending(r.taxPaise)),
        BankKv('Net', bankMoneyOrPending(r.netPaise), strong: true),
        BankKv('Settlement', r.settlementRef ?? gt('Pending')),
        BankKv('UTR', r.utr ?? gt('Pending')),
        BankKv('Settled', r.settledAt == null ? gt('Pending') : bankWhen(r.settledAt)),
      ],
    );
  }

  Widget _saleCard(SalePayerRow r) {
    final card = [
      if (r.cardScheme != null) r.cardScheme!,
      if (r.cardLast4 != null) '**** ${r.cardLast4}',
    ].join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Text('${r.mode} · ${r.provider}',
                  style: bankStyle(13.5, FontWeight.w800, AppColors.ink))),
          Text(bankMoney(r.amountPaise),
              style: bankStyle(14, FontWeight.w800, AppColors.ink)),
        ]),
        const SizedBox(height: 4),
        _kv('Account', r.accountName ?? gt('Unassigned')),
        _kv('Terminal', r.terminalId),
        _kv('Method', r.payMethod),
        _kv('Card', card),
        _kv('Issuing bank', r.issuingBank),
        _kv('UPI id', r.upiVpa),
        _kv('Reference (RRN)', r.reference),
        _kv('Approval code', r.authCode),
        // Cash has no provider fee or payout to wait for: no "Pending" rows.
        if (r.mode.toUpperCase() != 'CASH') ...[
          BankKv('Fee', bankMoneyOrPending(r.feePaise)),
          BankKv('GST on fee', bankMoneyOrPending(r.taxPaise)),
          BankKv('Net', bankMoneyOrPending(r.netPaise), strong: true),
          BankKv('Settlement', r.settlementRef ?? gt('Pending')),
          BankKv('UTR', r.utr ?? gt('Pending')),
          BankKv('Settled',
              r.settledAt == null ? gt('Pending') : bankWhen(r.settledAt)),
        ],
      ],
    );
  }
}
