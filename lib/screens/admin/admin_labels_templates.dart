import 'package:flutter/material.dart' hide Stepper;

import '../../data/api/api_exception.dart';
import '../../data/api/label_dto.dart';
import '../../data/label_store.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import 'admin_labels_common.dart';

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

/// Templates tab: built-ins first, "Duplicate" for built-ins, edit/delete for
/// custom ones (ADMIN only; CASHIER can only read).
class LabelTemplatesTab extends StatefulWidget {
  final bool canEdit;
  const LabelTemplatesTab({super.key, required this.canEdit});

  @override
  State<LabelTemplatesTab> createState() => _LabelTemplatesTabState();
}

class _LabelTemplatesTabState extends State<LabelTemplatesTab> {
  final _store = LabelStore.instance;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    _store.load(force: true);
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _delete(LabelTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gt('Delete template?')),
        content: Text(gt(
            'Past print history keeps the template name. This cannot be undone.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(gt('Keep'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(gt('Delete'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyId = t.id);
    try {
      await _store.api.deleteTemplate(t.id);
      showToast('Template deleted');
    } on ApiException catch (e) {
      if (e.statusCode != 404) showToast(e.message, 'error');
    } catch (e) {
      showToast(labelError(e), 'error');
    }
    if (mounted) setState(() => _busyId = null);
    await _store.load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final list = _store.templates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.canEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppButton('New template',
                icon: 'plus',
                block: true,
                onTap: () => go('/admin/labels?tab=templates&new=1')),
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Hint('Only the store admin can create or change templates.'),
          ),
        if (_store.loading && list.isEmpty)
          const SkeletonRows(rows: 3)
        else if (_store.error != null && list.isEmpty)
          EmptyState(
              icon: 'info',
              title: 'Could not load templates',
              copy: _store.error!,
              actionLabel: 'Try again',
              onAction: () => _store.load(force: true))
        else if (list.isEmpty)
          const EmptyState(
              icon: 'box',
              title: 'No templates yet',
              copy: 'Create a label template to start printing.')
        else
          for (final t in list) _row(t),
      ],
    );
  }

  Widget _row(LabelTemplate t) {
    final f = t.fields;
    final shown = <String>[
      if (f.shopName) 'Shop',
      if (f.productName != 'NONE') 'Name ${f.productName}',
      if (f.packSize) 'Pack',
      if (f.mrp) 'MRP',
      if (f.price) 'Price',
      if (f.pricePerUnit) 'Per unit',
      if (f.packedOn) 'Packed',
      if (f.bestBefore) 'Best before',
      if (f.batchNo) 'Batch',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(t.isSheet ? 'grid' : 'ticket',
                    size: 18, color: AppColors.ink2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: labelText(14, FontWeight.w800)),
                ),
                if (t.builtIn) Pill.active(gt('Built-in')),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                '${t.isSheet ? gt('Sheet') : gt('Thermal')} - ${t.sizeText} - ${t.barcodeType}',
                style: labelText(12, FontWeight.w600, AppColors.ink3)),
            const SizedBox(height: 2),
            Text(shown.map(gt).join(' / '),
                style: labelText(12, FontWeight.w600, AppColors.ink3)),
            if (widget.canEdit) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                AppButton('Duplicate',
                    size: BtnSize.sm,
                    variant: BtnVariant.secondary,
                    onTap: () =>
                        go('/admin/labels?tab=templates&dup=${t.id}')),
                if (!t.builtIn) ...[
                  AppButton('Edit',
                      size: BtnSize.sm,
                      variant: BtnVariant.secondary,
                      onTap: () =>
                          go('/admin/labels?tab=templates&edit=${t.id}')),
                  AppButton('Delete',
                      size: BtnSize.sm,
                      variant: BtnVariant.danger,
                      loading: _busyId == t.id,
                      onTap: _busyId != null ? null : () => _delete(t)),
                ],
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create / edit form
// ---------------------------------------------------------------------------

/// Create (`dupOf`/blank) or edit (`editId`) a template. Validates the sizes,
/// grid and field rules of the guide before sending and shows the server's
/// `details.fields` messages (including "needs N mm of height") under inputs.
class LabelTemplateForm extends StatefulWidget {
  final String? editId;
  final String? dupOf;
  const LabelTemplateForm({super.key, this.editId, this.dupOf});

