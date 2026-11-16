import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/pos_dto.dart';
import '../../data/validators.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/fields.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import 'pos_extras.dart' show posTry;

/// What the till keeps about the machine payment of the current bill. The
/// sheet writes into it on every answer, so the till still knows the session
/// (and its reference) when the cashier closes the sheet with a payment open.
class PosMachineHolder {
  PosMachineHolder({required this.reference, required this.channel, required this.mode});

  /// Key of the payment: new for each attempt, kept with the cart, so a
  /// repeated start returns the same session (P3 F6 step 3).
  String reference;
  final PayChannelDto channel;

  /// The mode the cashier chose (CARD or UPI); a manual session has no
  /// `payMethod`, so this decides the bill line mode.
  final String mode;
  TerminalSessionDto? session;

  /// Called on every session answer so the till can keep the open payment in
  /// browser storage and resume it after a page refresh (P3 F6 crash recovery).
  void Function(TerminalSessionDto)? onSession;
}

String _rs(int paise) {
  final p = paise.abs() % 100;
  final r = paise.abs() ~/ 100;
  final txt = r.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d\d)+\d$)'), (m) => '${m[1]},');
  return '${paise < 0 ? '-' : ''}₹$txt${p == 0 ? '' : '.${p.toString().padLeft(2, '0')}'}';
}

/// Opens the card/UPI machine dialog for [amountPaise] on [channel] (online
/// only). Starts the payment (or resumes [holder].session), polls it and lets
/// the cashier confirm (manual machine), cancel or void it. Returns the
/// APPROVED session when the cashier presses "Use this payment"; otherwise
/// null, with the latest session left in [holder].
Future<TerminalSessionDto?> showPosTerminalSheet(
  BuildContext context, {
  required PosMachineHolder holder,
  required int amountPaise,
}) =>
    showAppSheet<TerminalSessionDto>(
      context: context,
      title: holder.channel.isManual
          ? gt('Card / UPI machine (manual)')
          : (holder.channel.name.isEmpty ? gt('Card / UPI machine') : holder.channel.name),
      sub: _rs(amountPaise),
      builder: (_) => _TerminalBody(holder: holder, amountPaise: amountPaise),
    );

class _TerminalBody extends StatefulWidget {
  const _TerminalBody({required this.holder, required this.amountPaise});
  final PosMachineHolder holder;
  final int amountPaise;

  @override
  State<_TerminalBody> createState() => _TerminalBodyState();
}

class _TerminalBodyState extends State<_TerminalBody> {
  final _code = TextEditingController();
  final _rrn = TextEditingController();
  TerminalSessionDto? _s;
  bool _starting = false;
  bool _busy = false;
  bool _offline = false;
  String? _err; // start / action error (plain sentence)
  String? _openPaymentId; // TERMINAL_BUSY
  String? _codeErr;
  String? _rrnErr;
  String? _note; // CANCEL_ON_MACHINE etc.
  Timer? _timer;
  int _fails = 0;
  bool _booted = false;

  PosMachineHolder get _h => widget.holder;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    final existing = _h.session;
    if (existing != null) {
      _s = existing;
      _refresh();
    } else {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _rrn.dispose();
    super.dispose();
  }

