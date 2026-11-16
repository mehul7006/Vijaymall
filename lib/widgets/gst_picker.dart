import 'dart:async';

import 'package:flutter/material.dart';

import '../data/gst_catalog.dart';
import '../data/validators.dart';
import '../state/gu_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'buttons.dart';
import 'controls.dart';
import 'fields.dart';
import 'panels.dart';

/// Reusable GST block: rate chips + HSN field + a suggestion banner driven by
/// the server's GST master ([GstCatalog]).
///
/// * The suggestion follows [productName] / [category] / [price] (debounced
///   400 ms). [price] is the sale price or MRP in rupees; it picks the band for
///   price-based rules (clothing and footwear up to Rs 2,500).
/// * While the user has not touched the rate or HSN the suggestion is applied
///   automatically ([autoApply]); once they edit, it is only an optional
///   "Apply". The user can always change both freely.
/// * When one product has different rates (packed and labelled / loose) a
///   small choice is shown; other ranked matches are listed as alternatives.
/// * [suggestOnlyIfBlank] is for existing products: stored values are kept
///   and a suggestion shows only when the HSN was blank.
/// * Give the widget a new `key` to reload [initialGst] / [initialHsn].
class GstPicker extends StatefulWidget {
  final String productName;
  final String? category;
  final int initialGst;
  final String initialHsn;
  final bool autoApply;
  final bool suggestOnlyIfBlank;

  /// Sale price or MRP in rupees (optional), for price-band rules.
  final double? price;

  /// Called with the chosen whole-number rate and the trimmed HSN after every
  /// change (including an automatic apply).
  final void Function(int gstPercent, String hsn) onChanged;

  /// Overrides the built-in HSN validation message.
  final String? hsnError;

  const GstPicker({
    super.key,
    required this.productName,
    this.category,
    this.initialGst = 0,
    this.initialHsn = '',
    this.autoApply = true,
    this.suggestOnlyIfBlank = false,
    this.price,
    required this.onChanged,
    this.hsnError,
  });

  /// Same rule the picker shows under the field (null when fine).
  static String? hsnErrorFor(String v) {
    final m = GstCatalog.hsnError(v);
    return m == null ? null : gt(m);
  }

  @override
  State<GstPicker> createState() => _GstPickerState();
}

class _GstPickerState extends State<GstPicker> {
  late int _gst = widget.initialGst;
  late final TextEditingController _hsn =
      TextEditingController(text: widget.initialHsn);
  final TextEditingController _find = TextEditingController();
  Timer? _debounce;
  GstSuggestion? _sug; // best match as found
  GstSuggestion? _cur; // what is currently proposed (choice / alternative)
  bool _touched = false;
  bool _autoApplied = false;
  bool _finding = false;
  List<GstHsnHit> _hits = const [];
  String _hitsFor = '';
  Timer? _findDebounce;
  int _runSeq = 0;
  int _findSeq = 0;
  bool _showHint = false; // server master not available (shown once per session)

