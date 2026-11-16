import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/lots_api.dart';
import '../../data/api/lots_dto.dart';
import '../../data/lots_store.dart';
import '../../provider/state_scope.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import 'admin_stock_lots_common.dart';

/// "Lots" tab of one variant: the two switches (`lot-settings`) and its lots.
class LotsVariantTab extends StatefulWidget {
  final String? variantId;
  final ValueChanged<String?> onPick;
  final VoidCallback onStockHealth;
  const LotsVariantTab({
    super.key,
    required this.variantId,
    required this.onPick,
    required this.onStockHealth,
  });

  @override
  State<LotsVariantTab> createState() => _LotsVariantTabState();
}

class _LotsVariantTabState extends State<LotsVariantTab> {
  // switches
  bool _lotPriced = false, _trackExpiry = false;
  bool _savedPriced = false, _savedExpiry = false;
  bool _setLoading = false, _setSaving = false;
  String? _setError;
  Map<String, String> _setFields = const {};

  // lots
  final _lots = <LotRow>[];
  LotPageInfo? _info;
  bool _onlyOpen = false;
  bool _loading = false, _more = false;
  String? _error;

  // picker
  String _q = '';

  @override
  void initState() {
    super.initState();
    if (widget.variantId != null) _loadAll();
  }

  @override
  void didUpdateWidget(covariant LotsVariantTab old) {
    super.didUpdateWidget(old);
    if (old.variantId != widget.variantId) {
      _lots.clear();
      _info = null;
      _error = null;
      _setError = null;
      _setFields = const {};
      if (widget.variantId != null) _loadAll();
    }
  }

  void _loadAll() {
    _loadSettings();
    _loadLots();
  }

  Future<void> _loadSettings() async {
    final id = widget.variantId;
    if (id == null) return;
    setState(() {
      _setLoading = true;
      _setError = null;
    });
    try {
      final s = await LotsStore.instance.loadSettings(id);
      if (!mounted || id != widget.variantId) return;
      setState(() {
        _lotPriced = _savedPriced = s.lotPriced;
        _trackExpiry = _savedExpiry = s.trackExpiry;
        _setLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _setLoading = false;
        _setError = lotsError(e);
      });
    }
  }

