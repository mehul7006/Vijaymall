import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart' show Api;
import '../../data/api/dto.dart';
import '../../data/seed_data.dart' as seed;
import '../../data/validators.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import '../../state/gu_strings.dart';

/// `#/admin/shop-settings` — store details (name/address/phone/GST/UTR).
///
/// Saved via `PUT /admin/shop-settings`; the same values feed the store info
/// shown across admin and customer screens.
class AdminShopSettingsScreen extends StatelessWidget {
  const AdminShopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ShopSettingsBody();
}

class _ShopSettingsBody extends StatefulWidget {
  const _ShopSettingsBody();

  @override
  State<_ShopSettingsBody> createState() => _ShopSettingsBodyState();
}

class _ShopSettingsBodyState extends State<_ShopSettingsBody> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _gstin = TextEditingController();
  final _stateCode = TextEditingController();
  final _upiId = TextEditingController();
  final _invoicePrefix = TextEditingController();
  final _footer = TextEditingController();
  final _details = TextEditingController();
  final _promise = TextEditingController();
  final _shortName = TextEditingController();
  final _nameGu = TextEditingController();
  final _addressGu = TextEditingController();
  final _promiseGu = TextEditingController();
  final _detailsGu = TextEditingController();
  Map<String, String> _localErr = const {};
  Map<String, String> _fieldErr = const {};
  int _rev = 0;
  bool _refreshing = false;
  final _weighedPrefix = TextEditingController();
  String _weighedMode = 'WEIGHT_GRAMS';
  bool _loaded = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final state = StateScope.read(context);
    final s = state.shopSettings;
    _name.text = s?.shopName ?? seed.store.name;
    _address.text = s?.address ?? seed.store.address;
    _phone.text = s?.phone ?? seed.store.phone;
    _gstin.text = s?.gstin ?? '';
    _stateCode.text = s?.stateCode ?? '';
    _upiId.text = s?.upiId ?? '';
    _invoicePrefix.text = s?.invoicePrefix ?? '';
    _footer.text = s?.receiptFooter ?? '';
    _details.text = s?.details ?? '';
    _promise.text = s?.promise ?? seed.store.promise;
    _weighedPrefix.text = s?.weighedPrefix ?? '';
    _weighedMode = s?.weighedMode ?? 'WEIGHT_GRAMS';
    _origPrefix = _weighedPrefix.text.trim();
    _origMode = _weighedMode;
    _loadGu(s);
    // The app may not have the admin settings yet (the form would show
    // placeholders and a save would overwrite the real GSTIN, UPI id, prefix
    // and texts with blanks): read them from the server first.
    if (s == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromApi());
    }
  }

  String _origPrefix = '';
  String _origMode = 'WEIGHT_GRAMS';

  /// `GET /admin/shop-settings` straight into the form.
  Future<void> _loadFromApi() async {
    try {
      final s = await Api.instance.admin.getShop();
      if (!mounted) return;
      setState(() {
        _rev++;
        _name.text = s.shopName ?? _name.text;
        _address.text = s.address ?? '';
        _phone.text = s.phone ?? '';
        _gstin.text = s.gstin ?? '';
        _stateCode.text = s.stateCode ?? '';
        _upiId.text = s.upiId ?? '';
        _invoicePrefix.text = s.invoicePrefix ?? '';
        _footer.text = s.receiptFooter ?? '';
        _details.text = s.details ?? '';
        _promise.text = s.promise ?? '';
        _weighedPrefix.text = s.weighedPrefix ?? '';
        _weighedMode = s.weighedMode ?? 'WEIGHT_GRAMS';
        _origPrefix = _weighedPrefix.text.trim();
        _origMode = _weighedMode;
        _loadGu(s);
      });
    } catch (_) {
      // The form keeps what the app had; the server still validates a save.
    }
  }

  void _loadGu(ShopSettingDto? s) {
    _shortName.text = s?.shortName ?? '';
    _nameGu.text = s?.shopNameGu ?? '';
    _addressGu.text = s?.addressGu ?? '';
    _promiseGu.text = s?.promiseGu ?? '';
    _detailsGu.text = s?.detailsGu ?? '';
  }

  @override
  void dispose() {
    _shortName.dispose();
    _nameGu.dispose();
    _addressGu.dispose();
    _promiseGu.dispose();
    _detailsGu.dispose();
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _gstin.dispose();
    _stateCode.dispose();
    _upiId.dispose();
    _invoicePrefix.dispose();
    _footer.dispose();
    _details.dispose();
    _promise.dispose();
    _weighedPrefix.dispose();
    super.dispose();
  }

  /// Format and length checks (Swagger limits) shown under each field.
  Map<String, String> _validate() {
    final e = <String, String>{};
    void put(String k, String? m) {
      if (m != null) e[k] = gt(m);
    }

    put('shopName',
        Validators.text(_name.text, label: 'Shop name', required: true, max: 80));
    put('phone', _phoneError(_phone.text));
    put('address', Validators.text(_address.text, label: 'Address', max: 300));
    put('promise', Validators.text(_promise.text, label: 'Tagline', max: 200));
    put('receiptFooter',
        Validators.text(_footer.text, label: 'Receipt footer', max: 200));
    put('details', Validators.text(_details.text, label: 'Shop details', max: 500));
    put('gstin', Validators.gstin(_gstin.text));
    final sc = _stateCode.text.trim();
    if (sc.isNotEmpty && !RegExp(r'^\d{2}$').hasMatch(sc)) {
      e['stateCode'] = gt('State code must be 2 digits (for example 24)');
    }
    // Server rule: name@bank, `^[\w.\-]{2,}@[\w]{2,}$`.
    final upi = _upiId.text.trim();
    if (upi.isNotEmpty && !RegExp(r'^[\w.\-]{2,}@\w{2,}$').hasMatch(upi)) {
      e['upiId'] = gt('Enter a valid UPI ID, like name@bank');
    }
    // Server rule: 2 to 6 capital letters or digits (it upper-cases).
    final ip = _invoicePrefix.text.trim().toUpperCase();
    if (ip.isNotEmpty && !RegExp(r'^[A-Z0-9]{2,6}$').hasMatch(ip)) {
      e['invoicePrefix'] =
          gt('Invoice prefix: 2 to 6 capital letters or digits');
    }
    final wp = _weighedPrefix.text.trim();
    if (wp.isNotEmpty && !RegExp(r'^\d{1,2}$').hasMatch(wp)) {
      e['weighedPrefix'] = gt('Weighed prefix must be 1 or 2 digits');
    }
    put('shortName', Validators.text(_shortName.text, label: 'Short name', max: 20));
    put('shopNameGu',
        Validators.text(_nameGu.text, label: 'Shop name (Gujarati)', max: 80));
    put('addressGu',
        Validators.text(_addressGu.text, label: 'Address (Gujarati)', max: 300));
    put('promiseGu',
        Validators.text(_promiseGu.text, label: 'Tagline (Gujarati)', max: 200));
    put('detailsGu',
        Validators.text(_detailsGu.text, label: 'Details (Gujarati)', max: 500));
    return e;
  }

  /// Shop phone: 7 to 15 digits, with spaces, + and - allowed (Swagger).
  String? _phoneError(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;
    if (!RegExp(r'^[0-9 +\-]+$').hasMatch(t)) {
      return 'Phone can only have digits, spaces, + and -';
    }
    final n = t.replaceAll(RegExp(r'\D'), '').length;
    if (n < 7 || n > 15) return 'Phone must have 7 to 15 digits';
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final local = _validate();
    setState(() => _localErr = local);
    if (local.isNotEmpty) {
      showToast(local.values.first, 'error');
      return;
    }
    ApiException.clearFields();
    setState(() {
      _saving = true;
      _fieldErr = const {};
    });
    final state = StateScope.read(context);
    final err = await state.saveShopSettings(
      shopName: _name.text,
      address: _address.text,
      phone: _phone.text,
      gstin: _gstin.text,
      stateCode: _stateCode.text,
      upiId: _upiId.text,
      invoicePrefix: _invoicePrefix.text,
      receiptFooter: _footer.text,
      weighedPrefix: _weighedPrefix.text,
      weighedMode: _weighedMode,
      details: _details.text,
      promise: _promise.text,
      shortName: _shortName.text,
      shopNameGu: _nameGu.text,
      addressGu: _addressGu.text,
      promiseGu: _promiseGu.text,
      detailsGu: _detailsGu.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      setState(() => _fieldErr = ApiException.takeFields());
      showToast(err, 'error');
      return;
    }
    showToast(gt('Shop settings saved'));
  }

  /// Hard refresh: drop the cached store profile, refetch from the server and
  /// reload the form from the fresh admin settings.
  Future<void> _refreshFromServer() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final state = StateScope.read(context);
    await state.refreshStoreProfile(force: true);
    if (!mounted) return;
    final s = state.shopSettings;
    setState(() {
      _refreshing = false;
      _rev++;
      _name.text = s?.shopName ?? seed.store.name;
      _address.text = s?.address ?? seed.store.address;
      _phone.text = s?.phone ?? seed.store.phone;
      _gstin.text = s?.gstin ?? '';
      _stateCode.text = s?.stateCode ?? '';
      _upiId.text = s?.upiId ?? '';
      _invoicePrefix.text = s?.invoicePrefix ?? '';
      _footer.text = s?.receiptFooter ?? '';
      _details.text = s?.details ?? '';
      _promise.text = s?.promise ?? seed.store.promise;
      _weighedPrefix.text = s?.weighedPrefix ?? '';
      _weighedMode = s?.weighedMode ?? 'WEIGHT_GRAMS';
      _loadGu(s);
    });
    showToast(gt('Store details reloaded from the server'), 'success');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Shop settings'),
                  sub: gt('Store details, GST and receipts'),
                  bell: false,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                ScreenScroll(
                  bottom: 16,
                  child: KeyedSubtree(
                    key: ValueKey(_rev),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardPanel(
                        title: gt('Shop profile'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gt('Logo, opening hours, e-mail, WhatsApp, map, website, social links and the pause-online-orders switch live in the shop profile.'),
                              style: TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink2,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            AppButton(
                              'Edit logo, hours & links',
                              block: true,
                              variant: BtnVariant.secondary,
                              onTap: () => go('/admin/system?tab=profile'),
                            ),
                            const SizedBox(height: 8),
                            AppButton(
                              'Refresh from server',
                              block: true,
                              variant: BtnVariant.soft,
                              icon: 'refresh',
                              loading: _refreshing,
                              onTap: _refreshFromServer,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      CardPanel(
                        title: gt('Store details'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FieldRow(
                              flex: const [3, 2],
                              children: [
                                AppField(
                                  label: gt('Shop name'),
                                  value: _name.text,
                                  placeholder: seed.store.name,
                                  maxLength: 80,
                                  error: _localErr['shopName'] ?? _fieldErr['shopName'],
                                  onChanged: (v) => _name.text = v,
                                ),
                                AppField(
                                  label: gt('Phone'),
                                  value: _phone.text,
                                  numeric: true,
                                  placeholder: gt('Phone number'),
                                  maxLength: 16,
                                  error: _localErr['phone'] ?? _fieldErr['phone'],
                                  onChanged: (v) => _phone.text = v,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            AppField(
                              label: gt('Address'),
                              value: _address.text,
                              placeholder: gt('Shop address, city, pincode'),
                              error: _localErr['address'] ?? _fieldErr['address'],
                              onChanged: (v) => _address.text = v,
                            ),
                            const SizedBox(height: 10),
                            AppField(
                              label: gt('Tagline (shown to customers)'),
                              value: _promise.text,
                              placeholder: gt('Free Home Delivery'),
                              error: _localErr['promise'] ?? _fieldErr['promise'],
                              onChanged: (v) => _promise.text = v,
                            ),
                            const SizedBox(height: 10),
                            AppField(
                              label: gt('Receipt footer'),
                              value: _footer.text,
                              placeholder: gt('Thank you · visit again'),
                              error: _localErr['receiptFooter'] ?? _fieldErr['receiptFooter'],
                              onChanged: (v) => _footer.text = v,
                            ),
                            const SizedBox(height: 10),
                            AppField(
                              label: gt('Shop details'),
                              value: _details.text,
                              placeholder:
                                  'About the store — shown to customers (max 500)',
                              error: _localErr['details'] ?? _fieldErr['details'],
                              onChanged: (v) => _details.text = v,
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                              '${_details.text.length} / 500',
                              style: TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _details.text.length > 500
                                    ? AppColors.red
                                    : AppColors.ink3,
                              ),
                            ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      CardPanel(
                        title: gt('Gujarati texts and short name'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Hint(
                                'Shown when the app is in Gujarati. Leave blank to show the English text.'),
                            const SizedBox(height: 10),
                            FieldRow(
                              flex: const [2, 3],
                              children: [
                                AppField(
                                  label: gt('Short name (tight spaces)'),
                                  value: _shortName.text,
                                  maxLength: 20,
                                  error: _localErr['shortName'] ?? _fieldErr['shortName'],
                                  onChanged: (v) => _shortName.text = v,
                                ),
                                AppField(
                                  label: gt('Shop name (Gujarati)'),
                                  value: _nameGu.text,
                                  maxLength: 80,
                                  error: _localErr['shopNameGu'] ?? _fieldErr['shopNameGu'],
                                  onChanged: (v) => _nameGu.text = v,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            AppField(
                              label: gt('Address (Gujarati)'),
                              value: _addressGu.text,
                              maxLength: 300,
                              error: _localErr['addressGu'] ?? _fieldErr['addressGu'],
                              onChanged: (v) => _addressGu.text = v,
                            ),
                            const SizedBox(height: 10),
                            AppField(
                              label: gt('Tagline (Gujarati)'),
                              value: _promiseGu.text,
                              maxLength: 200,
                              error: _localErr['promiseGu'] ?? _fieldErr['promiseGu'],
                              onChanged: (v) => _promiseGu.text = v,
                            ),
                            const SizedBox(height: 10),
                            AppField(
                              label: gt('Shop details (Gujarati)'),
                              value: _detailsGu.text,
                              maxLength: 500,
                              error: _localErr['detailsGu'] ?? _fieldErr['detailsGu'],
                              onChanged: (v) => _detailsGu.text = v,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      CardPanel(
                        title: gt('GST & payments'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FieldRow(
                              flex: const [3, 1],
                              children: [
                                AppField(
                                  label: gt('GSTIN'),
                                  value: _gstin.text,
                                  uppercase: true,
                                  placeholder: '24ABCDE1234F1Z5',
                                  maxLength: 15,
                                  error: _localErr['gstin'] ?? _fieldErr['gstin'],
                                  onChanged: (v) => _gstin.text = v,
                                ),
                                AppField(
                                  label: gt('State code'),
                                  value: _stateCode.text,
                                  numeric: true,
                                  placeholder: '24',
                                  maxLength: 2,
                                  error: _localErr['stateCode'] ?? _fieldErr['stateCode'],
                                  onChanged: (v) => _stateCode.text = v,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            FieldRow(
                              flex: const [2, 1],
                              children: [
                                AppField(
                                  label: gt('UPI ID'),
                                  value: _upiId.text,
                                  placeholder: gt('shop@upi'),
                                  maxLength: 60,
                                  error: _localErr['upiId'] ?? _fieldErr['upiId'],
                                  onChanged: (v) => _upiId.text = v,
                                ),
                                AppField(
                                  label: gt('Invoice prefix'),
                                  value: _invoicePrefix.text,
                                  uppercase: true,
                                  placeholder: gt('VSM'),
                                  maxLength: 6,
                                  error: _localErr['invoicePrefix'] ?? _fieldErr['invoicePrefix'],
                                  onChanged: (v) => _invoicePrefix.text = v,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Hint(
                                'Changing the prefix affects only new invoice numbers. Blank keeps VSM.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      CardPanel(
                        title: gt('Weighed items'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FieldRow(
                              flex: const [2, 3],
                              children: [
                                AppField(
                                  label: gt('Weighed prefix (1-2 digits)'),
                                  value: _weighedPrefix.text,
                                  numeric: true,
                                  placeholder: '2',
                                  maxLength: 2,
                                  error: _localErr['weighedPrefix'] ?? _fieldErr['weighedPrefix'],
                                  onChanged: (v) =>
                                      setState(() => _weighedPrefix.text = v),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(gt('Weighed mode'),
                                      style: TextStyle(
                                        fontFamily: AppTheme.uiFont,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Segmented(
                                      options: const [
                                        SegmentOption('WEIGHT_GRAMS', 'Grams'),
                                        SegmentOption('PRICE_PAISE', 'Price (paise)'),
                                      ],
                                      value: _weighedMode,
                                      onChanged: (v) =>
                                          setState(() => _weighedMode = v),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (_weighedMode != _origMode ||
                                _weighedPrefix.text.trim() != _origPrefix) ...[
                              const SizedBox(height: 8),
                              Text(
                                  gt('You changed how scale labels are read. Reprint the scale labels after saving.'),
                                  style: const TextStyle(
                                      fontFamily: AppTheme.uiFont,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.red)),
                            ],
                            const SizedBox(height: 8),
                            const Hint(
                              'This is what the number inside a weighed-item '
                              'barcode means. To sell by kg, per item or per '
                              'dozen, add those units under More > Units and '
                              'pick one on each product pack.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                  ),
                ),
                AdminSaveBar(
                  child: AppButton(
                    'Save shop settings',
                    block: true,
                    loading: _saving,
                    onTap: _saving ? null : _save,
                  ),
                ),
              ],
            ),
            const AdminNav(active: 'more'),
          ],
        ),
      ),
    );
  }
}
