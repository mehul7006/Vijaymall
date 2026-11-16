import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/flash_dto.dart';
import '../../data/ist.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/flash_widgets.dart' show flashWhen;
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import 'admin_flash_common.dart';
import 'admin_flash_sales_screen.dart' show showFlashOverlapSheet;

// ---------------------------------------------------------------------------
// Product picker
// ---------------------------------------------------------------------------

class _PackChoice {
  final String id;
  final String name;
  final int pricePaise;
  const _PackChoice(this.id, this.name, this.pricePaise);
}

Future<_PackChoice?> _pickPack(BuildContext context, Set<String> exclude) {
  final state = StateScope.read(context);
  final all = <_PackChoice>[];
  for (final p in state.products) {
    for (final v in p.variants) {
      final id = v.backendId;
      if (id == null || id.isEmpty || !v.active || exclude.contains(id)) {
        continue;
      }
      final label = p.variants.length > 1 ? ' · ${v.label}' : '';
      all.add(_PackChoice(id, '${p.name}$label', (v.price * 100).round()));
    }
  }
  var q = '';
  return showAppSheet<_PackChoice>(
    context: context,
    title: 'Choose a product',
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final n = q.trim().toLowerCase();
      final list = (n.isEmpty
              ? all
              : all.where((c) => c.name.toLowerCase().contains(n)).toList())
          .take(60)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppField(
            placeholder: 'Search products by name',
            value: q,
            onChanged: (v) => setSheet(() => q = v),
          ),
          const SizedBox(height: 10),
          for (final c in list)
            SheetOption(
              title: c.name,
              sub: fmtPaise(c.pricePaise),
              selected: false,
              onTap: () => Navigator.of(ctx).pop(c),
            ),
          if (list.isEmpty) Hint(gt('No products match that search.')),
        ],
      );
    }),
  );
}

// ---------------------------------------------------------------------------
// Item sheet (add / edit one product of a sale)
// ---------------------------------------------------------------------------

/// Detail screen: add (item == null) or edit one item through the API.
/// Returns the updated sale.
Future<FlashSaleView?> showFlashItemSheet(BuildContext context,
    {required FlashSaleView sale, FlashItemView? item}) async {
  final r = await showAppSheet<Object>(
    context: context,
    title: item == null ? 'Add product' : 'Edit product',
    sub: item?.nameEn,
    builder: (ctx) => _ItemSheet(
      saleDefaultKind: sale.discountKind,
      view: item,
      initial: item == null ? null : FlashItemDraft.fromView(item),
      submit: (d) => item == null
          ? Api.instance.flash.addItem(sale.id, d.toJson())
          : Api.instance.flash
              .updateItem(sale.id, item.id, d.toJson(withProduct: false)),
    ),
  );
  return r is FlashSaleView ? r : null;
}

/// Create form: collect one item locally.
Future<FlashItemDraft?> _showDraftSheet(BuildContext context,
    {required String saleDefaultKind,
    FlashItemDraft? initial,
    required Set<String> taken}) async {
  final r = await showAppSheet<Object>(
    context: context,
    title: initial == null ? 'Add product' : 'Edit product',
    sub: initial?.name,
    builder: (ctx) => _ItemSheet(
      saleDefaultKind: saleDefaultKind,
      initial: initial,
      taken: taken,
    ),
  );
  return r is FlashItemDraft ? r : null;
}

class _ItemSheet extends StatefulWidget {
  final String saleDefaultKind;
  final FlashItemView? view;
  final FlashItemDraft? initial;
  final Set<String> taken;
  final Future<FlashSaleView> Function(FlashItemDraft)? submit;

  const _ItemSheet({
    required this.saleDefaultKind,
    this.view,
    this.initial,
    this.taken = const {},
    this.submit,
  });

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final FlashItemDraft _d = widget.initial ??
      FlashItemDraft(productId: '');
  late String _kind = _d.hasOwn ? _d.discountKind : 'NONE';
  late String _value = !_d.hasOwn
      ? ''
      : _d.discountKind == 'FIXED_PRICE'
          ? paiseToRupeesText(_d.discountValue)
          : '${_d.discountValue}';
  late String _max = _d.maxQty?.toString() ?? '';
  late String _per = _d.perCustomerLimit?.toString() ?? '';
  bool _busy = false;
  String? _err;
  Map<String, String> _fields = const {};

