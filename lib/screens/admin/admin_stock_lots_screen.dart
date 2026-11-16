import 'package:flutter/material.dart';

import '../../state/gu_strings.dart';
import '../../widgets/controls.dart';
import 'admin_stock_lots_common.dart';
import 'admin_stock_lots_reports.dart';
import 'admin_stock_lots_variant.dart';

/// `#/admin/stock-lots` - stock lots, lot-aware pricing, expiry, valuation and
/// margin (`74-stock-lots-and-pricing.md`, playbook P5). ADMIN only.
///
/// Query: `variant=<pack id>` opens that pack's Lots tab; `tab=lots|expiring|
/// value|margin|health` picks the tab.
class AdminStockLotsScreen extends StatefulWidget {
  final Map<String, String> query;
  const AdminStockLotsScreen({super.key, this.query = const {}});

  @override
  State<AdminStockLotsScreen> createState() => _AdminStockLotsScreenState();
}

class _AdminStockLotsScreenState extends State<AdminStockLotsScreen> {
  static const _tabs = [
    ('lots', 'Lots of a pack'),
    ('expiring', 'Expiring'),
    ('value', 'Stock value'),
    ('margin', 'Margin'),
    ('health', 'Stock health'),
  ];

  late String _tab = _tabs.any((t) => t.$1 == widget.query['tab'])
      ? widget.query['tab']!
      : 'lots';
  late String? _variant = (widget.query['variant'] ?? '').isEmpty
      ? null
      : widget.query['variant'];

  @override
  Widget build(BuildContext context) {
    return LotsPage(
      title: gt('Stock lots and expiry'),
      sub: gt('Batches, cost, expiry, stock value and margin'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChipRail(children: [
            for (final t in _tabs)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppChip(gt(t.$2),
                    selected: _tab == t.$1,
                    onTap: () => setState(() => _tab = t.$1)),
              ),
          ]),
          const SizedBox(height: 14),
          // Keyed so a tab starts fresh (and reloads) when it is re-opened.
          switch (_tab) {
            'expiring' => LotsExpiringTab(
                key: const ValueKey('expiring'),
                onStockHealth: () => setState(() => _tab = 'health')),
            'value' => const LotsValuationTab(key: ValueKey('value')),
            'margin' => const LotsMarginTab(key: ValueKey('margin')),
            'health' => const LotsHealthTab(key: ValueKey('health')),
            _ => LotsVariantTab(
                key: const ValueKey('lots'),
                variantId: _variant,
                onPick: (id) => setState(() => _variant = id),
                onStockHealth: () => setState(() => _tab = 'health')),
          },
        ],
      ),
    );
  }
}
