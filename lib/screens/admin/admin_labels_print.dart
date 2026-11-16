import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../data/api/api_exception.dart';
import '../../data/api/label_dto.dart';
import '../../data/label_store.dart';
import '../../data/purchase_file_view.dart';
import '../../data/validators.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import 'admin_labels_common.dart';

/// A pack that can be printed: the backend variant id, its display name and
/// the stock for "one per unit in stock".
class _Pick {
  final String id;
  final String name;
  final String pack;
  final int stock;
  const _Pick(this.id, this.name, this.pack, this.stock);
  String get full => pack.isEmpty ? name : '$name $pack';
}

/// Print tab: template, packs and copies, sheet start cell, optional dates and
/// batch, output mode, then the result (PDF in a new tab, printer commands to
/// copy, JSON preview).
class LabelPrintTab extends StatefulWidget {
  /// Variant (backend id) to start with, from the inventory shortcut.
  final String? variantId;
  const LabelPrintTab({super.key, this.variantId});

  @override
  State<LabelPrintTab> createState() => _LabelPrintTabState();
}

class _LabelPrintTabState extends State<LabelPrintTab> {
  final _store = LabelStore.instance;
  final List<LabelPrintItem> _items = [];
  final Map<String, String> _copyText = {};
  String? _templateId;
  String _mode = 'PDF';
  String _search = '';
  int _start = 1;
  DateTime? _packedOn;
  DateTime? _bestBefore;
  String _batch = '';
  bool _busy = false;
  bool _tried = false;
  String? _banner;
  Map<String, String> _fe = {};
  LabelPrintResult? _result;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _mode = _store.lastMode;
    _store.addListener(_changed);
    _store.load().then((_) => _pickDefaultTemplate());
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _pickDefaultTemplate() {
    if (!mounted || _store.templates.isEmpty) return;
    final last = _store.byId(_templateId ?? _store.lastTemplateId);
    _templateId = (last ?? _store.templates.first).id;
    _fixMode();
    setState(() {});
  }

  LabelTemplate? get _tpl => _store.byId(_templateId);

  void _fixMode() {
    final t = _tpl;
    if (t != null && t.isSheet && _mode != 'PDF' && _mode != 'JSON') {
      _mode = 'PDF';
    }
  }

  List<_Pick> _allPicks(BuildContext context) {
    final out = <_Pick>[];
    for (final p in StateScope.read(context).products) {
      for (final v in p.variants) {
        final id = v.backendId;
        if (id == null) continue;
        out.add(_Pick(id, p.name, p.variants.length > 1 ? v.label : v.label,
            v.stock));
      }
    }
    return out;
  }

  void _seed(BuildContext context) {
    if (_seeded) return;
    _seeded = true;
    final id = widget.variantId;
    if (id == null || id.isEmpty) return;
    for (final p in _allPicks(context)) {
      if (p.id == id) {
        _add(p);
        return;
      }
    }
  }

  void _add(_Pick p) {
    if (_items.any((i) => i.variantId == p.id)) return;
    _items.add(LabelPrintItem(p.id, p.full, stock: p.stock));
    _copyText[p.id] = '1';
    _result = null;
  }

  // ---- validation -----------------------------------------------------------

  int _copiesOf(LabelPrintItem i) {
    if (i.fromStock) return i.stock > 500 ? 500 : i.stock;
    return int.tryParse(_copyText[i.variantId] ?? '') ?? 0;
  }

  String? _copyError(LabelPrintItem i) {
    if (i.fromStock) {
      return i.stock <= 0 ? gt('Stock is 0, nothing to print') : null;
    }
    return Validators.whole(_copyText[i.variantId],
        label: 'Copies', required: true, min: 1, max: 500);
  }

  int get _total => _items.fold(0, (s, i) => s + _copiesOf(i));

  String? _datesError() {
    final p = _packedOn, b = _bestBefore;
    if (p != null && b != null && b.isBefore(p)) {
      return gt('Best before cannot be before packed on');
    }
    return null;
  }

