import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/dto.dart';
import '../../data/api/label_dto.dart' show barcodeError;
import '../../data/validators.dart';
import '../../state/gu_strings.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/gst_picker.dart';
import '../../widgets/panels.dart' show Hint;
import '../../widgets/sheet.dart';
import 'admin_purchases_common.dart';

/// What the quick-create sheet hands back to the purchase line.
class NewItemResult {
  final AdminProductDto product;
  final int gstPercent;
  final String hsn;
  final bool weighed;
  const NewItemResult(this.product, this.gstPercent, this.hsn, this.weighed);
}

/// "+ Add new item" from the purchase bill: creates the product through the
/// same admin API the inventory screens use (`POST /admin/products`, then
/// `PUT /admin/products/{id}/pos` for GST, HSN, sold-by and barcode) with an
/// opening stock of 0 (the purchase line adds the stock).
Future<NewItemResult?> showNewItemSheet(BuildContext context,
    {String presetName = ''}) {
  return showAppSheet<NewItemResult>(
    context: context,
    title: gt('Add new item'),
    sub: gt('It is added to your inventory and to this bill.'),
    builder: (ctx) => _NewItemForm(presetName: presetName),
  );
}

class _NewItemForm extends StatefulWidget {
  final String presetName;
  const _NewItemForm({required this.presetName});
  @override
  State<_NewItemForm> createState() => _NewItemFormState();
}

class _NewItemFormState extends State<_NewItemForm> {
  late final _name = TextEditingController(text: widget.presetName);
  final _nameGu = TextEditingController();
  final _pack = TextEditingController();
  final _mrp = TextEditingController();
  final _price = TextEditingController();
  final _barcode = TextEditingController();
  List<CategoryDto> _cats = const [];
  List<UnitDto> _units = const [];
  String? _catId;
  String? _unit;
  int _gst = 0;
  String _hsn = '';
  bool _loading = true, _busy = false;
  String? _loadError;
  Map<String, String> _err = {};

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  @override
  void dispose() {
    for (final c in [_name, _nameGu, _pack, _mrp, _price, _barcode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLists() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final admin = Api.instance.admin;
      final r = await Future.wait<dynamic>([admin.listCategories(), admin.listUnits()]);
      if (!mounted) return;
      setState(() {
        _cats = (r[0] as List<CategoryDto>).where((c) => c.active && c.id != null).toList();
        _units = (r[1] as List<UnitDto>).where((u) => u.active).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = purchaseError(e);
          _loading = false;
        });
      }
    }
  }

  String? _f(String name, [String? alt]) =>
      ApiException.fieldError(_err, [name, if (alt != null) alt]);