  void _set(TerminalSessionDto s) {
    final wasPaid = _s?.paid == true;
    _s = s;
    // Payment just came through: close the sheet and hand it to the POS,
    // which puts it on the bill by itself (no extra tap needed).
    if (s.paid && !wasPaid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(s);
      });
    }
    _h.session = s;
    _h.onSession?.call(s);
    _fails = 0;
    _offline = false;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final s = _s;
    if (s == null || !mounted) return;
    // Poll while open. An EXPIRED Paytm session may still flip to APPROVED
    // (15 minutes), so it is checked on demand ("Check again"), not forever.
    if (!s.open) return;
    final base = s.pollAfterSeconds < 2 ? 2 : s.pollAfterSeconds;
    final wait = _fails == 0 ? base : (base * (1 + _fails)).clamp(base, 20);
    _timer = Timer(Duration(seconds: wait), _refresh);
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _err = null;
      _openPaymentId = null;
    });
    final (s, e) = await posTry((api) => api.startTerminalPayment(
          amountPaise: widget.amountPaise,
          reference: _h.reference,
          moneyAccountId: _h.channel.moneyAccountId,
        ));
    if (!mounted) return;
    if (s != null) {
      setState(() {
        _starting = false;
        _set(s);
      });
      return;
    }
    setState(() {
      _starting = false;
      _err = _startError(e!);
    });
  }

  /// A plain sentence for a failed start, from the error `code`.
  String _startError(ApiException e) {
    switch (e.code) {
      case 'TERMINAL_BUSY':
        _openPaymentId = '${e.details?['openPaymentId'] ?? ''}';
        if (_openPaymentId!.isEmpty) _openPaymentId = null;
        return gt('This machine already has a payment open. Resume it, or use another channel.');
      case 'REFERENCE_REUSED':
        _h.reference = _newRef();
        return gt('That payment reference was used for another amount or machine. Press Try again to use a new one.');
      case 'TERMINAL_REJECTED':
        _h.reference = _newRef();
        return '${e.message} ${gt('Press Try again to start a new payment.')}';
      case 'TERMINAL_NOT_CONFIGURED':
        return gt('This machine is not set up on the server. Close this and take the payment with a typed reference instead, or ask an admin.');
      case 'RATE_LIMITED':
        return gt('Too many card payments in a minute. Wait a little and try again.');
    }
    if (e.fields.isNotEmpty) return e.fields.values.first;
    return e.message;
  }

  String _newRef() => 'VSM${DateTime.now().millisecondsSinceEpoch}';

  Future<void> _resumeOpen() async {
    final id = _openPaymentId;
    if (id == null) return;
    setState(() {
      _err = null;
      _openPaymentId = null;
      _starting = true;
    });
    final (s, e) = await posTry((api) => api.getTerminalPayment(id));
    if (!mounted) return;
    setState(() {
      _starting = false;
      if (s != null) {
        _set(s);
      } else {
        _err = e?.message ?? gt('Could not open that payment.');
      }
    });
  }

  Future<void> _refresh() async {
    final s = _s;
    if (s == null || !mounted) return;
    final (n, e) = await posTry((api) => api.getTerminalPayment(s.id));
    if (!mounted) return;
    if (n != null) {
      setState(() => _set(n));
      return;
    }
    // Keep the id and back off: the server keeps polling the machine.
    setState(() {
      _fails++;
      _offline = e == null || e.statusCode == 0 || e.statusCode >= 500;
      if (!_offline && e != null) _err = e.message;
    });
    _schedule();
  }

  Future<void> _confirm() async {
    final s = _s;
    if (s == null) return;
    final cErr = Validators.text(_code.text,
        label: gt('Approval code'), required: true, max: 40);
    final rErr = Validators.text(_rrn.text, label: 'RRN', max: 40);
    setState(() {
      _codeErr = cErr == null ? null : gt(cErr);
      _rrnErr = rErr == null ? null : gt(rErr);
    });
    if (cErr != null || rErr != null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final (n, e) = await posTry((api) => api.confirmTerminalPayment(s.id,
        approvalCode: _code.text.trim(), rrn: _rrn.text.trim()));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (n != null) {
        _set(n);
      } else {
        _err = switch (e?.code) {
          'TERMINAL_CONFIRMS_ITSELF' =>
            gt('This machine confirms by itself: wait for the result.'),
          'TERMINAL_PAYMENT_CLOSED' =>
            gt('This payment is already cancelled or declined. Start a new one.'),
          _ => e?.fields['approvalCode'] ?? e?.message ?? gt('Could not confirm.'),
        };
      }
    });
  }

  Future<void> _cancel() async {
    final s = _s;
    if (s == null) return;
    setState(() {
      _busy = true;
      _err = null;
      _note = null;
    });
    final (n, e) = await posTry((api) => api.cancelTerminalPayment(s.id));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (n != null) {
        _set(n);
        return;
      }
      switch (e?.code) {
        case 'CANCEL_ON_MACHINE':
          // Paytm has no call that removes a sale already on the machine.
          _note = gt('Press Cancel on the machine. This payment closes by itself once the machine reports it.');
        case 'ALREADY_PAID':
          _note = gt('The customer has already paid. Use this payment, or void it today.');
          _refresh();
        default:
          _err = e?.message ?? gt('Could not cancel.');
      }
    });
    _schedule();
  }

  Future<void> _void() async {
    final s = _s;
    if (s == null) return;
    setState(() {
      _busy = true;
      _err = null;
      _note = null;
    });
    final (n, e) = await posTry((api) => api.voidTerminalPayment(s.id));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (n != null) {
        _set(n);
        showToast(gt('Payment voided'));
        return;
      }
      _err = switch (e?.code) {
        'NOT_VOIDABLE' => gt('This payment cannot be voided here (not paid, or a manual machine). Refund it on the machine.'),
        'PAYMENT_IN_USE' => gt('A bill already uses this payment. Return the bill instead.'),
        'VOID_WINDOW_PASSED' => '${e?.message ?? ''} ${gt('Refund it from the Paytm dashboard instead.')}'.trim(),
        'VOID_UNKNOWN' => gt('The void result is unknown. Check the machine before trying again; this payment cannot go on a bill meanwhile.'),
        _ => e?.message ?? gt('Could not void.'),
      };
    });
  }

  Future<void> _again() async {
    // A finished attempt (declined / cancelled / expired): start a new one
    // with a NEW reference, forgetting the old session.
    _timer?.cancel();
    _h.session = null;
    _h.reference = _newRef();
    setState(() {
      _s = null;
      _err = null;
      _note = null;
    });
    await _start();
  }

  // ---------------------------------------------------------------------------

  TextStyle get _b => const TextStyle(
      fontFamily: AppTheme.uiFont,
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
      color: AppColors.ink);
  TextStyle get _m => const TextStyle(
      fontFamily: AppTheme.uiFont, fontSize: 12.5, color: AppColors.ink2);

  Widget _box(Color bg, List<Widget> kids) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids),
      );

  Widget _kv(String k, String? v) => (v == null || v.isEmpty)
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(k, style: _m)),
            Flexible(child: Text(v, style: _b, textAlign: TextAlign.right)),
          ]),
        );

  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.fromLTRB(
        20, 6, 20, 24 + MediaQuery.of(context).viewInsets.bottom);
    final s = _s;
    return Padding(
      padding: pad,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_starting)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.red)),
              ),
            if (_err != null)
              _box(AppColors.redTint, [
                Text(_err!, style: _m.copyWith(color: AppColors.red)),
                if (_openPaymentId != null) ...[
                  const SizedBox(height: 8),
                  AppButton(gt('Resume the open payment'),
                      size: BtnSize.sm, onTap: _resumeOpen),
                ] else if (s == null && !_starting) ...[
                  const SizedBox(height: 8),
                  AppButton(gt('Try again'), size: BtnSize.sm, onTap: _start),
                ],
              ]),
            if (_offline)
              _box(AppColors.goldTint, [
                Text(
                    gt('Connection lost. Still waiting: this payment is kept and checked again. Do not start another one.'),
                    style: _m),
              ]),
            if (s != null) _session(s),
            const SizedBox(height: 4),
            AppButton(gt('Close'),
                variant: BtnVariant.secondary,
                block: true,
                onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }

  Widget _details(TerminalSessionDto s) => Column(children: [
        _kv(gt('Machine'),
            [s.terminalName, s.terminalId].where((e) => (e ?? '').isNotEmpty).join(' / ')),
        _kv(gt('Paid by'), s.payMethod),
        _kv(gt('Card'),
            [s.cardScheme, s.maskedCard].where((e) => (e ?? '').isNotEmpty).join(' ')),
        _kv(gt('Bank'), s.issuingBank),
        _kv('UPI', s.upiVpa),
        _kv('RRN', s.rrn),
        _kv(gt('Approval code'), s.approvalCode),
        _kv(gt('Reference'), s.reference),
      ]);

  Widget _session(TerminalSessionDto s) {
    final msg = s.message.isNotEmpty ? s.message : (s.instructions ?? '');
    if (s.paid) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _box(AppColors.greenTint, [
          Text('${gt('Payment received')} ${_rs(s.amountPaise)}',
              style: _b.copyWith(fontSize: 16, color: AppColors.green)),
          const SizedBox(height: 6),
          _details(s),
          if (s.posSaleId != null)
            Text(gt('This payment is already on a bill.'),
                style: _m.copyWith(color: AppColors.red)),
        ]),
        if (_note != null) _box(AppColors.goldTint, [Text(_note!, style: _m)]),
        if (s.posSaleId == null)
          AppButton(gt('Use this payment on the bill'),
              block: true,
              onTap: () => Navigator.of(context).pop(s)),
        if (s.canVoid) ...[
          const SizedBox(height: 8),
          AppButton(gt('Void this payment (customer left)'),
              block: true,
              variant: BtnVariant.secondary,
              loading: _busy,
              onTap: _busy ? null : _void),
        ],
        const SizedBox(height: 8),
      ]);
    }
    if (s.open) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _box(AppColors.goldTint, [
          Row(children: [
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.red)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  s.needsManualConfirm
                      ? gt('Charge the customer on the bank machine, then type the approval code below.')
                      : gt('Waiting for the customer to pay on the machine...'),
                  style: _b),
            ),
          ]),
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(msg, style: _m),
          ],
          const SizedBox(height: 6),
          _details(s),
        ]),
        if (_note != null) _box(AppColors.goldTint, [Text(_note!, style: _m)]),
        if (s.needsManualConfirm) ...[
          FieldRow(
            children: [
              AppField(
                label: gt('Approval code'),
                controller: _code,
                maxLength: 40,
                uppercase: true,
                error: _codeErr,
                placeholder: gt('From the machine slip'),
              ),
              AppField(
                label: gt('RRN (optional)'),
                controller: _rrn,
                maxLength: 40,
                error: _rrnErr,
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppButton(gt('Confirm payment taken'),
              block: true, loading: _busy, onTap: _busy ? null : _confirm),
          const SizedBox(height: 8),
        ],
        AppButton(gt('Check now'),
            block: true,
            size: BtnSize.sm,
            variant: BtnVariant.secondary,
            onTap: _refresh),
        if (s.canCancel) ...[
          const SizedBox(height: 8),
          AppButton(gt('Cancel this payment'),
              block: true,
              size: BtnSize.sm,
              variant: BtnVariant.secondary,
              loading: _busy,
              onTap: _busy ? null : _cancel),
        ],
        const SizedBox(height: 8),
      ]);
    }
    // finished without money: DECLINED / CANCELLED / EXPIRED
    final expired = s.state == 'EXPIRED';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _box(AppColors.redTint, [
        Text(
            switch (s.state) {
              'DECLINED' => gt('The payment was declined.'),
              'CANCELLED' => s.providerStatus == 'VOIDED'
                  ? gt('The payment was voided.')
                  : gt('The payment was cancelled.'),
              'EXPIRED' => gt('The payment timed out.'),
              _ => s.state,
            },
            style: _b.copyWith(color: AppColors.red)),
        if (msg.isNotEmpty) ...[const SizedBox(height: 4), Text(msg, style: _m)],
        if (expired) ...[
          const SizedBox(height: 4),
          Text(
              gt('A late payment can still arrive for a while. Check the machine and press Check again before taking money from this customer another way.'),
              style: _m),
        ],
      ]),
      if (_note != null) _box(AppColors.goldTint, [Text(_note!, style: _m)]),
      if (expired)
        AppButton(gt('Check again'),
            block: true, variant: BtnVariant.secondary, onTap: _refresh),
      if (expired) const SizedBox(height: 8),
      AppButton(gt('Try again with a new payment'), block: true, onTap: _again),
      const SizedBox(height: 8),
    ]);
  }
}