  String? _formError() {
    if (_tpl == null) return gt('Pick a template');
    if (_items.isEmpty) return gt('Add at least one product');
    if (_items.length > 200) return gt('At most 200 products per print');
    for (final i in _items) {
      if (_copyError(i) != null) return gt('Fix the copies marked in red');
    }
    if (_total > 2000) {
      return gt('At most 2000 labels per print. Now: ') + '$_total';
    }
    if (_datesError() != null) return _datesError();
    final t = _tpl!;
    if (t.isSheet && (_start < 1 || _start > t.perPage)) {
      return gt('Start cell must be inside the sheet');
    }
    return null;
  }

  // ---- print ------------------------------------------------------------------

  Future<void> _print() async {
    if (_busy) return;
    setState(() {
      _tried = true;
      _banner = null;
      _fe = {};
      _result = null;
    });
    final err = _formError();
    if (err != null) {
      setState(() => _banner = err);
      return;
    }
    final t = _tpl!;
    final f = t.fields;
    _store.lastTemplateId = t.id;
    _store.lastMode = _mode;
    final body = <String, dynamic>{
      'templateId': t.id,
      'mode': _mode,
      if (t.isSheet) 'startPosition': _start,
      if (_packedOn != null && f.packedOn) 'packedOn': labelDate(_packedOn!),
      if (_bestBefore != null && f.bestBefore)
        'bestBefore': labelDate(_bestBefore!),
      if (_batch.trim().isNotEmpty && f.batchNo) 'batchNo': _batch.trim(),
      'items': [
        for (final i in _items)
          {
            'variantId': i.variantId,
            'copies': i.fromStock ? 'fromStock' : _copiesOf(i),
          }
      ],
    };
    setState(() => _busy = true);
    try {
      final r = await _store.api.print(body);
      if (!mounted) return;
      setState(() {
        _result = r;
        _busy = false;
      });
      if (_mode == 'PDF') _openPdf(r);
    } on ApiException catch (e) {
      if (!mounted) return;
      var msg = e.messageWithRef;
      final m = e.message;
      if (m.contains('Gujarati')) {
        msg = '$m\n${gt('Use PDF or "Draw in app (JSON)" for Gujarati names.')}';
      }
      setState(() {
        _busy = false;
        _fe = e.fields;
        _banner = e.fields.isEmpty || m.contains('Gujarati') ? msg : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = labelError(e);
      });
    }
  }

  void _openPdf(LabelPrintResult r) {
    if (!openBytesInTab(r.bytes, 'application/pdf')) {
      showToast('Could not open the PDF in a new tab', 'error');
    }
  }

