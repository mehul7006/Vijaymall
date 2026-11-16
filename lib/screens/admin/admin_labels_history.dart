import 'package:flutter/material.dart';

import '../../data/api/label_dto.dart';
import '../../data/label_store.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/panels.dart';
import 'admin_labels_common.dart';

/// "Printed before": one row per variant per print request, newest first.
/// With [variantId] only that variant's prints are listed.
class LabelHistoryTab extends StatefulWidget {
  final String? variantId;
  const LabelHistoryTab({super.key, this.variantId});

  @override
  State<LabelHistoryTab> createState() => _LabelHistoryTabState();
}

class _LabelHistoryTabState extends State<LabelHistoryTab> {
  final List<LabelHistoryRow> _rows = [];
  int _page = 0;
  bool _loading = true;
  bool _more = false;
  bool _hasMore = false;
  int _total = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _rows.clear();
        _page = 0;
      }
      _error = null;
    });
    try {
      final r = await LabelStore.instance.api.history(
          variantId: widget.variantId, page: more ? _page + 1 : 0, size: 20);
      if (!mounted) return;
      setState(() {
        _rows.addAll(r.items);
        _page = r.page;
        _total = r.total;
        _hasMore = r.hasMore;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = labelError(e);
        _loading = false;
        _more = false;
      });
    }
  }

  String _when(DateTime? t) {
    if (t == null) return '';
    // Show India time regardless of the browser zone.
    final ist = t.toUtc().add(const Duration(hours: 5, minutes: 30));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(ist.day)}/${two(ist.month)}/${ist.year} ${two(ist.hour)}:${two(ist.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonRows(rows: 4);
    if (_error != null && _rows.isEmpty) {
      return EmptyState(
          icon: 'info',
          title: 'Could not load history',
          copy: _error!,
          actionLabel: 'Try again',
          onAction: _load);
    }
    if (_rows.isEmpty) {
      return const EmptyState(
          icon: 'clock',
          title: 'Nothing printed yet',
          copy: 'Printed labels will be listed here, newest first.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('${gt('Prints')}: $_total',
              style: labelText(12.5, FontWeight.w800, AppColors.ink2)),
        ),
        for (final r in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CardPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(r.variantName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: labelText(13.5, FontWeight.w800))),
                    const SizedBox(width: 8),
                    Text('${r.copies} ${gt('labels')}',
                        style: labelText(13, FontWeight.w800, AppColors.red)),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                      '${r.templateName} - ${labelModeName(r.mode)}',
                      style: labelText(12, FontWeight.w600, AppColors.ink3)),
                  Text(
                      '${_when(r.printedAt)}${r.actorName.isEmpty ? '' : ' - ${r.actorName}'}',
                      style: labelText(12, FontWeight.w600, AppColors.ink3)),
                ],
              ),
            ),
          ),
        if (_hasMore)
          AppButton('Load more',
              variant: BtnVariant.secondary,
              block: true,
              loading: _more,
              onTap: _more ? null : () => _load(more: true)),
      ],
    );
  }
}
