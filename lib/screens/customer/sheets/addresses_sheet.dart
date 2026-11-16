import 'package:flutter/material.dart';
import '../../../data/validators.dart';
import '../../../data/api/api_exception.dart';

import '../../../provider/state_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/fields.dart';
import '../../../widgets/panels.dart';
import '../../../widgets/sheet.dart';
import '../../../widgets/toast.dart';
import '../../../state/gu_strings.dart';

/// §3.14 `Delivery address` — pick a saved address or add a new one.
void showAddressSheet(BuildContext context) {
  showAppSheet<void>(
    context: context,
    title: gt('Delivery address'),
    sub: gt('Where should we deliver this order?'),
    builder: (ctx) => const _AddressesBody(),
    footer: Builder(
      builder: (c) => AppButton(
        'Done',
        variant: BtnVariant.secondary,
        block: true,
        onTap: () => Navigator.of(c).maybePop(),
      ),
    ),
  );
}

class _AddressesBody extends StatefulWidget {
  const _AddressesBody();

  @override
  State<_AddressesBody> createState() => _AddressesBodyState();
}

class _AddressesBodyState extends State<_AddressesBody> {
  final _label = TextEditingController();
  final _phone = TextEditingController();
  final _detail = TextEditingController();
  final _area = TextEditingController();
  final _pincode = TextEditingController();
  String _detailErr = '';
  String _phoneErr = '';
  String _areaErr = '';
  String _pinErr = '';

  @override
  void dispose() {
    _label.dispose();
    _phone.dispose();
    _detail.dispose();
    _area.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final st = StateScope.read(context);
    final d = digits(_phone.text);
    // Prototype stores the phone as `first5 last5`.
    final phone = d.length == 10 ? '${d.substring(0, 5)} ${d.substring(5)}' : _phone.text;

    // Validate every field up front so all problems show at once — the
    // backend requires `line1`, `area` and a 6-digit `pincode`, and a rejected
    // save would otherwise only surface as a toast after the fact.
    final detail = _detail.text.trim();
    final area = _area.text.trim();
    final pincode = _pincode.text.trim();
    final detailErr = detail.isEmpty
        ? 'Add the full delivery address'
        : (detail.length > 200 ? 'Address must be 200 characters or fewer' : '');
    final areaErr = area.isEmpty
        ? 'Add the area / locality'
        : (area.length > 80 ? 'Area must be 80 characters or fewer' : '');
    final pinErr = Validators.pincode(pincode, required: true) ?? '';
    final phoneErr = Validators.mobile(d) ?? '';
    if (detailErr.isNotEmpty ||
        areaErr.isNotEmpty ||
        pinErr.isNotEmpty ||
        phoneErr.isNotEmpty) {
      setState(() {
        _detailErr = detailErr;
        _areaErr = areaErr;
        _pinErr = pinErr;
        _phoneErr = phoneErr;
      });
      return;
    }

    final err = st.addAddress(_label.text, detail, phone,
        area: area, pincode: pincode);
    if (err != null) {
      // Safety net — the checks above mirror `addAddress`'s own rules.
      setState(() {
        _phoneErr = err.contains('phone') ? err : '';
        _areaErr = err.contains('area') ? err : '';
        _pinErr = err.contains('pincode') ? err : '';
        _detailErr = err.contains('phone') ||
                err.contains('area') ||
                err.contains('pincode')
            ? ''
            : err;
      });
      return;
    }
    // Backend mode: wait for the server and highlight any rejected field.
    final newId = st.addresses.last.id;
    final sync = st.addressSync;
    if (sync != null) {
      final e = await sync;
      if (!mounted) return;
      if (e != null && e.isValidation) {
        final f = ApiException.takeFields();
        st.dropLocalAddress(newId);
        setState(() {
          _detailErr = ApiException.fieldError(f, ['line1', 'detail', 'address']) ?? '';
          _areaErr = ApiException.fieldError(f, ['area']) ?? '';
          _pinErr = ApiException.fieldError(f, ['pincode']) ?? '';
          _phoneErr = ApiException.fieldError(f, ['phone', 'mobile']) ?? '';
          if (f.isEmpty) _detailErr = e.message;
        });
        return;
      }
    }
    // Success: push + select, close the sheet, toast.
    st.selectAddress(st.addresses.last.id);
    Navigator.of(context).maybePop();
    showToast(gt('Address saved'));
  }

  @override
  Widget build(BuildContext context) {
    final st = StateScope.of(context);
    final selectedId = st.flow.selectedAddressId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (st.addresses.isEmpty) ...[
          const EmptyState(
            icon: 'pin',
            title: 'No saved addresses yet',
            copy: 'Add a delivery address below to continue.',
          ),
        ],
        for (final a in st.addresses) ...[
          SheetOption(
            title: a.isDefault ? '${a.label} · ${gt('Default')}' : a.label,
            sub: a.phone.isEmpty ? a.full : '${a.full} · ${a.phone}',
            selected: a.id == selectedId,
            onTap: () {
              st.selectAddress(a.id);
              Navigator.of(context).maybePop();
              showToast('Delivering to ${a.label}');
            },
          ),
          if (st.backendMode)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!a.isDefault)
                  TextButton(
                    style: TextButton.styleFrom(
                        minimumSize: const Size(64, 44)),
                    onPressed: () async {
                      final err = await st.makeDefaultAddress(a.id);
                      if (err != null) showToast(err, 'error');
                    },
                    child: Text(gt('Make default')),
                  ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                  onPressed: () => st.removeAddress(a.id),
                  child: Text(gt('Delete'),
                      style: const TextStyle(color: AppColors.red)),
                ),
              ],
            ),
        ],

        // `.field-row` add-address form.
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        Text(gt('Add another address'),
          style: const TextStyle(
            fontFamily: AppTheme.uiFont,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        FieldRow(
          children: [
              AppField(
                label: gt('Label'),
                controller: _label,
                placeholder: gt('Work'),
                maxLength: 20,
              ),
              AppField(
                label: gt('Phone (optional)'),
                controller: _phone,
                numeric: true,
                maxLength: 12,
                placeholder: '98765 43210',
                error: _phoneErr.isEmpty ? null : _phoneErr,
                onChanged: (_) => setState(() => _phoneErr = ''),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AppField(
          label: gt('Full address'),
          controller: _detail,
          placeholder: gt('Flat, street, landmark'),
          maxLength: 90,
          error: _detailErr.isEmpty ? null : _detailErr,
          onChanged: (_) => setState(() => _detailErr = ''),
        ),
        const SizedBox(height: 10),
        FieldRow(
          children: [
              AppField(
                label: gt('Area'),
                controller: _area,
                placeholder: gt('Locality'),
                maxLength: 40,
                error: _areaErr.isEmpty ? null : _areaErr,
                onChanged: (_) => setState(() => _areaErr = ''),
              ),
              AppField(
                label: gt('Pincode'),
                controller: _pincode,
                numeric: true,
                maxLength: 6,
                placeholder: '380015',
                error: _pinErr.isEmpty ? null : _pinErr,
                onChanged: (_) => setState(() => _pinErr = ''),
              ),
          ],
        ),
        const SizedBox(height: 14),
        AppButton(
          'Save address',
          icon: 'plus',
          block: true,
          onTap: _save,
        ),
            ],
          ),
        ),
      ],
    );
  }
}