  Future<void> _pickDate(bool packed) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (packed ? _packedOn : _bestBefore) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 6),
    );
    if (d == null) return;
    setState(() {
      if (packed) {
        _packedOn = d;
      } else {
        _bestBefore = d;
      }
    });
  }

  // ---- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _seed(context);
    final t = _tpl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _templateCard(),
        const SizedBox(height: 12),
        _itemsCard(context),
        if (t != null && t.isSheet) ...[
          const SizedBox(height: 12),
          _sheetCard(t),
        ],
        if (t != null &&
            (t.fields.packedOn || t.fields.bestBefore || t.fields.batchNo)) ...[
          const SizedBox(height: 12),
          _extrasCard(t),
        ],
        const SizedBox(height: 12),
        _outputCard(t),
        const SizedBox(height: 14),
        if (_banner != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_banner!,
                style: labelText(13, FontWeight.w700, AppColors.red)),
          ),
        if (_fe['templateId'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_fe['templateId']!,
                style: labelText(13, FontWeight.w700, AppColors.red)),
          ),
        if (_fe['items'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_fe['items']!,
                style: labelText(13, FontWeight.w700, AppColors.red)),
          ),
        AppButton(
            _total > 0
                ? '${gt('Print')} $_total ${gt('labels')}'
                : 'Print labels',
            block: true,
            loading: _busy,
            onTap: _busy ? null : _print),
        if (_result != null) ...[
          const SizedBox(height: 14),
          _resultCard(_result!),
        ],
      ],
    );
  }

  Widget _templateCard() {
    final list = _store.templates;
    return CardPanel(
      title: gt('Template'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_store.loading && list.isEmpty)
            const SkeletonRows(rows: 2)
          else if (_store.error != null && list.isEmpty)
            Row(children: [
              Expanded(
                  child: Text(_store.error!,
                      style: labelText(13, FontWeight.w700, AppColors.red))),
              AppButton('Try again',
                  size: BtnSize.sm,
                  variant: BtnVariant.secondary,
                  onTap: () => _store.load(force: true).then((_) => _pickDefaultTemplate())),
            ])
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in list)
                AppChip('${t.name}  (${t.sizeText.split(' cell').first})',
                    selected: t.id == _templateId, onTap: () {
                  setState(() {
                    _templateId = t.id;
                    _start = 1;
                    _result = null;
                    _fixMode();
                  });
                }),
            ]),
          if (_fe['templateId'] == null && _tpl != null) ...[
            const SizedBox(height: 8),
            Text(
                '${_tpl!.isSheet ? gt('A4 sheet') : gt('Thermal roll')} - ${_tpl!.barcodeType}',
                style: labelText(12, FontWeight.w600, AppColors.ink3)),
          ],
        ],
      ),
    );
  }

  Widget _itemsCard(BuildContext context) {
    final q = _search.trim().toLowerCase();
    final picks = q.length < 2
        ? const <_Pick>[]
        : _allPicks(context)
            .where((p) =>
                p.full.toLowerCase().contains(q) &&
                !_items.any((i) => i.variantId == p.id))
            .take(8)
            .toList();
    return CardPanel(
      title: gt('Products and copies'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppField(
            label: 'Find a product',
            value: _search,
            placeholder: 'Type 2 or more letters',
            onChanged: (v) => setState(() => _search = v),
          ),
          if (q.length >= 2 && picks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(gt('No matching product'),
                  style: labelText(12.5, FontWeight.w600, AppColors.ink3)),
            ),
          for (final p in picks)
            InkWell(
              onTap: () => setState(() {
                _add(p);
                _search = '';
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  Expanded(
                      child: Text(p.full,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: labelText(13.5, FontWeight.w700))),
                  Text('${p.stock} ${gt('in stock')}',
                      style: labelText(12, FontWeight.w600, AppColors.ink3)),
                  const SizedBox(width: 8),
                  Text(gt('Add'),
                      style: labelText(13, FontWeight.w800, AppColors.red)),
                ]),
              ),
            ),
          if (_items.isNotEmpty) const SizedBox(height: 10),
          for (var n = 0; n < _items.length; n++) _itemRow(n),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Hint('Search and add each pack you want labels for (up to 200).'),
            ),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${gt('Total labels')}: $_total / 2000',
                  style: labelText(12.5, FontWeight.w800,
                      _total > 2000 ? AppColors.red : AppColors.ink2)),
            ),
        ],
      ),
    );
  }

  Widget _itemRow(int n) {
    final i = _items[n];
    final err = _tried ? _copyError(i) : null;
    final serverErr =
        _fe['items[$n].copies'] ?? _fe['items[$n].variantId'] ?? _fe['items[$n]'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(i.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: labelText(13.5, FontWeight.w800))),
            IconButton(
              tooltip: gt('Remove'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: AppColors.ink3),
              onPressed: () => setState(() {
                _items.removeAt(n);
                _copyText.remove(i.variantId);
                _result = null;
              }),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 110,
                child: AppField(
                  key: ValueKey('copies-${i.variantId}'),
                  label: 'Copies',
                  value: i.fromStock ? '${_copiesOf(i)}' : (_copyText[i.variantId] ?? ''),
                  readOnly: i.fromStock,
                  numeric: true,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  error: err,
                  onChanged: (v) => setState(() {
                    _copyText[i.variantId] = v;
                    _result = null;
                  }),
                ),
              ),
              if (i.stock > 0)
                AppChip(
                    '${gt('One per unit in stock')} (${i.stock})',
                    small: true,
                    selected: i.fromStock,
                    onTap: () => setState(() {
                          i.fromStock = !i.fromStock;
                          _result = null;
                        })),
            ],
          ),
          if (i.fromStock && i.stock > 500)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(gt('Stock is above 500: capped at 500 labels'),
                  style: labelText(12, FontWeight.w700, AppColors.goldInk)),
            ),
          if (serverErr != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(serverErr,
                  style: labelText(12, FontWeight.w700, AppColors.red)),
            ),
          // 72 s2 step 4: "Printed before" for this pack (reprints visible).
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AppLink(gt('Printed before'),
                size: 12,
                onTap: () => go('/admin/labels?tab=history&variant=${i.variantId}')),
          ),
        ],
      ),
    );
  }

  Widget _sheetCard(LabelTemplate t) {
    return CardPanel(
      title: gt('First free cell on the sheet'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Hint('Tap the first unused label cell of a partly used sheet (top left is 1, counted row by row).'),
          const SizedBox(height: 10),
          for (var r = 0; r < t.rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                for (var c = 0; c < t.columns; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _cell(r * t.columns + c + 1),
                    ),
                  ),
              ]),
            ),
          if (_fe['startPosition'] != null)
            Text(_fe['startPosition']!,
                style: labelText(12, FontWeight.w700, AppColors.red)),
          Text('${gt('Starts at cell')} $_start / ${t.perPage}',
              style: labelText(12.5, FontWeight.w800, AppColors.ink2)),
        ],
      ),
    );
  }

  Widget _cell(int n) {
    final used = n < _start;
    final sel = n == _start;
    return GestureDetector(
      onTap: () => setState(() => _start = n),
      child: Container(
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel
              ? AppColors.redTint
              : used
                  ? AppColors.line
                  : AppColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: sel ? AppColors.red : AppColors.line),
        ),
        child: Text('$n',
            style: labelText(11, FontWeight.w800,
                sel ? AppColors.red : AppColors.ink3)),
      ),
    );
  }

  Widget _extrasCard(LabelTemplate t) {
    String d(DateTime? v) => v == null ? gt('Pick a date') : labelDate(v);
    return CardPanel(
      title: gt('Printed on every label'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.fields.packedOn || t.fields.bestBefore) ...[
            FieldRow(children: [
              if (t.fields.packedOn)
                SelectField(
                    label: 'Packed on',
                    value: _packedOn == null ? '' : d(_packedOn),
                    placeholder: 'Pick a date',
                    onTap: () => _pickDate(true)),
              if (t.fields.bestBefore)
                SelectField(
                    label: 'Best before',
                    value: _bestBefore == null ? '' : d(_bestBefore),
                    placeholder: 'Pick a date',
                    onTap: () => _pickDate(false)),
              if (!(t.fields.packedOn && t.fields.bestBefore))
                const SizedBox.shrink(),
            ]),
            if (t.fields.bestBefore &&
                (_datesError() != null || _fe['bestBefore'] != null))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_fe['bestBefore'] ?? _datesError()!,
                    style: labelText(12, FontWeight.w700, AppColors.red)),
              ),
            const SizedBox(height: 10),
          ],
          if (t.fields.batchNo)
            AppField(
              label: 'Batch number',
              value: _batch,
              maxLength: 40,
              error: _fe['batchNo'],
              onChanged: (v) => _batch = v,
            ),
        ],
      ),
    );
  }

  Widget _outputCard(LabelTemplate? t) {
    final sheet = t?.isSheet ?? false;
    return CardPanel(
      title: gt('Output'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in labelModes)
              if (!sheet || m == 'PDF' || m == 'JSON')
                AppChip(labelModeName(m), selected: _mode == m, onTap: () {
                  setState(() {
                    _mode = m;
                    _result = null;
                  });
                }),
          ]),
          const SizedBox(height: 8),
          Hint(switch (_mode) {
            'PDF' => 'PDF opens in a new tab. Print it at 100 percent, no "fit to page".',
            'TSPL' => 'TSC and most label printers. Commands are shown below to copy or save.',
            'ZPL' => 'Zebra and compatible printers. Commands are shown below to copy or save.',
            'ESCPOS' => 'Receipt-width printers (58 or 80 mm). Binary: save the file and send it unchanged.',
            _ => 'A preview of the label drawing, for printers driven by an app.',
          }),
          if (sheet)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Hint('A sheet template prints only as PDF or JSON.'),
            ),
          if (_fe['mode'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_fe['mode']!,
                  style: labelText(12.5, FontWeight.w700, AppColors.red)),
            ),
        ],
      ),
    );
  }

  // ---- result ---------------------------------------------------------------

  Widget _resultCard(LabelPrintResult r) {
    final n = r.count, p = r.pages;
    final head = '${n ?? '-'} ${gt('labels')}'
        '${p != null ? ' / $p ${gt('pages')}' : ''}';
    final children = <Widget>[
      Text(head, style: labelText(15, FontWeight.w800)),
      const SizedBox(height: 10),
    ];
    switch (r.mode) {
      case 'PDF':
        children.addAll([
          const Hint('The PDF opened in a new tab. If nothing opened, allow pop-ups for this site.'),
          const SizedBox(height: 8),
          AppButton('Open PDF again',
              variant: BtnVariant.secondary,
              block: true,
              onTap: () => _openPdf(r)),
        ]);
      case 'JSON':
        children.addAll(_jsonResult(r));
      case 'ESCPOS':
        children.addAll(_binaryResult(r));
      default:
        children.addAll(_textResult(r));
    }
    return CardPanel(
      title: gt('Result'),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _mono(String text) => Container(
        constraints: const BoxConstraints(maxHeight: 280),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: SingleChildScrollView(
          child: SelectableText(text,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: AppColors.ink)),
        ),
      );

  List<Widget> _textResult(LabelPrintResult r) {
    // TSPL is ISO-8859-1 (may hold bitmap bytes); ZPL is ASCII.
    final text = latin1.decode(r.bytes, allowInvalid: true);
    return [
      const Hint('Printer commands. If the roll gap differs, change the GAP line before sending. Raw bitmap bytes (Gujarati) survive only in the saved file.'),
      const SizedBox(height: 8),
      _mono(text),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        AppButton('Copy commands',
            size: BtnSize.sm,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: text));
              showToast('Copied');
            }),
        AppButton('Save file',
            size: BtnSize.sm,
            variant: BtnVariant.secondary,
            onTap: () => openBytesInTab(r.bytes, 'application/octet-stream')),
      ]),
    ];
  }

  List<Widget> _binaryResult(LabelPrintResult r) {
    final shown = r.bytes.take(192).toList();
    final hex = shown
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    final b64 = base64Encode(r.bytes);
    return [
      Text('${r.bytes.length} bytes. ${gt('First bytes')}:',
          style: labelText(12.5, FontWeight.w700, AppColors.ink2)),
      const SizedBox(height: 6),
      _mono(hex),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        AppButton('Save file',
            size: BtnSize.sm,
            onTap: () => openBytesInTab(r.bytes, 'application/octet-stream')),
        AppButton('Copy as base64',
            size: BtnSize.sm,
            variant: BtnVariant.secondary,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: b64));
              showToast('Copied');
            }),
      ]),
    ];
  }

  List<Widget> _jsonResult(LabelPrintResult r) {
    Map<String, dynamic>? j;
    String pretty;
    try {
      j = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bytes)) as Map);
      pretty = const JsonEncoder.withIndent('  ').convert(j);
    } catch (_) {
      pretty = utf8.decode(r.bytes, allowMalformed: true);
    }
    Widget? preview;
    final items = j?['items'];
    if (items is List && items.isNotEmpty && items.first is Map) {
      final first = Map<String, dynamic>.from(items.first as Map);
      final tpl = j?['template'];
      final w = tpl is Map ? (tpl['widthMm'] as num?)?.toDouble() : null;
      final h = tpl is Map ? (tpl['heightMm'] as num?)?.toDouble() : null;
      if (w != null && h != null) preview = _LabelPreview(w, h, first);
    }
    return [
      if (preview != null) ...[
        Text(gt('Preview of the first label'),
            style: labelText(12.5, FontWeight.w800, AppColors.ink2)),
        const SizedBox(height: 6),
        Center(child: preview),
        const SizedBox(height: 10),
      ],
      _mono(pretty),
      const SizedBox(height: 10),
      AppButton('Copy JSON',
          size: BtnSize.sm,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: pretty));
            showToast('Copied');
          }),
    ];
  }
}

