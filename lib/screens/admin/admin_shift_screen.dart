import 'package:flutter/material.dart';

import '../../data/api/dto.dart';
import '../../data/ist.dart';
import '../../data/pos_offline.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/fields.dart';
import '../../widgets/toast.dart';

/// `#/admin/shift` - the cashier's cash drawer, laid out like the "Cashier
/// shift" design sample: a teal bar ("Back to counter", "Cash drawer", who),
/// then one card that is either *Start your shift*, *Close your shift* or
/// *Shift closed*.
///
/// Server-driven: `GET /pos/shifts/current`, `POST /pos/shifts/open|close`
/// (the state methods `posLoadShift`, `posOpenShift`, `posCloseShift`).
class AdminShiftScreen extends StatefulWidget {
  const AdminShiftScreen({super.key});

  @override
  State<AdminShiftScreen> createState() => _AdminShiftScreenState();
}

class _AdminShiftScreenState extends State<AdminShiftScreen> {
  final _float = TextEditingController(text: '0');
  final _counted = TextEditingController();
  final _note = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _needsNote = false;
  ShiftViewDto? _closed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final st = StateScope.read(context);
      await Future.wait([st.posLoadShift(), st.posLoadDayReport()]);
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _float.dispose();
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  static int? _paise(String raw) {
    final v = double.tryParse(raw.trim());
    if (v == null || v < 0) return null;
    return (v * 100).round();
  }

