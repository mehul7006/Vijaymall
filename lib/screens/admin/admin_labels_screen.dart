import 'package:flutter/material.dart';

import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/gu_strings.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import 'admin_labels_history.dart';
import 'admin_labels_print.dart';
import 'admin_labels_templates.dart';

/// `#/admin/labels` - barcode labels (`72-barcode-labels.md`, playbook P2).
///
/// Query: `tab` = `print` (default) / `templates` / `history`; `variant=<id>`
/// preselects a pack to print (from the inventory shortcut); on the templates
/// tab `new=1`, `edit=<id>` and `dup=<id>` open the template form.
class AdminLabelsScreen extends StatelessWidget {
  final Map<String, String> query;
  const AdminLabelsScreen({super.key, this.query = const {}});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    // Writing templates is ADMIN only; the cashier prints and reads.
    final canEdit = state.adminPagesAllowed;
    final tab = const {'print', 'templates', 'history'}.contains(query['tab'])
        ? query['tab']!
        : 'print';
    final isForm = tab == 'templates' &&
        canEdit &&
        (query['new'] == '1' ||
            (query['edit'] ?? '').isNotEmpty ||
            (query['dup'] ?? '').isNotEmpty);

    final Widget body;
    if (isForm) {
      body = LabelTemplateForm(
        key: ValueKey('form-${query['edit']}-${query['dup']}-${query['new']}'),
        editId: query['edit'],
        dupOf: query['dup'],
      );
    } else {
      body = switch (tab) {
        'templates' => LabelTemplatesTab(canEdit: canEdit),
        'history' => LabelHistoryTab(key: ValueKey(query['variant'] ?? ''), variantId: query['variant']),
        _ => LabelPrintTab(
            key: ValueKey(query['variant'] ?? ''), variantId: query['variant']),
      };
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: isForm
                      ? (query['edit'] != null ? 'Edit template' : 'New template')
                      : 'Barcode labels',
                  sub: 'Templates, printing and history',
                  bell: false,
                  onBack: () {
                    if (isForm) {
                      go('/admin/labels?tab=templates');
                    } else if (!Nav.instance.pop()) {
                      go('/admin/more');
                    }
                  },
                ),
                if (!isForm)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Segmented(
                      options: [
                        SegmentOption('print', gt('Print')),
                        SegmentOption('templates', gt('Templates')),
                        SegmentOption('history', gt('History')),
                      ],
                      value: tab,
                      onChanged: (v) => go('/admin/labels?tab=$v'
                          '${query['variant'] != null && v != 'templates' ? '&variant=${query['variant']}' : ''}'),
                    ),
                  ),
                ScreenScroll(child: body),
              ],
            ),
            const AdminNav(active: 'more'),
          ],
        ),
      ),
    );
  }
}
