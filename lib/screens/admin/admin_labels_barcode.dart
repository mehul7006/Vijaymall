import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../data/api/label_dto.dart';
import '../../data/label_store.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/buttons.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import 'admin_labels_common.dart';

/// "Generate store barcode" for one variant (`POST /admin/variants/{id}/barcode/generate`).
///
/// Shows the code, whether it was just made, every barcode of the variant and
/// the check-digit result. Returns the answer so the caller can refresh its
/// barcode field.
Future<GeneratedBarcode?> showGenerateBarcodeSheet(
  BuildContext context, {
  required String variantId,
  required String name,
}) {
  return showAppSheet<GeneratedBarcode>(
    context: context,
    title: 'Generate store barcode',
    sub: name,
    builder: (ctx) => _GenerateBody(variantId: variantId),
  );
}

class _GenerateBody extends StatefulWidget {
  final String variantId;
  const _GenerateBody({required this.variantId});

  @override
  State<_GenerateBody> createState() => _GenerateBodyState();
}

class _GenerateBodyState extends State<_GenerateBody> {
  bool _busy = false;
  String? _error;
  GeneratedBarcode? _r;

  Future<void> _run() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await LabelStore.instance.api.generateBarcode(widget.variantId);
      if (!mounted) return;
      setState(() {
        _r = r;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = labelError(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Text(
            gt('Gives this pack a store-internal EAN-13 so a printed label scans at the counter. '
                'If it already has a store barcode, the same one is returned.'),
            style: labelText(13, FontWeight.w600, AppColors.ink2),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: labelText(13, FontWeight.w700, AppColors.red)),
          ),
        if (r != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.created ? gt('New barcode created') : gt('Already had a store barcode'),
                    style: labelText(12, FontWeight.w800, AppColors.ink3)),
                const SizedBox(height: 4),
                SelectableText(r.barcode,
                    style: labelText(22, FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  validGtin(r.barcode) && r.barcode.length == 13
                      ? gt('Check digit is correct (EAN-13)')
                      : gt('Check digit does not match - tell the backend team'),
                  style: labelText(
                      12,
                      FontWeight.w700,
                      validGtin(r.barcode) && r.barcode.length == 13
                          ? AppColors.green
                          : AppColors.red),
                ),
                if (r.barcodes.length > 1) ...[
                  const SizedBox(height: 8),
                  Text('${gt('All barcodes')}: ${r.barcodes.join(', ')}',
                      style: labelText(12, FontWeight.w600, AppColors.ink2)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppButton('Copy barcode',
              variant: BtnVariant.secondary,
              block: true,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: r.barcode));
                showToast('Copied');
              }),
          const SizedBox(height: 8),
          AppButton('Print labels for this pack',
              block: true,
              onTap: () {
                Navigator.of(context).pop(r);
                go('/admin/labels?variant=${widget.variantId}');
              }),
          const SizedBox(height: 8),
          AppButton('Done',
              variant: BtnVariant.secondary,
              block: true,
              onTap: () => Navigator.of(context).pop(r)),
        ] else ...[
          AppButton(_error == null ? 'Generate barcode' : 'Try again',
              block: true, loading: _busy, onTap: _busy ? null : _run),
          const SizedBox(height: 8),
          const Hint(
              'Items sold by weight use their item code (PLU), not a barcode.'),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
