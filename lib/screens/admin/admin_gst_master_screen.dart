import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/gst_catalog.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';

/// `#/admin/gst-master` - read-only review of the GST and HSN master
/// (`GET /gst/hsn`) for the owner and the CA.
class AdminGstMasterScreen extends StatefulWidget {
  const AdminGstMasterScreen({super.key});

  @override
  State<AdminGstMasterScreen> createState() => _AdminGstMasterScreenState();
}

class _AdminGstMasterScreenState extends State<AdminGstMasterScreen> {
  static const _page = 50;

  final TextEditingController _q = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _rate = ''; // '' = all, else a percent text, 'other'
  String _status = ''; // '', 'V', 'P'
  bool _loading = true;
  bool _loadingMore = false;
  bool _unavailable = false;
  int _seq = 0;
  int _next = 0;
  int _total = 0;
  bool _exact = true;
  bool _hasMore = false;
  List<GstHsnRow> _items = const [];

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _fetch({required bool reset}) async {
    final seq = ++_seq;
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    final p = await GstCatalog.instance.hsnPage(
      q: _query,
      verification: _status == 'V'
          ? 'VERIFIED'
          : (_status == 'P' ? 'VERIFY_PRODUCT' : null),
      page: reset ? 0 : _next,
      size: _page,
    );
    if (!mounted || seq != _seq) return;
    setState(() {
      _loading = false;
      _loadingMore = false;
      if (p == null) {
        _unavailable = true;
        _items = const [];
        _hasMore = false;
        return;
      }
      _unavailable = false;
      _items = reset ? p.items : [..._items, ...p.items];
      _next = p.page + 1;
      _total = p.total;
      _exact = p.totalExact;
      _hasMore = p.hasMore;
    });
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _query = v.trim();
      _fetch(reset: true);
    });
  }

  /// The rate chips filter the rows already loaded (the server has no rate
  /// filter).
  List<GstHsnRow> _filtered() {
    if (_rate.isEmpty) return _items;
    return _items.where((r) {
      final p = r.rate;
      if (_rate == 'other') {
        return p == null || ![0, 5, 18, 40].contains(p);
      }
      return p != null && GstCatalog.fmt(p) == _rate;
    }).toList();
  }

  String _count(int n) {
    final s = '$n';
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _loading ? const <GstHsnRow>[] : _filtered();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            AdminHead(
              title: gt('GST and HSN master'),
              sub: gt('Read-only list for the owner and the CA'),
              bell: false,
            ),
            ScreenScroll(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: _loading
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Hint(gt('Loading GST master...')),
                        )
                      : _unavailable
                          ? EmptyState(
                              icon: 'info',
                              title: gt('The GST master is not set up on the server yet'),
                              copy: gt(
                                  'The server does not offer the GST and HSN master yet, so there is nothing to review here. You can still enter the GST rate and HSN code by hand on products and purchases.'),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CardPanel(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AppField(
                                        controller: _q,
                                        placeholder: gt('Search HSN, product or condition'),
                                        onChanged: _onQuery,
                                      ),
                                      const SizedBox(height: 10),
                                      _chips(
                                        [
                                          ('', gt('All rates')),
                                          ('0', '0%'),
                                          ('5', '5%'),
                                          ('18', '18%'),
                                          ('40', '40%'),
                                          ('other', gt('Other')),
                                        ],
                                        _rate,
                                        (v) => setState(() => _rate = v),
                                      ),
                                      const SizedBox(height: 8),
                                      _chips(
                                        [
                                          ('', gt('All')),
                                          ('V', gt('Verified')),
                                          ('P', gt('Please verify')),
                                        ],
                                        _status,
                                        (v) {
                                          setState(() => _status = v);
                                          _fetch(reset: true);
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      Hint(
                                        '${rows.length} / ${_count(_total)}${_exact ? '' : '+'} ${gt('rows')}',
                                      ),
                                      const SizedBox(height: 4),
                                      Hint(gt(
                                          'Rates shown are IGST. On a bill they split equally into CGST and SGST.')),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (rows.isEmpty)
                                  EmptyState(
                                    icon: 'search',
                                    title: gt('No matching rows'),
                                    copy: gt(
                                        'Try another word, an HSN number or a different filter.'),
                                  )
                                else ...[
                                  for (final r in rows) _row(r),
                                  if (_hasMore)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: AppButton(
                                        gt('Show more'),
                                        variant: BtnVariant.secondary,
                                        onTap: _loadingMore
                                            ? null
                                            : () => _fetch(reset: false),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips(List<(String, String)> items, String value, void Function(String) onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (k, label) in items)
          AppChip(label, selected: value == k, small: true, onTap: () => onPick(k)),
      ],
    );
  }

  String _date(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}-${p[1]}-${p[0]}';
  }

  Widget _row(GstHsnRow r) {
    final rate = r.rate;
    final accepted =
        r.acceptedForBilling ?? GstCatalog.instance.rateAccepted(rate);
    final cond = r.conditionLabel.isNotEmpty ? r.conditionLabel : r.conditions;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.goldTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(r.hsn, style: _t(13, AppColors.ink, 800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(r.description, style: _t(13, AppColors.ink, 700)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(rate == null ? '?' : '${GstCatalog.fmt(rate)}%',
                      style: _t(18, AppColors.navy2, 800)),
                  if (rate != null && !accepted)
                    Text(gt('Not accepted by the server yet'),
                        textAlign: TextAlign.right,
                        style: _t(10, AppColors.orange, 700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (cond.isNotEmpty) _kv(gt('Condition'), gt(cond)),
          _kv(gt('Source'), _source(r)),
          Row(
            children: [
              Expanded(child: _kv(gt('Effective from'), _date(r.effectiveFrom))),
              Text(
                r.verified ? gt('Verified') : gt('Please verify'),
                style: _t(11.5, r.verified ? AppColors.green : AppColors.orange, 800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _source(GstHsnRow r) {
    if (r.notification.isEmpty) return r.sourceReference;
    return r.schedule.isEmpty ? r.notification : '${r.notification}, ${r.schedule}';
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$k: ', style: _t(11.5, AppColors.ink3, 700)),
            TextSpan(text: v, style: _t(11.5, AppColors.ink2, 600)),
          ]),
        ),
      );

  TextStyle _t(double size, Color c, int w) => TextStyle(
        fontFamily: AppTheme.uiFont,
        fontSize: size,
        height: 1.35,
        fontWeight: w >= 800 ? FontWeight.w800 : (w >= 700 ? FontWeight.w700 : FontWeight.w600),
        color: c,
      );
}