  Future<void> _save() async {
    final local = <String, String>{};
    void chk(String f, String? m) {
      if (m != null) local[f] = pgt(m);
    }

    chk('nameEn', Validators.text(_name.text, label: 'Item name', required: true, max: 120));
    chk('nameGu', Validators.text(_nameGu.text, label: 'Gujarati name', max: 120));
    if (_catId == null) local['categoryId'] = gt('Choose a category');
    if (_unit == null) local['unit'] = gt('Choose a unit');
    chk('packSize', Validators.text(_pack.text, label: 'Pack size', max: 40));
    final hsn = _hsn.trim();
    final hsnMsg = GstPicker.hsnErrorFor(hsn);
    if (hsnMsg != null) local['hsn'] = hsnMsg;
    final mrp = rsToPaise(_mrp.text);
    final price = rsToPaise(_price.text);
    if (mrp == null) {
      local['mrpPaise'] = gt('Enter the MRP in rupees');
    } else if (mrp > 100000000) {
      local['mrpPaise'] = gt('Cost is too high');
    }
    if (price == null) {
      local['pricePaise'] = gt('Enter the selling price in rupees');
    } else if (price > 100000000) {
      local['pricePaise'] = gt('Cost is too high');
    }
    if (mrp != null && price != null && price > mrp) {
      local['pricePaise'] = gt('Selling price cannot be above the MRP');
    }
    final bc = _barcode.text.trim();
    if (bc.isNotEmpty) {
      final m = barcodeError(bc);
      if (m != null) local['barcodes'] = m;
    }
    if (local.isNotEmpty) {
      setState(() => _err = local);
      return;
    }
    setState(() {
      _busy = true;
      _err = {};
    });
    final admin = Api.instance.admin;
    final unit = _units.firstWhere((u) => u.code == _unit);
    final weighed = unit.soldBy == 'WEIGHT';
    final nameEn = _name.text.trim();
    AdminProductDto created;
    try {
      created = await admin.createProduct(
        categoryId: _catId!,
        nameEn: nameEn,
        nameGu: _nameGu.text.trim().isEmpty ? nameEn : _nameGu.text.trim(),
        mrpPaise: mrp!,
        pricePaise: price!,
        unit: _unit,
        packSize: _pack.text.trim().isEmpty ? null : _pack.text.trim(),
        qtyOnHand: 0,
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _err = e.fields.isNotEmpty ? e.fields : {'_': e.messageWithRef};
          _busy = false;
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = {'_': purchaseError(e)};
          _busy = false;
        });
      }
      return;
    }
    // GST, HSN, sold-by and barcode live on the counter details.
    String? warn;
    try {
      await admin.savePosAttributes(
        created.id!,
        soldBy: weighed ? 'WEIGHT' : 'UNIT',
        gstPercent: _gst,
        hsn: hsn,
        barcodes: bc.isEmpty ? null : [bc],
      );
    } catch (e) {
      warn = e is ApiException ? e.messageWithRef : purchaseError(e);
    }
    if (!mounted) return;
    if (warn != null) {
      // The item exists now: keep it, tell the user what to fix.
      setState(() {
        _busy = false;
        _err = {
          '_': '${pgt('The item was created, but the GST, HSN or barcode was not saved')}: $warn. '
              '${pgt('Fix it later in Inventory.')}'
        };
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
    }
    Navigator.of(context).pop(NewItemResult(created, _gst, hsn, weighed));
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(pgt(t), style: pHead),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonRows(rows: 5);
    if (_loadError != null) {
      return ErrorRetry(message: _loadError!, onRetry: _loadLists);
    }
    final unitErr = _f('unit');
    final catErr = _f('categoryId');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppField(
          label: 'Item name (English)',
          controller: _name,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          error: _f('nameEn', 'name')),
      const SizedBox(height: 10),
      AppField(
          label: 'Gujarati name (optional)',
          controller: _nameGu,
          maxLength: 120,
          error: _f('nameGu')),
      const SizedBox(height: 12),
      _label('Category'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in _cats)
          AppChip(c.nameEn ?? '-',
              small: true,
              selected: _catId == c.id,
              onTap: () => setState(() => _catId = c.id)),
      ]),
      if (catErr != null) PNote(catErr, error: true),
      const SizedBox(height: 12),
      _label('Unit'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final u in _units)
          AppChip(u.label,
              small: true,
              selected: _unit == u.code,
              onTap: () => setState(() => _unit = u.code)),
      ]),
      if (unitErr != null) PNote(unitErr, error: true),
      if (_unit != null &&
          _units.firstWhere((u) => u.code == _unit).soldBy == 'WEIGHT')
        const PHint('Sold by weight: stock is counted in grams, so the bill quantity is in grams.'),
      const SizedBox(height: 10),
      FieldRow(children: [
        AppField(
            label: 'Pack size (for example 500 g, 1 kg, 1 pc)',
            controller: _pack,
            maxLength: 40,
            error: _f('packSize')),
        AppField(
            label: 'Barcode (optional)',
            controller: _barcode,
            numeric: true,
            maxLength: 14,
            error: _f('barcodes', 'barcode')),
      ]),
      const SizedBox(height: 12),
      GstPicker(
        productName: _name.text,
        category: _catId == null
            ? null
            : _cats.firstWhere((c) => c.id == _catId).nameEn,
        initialGst: 0,
        initialHsn: '',
        autoApply: true,
        hsnError: _f('hsn'),
        onChanged: (g, h) => setState(() {
          _gst = g;
          _hsn = h;
        }),
      ),
      if (_f('gstPercent') != null) PNote(_f('gstPercent')!, error: true),
      const SizedBox(height: 10),
      FieldRow(children: [
        AppField(
            label: 'MRP (Rs)',
            controller: _mrp,
            numeric: true,
            maxLength: 10,
            error: _f('mrpPaise', 'mrp')),
        AppField(
            label: 'Selling price (Rs)',
            controller: _price,
            numeric: true,
            maxLength: 10,
            error: _f('pricePaise', 'price')),
      ]),
      const SizedBox(height: 6),
      const Hint('Opening stock is 0: the quantity you receive on this bill becomes the stock.'),
      if (_err['_'] != null) PNote(_err['_']!, error: true),
      const SizedBox(height: 14),
      AppButton('Create and add to bill',
          block: true, loading: _busy, onTap: _busy ? null : _save),
      const SizedBox(height: 8),
    ]);
  }
}