  Future<void> _open() async {
    final p = _paise(_float.text);
    if (p == null) {
      showToast(gt('Enter the opening float (0 or more)'), 'error');
      return;
    }
    setState(() => _busy = true);
    final err = await StateScope.read(context).posOpenShift(p);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _counted.clear();
      _note.clear();
      _needsNote = false;
    });
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    showToast(gt('Shift opened'));
  }

  Future<void> _close(ShiftViewDto s) async {
    final p = _paise(_counted.text);
    if (p == null) {
      showToast(gt('Enter the cash counted in the drawer'), 'error');
      return;
    }
    setState(() => _busy = true);
    // Offline bills must reach the server BEFORE the drawer is closed, or
    // their cash is missing from this shift's expected cash (guide 30).
    final off = PosOffline.instance;
    if (off.waiting > 0) {
      await off.sync();
      if (!mounted) return;
      if (off.waiting > 0) {
        setState(() => _busy = false);
        showToast(
            '${off.waiting} ${gt('offline bills are still waiting to be sent. Send them first (till, Offline button), then close the shift.')}',
            'error');
        return;
      }
    }
    final (closed, err, code) = await StateScope.read(context)
        .posCloseShift(p, note: _note.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _closed = closed;
      if (code == 'VARIANCE_NEEDS_NOTE') _needsNote = true;
    });
    if (err != null) showToast(err, 'error');
  }

  void _toCounter() => go('/admin/pos');

  @override
  Widget build(BuildContext context) {
    final st = StateScope.of(context);
    final shift = st.posShift;
    final closed = _closed;
    final Widget card;
    if (_loading) {
      card = const _Card(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator(color: AppColors.red)),
        ),
      );
    } else if (closed != null) {
      card = _doneCard(closed);
    } else if (shift == null) {
      card = _startCard();
    } else {
      card = _closeCard(st, shift);
    }

    final who = st.userName.trim().isEmpty ? gt('Cashier') : st.userName.trim();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            AdminHead(
              title: gt('Cash drawer'),
              sub: who,
              bell: false,
              onBack: _toCounter,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: AppButton(
                    gt('Back to counter'),
                    size: BtnSize.sm,
                    variant: BtnVariant.gold,
                    onTap: _toCounter,
                  ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 56),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: card,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Start your shift ----------------------------------------------------

  Widget _startCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(gt('Start your shift'), style: _h1),
          const SizedBox(height: 6),
          Text(
            gt('Count the cash in the drawer and enter it. Billing opens once your shift starts.'),
            style: _muted,
          ),
          const SizedBox(height: 20),
          AppField(
            label: gt('Cash in the drawer now (₹)'),
            controller: _float,
            numeric: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 64,
            child: AppButton(
              gt('Start shift'),
              block: true,
              size: BtnSize.lg,
              loading: _busy,
              disabled: _paise(_float.text) == null,
              onTap: _busy ? null : _open,
            ),
          ),
        ],
      ),
    );
  }

  // --- Close your shift ----------------------------------------------------

  Widget _closeCard(AppState st, ShiftViewDto s) {
    final opened = parseIst(s.openedAt);
    final now = istNow();
    String since = '';
    if (opened != null) {
      final mins = now.difference(opened).inMinutes.clamp(0, 100000);
      since = '${gt('Open since')} ${_clock(opened)} · '
          '${mins ~/ 60} hr ${mins % 60} min';
    }
    final counted = _paise(_counted.text);
    final has = _counted.text.trim().isNotEmpty && counted != null;
    final diff = has ? counted - s.expectedCashPaise : 0;
    final needNote = has && diff != 0;
    final moved = s.expectedCashPaise - s.openingFloatPaise;
    final day = st.posDayReport;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(gt('Close your shift'), style: _h1),
              if (since.isNotEmpty) Text(since, style: _muted),
            ],
          ),
          const SizedBox(height: 20),
          _Kv(gt('Cash you started with'), _rs(s.openingFloatPaise)),
          _Kv(
            gt('Cash taken and given back since then'),
            '${moved < 0 ? '− ' : '+ '}${_rs(moved.abs())}',
          ),
          const Divider(height: 28, color: AppColors.line),
          _Kv(gt('Cash that should be in the drawer'), _rs(s.expectedCashPaise),
              big: true),
          if (day != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.navyTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 24,
                runSpacing: 10,
                children: [
                  _Stat('UPI', _rs(day.paidByMode['UPI'] ?? 0)),
                  _Stat(gt('Card'), _rs(day.paidByMode['CARD'] ?? 0)),
                  _Stat(gt('Sold on credit'), _rs(day.creditGivenPaise)),
                  _Stat(gt('Bills today'), '${day.bills}'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          AppField(
            label: gt('Cash you counted (₹)'),
            controller: _counted,
            numeric: true,
            placeholder: gt('Count the drawer, then type here'),
            onChanged: (_) => setState(() {}),
          ),
          if (has) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: diff == 0 ? AppColors.greenTint : AppColors.redTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _diffText(diff),
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: diff == 0 ? AppColors.green : AppColors.red3,
                ),
              ),
            ),
          ],
          if (needNote || _needsNote) ...[
            const SizedBox(height: 14),
            AppField(
              label: gt('Tell the owner why it does not match'),
              controller: _note,
              maxLength: 200,
              placeholder: gt('e.g. gave ₹100 extra change on a ₹500 note'),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 64,
            child: AppButton(
              gt('Close shift'),
              block: true,
              size: BtnSize.lg,
              loading: _busy,
              disabled:
                  !has || ((needNote || _needsNote) && _note.text.trim().isEmpty),
              onTap: _busy ? null : () => _close(s),
            ),
          ),
        ],
      ),
    );
  }

  // --- Shift closed ----------------------------------------------------------

  Widget _doneCard(ShiftViewDto c) {
    final diff = c.variancePaise ?? ((c.countedCashPaise ?? 0) - c.expectedCashPaise);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(gt('Shift closed'), style: _h1),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: diff == 0 ? AppColors.greenTint : AppColors.redTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _diffText(diff),
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: diff == 0 ? AppColors.green : AppColors.red3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Kv(gt('Expected'), _rs(c.expectedCashPaise)),
          _Kv(gt('Counted'), _rs(c.countedCashPaise ?? 0)),
          const SizedBox(height: 12),
          Text(
            gt('The owner can see this under Counter desk → Shifts.'),
            style: _muted,
          ),
          const SizedBox(height: 16),
          AppButton(
            gt('Start a new shift'),
            block: true,
            onTap: () {
              setState(() {
                _closed = null;
                _needsNote = false;
                _counted.clear();
                _note.clear();
              });
            },
          ),
          const SizedBox(height: 10),
          AppButton(
            gt('Back to counter'),
            block: true,
            variant: BtnVariant.secondary,
            onTap: _toCounter,
          ),
        ],
      ),
    );
  }

  // --- helpers ---------------------------------------------------------------

  static String _diffText(int diff) {
    if (diff == 0) return gt('Cash matches. Nothing to explain.');
    return diff < 0
        ? '${gt('Drawer is')} ${_rs(diff.abs())} ${gt('short')}'
        : '${gt('Drawer is')} ${_rs(diff.abs())} ${gt('over')}';
  }

  static String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'am' : 'pm'}';
  }

  /// Rupees with two decimals, Indian grouping (₹14,590.00).
  static String _rs(int paise) {
    final a = paise.abs();
    final r = money(a ~/ 100);
    return '$r.${(a % 100).toString().padLeft(2, '0')}';
  }
}

const _h1 = TextStyle(
  fontFamily: AppTheme.uiFont,
  fontSize: 22,
  height: 1.2,
  fontWeight: FontWeight.w800,
  color: AppColors.ink,
);

const _muted = TextStyle(
  fontFamily: AppTheme.uiFont,
  fontSize: 14,
  height: 1.4,
  color: AppColors.ink2,
);

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.sh1,
      ),
      child: child,
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.k, this.v, {this.big = false});

  final String k;
  final String v;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppTheme.uiFont,
      fontSize: big ? 20 : 15,
      fontWeight: big ? FontWeight.w800 : FontWeight.w600,
      color: big ? AppColors.ink : AppColors.ink2,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(k, style: style)),
          const SizedBox(width: 12),
          Text(
            v,
            style: style.copyWith(
              color: AppColors.ink,
              fontWeight: big ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 13,
                color: AppColors.ink2)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink)),
      ],
    );
  }
}