  @override
  State<LabelTemplateForm> createState() => _LabelTemplateFormState();
}

class _LabelTemplateFormState extends State<LabelTemplateForm> {
  final _store = LabelStore.instance;
  bool _ready = false;
  bool _saving = false;
  String? _banner;
  Map<String, String> _fe = {};
  bool _tried = false;

  String _name = '';
  String _kind = 'THERMAL';
  String _w = '50';
  String _h = '25';
  String _cols = '1';
  String _rows = '1';
  String _gapX = '0';
  String _gapY = '0';
  String _marL = '0';
  String _marT = '0';
  String _barcode = 'EAN13';
  LabelFields _f = LabelFields();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _store.load();
    final srcId = widget.editId ?? widget.dupOf;
    final src = _store.byId(srcId);
    if (src != null) {
      _name = widget.dupOf != null ? '${src.name} copy' : src.name;
      if (_name.length > 60) _name = _name.substring(0, 60);
      _kind = src.kind;
      _w = LabelTemplate.mm(src.widthMm);
      _h = LabelTemplate.mm(src.heightMm);
      _cols = '${src.columns}';
      _rows = '${src.rows}';
      _gapX = LabelTemplate.mm(src.gapXMm);
      _gapY = LabelTemplate.mm(src.gapYMm);
      _marL = LabelTemplate.mm(src.marginLeftMm);
      _marT = LabelTemplate.mm(src.marginTopMm);
      _barcode = src.barcodeType;
      _f = src.fields.copy();
    }
    if (mounted) setState(() => _ready = true);
  }

  // ---- validation -----------------------------------------------------------

  double? _num(String s) {
    final t = s.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) return null;
    return double.tryParse(t);
  }

  String? _range(String s, String label, double min, double max) {
    final v = _num(s);
    if (s.trim().isEmpty) return '${gt(label)} ${gt('is required')}';
    if (v == null) return '${gt(label)}: ${gt('enter a number (up to 2 decimals)')}';
    if (v < min || v > max) {
      return '${gt(label)}: ${LabelTemplate.mm(min)} ${gt('to')} ${LabelTemplate.mm(max)}';
    }
    return null;
  }

  String? _int(String s, String label, int min, int max) {
    final t = s.trim();
    final v = int.tryParse(t);
    if (v == null || !RegExp(r'^\d+$').hasMatch(t)) {
      return '${gt(label)}: ${gt('enter a whole number')}';
    }
    if (v < min || v > max) return '${gt(label)}: $min ${gt('to')} $max';
    return null;
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    final n = _name.trim();
    if (n.isEmpty) {
      e['name'] = gt('Name is required');
    } else if (n.length > 60) {
      e['name'] = gt('Name must be 60 characters or fewer');
    }
    final w = _range(_w, 'Width (mm)', 10, 200);
    if (w != null) e['widthMm'] = w;
    final h = _range(_h, 'Height (mm)', 10, 200);
    if (h != null) e['heightMm'] = h;
    if (_kind == 'SHEET') {
      final c = _int(_cols, 'Columns', 1, 10);
      if (c != null) e['columns'] = c;
      final r = _int(_rows, 'Rows', 1, 30);
      if (r != null) e['rows'] = r;
      final gx = _range(_gapX, 'Gap across (mm)', 0, 50);
      if (gx != null) e['gapXMm'] = gx;
      final gy = _range(_gapY, 'Gap down (mm)', 0, 50);
      if (gy != null) e['gapYMm'] = gy;
      final ml = _range(_marL, 'Left margin (mm)', 0, 100);
      if (ml != null) e['marginLeftMm'] = ml;
      final mt = _range(_marT, 'Top margin (mm)', 0, 100);
      if (mt != null) e['marginTopMm'] = mt;
      if (e.isEmpty) {
        final width = _num(_marL)! +
            int.parse(_cols) * _num(_w)! +
            (int.parse(_cols) - 1) * _num(_gapX)!;
        final height = _num(_marT)! +
            int.parse(_rows) * _num(_h)! +
            (int.parse(_rows) - 1) * _num(_gapY)!;
        if (width > 210) e['columns'] = gt('The columns are wider than an A4 page (210 mm)');
        if (height > 297) e['rows'] = gt('The rows are taller than an A4 page (297 mm)');
      }
    }
    if (_f.fontSize < 4 || _f.fontSize > 24) {
      e['fields.fontSize'] = gt('Font size: 4 to 24 points');
    }
    if (_f.pricePerUnit && !_f.price) {
      e['fields.pricePerUnit'] = gt('Price per unit needs the price to be on');
    }
    return e;
  }

  Map<String, dynamic> _body() {
    final sheet = _kind == 'SHEET';
    return {
      'name': _name.trim(),
      'kind': _kind,
      'widthMm': double.parse(_w.trim()),
      'heightMm': double.parse(_h.trim()),
      'columns': sheet ? int.parse(_cols.trim()) : 1,
      'rows': sheet ? int.parse(_rows.trim()) : 1,
      'gapXMm': sheet ? double.parse(_gapX.trim()) : 0,
      'gapYMm': sheet ? double.parse(_gapY.trim()) : 0,
      'marginLeftMm': sheet ? double.parse(_marL.trim()) : 0,
      'marginTopMm': sheet ? double.parse(_marT.trim()) : 0,
      'barcodeType': _barcode,
      'fields': _f.toJson(),
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _tried = true;
      _banner = null;
      _fe = _validate();
    });
    if (_fe.isNotEmpty) return;
    setState(() => _saving = true);
    ApiException.clearFields();
    try {
      final body = _body();
      final t = widget.editId != null
          ? await _store.api.updateTemplate(widget.editId!, body)
          : await _store.api.createTemplate(body);
      await _store.load(force: true);
      showToast(widget.editId != null ? 'Template saved' : 'Template created');
      if (!mounted) return;
      _store.lastTemplateId ??= t.id;
      go('/admin/labels?tab=templates');
    } on ApiException catch (e) {
      if (!mounted) return;
      final fe = Map<String, String>.from(e.fields);
      if (e.code == 'NAME_TAKEN' && !fe.containsKey('name')) {
        fe['name'] = e.message;
      }
      setState(() {
        _saving = false;
        _fe = fe;
        _banner = fe.isEmpty ? e.messageWithRef : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _banner = labelError(e);
      });
    }
  }

  String? _err(String key) => _fe[key];

  /// Server messages for fields this form has no input for are still shown.
  List<String> _otherErrors() {
    const known = {
      'name', 'kind', 'widthMm', 'heightMm', 'columns', 'rows', 'gapXMm',
      'gapYMm', 'marginLeftMm', 'marginTopMm', 'barcodeType',
      'fields.fontSize', 'fields.pricePerUnit', 'fields',
    };
    return [
      for (final e in _fe.entries)
        if (!known.contains(e.key)) '${e.key}: ${e.value}'
    ];
  }

  // ---- UI ---------------------------------------------------------------------

  Widget _num2(String label, String value, String key, ValueChanged<String> on,
          ) =>
      AppField(
        label: label,
        value: value,
        numeric: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        maxLength: 6,
        error: _err(key),
        onChanged: (v) {
          on(v);
          if (_tried) setState(() => _fe = _validate());
        },
      );

  Widget _chips(List<(String, String)> opts, String value,
          ValueChanged<String> on) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in opts)
          AppChip(gt(o.$2), selected: value == o.$1, onTap: () => setState(() {
                on(o.$1);
                if (_tried) _fe = _validate();
              })),
      ]);

  Widget _switch(String label, bool v, ValueChanged<bool> on) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(gt(label), style: labelText(13.5, FontWeight.w700))),
          AppSwitch(
              value: v,
              onChanged: (x) => setState(() {
                    on(x);
                    if (_tried) _fe = _validate();
                  })),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SkeletonRows(rows: 4);
    final other = _otherErrors();
    final sheet = _kind == 'SHEET';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_banner != null || other.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text([if (_banner != null) _banner!, ...other].join('\n'),
                style: labelText(13, FontWeight.w700, AppColors.red)),
          ),
        CardPanel(
          title: gt('Template'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppField(
                label: 'Name',
                value: _name,
                maxLength: 60,
                error: _err('name'),
                onChanged: (v) {
                  _name = v;
                  if (_tried) setState(() => _fe = _validate());
                },
              ),
              const SizedBox(height: 10),
              const LabelCaption('Kind'),
              Segmented(
                options: const [
                  SegmentOption('THERMAL', 'Thermal roll'),
                  SegmentOption('SHEET', 'A4 sheet'),
                ],
                value: _kind,
                onChanged: (v) => setState(() {
                  _kind = v;
                  if (_tried) _fe = _validate();
                }),
              ),
              const SizedBox(height: 4),
              Hint(sheet
                  ? 'Width and height are one label (cell) of the A4 page.'
                  : 'Width and height are the whole label.'),
              const SizedBox(height: 12),
              FieldRow(children: [
                _num2('Width (mm)', _w, 'widthMm', (v) => _w = v),
                _num2('Height (mm)', _h, 'heightMm', (v) => _h = v),
              ]),
              if (sheet) ...[
                const SizedBox(height: 10),
                FieldRow(children: [
                  _num2('Columns (1-10)', _cols, 'columns', (v) => _cols = v),
                  _num2('Rows (1-30)', _rows, 'rows', (v) => _rows = v),
                ]),
                const SizedBox(height: 10),
                FieldRow(children: [
                  _num2('Gap across (mm)', _gapX, 'gapXMm', (v) => _gapX = v),
                  _num2('Gap down (mm)', _gapY, 'gapYMm', (v) => _gapY = v),
                ]),
                const SizedBox(height: 10),
                FieldRow(children: [
                  _num2('Left margin (mm)', _marL, 'marginLeftMm',
                      (v) => _marL = v),
                  _num2('Top margin (mm)', _marT, 'marginTopMm',
                      (v) => _marT = v),
                ]),
              ],
              const SizedBox(height: 12),
              const LabelCaption('Barcode type'),
              _chips(const [
                ('EAN13', 'EAN-13'),
                ('CODE128', 'Code 128'),
                ('QR', 'QR code'),
              ], _barcode, (v) => _barcode = v),
              const SizedBox(height: 4),
              const Hint('A barcode needs about 7 mm of height (QR 10 mm) below the text lines.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('What is printed'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelCaption('Product name'),
              _chips(const [
                ('NONE', 'None'),
                ('EN', 'English'),
                ('GU', 'Gujarati'),
                ('BOTH', 'Both'),
              ], _f.productName, (v) => _f.productName = v),
              const SizedBox(height: 8),
              _switch('Shop name', _f.shopName, (v) => _f.shopName = v),
              _switch('Pack size', _f.packSize, (v) => _f.packSize = v),
              _switch('MRP', _f.mrp, (v) => _f.mrp = v),
              _switch('Price', _f.price, (v) => _f.price = v),
              _switch('Price per unit', _f.pricePerUnit,
                  (v) => _f.pricePerUnit = v),
              if (_err('fields.pricePerUnit') != null)
                Text(_err('fields.pricePerUnit')!,
                    style: labelText(12, FontWeight.w700, AppColors.red)),
              _switch('Packed on', _f.packedOn, (v) => _f.packedOn = v),
              _switch('Best before', _f.bestBefore, (v) => _f.bestBefore = v),
              _switch('Batch number', _f.batchNo, (v) => _f.batchNo = v),
              const SizedBox(height: 8),
              const LabelCaption('Alignment'),
              _chips(const [
                ('LEFT', 'Left'),
                ('CENTER', 'Centre'),
                ('RIGHT', 'Right'),
              ], _f.alignment, (v) => _f.alignment = v),
              const SizedBox(height: 12),
              const LabelCaption('Font size (points, 4 to 24)'),
              Row(children: [
                Stepper(
                  value: _f.fontSize,
                  onDec: _f.fontSize > 4
                      ? () => setState(() {
                            _f.fontSize--;
                            if (_tried) _fe = _validate();
                          })
                      : null,
                  onInc: _f.fontSize < 24
                      ? () => setState(() {
                            _f.fontSize++;
                            if (_tried) _fe = _validate();
                          })
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(gt('The price line is 2 points bigger.'),
                      style: labelText(12, FontWeight.w600, AppColors.ink3)),
                ),
              ]),
              if (_err('fields.fontSize') != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_err('fields.fontSize')!,
                      style: labelText(12, FontWeight.w700, AppColors.red)),
                ),
              if (_err('fields') != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_err('fields')!,
                      style: labelText(13, FontWeight.w700, AppColors.red)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppButton(widget.editId != null ? 'Save template' : 'Create template',
            block: true, loading: _saving, onTap: _saving ? null : _save),
        const SizedBox(height: 8),
        AppButton('Cancel',
            variant: BtnVariant.secondary,
            block: true,
            onTap: () => go('/admin/labels?tab=templates')),
      ],
    );
  }
}