  /// Once units sold, only the cap may change, and only upwards.
  bool get _sold => (widget.view?.soldQty ?? 0) > 0;
  bool get _hadCap => widget.view?.maxQty != null;

  String? _build() {
    if (_d.productId.isEmpty) return gt('Choose a product');
    int? v;
    if (_kind != 'NONE') {
      if (_kind == 'PERCENT') {
        v = int.tryParse(_value.trim());
        if (v == null || v < 1 || v > 90) return gt('Percent must be 1 to 90');
      } else {
        v = rupeesTextToPaise(_value);
        if (v == null || v < 100) return gt('Sale price must be at least Rs 1');
      }
    } else if (widget.saleDefaultKind == 'NONE') {
      return gt('This sale has no default discount, so set a discount for this product');
    }
    int? mx;
    if (_max.trim().isNotEmpty) {
      mx = int.tryParse(_max.trim());
      if (mx == null || mx < 1 || mx > 1000000) {
        return gt('Quantity cap must be 1 to 1,000,000');
      }
      final old = widget.view?.maxQty;
      if (_sold && old != null && mx < old) {
        return '${gt('Quantity can only be raised from')} $old';
      }
    }
    int? per;
    if (_per.trim().isNotEmpty) {
      per = int.tryParse(_per.trim());
      if (per == null || per < 0 || per > 999) {
        return gt('Per-customer limit must be 0 to 999');
      }
    }
    _d
      ..discountKind = _kind
      ..discountValue = v ?? 0
      ..maxQty = mx
      ..perCustomerLimit = per;
    return null;
  }

  Future<void> _save() async {
    if (_busy) return;
    final e = _build();
    if (e != null) {
      setState(() => _err = e);
      return;
    }
    final submit = widget.submit;
    if (submit == null) {
      Navigator.of(context).pop(_d);
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
      _fields = const {};
    });
    ApiException.clearFields();
    try {
      final sale = await submit(_d);
      if (mounted) Navigator.of(context).pop(sale);
    } on ApiException catch (ex) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = ex.messageWithRef;
        _fields = ex.fields.isNotEmpty ? ex.fields : ApiException.takeFields();
      });
      if (ex.code == 'FLASH_OVERLAP') {
        final id = ex.details?['saleId']?.toString();
        if (id != null && id.isNotEmpty) {
          showFlashOverlapSheet(context,
              message: ex.message,
              saleId: id,
              saleName: ex.details?['saleName']?.toString() ?? '');
        }
      }
    } catch (ex) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = flashError(ex);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final needPick = _d.productId.isEmpty;
    final itemsErr = _fields['items'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (needPick)
          SelectField(
            label: 'Product',
            value: _d.name,
            placeholder: 'Choose a product',
            onTap: () async {
              final c = await _pickPack(context, widget.taken);
              if (c != null && mounted) {
                setState(() {
                  _d.productId = c.id;
                  _d.name = c.name;
                  _d.listPricePaise = c.pricePaise;
                });
              }
            },
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(_d.name,
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                )),
          ),
        if (_d.listPricePaise > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${gt('List price')}: ${fmtPaise(_d.listPricePaise)}',
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink3,
                )),
          ),
        const SizedBox(height: 10),
        if (_sold)
          const Hint(
              'Units of this product have been sold, so only the quantity cap can change, and only upwards. To change the discount, end the sale and make a new one.')
        else ...[
          Segmented(
            value: _kind,
            options: [
              SegmentOption('NONE', gt('Sale default')),
              SegmentOption('PERCENT', gt('Percent off')),
              SegmentOption('FIXED_PRICE', gt('Fixed price')),
            ],
            onChanged: (v) => setState(() => _kind = v),
          ),
          if (_kind != 'NONE') ...[
            const SizedBox(height: 12),
            AppField(
              label: _kind == 'PERCENT' ? 'Percent off (1 to 90)' : 'Sale price (Rs)',
              value: _value,
              numeric: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _value = v,
            ),
          ],
        ],
        const SizedBox(height: 12),
        if (_sold && !_hadCap)
          const Hint(
              'This product has no quantity cap and a cap cannot be added after units are sold.')
        else
          AppField(
            label: 'Quantity cap (blank = no cap)',
            value: _max,
            numeric: true,
            keyboardType: TextInputType.number,
            onChanged: (v) => _max = v,
          ),
        if (!_sold) ...[
          const SizedBox(height: 12),
          AppField(
            label: 'Per-customer limit (blank = follow the sale, 0 = none)',
            value: _per,
            numeric: true,
            keyboardType: TextInputType.number,
            onChanged: (v) => _per = v,
          ),
        ],
        if (itemsErr != null) FlashNote(itemsErr, error: true),
        if (_err != null && _err != itemsErr) FlashNote(_err!, error: true),
        const SizedBox(height: 16),
        AppButton(widget.submit == null ? 'Done' : 'Save',
            block: true, loading: _busy, onTap: _busy ? null : _save),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Duplicate sheet
