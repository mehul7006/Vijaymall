import 'package:flutter/material.dart';

import '../../data/validators.dart';
import '../../data/api/dto.dart';
import '../../provider/state_scope.dart';
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

/// `#/admin/units` — units of measure the store sells in.
///
/// `GET /units` is public and the product editor picks from it, so this is
/// where a missing unit comes from: saving a product whose `unit` is not an
/// active row here is rejected by the backend with
/// "unknown unit 'X'; add it under units first".
class AdminUnitsScreen extends StatelessWidget {
  const AdminUnitsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _UnitsBody();
}

class _UnitsBody extends StatefulWidget {
  const _UnitsBody();

  @override
  State<_UnitsBody> createState() => _UnitsBodyState();
}

class _UnitsBodyState extends State<_UnitsBody> {
  bool _loaded = false;
  bool _adding = false;
  bool _busy = false;
  final _code = TextEditingController();
  final _nameEn = TextEditingController();
  final _nameGu = TextEditingController();
  String _soldBy = 'UNIT';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    // Public endpoint — reads even for a counter session that got this far.
    StateScope.read(context).refreshUnits();
    StateScope.read(context).refreshAdminUnits();
  }

  @override
  void dispose() {
    _code.dispose();
    _nameEn.dispose();
    _nameGu.dispose();
    super.dispose();
  }

  Map<String, String> _errs = const {};

  Future<void> _add() async {
    if (_busy) return;
    final e = <String, String>{};
    final code = _code.text.trim();
    if (code.isEmpty) {
      e['code'] = gt('Enter the unit code');
    } else if (code.length > 20 || !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(code)) {
      e['code'] = gt('Code: up to 20 letters, digits or . _ -');
    }
    final n1 = Validators.text(_nameEn.text,
        label: 'Name', required: true, max: 60);
    if (n1 != null) e['nameEn'] = gt(n1);
    final n2 = Validators.text(_nameGu.text, label: 'Name', max: 60);
    if (n2 != null) e['nameGu'] = gt(n2);
    setState(() => _errs = e);
    if (e.isNotEmpty) return;
    setState(() => _busy = true);
    final err = await StateScope.read(context).addUnit(
      code: _code.text,
      nameEn: _nameEn.text,
      nameGu: _nameGu.text,
      soldBy: _soldBy,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    _code.clear();
    _nameEn.clear();
    _nameGu.clear();
    setState(() {
      _soldBy = 'UNIT';
      _adding = false;
    });
    showToast(gt('Unit added · it is now available on products'));
  }

  Future<void> _save(UnitDto unit, {String? oldCode}) async {
    final err =
        await StateScope.read(context).saveUnit(unit, oldCode: oldCode);
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    showToast(gt('Unit saved'));
  }

  Future<void> _delete(UnitDto unit) async {
    final err = await StateScope.read(context).removeUnit(unit.code);
    if (err != null) {
      // Backend refuses while a product still uses it — show its reason.
      showToast(err, 'error');
      return;
    }
    showToast(gt('Unit deleted'));
  }

  void _edit(UnitDto unit) {
    final draft = UnitDto(
      code: unit.code,
      nameEn: unit.nameEn,
      nameGu: unit.nameGu,
      soldBy: unit.soldBy,
      sortOrder: unit.sortOrder,
      active: unit.active,
    );
    showAppSheet<void>(
      context: context,
      title: 'Edit ${unit.label}',
      builder: (ctx) => _UnitEditor(
        draft: draft,
        onSave: () {
          Navigator.of(ctx).pop();
          _save(draft, oldCode: unit.code);
        },
        onDelete: () {
          Navigator.of(ctx).pop();
          _delete(draft);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = StateScope.of(context);
    // The admin list (every unit, switched-off ones too); the public list
    // until it has loaded.
    final units = st.adminUnits.isNotEmpty ? st.adminUnits : st.units;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Units'),
                  sub: '${units.length} unit${units.length == 1 ? '' : 's'} · used by products',
                  bell: false,
                  actions: [
                    if (!_adding)
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: IconBtn(
                          'plus',
                          size: 38,
                          iconSize: 17,
                          onTap: () => setState(() => _adding = true),
                        ),
                      ),
                  ],
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (units.isNotEmpty) ...[
                        KpiGrid([
                          KpiCard(
                            icon: 'box',
                            tint: AppColors.navy2,
                            bg: AppColors.navyTint,
                            label: gt('Units'),
                            value: '${units.length}',
                          ),
                          KpiCard(
                            icon: 'check',
                            tint: AppColors.green,
                            bg: AppColors.greenTint,
                            label: gt('Active'),
                            value: '${units.where((u) => u.active).length}',
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      if (_adding) _addCard(),
                      if (_missingPresets(units).isNotEmpty) _presetsCard(units),
                      if (units.isEmpty)
                        AdminLoadingOrElse(
                          fallback: CardPanel(
                            title: gt('Unit list'),
                            child: const Hint(
                                'No units yet. Products need one — add '
                                '"pc", "kg", "ml" and the rest before saving '
                                'an item.'),
                          ),
                        )
                      else
                      CardPanel(
                        title: gt('Unit list'),
                        child: Column(
                                children: [
                                  for (var i = 0; i < units.length; i++)
                                    _unitRow(units[i],
                                        last: i == units.length - 1),
                                ],
                              ),
                      ),
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Hint(
                          'Every product pack stores one of these codes. A '
                          'unit that is switched off stays on old products '
                          'but cannot be picked for new ones.',
                        ),
                      ),
                      const SizedBox(height: 8),
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

  /// Common selling units a shop needs: priced per kg / gram (weight) or per
  /// piece / dozen (count). One tap creates the real backend unit so it shows
  /// up in every product's unit picker.
  static final _presets = <({String code, String en, String gu, String soldBy, String hint})>[
    (code: 'kg', en: 'Kilogram', gu: 'કિલોગ્રામ', soldBy: 'WEIGHT', hint: gt('price per kg')),
    (code: 'g', en: 'Gram', gu: 'ગ્રામ', soldBy: 'WEIGHT', hint: gt('price per gram')),
    (code: 'pc', en: 'Piece', gu: 'નંગ', soldBy: 'UNIT', hint: gt('price per item')),
    (code: 'doz', en: 'Dozen', gu: 'ડઝન', soldBy: 'UNIT', hint: gt('price per dozen')),
    (code: 'ltr', en: 'Litre', gu: 'લિટર', soldBy: 'WEIGHT', hint: gt('price per litre')),
    (code: 'ml', en: 'Millilitre', gu: 'મિલી', soldBy: 'WEIGHT', hint: gt('price per ml')),
  ];

  List<({String code, String en, String gu, String soldBy, String hint})>
      _missingPresets(List<UnitDto> units) {
    final have = units.map((u) => u.code.toLowerCase()).toSet();
    return _presets.where((p) => !have.contains(p.code)).toList();
  }

  Widget _presetsCard(List<UnitDto> units) {
    final missing = _missingPresets(units);
    return CardPanel(
      title: gt('Quick add'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Hint(
            'Tap to add a common unit: kg and gram (priced by weight), '
            'piece (price per item) and dozen.',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in missing)
                AppChip(
                  '${p.en} · ${p.hint}',
                  selected: false,
                  onTap: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          final err =
                              await StateScope.read(context).addUnit(
                            code: p.code,
                            nameEn: p.en,
                            nameGu: p.gu,
                            soldBy: p.soldBy,
                          );
                          if (!mounted) return;
                          setState(() => _busy = false);
                          showToast(err ?? '${p.en} added',
                              err == null ? 'success' : 'error');
                        },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addCard() {
    return CardPanel(
      title: gt('Add unit'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldRow(
            flex: const [2, 3],
            children: [
              AppField(
                label: gt('Code'),
                value: _code.text,
                placeholder: gt('kg'),
                maxLength: 20,
                error: _errs['code'],
                onChanged: (v) => _code.text = v,
              ),
              AppField(
                label: gt('Name (English)'),
                value: _nameEn.text,
                placeholder: gt('Kilogram'),
                maxLength: 60,
                error: _errs['nameEn'],
                onChanged: (v) => _nameEn.text = v,
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppField(
            label: gt('Name (Gujarati)'),
            value: _nameGu.text,
            placeholder: 'કિલોગ્રામ',
            maxLength: 60,
            error: _errs['nameGu'],
            onChanged: (v) => _nameGu.text = v,
          ),
          const SizedBox(height: 14),
          Text(gt('Sold by'),
            style: TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 7),
          Segmented(
            options: const [
              SegmentOption('UNIT', 'Unit'),
              SegmentOption('WEIGHT', 'Weight'),
            ],
            value: _soldBy,
            onChanged: (v) => setState(() => _soldBy = v),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  'Add unit',
                  block: true,
                  loading: _busy,
                  onTap: _busy ? null : _add,
                ),
              ),
              const SizedBox(width: 10),
              AppButton(
                'Cancel',
                variant: BtnVariant.secondary,
                onTap: () => setState(() => _adding = false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unitRow(UnitDto u, {required bool last}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${u.label}  ·  ${u.code}',
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${u.soldBy == 'WEIGHT' ? 'Sold by weight' : 'Sold by count'}'
                  '${u.active ? '' : ' · inactive'}',
                  style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 11.5,
                    color: u.active ? AppColors.ink3 : AppColors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppButton(
            'Edit',
            variant: BtnVariant.secondary,
            onTap: () => _edit(u),
          ),
        ],
      ),
    );
  }
}

/// Sheet editor for one unit: name, Gujarati name, sold-by and active flag.
class _UnitEditor extends StatefulWidget {
  final UnitDto draft;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const _UnitEditor({
    required this.draft,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_UnitEditor> createState() => _UnitEditorState();
}

class _UnitEditorState extends State<_UnitEditor> {
  late final TextEditingController _nameEn;
  late final TextEditingController _nameGu;
  late String _soldBy;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _nameEn = TextEditingController(text: widget.draft.nameEn);
    _nameGu = TextEditingController(text: widget.draft.nameGu);
    _soldBy = widget.draft.soldBy;
    _active = widget.draft.active;
  }

  @override
  void dispose() {
    _nameEn.dispose();
    _nameGu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldRow(
          flex: const [2, 3],
          children: [
            AppField(
              label: gt('Code'),
              value: widget.draft.code,
              maxLength: 20,
              onChanged: (v) => widget.draft.code = v.trim(),
            ),
            AppField(
              label: gt('Name (English)'),
              value: _nameEn.text,
              onChanged: (v) => widget.draft.nameEn = v,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Hint(gt('Changing the code renames the unit on every product that uses it.')),
        const SizedBox(height: 10),
        AppField(
          label: gt('Name (Gujarati)'),
          value: _nameGu.text,
          onChanged: (v) => widget.draft.nameGu = v,
        ),
        const SizedBox(height: 14),
        Text(gt('Sold by'),
          style: TextStyle(
            fontFamily: AppTheme.uiFont,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 7),
        Segmented(
          options: const [
            SegmentOption('UNIT', 'Unit'),
            SegmentOption('WEIGHT', 'Weight'),
          ],
          value: _soldBy,
          onChanged: (v) => setState(() {
            _soldBy = v;
            widget.draft.soldBy = v;
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(gt('Available on new products'),
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink2,
                ),
              ),
            ),
            AppSwitch(
              value: _active,
              onChanged: (v) => setState(() {
                _active = v;
                widget.draft.active = v;
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppButton('Save unit', block: true,
                  onTap: widget.onSave),
            ),
            const SizedBox(width: 10),
            AppButton(
              'Delete',
              variant: BtnVariant.danger,
              onTap: widget.onDelete,
            ),
          ],
        ),
      ],
    );
  }
}
