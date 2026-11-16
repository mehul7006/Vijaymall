import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/models.dart';
import '../../data/validators.dart';
import 'admin_coupon_targets.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import '../../state/gu_strings.dart';

/// `#/admin/coupons` — coupon list, plus the `?new=1` / `?edit=CODE` editor.
class AdminCouponsScreen extends StatelessWidget {
  final bool isNew;
  final String? editCode;

  const AdminCouponsScreen({super.key, this.isNew = false, this.editCode});

  @override
  Widget build(BuildContext context) {
    if (isNew || editCode != null) {
      return _CouponEditor(isNew: isNew, editCode: editCode);
    }

    final state = StateScope.of(context);
    final coupons = state.coupons;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Coupons'),
                  sub: '${state.coupons.where((c) => c.active).length} active · ${state.coupons.length} total',
                  bell: false,
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (coupons.isEmpty)
                        CardPanel(
                          child: EmptyState(
                            icon: 'ticket',
                            title: gt('No coupons yet'),
                            copy: gt('Create a coupon to run an offer for your customers.'),
                            actionLabel: gt('Add coupon'),
                            onAction: () => go('/admin/coupons?new=1'),
                          ),
                        )
                      else ...[
                        KpiGrid([
                          KpiCard(
                            icon: 'ticket',
                            tint: AppColors.green,
                            bg: AppColors.greenTint,
                            label: gt('Active'),
                            value:
                                '${coupons.where((c) => state.couponDateStatus(c) == 'active').length}',
                          ),
                          KpiCard(
                            icon: 'clock',
                            tint: AppColors.goldInk,
                            bg: AppColors.goldTint,
                            label: gt('Scheduled'),
                            value:
                                '${coupons.where((c) => state.couponDateStatus(c) == 'scheduled').length}',
                          ),
                          KpiCard(
                            icon: 'percent',
                            tint: AppColors.navy2,
                            bg: AppColors.navyTint,
                            label: gt('Total uses'),
                            value:
                                '${coupons.fold<int>(0, (a, c) => a + c.uses)}',
                          ),
                        ]),
                        const SizedBox(height: 12),
                        LayoutBuilder(builder: (context, c) {
                          if (c.maxWidth >= 860) {
                            return _couponTable(state, coupons);
                          }
                          return CardPanel(
                            child: Column(
                              children: [
                                for (var i = 0; i < coupons.length; i++)
                                  _couponRow(
                                    state,
                                    coupons[i],
                                    divider: i < coupons.length - 1,
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 12),
                      AppButton(
                        'Add coupon',
                        block: true,
                        onTap: () => go('/admin/coupons?new=1'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const AdminNav(active: 'more'),
          ],
        ),
      ),
    );
  }
}

/// Wide-screen table of coupons with hover rows.
Widget _couponTable(AppState state, List<Coupon> coupons) {
  const label = TextStyle(
      fontFamily: AppTheme.uiFont,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: AppColors.ink2);
  return TableCard(
    header: TableHeadRow(
      [
        TableCol(gt('Code'), 3),
        TableCol(gt('Status'), 2),
        TableCol(gt('Uses'), 2),
        TableCol(gt('Expires'), 2),
      ],
      trailing: 112,
    ),
    rows: [
      for (var i = 0; i < coupons.length; i++)
        TableRowShell(
          last: i == coupons.length - 1,
          onTap: () => go('/admin/coupons?edit=${coupons[i].code}'),
          semanticLabel: 'Edit coupon ${coupons[i].code}',
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coupons[i].code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AppColors.ink)),
                    Text(coupons[i].desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: label.copyWith(
                            fontSize: 11.5, color: AppColors.ink3)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: switch (state.couponDateStatus(coupons[i])) {
                    'active' => Pill.active('Active'),
                    'scheduled' => Pill.low('Scheduled'),
                    'expired' => Pill.out('Expired'),
                    _ => Pill.out('Paused'),
                  },
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coupons[i].maxUses >= 999999 ? '${coupons[i].uses}/∞' : '${coupons[i].uses}/${coupons[i].maxUses}',
                          style: label.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      MeterBar(
                          coupons[i].maxUses > 0
                              ? coupons[i].uses / coupons[i].maxUses
                              : 0,
                          height: 5),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                    coupons[i].expires.isEmpty ? 'No expiry' : coupons[i].expires,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: label),
              ),
              SizedBox(
                width: 112,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppSwitch(
                      value: coupons[i].active,
                      onChanged: (_) => state.toggleCoupon(coupons[i].code),
                    ),
                    const SizedBox(width: 8),
                    IconBtn(
                      'edit',
                      size: 38,
                      iconSize: 16,
                      onTap: () => go('/admin/coupons?edit=${coupons[i].code}'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// `couponRow(c)` — code + status pill, description, uses/expiry, switch, edit.
Widget _couponRow(AppState state, Coupon c, {required bool divider}) {
  final status = state.couponDateStatus(c);
  final Widget pill = switch (status) {
    'active' => Pill.active('Active'),
    'scheduled' => Pill.low('Scheduled'),
    'expired' => Pill.out('Expired'),
    _ => Pill.out('Paused'),
  };
  final expiry = c.expires.isEmpty ? 'No expiry' : 'Expires ${c.expires}';
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: divider ? AppColors.line : Colors.transparent,
        ),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      c.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  pill,
                ],
              ),
              const SizedBox(height: 4),
              Text(
                c.desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink3,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      c.maxUses >= 999999
                          ? '${c.uses} ${gt('uses (unlimited)')}'
                          : '${c.uses}/${c.maxUses} uses',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      expiry,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSwitch(
              value: c.active,
              onChanged: (_) => state.toggleCoupon(c.code),
            ),
            const SizedBox(width: 8),
            IconBtn(
              'edit',
              size: 38,
              iconSize: 16,
              onTap: () => go('/admin/coupons?edit=${c.code}'),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Editor draft holder for `?new=1` / `?edit=CODE`.
class _CouponEditor extends StatefulWidget {
  final bool isNew;
  final String? editCode;

  const _CouponEditor({required this.isNew, required this.editCode});

  @override
  State<_CouponEditor> createState() => _CouponEditorState();
}

/// Multi-select category picker for a coupon's scope.
///
/// Empty selection = the coupon covers **every** category, which is what the
/// backend stores when a coupon has no `coupon_category` rows.
class _ScopePicker extends StatefulWidget {
  final List<Category> categories;
  final List<String> selected;
  final void Function(List<String>) onDone;

  const _ScopePicker({
    required this.categories,
    required this.selected,
    required this.onDone,
  });

  @override
  State<_ScopePicker> createState() => _ScopePickerState();
}

class _ScopePickerState extends State<_ScopePicker> {
  late final Set<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = Set<String>.of(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final all = _picked.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetOption(
          title: gt('All items'),
          sub: gt('Every category'),
          selected: all,
          onTap: () => setState(() => _picked.clear()),
        ),
        for (final c in widget.categories)
          SheetOption(
            title: c.name,
            selected: _picked.contains(c.id),
            onTap: () => setState(() {
              if (!_picked.remove(c.id)) _picked.add(c.id);
            }),
          ),
        const SizedBox(height: 12),
        AppButton(
          all ? 'Use all items' : 'Use ${_picked.length} selected',
          block: true,
          onTap: () => widget.onDone(List<String>.of(_picked)),
        ),
      ],
    );
  }
}

class _CouponEditorState extends State<_CouponEditor> {
  String _code = '';
  String _type = 'flat';
  String _value = '';
  String _min = '';
  String _maxUses = '100';
  String _maxDiscount = '';

  /// Categories this coupon covers — empty = every category (the backend's
  /// meaning for an empty `coupon_category` list).
  List<String> _categoryIds = <String>[];
  String _starts = '';
  String _expires = '';
  bool _active = true;
  bool _worksWithCoins = true;
  bool _firstOrderOnly = false;
  bool _loaded = false;

  /// Item targeting (packs / whole products) with display names.
  final CouponTargets _targets = CouponTargets();
  Map<String, String> _vErr = const {};

  Coupon? _existing(AppState state) {
    final code = widget.editCode;
    if (code == null) return null;
    for (final c in state.coupons) {
      if (c.code == code) return c;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final existing = _existing(StateScope.read(context));
    if (existing != null) {
      _code = existing.code;
      _type = existing.type;
      _value = existing.value.toString();
      _min = existing.min.toString();
      _maxUses = existing.maxUses >= 999999 ? '' : existing.maxUses.toString();
      _maxDiscount = (existing.maxDiscount ?? 0).toString();
      // Prefer the list; fall back to the single legacy scope.
      _categoryIds = List<String>.of(existing.categoryIds);
      if (_categoryIds.isEmpty &&
          existing.scope.isNotEmpty &&
          existing.scope != 'all') {
        _categoryIds = <String>[existing.scope];
      }
      _starts = existing.starts;
      _expires = existing.expires;
      _active = existing.active;
      _worksWithCoins = existing.worksWithCoins;
      _firstOrderOnly = existing.firstOrderOnly;
      for (final id in existing.productIds) {
        _targets.products[id] = existing.itemNames[id] ?? id;
      }
      for (final id in existing.productGroupIds) {
        _targets.groups[id] = existing.itemNames[id] ?? id;
      }
    }
  }

  Coupon _buildDraft(AppState state) {
    final existing = _existing(state);
    return Coupon(
      code: _code.trim().toUpperCase(),
      desc: existing?.desc ?? '',
      type: _type,
      value: num.tryParse(_value.trim()) ?? 0,
      maxDiscount:
          _type == 'percent' ? (num.tryParse(_maxDiscount.trim()) ?? 0) : null,
      min: num.tryParse(_min.trim()) ?? 0,
      scope: _categoryIds.isNotEmpty ? _categoryIds.first : 'all',
      categoryIds: List<String>.of(_categoryIds),
      active: _active,
      starts: _starts.trim(),
      expires: _expires.trim(),
      uses: existing?.uses ?? 0,
      maxUses: int.tryParse(_maxUses.trim()) ?? 0,
      worksWithCoins: _worksWithCoins,
      firstOrderOnly: _firstOrderOnly,
      productIds: _targets.products.keys.toList(),
      productGroupIds: _targets.groups.keys.toList(),
      itemNames: {..._targets.products, ..._targets.groups},
      appliesText: existing?.appliesText ?? '',
    );
  }

  Map<String, String> _fieldErr = const {};

  static final _dayRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Field checks matching Swagger (code 30, value/min/cap up to Rs 10 lakh)
  /// and the guide; shown under each input.
  Map<String, String> _validate() {
    final e = <String, String>{};
    void put(String k, String? m) {
      if (m != null) e[k] = gt(m);
    }

    final code = _code.trim();
    if (code.isEmpty) {
      e['code'] = gt('Enter the coupon code');
    } else if (!RegExp(r'^[A-Za-z0-9]{3,16}$').hasMatch(code)) {
      e['code'] = gt('Use 3 to 16 letters or numbers');
    }
    if (_type == 'percent') {
      put('value', Validators.whole(_value,
          label: 'Percent', required: true, min: 1, max: 100));
    } else {
      put('value', Validators.rupees(_value,
          label: 'Value', required: true, min: 1, max: 1000000));
    }
    put('min', Validators.rupees(_min, label: 'Min order', max: 1000000));
    if (_maxUses.trim().isNotEmpty) {
      put('maxUses', Validators.whole(_maxUses,
          label: 'Max uses', min: 0, max: 100000000));
    }
    if (_type == 'percent') {
      put('maxDiscount',
          Validators.rupees(_maxDiscount, label: 'Max discount', max: 1000000));
    }
    for (final (k, v) in [('starts', _starts), ('expires', _expires)]) {
      final t = v.trim();
      if (t.isEmpty) continue;
      if (!_dayRe.hasMatch(t) || DateTime.tryParse(t) == null) {
        e[k] = gt('Use the date format yyyy-MM-dd');
      }
    }
    if (!e.containsKey('starts') &&
        !e.containsKey('expires') &&
        _starts.trim().isNotEmpty &&
        _expires.trim().isNotEmpty &&
        _expires.trim().compareTo(_starts.trim()) < 0) {
      e['expires'] = gt('The end date must be after the start date');
    }
    return e;
  }

  Future<void> _pickTargets() async {
    final r = await showCouponTargetPicker(context, current: _targets);
    if (r == null || !mounted) return;
    setState(() {
      _targets.products
        ..clear()
        ..addAll(r.products);
      _targets.groups
        ..clear()
        ..addAll(r.groups);
    });
  }

  String get _targetsLabel {
    final n = _targets.products.length + _targets.groups.length;
    if (n == 0) return '';
    final names = [..._targets.groups.values, ..._targets.products.values]
        .where((x) => x.isNotEmpty)
        .take(2)
        .join(', ');
    return n <= 2 ? names : '$names +${n - 2}';
  }

  Future<void> _save() async {
    final state = StateScope.read(context);
    final ve = _validate();
    setState(() => _vErr = ve);
    if (ve.isNotEmpty) {
      showToast(ve.values.first, 'error');
      return;
    }
    final err = state.saveCoupon(_buildDraft(state), existingCode: widget.editCode);
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    final sync = state.couponSync;
    if (state.backendMode && sync != null) {
      final e = await sync;
      if (!mounted) return;
      if (e != null) {
        setState(() => _fieldErr = ApiException.takeFields());
        showToast(e.message, 'error');
        return;
      }
    }
    showToast(gt('Coupon saved'));
    go('/admin/coupons');
  }

  /// Multi-select sheet: one tick per category, "All items" clears the set.
  void _pickScope(AppState state) {
    showAppSheet<void>(
      context: context,
      title: gt('Applies to'),
      builder: (ctx) => _ScopePicker(
        categories: state.pickerCategories,
        selected: List<String>.of(_categoryIds),
        onDone: (ids) {
          Navigator.of(ctx).pop();
          setState(() => _categoryIds = ids);
        },
      ),
    );
  }

  String _scopeLabel(AppState state) => state.scopeLabelOf(_categoryIds);

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: AppTheme.uiFont,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      );

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink2,
            ),
          ),
        ),
        AppSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final percent = _type == 'percent';
    final couponSub =
        widget.isNew ? 'New offer' : 'Edit code ${widget.editCode ?? ''}';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: widget.isNew ? 'Add coupon' : 'Edit coupon',
                  sub: couponSub,
                  bell: false,
                ),
                ScreenScroll(
                  bottom: 32,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardPanel(
                        title: widget.isNew ? 'Add coupon' : 'Edit coupon',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FieldRow(
                              children: [
                                AppField(
                                  label: gt('Code'),
                                  value: _code,
                                  uppercase: true,
                                  readOnly: widget.editCode != null,
                                  placeholder: gt('SUMMER'),
                                  maxLength: 30,
                                  error: _vErr['code'] ??
                                      ApiException.fieldError(_fieldErr, ['code']),
                                  onChanged: (v) => setState(() => _code = v),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Type'),
                                    const SizedBox(height: 7),
                                    Segmented(
                                      options: const [
                                        SegmentOption('flat', 'Flat'),
                                        SegmentOption('percent', 'Percent'),
                                      ],
                                      value: _type,
                                      onChanged: (v) => setState(() => _type = v),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            FieldRow(
                              children: [
                                AppField(
                                  label: _type == 'flat' ? 'Value (₹)' : 'Value (%)',
                                  value: _value,
                                  numeric: true,
                                  placeholder: '0',
                                  error: _vErr['value'] ??
                                      ApiException.fieldError(_fieldErr, ['value']),
                                  onChanged: (v) => setState(() => _value = v),
                                ),
                                AppField(
                                  label: gt('Min order'),
                                  value: _min,
                                  numeric: true,
                                  placeholder: '0',
                                  error: _vErr['min'] ??
                                      ApiException.fieldError(_fieldErr, ['minOrderPaise', 'minOrder']),
                                  onChanged: (v) => setState(() => _min = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            FieldRow(
                              children: [
                                AppField(
                                  label: gt('Max uses'),
                                  value: _maxUses,
                                  numeric: true,
                                  placeholder: gt('Blank = unlimited'),
                                  error: _vErr['maxUses'] ??
                                      ApiException.fieldError(_fieldErr, ['totalLimit', 'maxUses']),
                                  onChanged: (v) => setState(() => _maxUses = v),
                                ),
                                if (percent)
                                  AppField(
                                    label: gt('Max discount'),
                                    value: _maxDiscount,
                                    numeric: true,
                                    placeholder: '0',
                                    error: _vErr['maxDiscount'] ??
                                        ApiException.fieldError(_fieldErr, ['maxDiscountPaise', 'maxDiscount']),
                                    onChanged: (v) =>
                                        setState(() => _maxDiscount = v),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SelectField(
                              label: gt('Applies to'),
                              value: _scopeLabel(state),
                              placeholder: gt('All items'),
                              onTap: () => _pickScope(state),
                            ),
                            const SizedBox(height: 10),
                            SelectField(
                              label: gt('Specific items (optional)'),
                              value: _targetsLabel,
                              placeholder: gt('Any item in the chosen categories'),
                              onTap: _pickTargets,
                            ),
                            const SizedBox(height: 4),
                            Hint(gt(
                                'Pick categories, single packs or whole products. The discount is shared over the covered lines only, and the minimum order counts them only.')),
                            const SizedBox(height: 10),
                            FieldRow(
                              children: [
                                AppField(
                                  label: gt('Starts'),
                                  value: _starts,
                                  placeholder: gt('yyyy-MM-dd'),
                                  error: _vErr['starts'] ??
                                      ApiException.fieldError(_fieldErr, ['startAt', 'starts']),
                                  onChanged: (v) => setState(() => _starts = v),
                                ),
                                AppField(
                                  label: gt('Expires'),
                                  value: _expires,
                                  placeholder: gt('yyyy-MM-dd'),
                                  error: _vErr['expires'] ??
                                      ApiException.fieldError(_fieldErr, ['endAt', 'expires']),
                                  onChanged: (v) => setState(() => _expires = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _switchRow('Active', _active,
                                (v) => setState(() => _active = v)),
                            const SizedBox(height: 10),
                            _switchRow('Works with coins', _worksWithCoins,
                                (v) => setState(() => _worksWithCoins = v)),
                            const SizedBox(height: 10),
                            _switchRow('First order only', _firstOrderOnly,
                                (v) => setState(() => _firstOrderOnly = v)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              'Save coupon',
                              block: true,
                              onTap: _save,
                            ),
                          ),
                          const SizedBox(width: 10),
                          AppButton(
                            'Cancel',
                            variant: BtnVariant.secondary,
                            onTap: () => Nav.instance.pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