// ---------------------------------------------------------------------------

Future<FlashSaleView?> showFlashDuplicateSheet(
    BuildContext context, FlashSaleView sale) async {
  return showAppSheet<FlashSaleView>(
    context: context,
    title: 'Run this sale again',
    builder: (ctx) => _DuplicateSheet(sale: sale),
  );
}

class _DuplicateSheet extends StatefulWidget {
  final FlashSaleView sale;
  const _DuplicateSheet({required this.sale});

  @override
  State<_DuplicateSheet> createState() => _DuplicateSheetState();
}

class _DuplicateSheetState extends State<_DuplicateSheet> {
  late String _name = '${widget.sale.name} (copy)'.length > 80
      ? widget.sale.name
      : '${widget.sale.name} (copy)';
  DateTime? _start;
  DateTime? _end;
  bool _busy = false;
  String? _err;
  Map<String, String> _fields = const {};

  Future<void> _go() async {
    if (_busy) return;
    if (_start == null) {
      setState(() => _err = gt('Choose a new start time'));
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
      _fields = const {};
    });
    ApiException.clearFields();
    try {
      final r = await Api.instance.flash.duplicate(widget.sale.id, body: {
        'name': _name.trim(),
        'startsAt': istToWire(_start!),
        if (_end != null) 'endsAt': istToWire(_end!),
      });
      if (mounted) Navigator.of(context).pop(r);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = e.messageWithRef;
        _fields = e.fields.isNotEmpty ? e.fields : ApiException.takeFields();
      });
      if (e.code == 'FLASH_OVERLAP') {
        final id = e.details?['saleId']?.toString();
        if (id != null && id.isNotEmpty) {
          showFlashOverlapSheet(context,
              message: e.message,
              saleId: id,
              saleName: e.details?['saleName']?.toString() ?? '');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = flashError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppField(
          label: 'Name',
          value: _name,
          maxLength: 80,
          error: _fields['name'],
          onChanged: (v) => _name = v,
        ),
        const SizedBox(height: 12),
        FieldRow(
          minWidth: 420,
          children: [
            SelectField(
              label: 'New start (India time)',
              value: _start == null ? '' : flashWhen(_start),
              placeholder: 'Choose date and time',
              onTap: () async {
                final d = await pickIstDateTime(
                    context, _start ?? istNow().add(const Duration(hours: 1)));
                if (d != null) setState(() => _start = d);
              },
            ),
            SelectField(
              label: 'New end (blank = same length as before)',
              value: _end == null ? '' : flashWhen(_end),
              placeholder: 'Same length as the original',
              onTap: () async {
                final base = _start ?? istNow();
                final d = await pickIstDateTime(
                    context, _end ?? base.add(const Duration(hours: 2)));
                if (d != null) setState(() => _end = d);
              },
            ),
          ],
        ),
        if (_fields['startsAt'] != null)
          FlashNote(_fields['startsAt']!, error: true),
        if (_fields['endsAt'] != null) FlashNote(_fields['endsAt']!, error: true),
        if (_fields['items'] != null) FlashNote(_fields['items']!, error: true),
        if (_err != null) FlashNote(_err!, error: true),
        const SizedBox(height: 16),
        AppButton('Create copy',
            block: true, loading: _busy, onTap: _busy ? null : _go),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Create / edit form
// ---------------------------------------------------------------------------

class AdminFlashFormScreen extends StatefulWidget {
  final String? editId;
  const AdminFlashFormScreen({super.key, this.editId});

  @override
  State<AdminFlashFormScreen> createState() => _AdminFlashFormScreenState();
}

class _AdminFlashFormScreenState extends State<AdminFlashFormScreen> {
  FlashSaleView? _orig;
  bool _loading = false;
  String? _loadError;
  bool _busy = false;
  String? _err;
  Map<String, String> _fields = const {};

  String _name = '';
  String _desc = '';
  String _banner = '';
  String _channel = 'BOTH';
  bool _startNow = true;
  DateTime? _start;
  DateTime? _end;
  String _kind = 'PERCENT';
  String _value = '';
  String _per = '';
  final List<FlashItemDraft> _items = [];

  bool get _editing => widget.editId != null;
  bool get _running => _orig?.isActive == true;

  @override
  void initState() {
    super.initState();
    if (_editing) _loadSale();
  }

  Future<void> _loadSale() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final s = await Api.instance.flash.get(widget.editId!);
      if (!mounted) return;
      setState(() {
        _orig = s;
        _loading = false;
        _name = s.name;
        _desc = s.description;
        _banner = s.bannerText;
        _channel = s.channel.toUpperCase();
        _startNow = false;
        _start = s.startsAt;
        _end = s.endsAt;
        _kind = s.discountKind;
        _value = s.discountKind == 'FIXED_PRICE'
            ? paiseToRupeesText(s.discountValue)
            : (s.discountKind == 'PERCENT' ? '${s.discountValue}' : '');
        _per = s.perCustomerLimit > 0 ? '${s.perCustomerLimit}' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = flashError(e);
      });
    }
  }

  /// Client-side checks only for what the server cannot tell field by field;
  /// the server stays authoritative and its messages are shown as they come.
  Map<String, dynamic>? _buildCreate() {
    final f = <String, String>{};
    if (_name.trim().isEmpty) f['name'] = gt('Enter a name');
    if (_end == null) f['endsAt'] = gt('Choose when the sale ends');
    if (!_startNow && _start == null) f['startsAt'] = gt('Choose a start time');
    int? dv;
    if (_kind == 'PERCENT') {
      dv = int.tryParse(_value.trim());
      if (dv == null || dv < 1 || dv > 90) f['discountValue'] = gt('Percent must be 1 to 90');
    } else if (_kind == 'FIXED_PRICE') {
      dv = rupeesTextToPaise(_value);
      if (dv == null || dv < 100) f['discountValue'] = gt('Sale price must be at least Rs 1');
    }
    int? per;
    if (_per.trim().isNotEmpty) {
      per = int.tryParse(_per.trim());
      if (per == null || per < 0 || per > 999) {
        f['perCustomerLimit'] = gt('Per-customer limit must be 0 to 999');
      }
    }
    if (_items.isEmpty) f['items'] = gt('Choose at least one product');
    if (f.isNotEmpty) {
      setState(() => _fields = f);
      return null;
    }
    return {
      'name': _name.trim(),
      'description': _desc.trim(),
      'bannerText': _banner.trim(),
      if (!_startNow) 'startsAt': istToWire(_start!),
      'endsAt': istToWire(_end!),
      'channel': _channel,
      'discountKind': _kind,
      if (_kind != 'NONE') 'discountValue': dv,
      if (per != null) 'perCustomerLimit': per,
      'items': [for (final i in _items) i.toJson()],
    };
  }

  Map<String, dynamic>? _buildPatch() {
    final o = _orig!;
    final f = <String, String>{};
    final body = <String, dynamic>{};
    if (_name.trim().isEmpty) f['name'] = gt('Enter a name');
    if (_name.trim() != o.name) body['name'] = _name.trim();
    if (_desc.trim() != o.description) body['description'] = _desc.trim();
    if (_banner.trim() != o.bannerText) body['bannerText'] = _banner.trim();
    if (_end != null && _end != o.endsAt) body['endsAt'] = istToWire(_end!);
    if (!_running) {
      if (_start != null && _start != o.startsAt) {
        body['startsAt'] = istToWire(_start!);
      }
      if (_channel != o.channel.toUpperCase()) body['channel'] = _channel;
      int? dv;
      if (_kind == 'PERCENT') {
        dv = int.tryParse(_value.trim());
        if (dv == null || dv < 1 || dv > 90) f['discountValue'] = gt('Percent must be 1 to 90');
      } else if (_kind == 'FIXED_PRICE') {
        dv = rupeesTextToPaise(_value);
        if (dv == null || dv < 100) f['discountValue'] = gt('Sale price must be at least Rs 1');
      } else {
        dv = 0;
      }
      if (_kind != o.discountKind || (dv != null && dv != o.discountValue)) {
        // Always both together (doc: a kind without a value reuses the old one).
        body['discountKind'] = _kind;
        body['discountValue'] = dv ?? 0;
      }
      final per = _per.trim().isEmpty ? 0 : int.tryParse(_per.trim());
      if (per == null || per < 0 || per > 999) {
        f['perCustomerLimit'] = gt('Per-customer limit must be 0 to 999');
      } else if (per != o.perCustomerLimit) {
        body['perCustomerLimit'] = per;
      }
    }
    if (f.isNotEmpty) {
      setState(() => _fields = f);
      return null;
    }
    return body;
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _err = null;
      _fields = const {};
    });
    final body = _editing ? _buildPatch() : _buildCreate();
    if (body == null) return;
    if (_editing && body.isEmpty) {
      showToast(gt('Nothing to save'));
      return;
    }
    setState(() => _busy = true);
    ApiException.clearFields();
    try {
      final s = _editing
          ? await Api.instance.flash.patch(widget.editId!, body)
          : await Api.instance.flash.create(body);
      if (!mounted) return;
      showToast(gt(_editing ? 'Sale updated' : 'Sale created'));
      // Replace the form with the saved sale (back goes to the list).
      Nav.instance.pop();
      go('/admin/flash-sales?id=${s.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = e.messageWithRef;
        _fields = e.fields.isNotEmpty ? e.fields : ApiException.takeFields();
      });
      if (e.code == 'FLASH_OVERLAP') {
        final id = e.details?['saleId']?.toString();
        if (id != null && id.isNotEmpty) {
          showFlashOverlapSheet(context,
              message: e.message,
              saleId: id,
              saleName: e.details?['saleName']?.toString() ?? '');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = flashError(e);
        });
      }
    }
  }

  Future<void> _addItem() async {
    final d = await _showDraftSheet(context,
        saleDefaultKind: _kind,
        taken: {for (final i in _items) i.productId});
    if (d != null) setState(() => _items.add(d));
  }

  Future<void> _editItem(int i) async {
    final d = await _showDraftSheet(context,
        saleDefaultKind: _kind,
        initial: _items[i],
        taken: {for (final x in _items) x.productId});
    if (d != null) setState(() => _items[i] = d);
  }

  Future<void> _pickTime(bool start) async {
    final base = (start ? _start : _end) ??
        (start ? istNow().add(const Duration(hours: 1)) : (_start ?? istNow()).add(const Duration(hours: 2)));
    final d = await pickIstDateTime(context, base);
    if (d == null || !mounted) return;
    setState(() => start ? _start = d : _end = d);
  }

  @override
  Widget build(BuildContext context) {
    final title = _editing ? gt('Edit flash sale') : gt('New flash sale');
    return FlashAdminPage(
      title: title,
      sub: gt('Times are in India time'),
      backToList: true,
      child: _loading
          ? const SkeletonRows(rows: 5)
          : _loadError != null
              ? ErrorRetry(message: _loadError!, onRetry: _loadSale)
              : _editing && _orig != null && _orig!.isClosed
                  ? Hint(gt('This sale has ended or been cancelled and cannot be edited. Use Duplicate to run it again.'))
                  : _form(),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardPanel(
          title: gt('Details'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppField(
                label: 'Name',
                placeholder: 'Weekend Dhamaka',
                value: _name,
                maxLength: 80,
                error: _fields['name'],
                onChanged: (v) => _name = v,
              ),
              const SizedBox(height: 10),
              AppField(
                label: 'Banner text (optional)',
                placeholder: 'Up to 30% off',
                value: _banner,
                maxLength: 80,
                error: _fields['bannerText'],
                onChanged: (v) => _banner = v,
              ),
              const SizedBox(height: 10),
              AppField(
                label: 'Description (optional)',
                value: _desc,
                maxLength: 300,
                error: _fields['description'],
                onChanged: (v) => _desc = v,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('When (India time)'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_editing) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(gt('Start now'),
                          style: const TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          )),
                    ),
                    AppSwitch(
                        value: _startNow,
                        onChanged: (v) => setState(() => _startNow = v)),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              FieldRow(
                minWidth: 420,
                children: [
                  if (!_startNow)
                    SelectField(
                      label: 'Starts',
                      value: _start == null ? '' : flashWhen(_start),
                      placeholder: 'Choose date and time',
                      onTap: _running ? null : () => _pickTime(true),
                    ),
                  SelectField(
                    label: 'Ends',
                    value: _end == null ? '' : flashWhen(_end),
                    placeholder: 'Choose date and time',
                    onTap: () => _pickTime(false),
                  ),
                ],
              ),
              if (!_startNow && _fields['startsAt'] != null)
                FlashNote(_fields['startsAt']!, error: true),
              if (_fields['endsAt'] != null)
                FlashNote(_fields['endsAt']!, error: true),
              if (_running)
                FlashNote(gt('This sale is running: only the name, texts and end time can change.')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('Where and how much'),
          child: Opacity(
            opacity: _running ? .5 : 1,
            child: IgnorePointer(
              ignoring: _running,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Segmented(
                    value: _channel,
                    options: [
                      SegmentOption('BOTH', gt('Online + Counter')),
                      SegmentOption('ONLINE', gt('Online')),
                      SegmentOption('POS', gt('Counter')),
                    ],
                    onChanged: (v) => setState(() => _channel = v),
                  ),
                  if (_fields['channel'] != null)
                    FlashNote(_fields['channel']!, error: true),
                  const SizedBox(height: 14),
                  Text(gt('Default discount'),
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      )),
                  const SizedBox(height: 7),
                  Segmented(
                    value: _kind,
                    options: [
                      SegmentOption('PERCENT', gt('Percent off')),
                      SegmentOption('FIXED_PRICE', gt('Fixed price')),
                      SegmentOption('NONE', gt('Per product')),
                    ],
                    onChanged: (v) => setState(() => _kind = v),
                  ),
                  if (_kind != 'NONE') ...[
                    const SizedBox(height: 12),
                    AppField(
                      label: _kind == 'PERCENT'
                          ? 'Percent off (1 to 90)'
                          : 'Sale price (Rs)',
                      value: _value,
                      numeric: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      error: _fields['discountValue'],
                      onChanged: (v) => _value = v,
                    ),
                  ] else
                    FlashNote(gt('Every product needs its own discount.')),
                  if (_fields['discountKind'] != null)
                    FlashNote(_fields['discountKind']!, error: true),
                  const SizedBox(height: 14),
                  AppField(
                    label: 'Per-customer limit (blank = no limit)',
                    value: _per,
                    numeric: true,
                    keyboardType: TextInputType.number,
                    error: _fields['perCustomerLimit'],
                    onChanged: (v) => _per = v,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_editing) ...[
          const SizedBox(height: 12),
          CardPanel(
            title: '${gt('Products')} (${_items.length})',
            actionLabel: gt('Add product'),
            onAction: _addItem,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_items.isEmpty) Hint(gt('Add at least one product.')),
                for (var i = 0; i < _items.length; i++) _draftRow(i),
                if (_fields['items'] != null)
                  FlashNote(_fields['items']!, error: true),
              ],
            ),
          ),
        ],
        if (_err != null && _fields.isEmpty) FlashNote(_err!, error: true),
        if (_err != null && _fields.isNotEmpty) FlashNote(_err!, error: true),
        const SizedBox(height: 16),
        AppButton(_editing ? 'Save changes' : 'Create flash sale',
            block: true, loading: _busy, onTap: _busy ? null : _save),
      ],
    );
  }

  Widget _draftRow(int i) {
    final d = _items[i];
    final disc = !d.hasOwn
        ? gt('Sale default')
        : d.discountKind == 'PERCENT'
            ? '${d.discountValue}% ${gt('off')}'
            : '${gt('Fixed')} ${fmtPaise(d.discountValue)}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    )),
                const SizedBox(height: 2),
                Text(
                    '$disc · ${d.maxQty == null ? gt('No cap') : '${gt('Cap')} ${d.maxQty}'}'
                    ' · ${d.perCustomerLimit == null ? gt('Sale limit') : '${gt('Max')} ${d.perCustomerLimit}'}',
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink3,
                    )),
              ],
            ),
          ),
          IconBtn('edit', size: 36, iconSize: 15, onTap: () => _editItem(i)),
          const SizedBox(width: 6),
          IconBtn('trash',
              size: 36,
              iconSize: 15,
              onTap: () => setState(() => _items.removeAt(i))),
        ],
      ),
    );
  }
}