  bool get _eligible =>
      !widget.suggestOnlyIfBlank || widget.initialHsn.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    GstCatalog.instance.load().then((_) {
      if (mounted) {
        setState(() {}); // the rate card may have arrived
        _run();
      }
    });
  }

  @override
  void didUpdateWidget(covariant GstPicker old) {
    super.didUpdateWidget(old);
    if (old.productName != widget.productName ||
        old.category != widget.category ||
        old.price != widget.price) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) _run();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _findDebounce?.cancel();
    _hsn.dispose();
    _find.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged(_gst, _hsn.text.trim());

  Future<void> _run() async {
    if (!_eligible) return;
    final seq = ++_runSeq;
    final cat = GstCatalog.instance;
    final s = await cat.suggest(widget.productName,
        category: widget.category, price: widget.price);
    if (!mounted || seq != _runSeq) return;
    if (s == null && cat.unavailable && cat.claimUnavailableHint()) {
      setState(() => _showHint = true);
    }
    if (s == null) {
      // The name no longer matches: undo an earlier automatic fill.
      if (_autoApplied && !_touched) {
        setState(() {
          _sug = null;
          _cur = null;
          _autoApplied = false;
          _gst = widget.initialGst;
          _hsn.text = widget.initialHsn;
        });
        _notify();
      } else if (_sug != null) {
        setState(() {
          _sug = null;
          _cur = null;
        });
      }
      return;
    }
    if (widget.autoApply && !_touched) {
      setState(() {
        _sug = s;
        _cur = s;
        _autoApplied = true;
        _fill(s);
      });
      _notify();
    } else {
      setState(() {
        _sug = s;
        _cur = s;
      });
    }
  }

  void _fill(GstSuggestion s) {
    _hsn.text = s.hsn;
    final r = s.serverRate;
    if (r != null) _gst = r;
  }

  void _apply() {
    final s = _cur;
    if (s == null) return;
    setState(() {
      _fill(s);
      _autoApplied = true;
    });
    _notify();
  }

  bool get _matches {
    final s = _cur;
    if (s == null) return false;
    final r = s.serverRate;
    return _hsn.text.trim() == s.hsn && (r == null || r == _gst);
  }

  void _pickRate(int g) {
    setState(() {
      _gst = g;
      _touched = true;
    });
    _notify();
  }

  /// Packed / loose / price band: switch the proposed rate.
  void _pickChoice(GstChoice c) {
    final s = _cur;
    if (s == null) return;
    final next = s.copyWith(
      ratePercent: c.rate,
      conditionKey: c.key,
      conditionLabel: c.label,
      notification: c.row.notification,
      sourceReference: c.row.sourceReference,
      effectiveFrom: c.row.effectiveFrom,
      verification: c.row.status,
      taxType: c.row.taxType,
    );
    setState(() {
      _cur = next;
      _fill(next);
      _autoApplied = true;
    });
    _notify();
  }

  /// Another ranked match: propose it and apply it (the user asked for it).
  void _pickAlternative(GstSuggestion a) {
    setState(() {
      _cur = a;
      _fill(a);
      _autoApplied = true;
    });
    _notify();
  }

  void _search(String q) {
    _findDebounce?.cancel();
    final t = q.trim();
    if (t.isEmpty) {
      _findSeq++;
      setState(() {
        _hits = const [];
        _hitsFor = '';
      });
      return;
    }
    _findDebounce = Timer(const Duration(milliseconds: 300), () async {
      final seq = ++_findSeq;
      final hits = await GstCatalog.instance.searchHsn(t);
      if (!mounted || seq != _findSeq) return;
      setState(() {
        _hits = hits;
        _hitsFor = t;
      });
    });
  }

  void _pickHit(GstHsnHit h) {
    setState(() {
      _hsn.text = h.hsn;
      final r = h.rate;
      if (r != null &&
          r == r.roundToDouble() &&
          Validators.gstSlabs.contains(r.round())) {
        _gst = r.round();
      }
      _touched = true;
      _finding = false;
      _find.clear();
      _findSeq++;
      _hits = const [];
      _hitsFor = '';
    });
    _notify();
  }

  static const _unavailableText =
      'GST suggestions come from the server and are not available right now. Enter the rate and HSN yourself.';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _date(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (m == null || d == null || m < 1 || m > 12) return iso;
    return '$d ${gt(_months[m - 1])} ${p[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final cat = GstCatalog.instance;
    final rates = cat.selectableRates;
    final accepted = <int>{};
    final refused = <GstRateOption>[];
    for (final r in rates) {
      if (r.serverAccepts) {
        accepted.add(r.percent.round());
      } else {
        refused.add(r);
      }
    }
    // Fallback when the master could not be read: the server's own slabs.
    if (accepted.isEmpty) accepted.addAll(Validators.gstSlabs);
    final chips = accepted.toList()..sort();
    final extra = !chips.contains(_gst);
    final s = _cur;
    final sugRate = s?.ratePercent;
    final changed = s != null &&
        sugRate != null &&
        (_touched || !_autoApplied || !_matches) &&
        sugRate != _gst.toDouble();
    final hsnErr = widget.hsnError ?? GstPicker.hsnErrorFor(_hsn.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s != null) ...[
          _banner(s),
          if (s.choices.length > 1) ...[
            const SizedBox(height: 8),
            _choiceRow(s),
          ],
          if (_sug != null && _sug!.alternatives.isNotEmpty) ...[
            const SizedBox(height: 8),
            _alternatives(_sug!),
          ],
          const SizedBox(height: 12),
        ],
        Text(
          gt('GST rate (included in the price)'),
          style: const TextStyle(
            fontFamily: AppTheme.uiFont,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in chips)
              AppChip('$g%', selected: _gst == g, onTap: () => _pickRate(g)),
            if (extra) AppChip('$_gst%', selected: true),
            for (final r in refused)
              Opacity(
                opacity: .45,
                child: IgnorePointer(child: AppChip(r.label, selected: false)),
              ),
          ],
        ),
        if (changed) ...[
          const SizedBox(height: 6),
          Hint(
            '${gt('changed from the suggested')} '
            '${GstCatalog.fmt(sugRate)}%',
            icon: 'info',
            color: AppColors.goldInk,
          ),
        ],
        if (extra || (cat.loaded && !cat.rateInMaster(_gst.toDouble()))) ...[
          const SizedBox(height: 6),
          Hint(gt('This rate is not in the GST master'),
              color: AppColors.orange),
        ],
        if (refused.isNotEmpty) ...[
          const SizedBox(height: 6),
          Hint(
            '${refused.map((r) => r.label).join(', ')} '
            '${gt('are in the GST master but the server does not accept them yet')}',
          ),
        ],
        const SizedBox(height: 12),
        FieldRow(
          flex: const [2, 3],
          children: [
            AppField(
              label: 'HSN code',
              controller: _hsn,
              placeholder: 'e.g. 0802',
              maxLength: 8,
              keyboardType: TextInputType.number,
              error: hsnErr,
              onChanged: (_) {
                setState(() => _touched = true);
                _notify();
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _finding = !_finding),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    gt(_finding ? 'Close HSN search' : 'Find an HSN code'),
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_finding) ...[
          AppField(
            controller: _find,
            placeholder: 'Search by name or code, e.g. rice or 1006',
            onChanged: _search,
          ),
          const SizedBox(height: 8),
          if (_hits.isEmpty && _find.text.trim().isNotEmpty && cat.unavailable)
            Hint(gt(_unavailableText))
          else if (_hits.isEmpty &&
              _find.text.trim().isNotEmpty &&
              _hitsFor == _find.text.trim())
            Hint(gt('No matching HSN in the GST master')),
          for (final h in _hits) _hitRow(h),
        ],
        if (_showHint) ...[
          const SizedBox(height: 6),
          Hint(gt(_unavailableText)),
        ],
      ],
    );
  }

  Widget _choiceRow(GstSuggestion s) {
    final needsPrice = s.choices.any((c) => c.row.isPriceRow) &&
        (widget.price == null || widget.price! <= 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gt('The rate depends on how it is sold - choose:'),
          style: const TextStyle(
            fontFamily: AppTheme.uiFont,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.ink2,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in s.choices)
              AppChip(
                '${gt(c.label.isEmpty ? c.key : c.label)}'
                '${c.rate == null ? '' : ' - ${GstCatalog.fmt(c.rate!)}%'}',
                selected: s.conditionKey == c.key,
                onTap: () => _pickChoice(c),
              ),
          ],
        ),
        if (needsPrice) ...[
          const SizedBox(height: 6),
          Hint(gt('Enter the price and the band is picked automatically')),
        ],
      ],
    );
  }

  Widget _alternatives(GstSuggestion best) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gt('Other matches'),
          style: const TextStyle(
            fontFamily: AppTheme.uiFont,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.ink2,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChip(
              '${best.matchedName} - ${best.hsn}'
              '${best.ratePercent == null ? '' : ' - ${GstCatalog.fmt(best.ratePercent!)}%'}',
              selected: identical(_cur, best) ||
                  (_cur?.hsn == best.hsn && _cur?.matchedName == best.matchedName),
              onTap: () => _pickAlternative(best),
            ),
            for (final a in best.alternatives)
              AppChip(
                '${a.matchedName} - ${a.hsn}'
                '${a.ratePercent == null ? '' : ' - ${GstCatalog.fmt(a.ratePercent!)}%'}',
                selected: _cur?.hsn == a.hsn && _cur?.matchedName == a.matchedName,
                onTap: () => _pickAlternative(a),
              ),
          ],
        ),
      ],
    );
  }

  Widget _hitRow(GstHsnHit h) {
    final r = h.rate;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pickHit(h),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Text(h.hsn,
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  h.conditionLabel.isEmpty
                      ? h.description
                      : '${h.description} (${gt(h.conditionLabel)})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink2)),
            ),
            const SizedBox(width: 8),
            Text(r == null ? '?' : '${GstCatalog.fmt(r)}%',
                style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy2)),
          ],
        ),
      ),
    );
  }

  Widget _banner(GstSuggestion s) {
    final r = s.ratePercent;
    final unsupported = r != null && s.serverRate == null;
    final applied = _matches && _autoApplied;
    final head = gt('Suggested from the GST master');
    final String body;
    if (r == null) {
      body = '$head: HSN ${s.hsn}. ${gt('The rate depends on the product - choose it below.')}';
    } else if (unsupported) {
      body = '$head: HSN ${s.hsn} - ${GstCatalog.fmt(r)}%. '
          '${gt('The server does not accept this rate yet - choose a rate below.')}';
    } else {
      body = '$head: HSN ${s.hsn} - ${GstCatalog.fmt(r)}%. ${s.description}.';
    }
    final String source;
    if (s.verified) {
      final n = s.notification.isEmpty ? '' : ' ${s.notification}';
      final d = s.effectiveFrom.isEmpty
          ? ''
          : ', ${gt('from')} ${_date(s.effectiveFrom)}';
      source = '${gt('Official rate, notification')}$n$d';
    } else {
      source = gt('Please confirm this rate with your CA');
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: applied ? AppColors.greenTint : AppColors.goldTint,
        borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
        border: Border.all(
            color: (applied ? AppColors.green : AppColors.gold)
                .withValues(alpha: .5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 18, color: applied ? AppColors.green : AppColors.goldInk),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.reason,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  source,
                  style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: s.verified ? AppColors.green : AppColors.orange,
                  ),
                ),
                if (unsupported && r == 40)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      gt('40% applies by law to this item but the server only accepts 0, 3, 5, 12, 18 and 28 for now'),
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                if (applied)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      gt('Applied - you can change it below'),
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!applied) ...[
            const SizedBox(width: 8),
            AppButton('Apply', size: BtnSize.sm, onTap: _apply),
          ],
        ],
      ),
    );
  }
}
