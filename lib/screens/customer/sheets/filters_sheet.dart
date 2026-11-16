import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/controls.dart';
import '../../../widgets/sheet.dart';
import '../../../state/gu_strings.dart';

/// §3.14 `Filter products` — sort list plus the in-stock / coins toggles.
///
/// Every change applies live through [onApply] (mirrors the prototype's
/// `set-sort` / `filter-stock` / `filter-coins` handlers); `Show results`
/// only closes the sheet and `Clear all filters` delegates to [onClear].
void showFiltersSheet(
  BuildContext context, {
  required bool stock,
  required bool coins,
  required String sort,
  required void Function(String sort, bool stock, bool coins) onApply,
  required VoidCallback onClear,
}) {
  showAppSheet<void>(
    context: context,
    title: gt('Filter products'),
    sub: gt('Find exactly what you need'),
    footer: Builder(
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            'Show results',
            block: true,
            onTap: () => Navigator.of(c).maybePop(),
          ),
          const SizedBox(height: 8),
          AppButton(
            'Clear all filters',
            variant: BtnVariant.soft,
            block: true,
            onTap: () {
              onClear();
              Navigator.of(c).maybePop();
            },
          ),
        ],
      ),
    ),
    builder: (ctx) => _FiltersBody(
      stock: stock,
      coins: coins,
      sort: sort,
      onApply: onApply,
      onClear: onClear,
    ),
  );
}

class _FiltersBody extends StatefulWidget {
  const _FiltersBody({
    required this.stock,
    required this.coins,
    required this.sort,
    required this.onApply,
    required this.onClear,
  });

  final bool stock;
  final bool coins;
  final String sort;
  final void Function(String sort, bool stock, bool coins) onApply;
  final VoidCallback onClear;

  @override
  State<_FiltersBody> createState() => _FiltersBodyState();
}

class _FiltersBodyState extends State<_FiltersBody> {
  static const _sorts = [
    ['popular', 'Most popular'],
    ['price-low', 'Price: low to high'],
    ['price-high', 'Price: high to low'],
    ['rating', 'Top rated'],
  ];

  late String _sort = widget.sort;
  late bool _stock = widget.stock;
  late bool _coins = widget.coins;

  void _apply() => widget.onApply(_sort, _stock, _coins);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `.filter-group` — Sort by.
        Text(gt('Sort by'), style: _head()),
        const SizedBox(height: 8),
        for (final option in _sorts)
          _SortOption(
            label: option[1],
            selected: _sort == option[0],
            onTap: () => setState(() {
              _sort = option[0];
              _apply();
            }),
          ),

        // `.filter-group` — Show only.
        const SizedBox(height: 16),
        Text(gt('Show only'), style: _head()),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(children: [
        _ToggleRow(
          title: gt('In stock'),
          sub: gt('Hide items that are sold out'),
          value: _stock,
          onChanged: (v) => setState(() {
            _stock = v;
            _apply();
          }),
        ),
        const Divider(height: 1, color: AppColors.line),
        _ToggleRow(
          title: gt('Coins eligible'),
          sub: gt('Earn or redeem coins on these items'),
          value: _coins,
          onChanged: (v) => setState(() {
            _coins = v;
            _apply();
          }),
        ),

          ]),
        ),
      ],
    );
  }
}

/// `.sort-option` — full-width sort row with a check when selected.
class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.redTint : AppColors.white,
          border: Border.all(color: selected ? AppColors.red : AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.red : AppColors.ink,
                ),
              ),
            ),
            if (selected)
              const AppIcon('check', size: 15, color: AppColors.red),
          ],
        ),
      ),
    );
  }
}

/// `.toggle-row` — label + sub + iOS switch (last row drops its divider).
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// `.filter-group h3` — 11px uppercase-ish group heading.
TextStyle _head() => TextStyle(
      fontFamily: AppTheme.uiFont,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    );