/// Draws the JSON `elements` of one item at screen scale (millimetres to
/// pixels): text boxes and the barcode box with its payload.
class _LabelPreview extends StatelessWidget {
  final double wMm;
  final double hMm;
  final Map<String, dynamic> item;
  const _LabelPreview(this.wMm, this.hMm, this.item);

  @override
  Widget build(BuildContext context) {
    final scale = (300 / wMm).clamp(2.0, 7.0);
    final els = (item['elements'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return Container(
      width: wMm * scale,
      height: hMm * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.ink3),
      ),
      child: Stack(children: [
        for (final e in els)
          Positioned(
            left: d(e['xMm']) * scale,
            top: d(e['yMm']) * scale,
            width: d(e['widthMm']) * scale,
            height: d(e['heightMm']) * scale,
            child: e['type'] == 'barcode'
                ? Container(
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.ink3),
                    ),
                    child: '${e['barcodeType']}' == 'EAN13' &&
                            RegExp(r'^\d{13}$').hasMatch('${e['payload']}')
                        ? _Ean13Bars('${e['payload']}')
                        : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('${e['barcodeType'] ?? ''}  ${e['payload'] ?? ''}',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: AppColors.ink)),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: switch ('${e['align']}') {
                      'LEFT' => Alignment.centerLeft,
                      'RIGHT' => Alignment.centerRight,
                      _ => Alignment.center,
                    },
                    child: Text('${e['text'] ?? ''}',
                        style: TextStyle(
                            fontSize: d(e['fontPt']) * scale / 2.83,
                            fontWeight: e['bold'] == true
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: AppColors.ink)),
                  ),
          ),
      ]),
    );
  }
}