  Future<void> _saveSettings() async {
    final id = widget.variantId;
    if (id == null || _setSaving) return;
    setState(() {
      _setSaving = true;
      _setError = null;
      _setFields = const {};
    });
    try {
      final s = await LotsStore.instance
          .saveSettings(id, lotPriced: _lotPriced, trackExpiry: _trackExpiry);
      if (!mounted) return;
      setState(() {
        _lotPriced = _savedPriced = s.lotPriced;
        _trackExpiry = _savedExpiry = s.trackExpiry;
        _setSaving = false;
      });
      showToast(gt('Lot settings saved'));
      _loadLots();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _setSaving = false;
        if (e is ApiException) _setFields = e.fields;
        _setError = lotsError(e);
      });
    }
  }

  Future<void> _loadLots({bool more = false}) async {
    final id = widget.variantId;
    if (id == null) return;
    setState(() {
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = more ? ((_info?.page ?? 0) + 1) : 0;
      final r = await LotsApi.instance
          .lots(id, onlyOpen: _onlyOpen, page: page, size: 20);
      if (!mounted || id != widget.variantId) return;
      setState(() {
        if (!more) _lots.clear();
        _lots.addAll(r.items);
        _info = r.info;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _more = false;
        _error = lotsError(e);
      });
    }
  }

  // ---- picker ---------------------------------------------------------------

  Widget _picker() {
    final state = StateScope.of(context);
    final q = _q.trim().toLowerCase();
    final rows = <(String, String, String)>[]; // id, title, sub
    for (final p in state.products) {
      for (final v in p.variants) {
        final id = v.backendId;
        if (id == null) continue;
        if (q.isNotEmpty &&
            !p.name.toLowerCase().contains(q) &&
            !v.label.toLowerCase().contains(q)) {
          continue;
        }
        rows.add((id, p.name, v.label));
      }
    }
    final shown = rows.take(40).toList();
    return CardPanel(
      title: gt('Pick a product pack'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppField(
            value: _q,
            placeholder: gt('Search by product name'),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            EmptyState(
                icon: 'box',
                title: gt('No products found'),
                copy: gt('Try another name.'))
          else
            for (final r in shown)
              InkWell(
                onTap: () => widget.onPick(r.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(r.$2,
                              style: lHead,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Text(r.$3, style: lSub),
                    ],
                  ),
                ),
              ),
          if (rows.length > shown.length)
            LotsNote(gt('Showing the first 40. Type to narrow the list.')),
        ],
      ),
    );
  }

  // ---- switches -------------------------------------------------------------

  Widget _switchRow(String title, String help, bool value,
      ValueChanged<bool> onChanged, String? err) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(gt(title),
              style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          subtitle: Text(gt(help), style: lSub),
          value: value,
          onChanged: _setSaving ? null : onChanged,
        ),
        if (err != null) LotsNote(err, error: true),
      ],
    );
  }

  Widget _settingsCard() {
    final dirty = _lotPriced != _savedPriced || _trackExpiry != _savedExpiry;
    return CardPanel(
      title: gt('Lot settings'),
      child: _setLoading
          ? const SkeletonRows(rows: 2)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _switchRow(
                  'Lot priced',
                  'The selling price and MRP follow the lot that sells next.',
                  _lotPriced,
                  (v) => setState(() => _lotPriced = v),
                  ApiException.fieldError(_setFields, ['lotPriced']),
                ),
                _switchRow(
                  'Track expiry',
                  'Sell the lot with the earliest expiry date first.',
                  _trackExpiry,
                  (v) => setState(() => _trackExpiry = v),
                  ApiException.fieldError(_setFields, ['trackExpiry']),
                ),
                Hint(gt(
                    'A change takes effect at the next stock movement of this variant (a purchase, a sale or a return), not instantly. Give purchase lines a selling price so a lot-priced variant has prices to follow.')),
                if (_setError != null) LotsNote(_setError!, error: true),
                const SizedBox(height: 12),
                AppButton('Save lot settings',
                    block: true,
                    loading: _setSaving,
                    disabled: !dirty,
                    onTap: _saveSettings),
              ],
            ),
    );
  }

  // ---- lots -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final id = widget.variantId;
    if (id == null) return _picker();
    final state = StateScope.of(context);
    final unit = lotUnitFor(state, id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                  unit.productName.isEmpty
                      ? gt('This variant')
                      : '${unit.productName}${unit.pack.isEmpty ? '' : ' · ${unit.pack}'}',
                  style: lHead),
            ),
            AppLink(gt('Change'), onTap: () => widget.onPick(null)),
          ],
        ),
        const SizedBox(height: 10),
        _settingsCard(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
                child: Text(
                    _info == null
                        ? gt('Lots')
                        : '${gt('Lots')} (${_info!.totalText})',
                    style: lHead)),
            AppChip(gt('Hide empty lots'),
                small: true,
                selected: _onlyOpen,
                onTap: () {
                  setState(() => _onlyOpen = !_onlyOpen);
                  _loadLots();
                }),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading && _lots.isEmpty)
          const SkeletonRows(rows: 3)
        else if (_error != null && _lots.isEmpty)
          ErrorRetry(message: _error!, onRetry: _loadLots)
        else if (_lots.isEmpty)
          CardPanel(
            child: EmptyState(
                icon: 'box',
                title: gt('No lots yet'),
                copy: gt('Receive a purchase to create one.')),
          )
        else ...[
          for (final l in _lots)
            LotCard(
              lot: l,
              unit: unit,
              onChanged: () {
                _loadLots();
                _loadSettings();
              },
              onStockHealth: widget.onStockHealth,
            ),
          if (_info?.hasMore == true)
            AppButton('Load more',
                variant: BtnVariant.secondary,
                block: true,
                loading: _more,
                onTap: () => _loadLots(more: true)),
          if (_error != null) LotsNote(_error!, error: true),
        ],
      ],
    );
  }
}
