import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/api_service.dart';
import '../../data/api/dto.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';

/// What a coupon is limited to besides categories: single packs
/// (`productIds`) and whole products with all their packs (`productGroupIds`).
/// Ids map to a display name.
class CouponTargets {
  final Map<String, String> products;
  final Map<String, String> groups;

  CouponTargets({Map<String, String>? products, Map<String, String>? groups})
      : products = products ?? {},
        groups = groups ?? {};

  bool get isEmpty => products.isEmpty && groups.isEmpty;
}

/// Opens the item picker; resolves to the new selection, or null when closed
/// without pressing Done.
Future<CouponTargets?> showCouponTargetPicker(
  BuildContext context, {
  required CouponTargets current,
}) {
  return showAppSheet<CouponTargets>(
    context: context,
    title: gt('Specific items'),
    sub: gt('Limit the coupon to chosen packs or whole products'),
    builder: (ctx) => _TargetPicker(current: current),
  );
}

class _TargetPicker extends StatefulWidget {
  final CouponTargets current;
  const _TargetPicker({required this.current});

  @override
  State<_TargetPicker> createState() => _TargetPickerState();
}

class _TargetPickerState extends State<_TargetPicker> {
  late final CouponTargets _sel = CouponTargets(
    products: Map<String, String>.of(widget.current.products),
    groups: Map<String, String>.of(widget.current.groups),
  );
  List<AdminProductDto> _results = const [];
  bool _loading = false;
  String? _error;
  String _q = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.instance.admin
          .listProducts(q: q.trim(), active: true, page: 0, size: 20);
      if (!mounted || q != _q) return;
      setState(() {
        _results = r.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = gt('Could not load the items. Try again.');
      });
    }
  }

  String _label(AdminProductDto p) {
    final pack = (p.packSize ?? '').trim();
    return '${p.nameEn ?? ''}${pack.isEmpty ? '' : ' · $pack'}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_sel.isEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in _sel.products.entries)
                AppChip('${e.value} (${gt('this pack')})  x',
                    selected: true,
                    small: true,
                    onTap: () => setState(() => _sel.products.remove(e.key))),
              for (final e in _sel.groups.entries)
                AppChip('${e.value} (${gt('all packs')})  x',
                    selected: true,
                    small: true,
                    onTap: () => setState(() => _sel.groups.remove(e.key))),
            ],
          ),
          const SizedBox(height: 10),
        ],
        AppField(
          label: gt('Search items'),
          value: _q,
          placeholder: gt('Name of the product'),
          maxLength: 60,
          onChanged: (v) {
            _q = v;
            _debounce?.cancel();
            _debounce =
                Timer(const Duration(milliseconds: 350), () => _search(v));
          },
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.red)),
          )
        else if (_error != null)
          Hint(_error!)
        else if (_results.isEmpty)
          Hint(gt('No items found.'))
        else
          for (final p in _results)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _label(p),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppChip(gt('This pack'),
                      small: true,
                      selected: _sel.products.containsKey(p.id),
                      onTap: p.id == null
                          ? null
                          : () => setState(() {
                                if (_sel.products.remove(p.id) == null) {
                                  _sel.products[p.id!] = _label(p);
                                }
                              })),
                  if ((p.productGroupId ?? '').isNotEmpty) ...[
                    const SizedBox(width: 6),
                    AppChip(gt('All packs'),
                        small: true,
                        selected: _sel.groups.containsKey(p.productGroupId),
                        onTap: () => setState(() {
                              if (_sel.groups.remove(p.productGroupId) ==
                                  null) {
                                _sel.groups[p.productGroupId!] =
                                    p.nameEn ?? '';
                              }
                            })),
                  ],
                ],
              ),
            ),
        const SizedBox(height: 12),
        AppButton(
          _sel.isEmpty
              ? gt('No specific items')
              : '${gt('Use')} ${_sel.products.length + _sel.groups.length} ${gt('selected')}',
          block: true,
          onTap: () => Navigator.of(context).pop(_sel),
        ),
      ],
    );
  }
}