/// EAN-13 bars with the digits under them, for the JSON preview.
class _Ean13Bars extends StatelessWidget {
  final String code;
  const _Ean13Bars(this.code);

  static const _l = ['0001101', '0011001', '0010011', '0111101', '0100011', '0110001', '0101111', '0111011', '0110111', '0001011'];
  static const _g = ['0100111', '0110011', '0011011', '0100001', '0011101', '0111001', '0000101', '0010001', '0001001', '0010111'];
  static const _r = ['1110010', '1100110', '1101100', '1000010', '1011100', '1001110', '1010000', '1000100', '1001000', '1110100'];
  static const _parity = ['LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG', 'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL'];

  /// 95 modules: guard, 6 left digits, centre guard, 6 right digits, guard.
  String get bits {
    final d = code.codeUnits.map((c) => c - 48).toList();
    final par = _parity[d[0]];
    final b = StringBuffer('101');
    for (var i = 0; i < 6; i++) {
      b.write(par[i] == 'L' ? _l[d[i + 1]] : _g[d[i + 1]]);
    }
    b.write('01010');
    for (var i = 7; i < 13; i++) {
      b.write(_r[d[i]]);
    }
    b.write('101');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: CustomPaint(
                size: Size.infinite, painter: _BarPainter(bits)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(code,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 8,
                    letterSpacing: 2,
                    color: AppColors.ink)),
          ),
        ],
      );
}

class _BarPainter extends CustomPainter {
  final String bits;
  _BarPainter(this.bits);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / bits.length;
    final paint = Paint()..color = AppColors.ink;
    for (var i = 0; i < bits.length; i++) {
      if (bits[i] == '1') {
        canvas.drawRect(Rect.fromLTWH(i * w, 0, w + 0.3, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.bits != bits;
}
