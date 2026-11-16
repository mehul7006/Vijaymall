import '../../state/gu_strings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/validators.dart';
import '../../data/api/api_service.dart';
import '../../data/api/dto_ops.dart';
import '../../data/store_profile_cache.dart';
import '../../data/web_file_picker.dart';
import '../../widgets/app_icon.dart' show LogoMark;
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/confirm.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/chrome.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import 'admin_bank_defaults.dart' show BankSettingKeys, AccountSettingField;

/// `#/admin/system` - the owner's operations desk from
/// `20-orders-payments-admin-config.md`: refunds (retry failed ones), shop
/// profile (hours, contact links, logo, pause online orders), the generic
/// configuration screen with start-up health and "Test" buttons, caches and
/// log status. ADMIN only (the backend answers 403 to anyone else).
class AdminSystemScreen extends StatefulWidget {
  const AdminSystemScreen({super.key, this.tab = 'refunds'});

  final String tab;

  @override
  State<AdminSystemScreen> createState() => _AdminSystemScreenState();
}

TextStyle _t(double size, FontWeight w, Color c) => TextStyle(
    fontFamily: AppTheme.uiFont, fontSize: size, fontWeight: w, color: c);

String _err(Object e) =>
    e is ApiException ? e.message : 'Something went wrong. Please try again.';

class _AdminSystemScreenState extends State<AdminSystemScreen> {
  static const _tabs = {
    'refunds': 'Refunds',
    'profile': 'Shop profile',
    'config': 'Configuration',
    'caches': 'Caches & logs',
  };
  late String _tab = _tabs.containsKey(widget.tab) ? widget.tab : 'refunds';

  @override
  void didUpdateWidget(covariant AdminSystemScreen old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) {
      _tab = _tabs.containsKey(widget.tab) ? widget.tab : 'refunds';
    }
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
                  title: 'Operations',
                  sub: 'Refunds, shop profile, configuration, caches',
                  bell: false,
                  onBack: () => go('/admin/more'),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final e in _tabs.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: _tab == e.key,
                            onSelected: (_) => setState(() => _tab = e.key),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ScreenScroll(
                    child: switch (_tab) {
                      'profile' => const _ProfileTab(),
                      'config' => const _ConfigTab(),
                      'caches' => const _CachesTab(),
                      _ => const _RefundsTab(),
                    },
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

// ---------------------------------------------------------------------------
// Refunds
// ---------------------------------------------------------------------------

class _RefundsTab extends StatefulWidget {
  const _RefundsTab();

  @override
  State<_RefundsTab> createState() => _RefundsTabState();
}

class _RefundsTabState extends State<_RefundsTab> {
  String _status = 'FAILED';
  List<RefundDto> _items = const [];
  bool _loading = true;
  String? _error;
  String? _retrying;
  int _page = 0;
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    if (!next) _page = 0;
    setState(() {
      _loading = !next;
      _error = null;
    });
    try {
      final p = await Api.instance.ops
          .listRefunds(status: _status, page: next ? _page + 1 : 0);
      if (mounted) {
        setState(() {
          _page = p.page;
          _more = p.hasMore;
          _items = next ? [..._items, ...p.items] : p.items;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _retry(RefundDto r) async {
    setState(() => _retrying = r.id);
    try {
      await Api.instance.ops.retryRefund(r.id);
      showToast('Refund queued again', 'success');
      await _load();
    } on ApiException catch (e) {
      showToast(e.code == 'REFUND_NOT_FAILED'
          ? 'Only a failed refund can be retried'
          : e.message, 'error');
    }
    if (mounted) setState(() => _retrying = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final s in const ['FAILED', 'PENDING', 'PROCESSING', 'ISSUED', ''])
              ChoiceChip(
                label: Text(s.isEmpty ? 'All' : s[0] + s.substring(1).toLowerCase()),
                selected: _status == s,
                onSelected: (_) {
                  _status = s;
                  _load();
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        CardPanel(
          title: 'Refunds sent back to customers',
          child: _loading
              ? const SkeletonRows(rows: 3)
              : _error != null
                  ? ErrorRetry(
                      title: "Couldn't load refunds",
                      message: _error!,
                      onRetry: _load)
                  : _items.isEmpty
                      ? Text('Nothing here.',
                          style: _t(13, FontWeight.w600, AppColors.ink3))
                      : Column(
                          children: [
                            for (final r in _items)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${money(r.amountPaise / 100)} · ${r.status}',
                                              style: _t(14, FontWeight.w800,
                                                  r.status == 'FAILED'
                                                      ? AppColors.red
                                                      : AppColors.ink)),
                                          Text(r.reason,
                                              style: _t(12, FontWeight.w600,
                                                  AppColors.ink2)),
                                          if (r.status == 'FAILED' ||
                                              r.attempts > 0)
                                            Text(
                                                'Attempts ${r.attempts}${r.lastError.isEmpty ? '' : ' · ${r.lastError}'}',
                                                style: _t(11.5, FontWeight.w600,
                                                    AppColors.ink3)),
                                        ],
                                      ),
                                    ),
                                    if (r.status == 'FAILED')
                                      AppButton('Retry',
                                          size: BtnSize.sm,
                                          loading: _retrying == r.id,
                                          onTap: () => _retry(r)),
                                  ],
                                ),
                              ),
                            if (_more)
                              AppButton('Load more',
                                  size: BtnSize.sm,
                                  variant: BtnVariant.secondary,
                                  onTap: () => _load(next: true)),
                          ],
                        ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shop profile
// ---------------------------------------------------------------------------

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  ShopProfileDto? _p;
  String? _error;
  bool _busy = false;
  Map<String, String> _fe = const {};
  final _c = <String, TextEditingController>{};

  static const _fields = {
    'email': 'Contact e-mail',
    'whatsapp': 'WhatsApp number (10-15 digits)',
    'mapUrl': 'Map link (https://...)',
    'website': 'Website (https://...)',
    'instagram': 'Instagram (https://...)',
    'facebook': 'Facebook (https://...)',
    'holidayNote': 'Holiday note (max 200)',
    'holidayNoteGu': 'Holiday note in Gujarati (max 200)',
    'onlineOrdersMessage': 'Message shown while orders are paused',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _get(ShopProfileDto p, String k) => switch (k) {
        'email' => p.email,
        'whatsapp' => p.whatsapp,
        'mapUrl' => p.mapUrl,
        'website' => p.website,
        'instagram' => p.instagram,
        'facebook' => p.facebook,
        'holidayNote' => p.holidayNote,
        'holidayNoteGu' => p.holidayNoteGu,
        _ => p.onlineOrdersMessage,
      };

  void _adopt(ShopProfileDto p) {
    _p = p;
    for (final k in _fields.keys) {
      (_c[k] ??= TextEditingController()).text = _get(p, k);
    }
  }

  Future<void> _load() async {
    try {
      final p = await Api.instance.ops.getShopProfile();
      if (mounted) setState(() => _adopt(p));
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
  }

  /// Format/length checks before the PUT (Swagger + guide limits).
  Map<String, String> _check() {
    final e = <String, String>{};
    void put(String k, String? m) {
      if (m != null) e[k] = gt(m);
    }

    put('email', Validators.email(_c['email']!.text));
    // Server rule: spaces removed, then `^\+?[0-9]{10,15}$`.
    final wa = _c['whatsapp']!.text.replaceAll(' ', '');
    if (wa.isNotEmpty && !RegExp(r'^\+?[0-9]{10,15}$').hasMatch(wa)) {
      e['whatsapp'] = gt('WhatsApp number must be 10 to 15 digits');
    }
    for (final k in const ['mapUrl', 'website', 'instagram', 'facebook']) {
      final v = _c[k]!.text.trim();
      if (v.isEmpty) continue;
      final u = Uri.tryParse(v);
      if (v.length > 300 ||
          u == null ||
          u.scheme.toLowerCase() != 'https' ||
          u.host.isEmpty) {
        e[k] = gt('Enter a full link starting with https://');
      }
    }
    // Opening hours: open must be strictly before close (no overnight spans).
    final hrs = _p?.hours ?? const <DayHoursDto>[];
    for (final d in hrs) {
      if (!d.closed && d.open.compareTo(d.close) >= 0) {
        e['hours'] = '${d.day}: ${gt('opening time must be before closing time')}';
        break;
      }
    }
    put('holidayNote',
        Validators.text(_c['holidayNote']!.text, label: 'Holiday note', max: 200));
    put('holidayNoteGu',
        Validators.text(_c['holidayNoteGu']!.text, label: 'Holiday note', max: 200));
    put('onlineOrdersMessage',
        Validators.text(_c['onlineOrdersMessage']!.text, label: 'Message', max: 200));
    return e;
  }

  Future<void> _save() async {
    final p = _p;
    if (p == null) return;
    final bad = _check();
    if (bad.isNotEmpty) {
      setState(() => _fe = bad);
      showToast(bad.values.first, 'error');
      return;
    }
    p
      ..holidayNoteGu = _c['holidayNoteGu']!.text
      ..email = _c['email']!.text
      ..whatsapp = _c['whatsapp']!.text
      ..mapUrl = _c['mapUrl']!.text
      ..website = _c['website']!.text
      ..instagram = _c['instagram']!.text
      ..facebook = _c['facebook']!.text
      ..holidayNote = _c['holidayNote']!.text
      ..onlineOrdersMessage = _c['onlineOrdersMessage']!.text;
    ApiException.clearFields();
    setState(() {
      _busy = true;
      _fe = const {};
    });
    try {
      final saved = await Api.instance.ops.saveShopProfile(p);
      if (!mounted) return;
      setState(() => _adopt(saved));
      showToast('Shop profile saved', 'success');
      // Customers hear about it through the `SHOP` live event; hard-refresh
      // our own cached copy of the public details so it shows at once.
      StateScope.read(context).refreshStoreProfile(force: true);
    } catch (e) {
      if (mounted) {
        setState(() => _fe = e is ApiException && e.fields.isNotEmpty
            ? e.fields
            : ApiException.takeFields());
      }
      showToast(_err(e), 'error');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _logo({required bool remove}) async {
    setState(() => _busy = true);
    try {
      ShopProfileDto saved;
      if (remove) {
        saved = await Api.instance.ops.deleteShopLogo();
      } else {
        final f = await pickImageFile();
        if (f == null) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        saved = await Api.instance.ops.uploadShopLogo(f.bytes, f.name);
      }
      if (mounted) {
        setState(() {
          _p?.logoUrl = saved.logoUrl;
          _p?.iconUrl = saved.iconUrl;
          _p?.icon192Url = saved.icon192Url;
        });
      }
      showToast(remove ? 'Logo removed' : 'Logo updated', 'success');
      if (mounted) {
        await StateScope.read(context).refreshStoreProfile(force: true);
      }
    } catch (e) {
      showToast(_err(e), 'error');
    }
    if (mounted) setState(() => _busy = false);
  }

  /// `POST /admin/shop-profile/logo/icon`: make the app icons again from the
  /// stored logo (shown when a logo exists but no icon yet).
  Future<void> _makeIcon() async {
    setState(() => _busy = true);
    try {
      final saved = await Api.instance.ops.createShopIcon();
      if (mounted) {
        setState(() {
          _p?.iconUrl = saved.iconUrl;
          _p?.icon192Url = saved.icon192Url;
        });
      }
      showToast('App icon created', 'success');
      if (mounted) {
        await StateScope.read(context).refreshStoreProfile(force: true);
      }
    } catch (e) {
      showToast(_err(e), 'error');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickTime(DayHoursDto d, bool open) async {
    final cur = (open ? d.open : d.close).split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(cur[0]) ?? 9, minute: int.tryParse(cur[1]) ?? 0),
    );
    if (t == null) return;
    final s =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => open ? d.open = s : d.close = s);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) {
      return _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : const SkeletonRows(rows: 5);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardPanel(
          title: 'Pause online orders',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    p.onlineOrdersEnabled
                        ? 'Taking online orders'
                        : 'Online orders are PAUSED',
                    style: _t(14, FontWeight.w800,
                        p.onlineOrdersEnabled ? AppColors.green : AppColors.red)),
                subtitle: const Text(
                    'While paused, customers cannot check out and see the message below.'),
                value: p.onlineOrdersEnabled,
                onChanged: _busy
                    ? null
                    : (v) async {
                        if (!v) {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Pause online orders?'),
                              content: const Text(
                                  'Customers will not be able to place new orders until you switch this back on.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Keep open')),
                                FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(gt('Pause'))),
                              ],
                            ),
                          );
                          if (ok != true) return;
                        }
                        setState(() => p.onlineOrdersEnabled = v);
                      },
              ),
              _field('onlineOrdersMessage'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: 'Logo',
          child: Row(
            children: [
              const LogoMark(size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    p.logoUrl.isEmpty ? 'No logo uploaded' : p.logoUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(12.5, FontWeight.w600, AppColors.ink2)),
              ),
              if (kIsWeb)
                AppButton('Upload',
                    size: BtnSize.sm,
                    variant: BtnVariant.secondary,
                    onTap: _busy ? null : () => _logo(remove: false)),
              if (p.logoUrl.isNotEmpty) ...[
                const SizedBox(width: 8),
                AppButton('Remove',
                    size: BtnSize.sm,
                    variant: BtnVariant.dangerSoft,
                    onTap: _busy
                        ? null
                        : () async {
                            final ok = await confirmAction(context,
                                title: 'Remove the shop logo?',
                                body: gt(
                                    'The logo is removed from the app and receipts. You can upload a new one afterwards.'),
                                confirmLabel: 'Remove');
                            if (ok && mounted) _logo(remove: true);
                          }),
              ],
            ],
          ),
        ),
        if (p.logoUrl.isNotEmpty && p.iconUrl.isEmpty) ...[
          const SizedBox(height: 8),
          AppButton('Create app icon from the logo',
              block: true,
              variant: BtnVariant.secondary,
              onTap: _busy ? null : _makeIcon),
        ] else if (p.iconUrl.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(gt('App icon ready (192 and 512 px). Replacing the logo makes new icons.'),
              style: _t(11.5, FontWeight.w600, AppColors.ink3)),
        ],
        const SizedBox(height: 12),
        CardPanel(
          title: 'Opening hours',
          child: Column(
            children: [
              for (final d in p.hours)
                Row(
                  children: [
                    SizedBox(
                        width: 44,
                        child: Text(d.day,
                            style: _t(13, FontWeight.w800, AppColors.ink))),
                    Checkbox(
                        value: d.closed,
                        onChanged: (v) => setState(() => d.closed = v ?? false)),
                    Text(gt('Closed'), style: _t(12, FontWeight.w600, AppColors.ink3)),
                    const Spacer(),
                    TextButton(
                        onPressed: d.closed ? null : () => _pickTime(d, true),
                        child: Text(d.open)),
                    const Text('-'),
                    TextButton(
                        onPressed: d.closed ? null : () => _pickTime(d, false),
                        child: Text(d.close)),
                  ],
                ),
              _field('holidayNote'),
              _field('holidayNoteGu'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: 'Contact links',
          child: Column(children: [
            for (final k in const [
              'email',
              'whatsapp',
              'mapUrl',
              'website',
              'instagram',
              'facebook'
            ])
              _field(k),
          ]),
        ),
        const SizedBox(height: 12),
        AppButton('Save shop profile', block: true, loading: _busy, onTap: _save),
        const SizedBox(height: 6),
        Text(
            'Saving replaces these fields: anything left blank is cleared. Name, address and phone are edited under Shop settings.',
            style: _t(11.5, FontWeight.w600, AppColors.ink3)),
      ],
    );
  }

  Widget _field(String k) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          controller: _c[k],
          decoration:
              InputDecoration(labelText: _fields[k], errorText: _fe[k]),
        ),
      );
}

// ---------------------------------------------------------------------------
// Configuration (server-described form)
// ---------------------------------------------------------------------------

class _ConfigTab extends StatefulWidget {
  const _ConfigTab();

  @override
  State<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<_ConfigTab> {
  ConfigViewDto? _view;
  List<BootstrapItemDto> _boot = const [];
  String? _error;
  bool _busy = false;
  final _edits = <String, String>{}; // key -> new value ('' clears)
  final _fieldErrors = <String, String>{};
  final _ctrls = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final v = await Api.instance.ops.getConfig();
      final b = await Api.instance.ops.getBootstrap();
      if (!mounted) return;
      setState(() {
        _view = v;
        _boot = b;
        _edits.clear();
        _fieldErrors.clear();
        for (final c in _ctrls.values) {
          c.dispose();
        }
        _ctrls.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
  }

  static final _uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// Same rule as the server: https, or plain http only for this computer (a test machine simulator).
  static bool _httpsOrLocal(String url) {
    final l = url.toLowerCase();
    return l.startsWith('https://') ||
        l.startsWith('http://localhost') ||
        l.startsWith('http://127.0.0.1');
  }

  /// Client-side range and format checks for the edited values, so a bad one
  /// is caught under its field before the request (the server still checks).
  Map<String, String> _checkEdits() {
    final out = <String, String>{};
    final items = {
      for (final g in _view!.groups)
        for (final it in g.items) it.key: it
    };
    _edits.forEach((k, v) {
      final it = items[k];
      if (it == null) return;
      // Paytm merchant key: exactly 16 characters (blank keeps / clears it).
      if (k == 'paytm.merchantKey' && v.isNotEmpty && v.length != 16) {
        out[k] = gt('The merchant key is exactly 16 characters');
        return;
      }
      final t = v.trim();
      if (t.isEmpty) return; // blank clears / falls back to the default
      if (it.type == 'INT') {
        final n = int.tryParse(t);
        if (n == null) {
          out[k] = gt('Enter a whole number');
        } else if (it.min != null && n < it.min!) {
          out[k] = '${gt('Must be at least')} ${it.min}';
        } else if (it.max != null && n > it.max!) {
          out[k] = '${gt('Must be at most')} ${it.max}';
        }
      } else if (it.type == 'STRING') {
        if (t.length > 500) {
          out[k] = gt('Too long (500 characters at most)');
        } else if ((k == 'payment.gatewayAccountId' ||
                k.startsWith('pos.defaultAccount.')) &&
            !_uuidRe.hasMatch(t)) {
          out[k] = gt('Pick the id of a money account (a UUID) or leave blank');
        } else if (k == 'otp.from' &&
            Validators.email(t) != null &&
            !t.contains('<')) {
          out[k] = gt('Enter a valid e-mail address');
        } else if ((k == 'paytm.baseUrl' || k == 'paytm.settlement.baseUrl') &&
            !_httpsOrLocal(t)) {
          out[k] = gt('Must start with https:// (http://localhost or http://127.0.0.1 is allowed for a test machine)');
        } else if (k == 'sms.http.url' &&
            !(t.startsWith('https://') || t.startsWith('http://'))) {
          out[k] = gt('Enter a full link starting with https://');
        } else if (k == 'sms.senderId' && t.length > 11) {
          out[k] = gt('Sender id is at most 11 characters');
        }
      }
    });
    return out;
  }

  Future<void> _save() async {
    final bad = _checkEdits();
    if (bad.isNotEmpty) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(bad);
      });
      showToast(bad.values.first, 'error');
      return;
    }
    setState(() {
      _busy = true;
      _fieldErrors.clear();
    });
    try {
      final v = await Api.instance.ops.saveConfig(Map.of(_edits));
      if (!mounted) return;
      setState(() {
        _view = v;
        _edits.clear();
        for (final c in _ctrls.values) {
          c.dispose();
        }
        _ctrls.clear();
      });
      showToast('Configuration saved', 'success');
    } on ApiException catch (e) {
      final p = e.payload;
      if (p is Map && p['details'] is Map && p['details']['fields'] is Map) {
        setState(() {
          (p['details']['fields'] as Map)
              .forEach((k, v) => _fieldErrors['$k'] = '$v');
        });
      }
      showToast(e.code == 'CONFIG_KEY_MISSING'
          ? 'The server has no secrets encryption key (CONFIG_ENCRYPTION_KEY), so secrets cannot be saved.'
          : e.message, 'error');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _test(String target) async {
    Map<String, String>? args;
    if (target == 'sms' || target == 'email') {
      final ctl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(target == 'sms' ? 'Send a test SMS' : 'Send a test e-mail'),
          content: TextField(
            controller: ctl,
            keyboardType: target == 'sms'
                ? TextInputType.phone
                : TextInputType.emailAddress,
            decoration: InputDecoration(
                labelText: target == 'sms' ? '10-digit mobile' : 'E-mail address'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send')),
          ],
        ),
      );
      final v = ctl.text.trim();
      ctl.dispose();
      if (ok != true || v.isEmpty) return;
      final bad = target == 'sms'
          ? Validators.mobile(v, required: true)
          : Validators.email(v, required: true);
      if (bad != null) {
        showToast(gt(bad), 'error');
        return;
      }
      args = {target == 'sms' ? 'mobile' : 'to': v};
    }
    setState(() => _busy = true);
    try {
      final r = await Api.instance.ops.testConfig(target, args: args);
      showToast(r.message, r.ok ? 'success' : 'error');
    } catch (e) {
      showToast(_err(e), 'error');
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _item(ConfigItemDto it) {
    final err = _fieldErrors[it.key];
    final edited = _edits.containsKey(it.key);
    Widget input;
    if (BankSettingKeys.kindsFor(it.key) != null) {
      // Money-account setting (bank module): pick an active account by name.
      input = AccountSettingField(
        label: it.label,
        settingKey: it.key,
        value: _edits[it.key] ?? it.value ?? '',
        onChanged: (v) => setState(() {
          if (v == (it.value ?? '')) {
            _edits.remove(it.key);
          } else {
            _edits[it.key] = v;
          }
        }),
      );
    } else {
    switch (it.type) {
      case 'BOOLEAN':
        final cur = (_edits[it.key] ?? it.value ?? 'false') == 'true';
        input = SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(it.label, style: _t(13.5, FontWeight.w700, AppColors.ink)),
          value: cur,
          onChanged: (v) async {
            // Auto write-off removes expired stock without anyone looking.
            if (it.key == 'inventory.autoWriteOffExpired' && v) {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(gt('Write off expired lots automatically?')),
                  content: Text(gt(
                      'Every night at 03:15 lots past their expiry date are taken out of stock without anyone checking them.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(gt('Cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(gt('Turn on'))),
                  ],
                ),
              );
              if (ok != true || !mounted) return;
            }
            setState(() => _edits[it.key] = v ? 'true' : 'false');
          },
        );
      case 'ENUM':
        final cur = _edits[it.key] ?? it.value ?? '';
        input = DropdownButtonFormField<String>(
          initialValue: it.allowed.contains(cur) ? cur : null,
          decoration: InputDecoration(labelText: it.label),
          items: [
            // `console` (codes written to the server log) exists only on a
            // dev server; a real one refuses it, so it is offered only when
            // it is already the effective value.
            for (final a in it.allowed)
              if (a != 'console' ||
                  !(it.key == 'otp.channel' || it.key == 'sms.channel') ||
                  a == cur)
                DropdownMenuItem(value: a, child: Text(a))
          ],
          // Single-value settings (CAP, FIFO) are shown but cannot change.
          onChanged: it.key.startsWith('inventory.') && it.allowed.length < 2
              ? null
              : (v) {
                  if (v != null) setState(() => _edits[it.key] = v);
                },
        );
      case 'SECRET':
        input = Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrls[it.key] ??= TextEditingController(),
              obscureText: true,
              decoration: InputDecoration(
                labelText: it.label,
                helperText: it.isSet
                    ? 'Saved - leave blank to keep it'
                    : 'Not set',
              ),
              onChanged: (v) => setState(() {
                if (v.isEmpty) {
                  _edits.remove(it.key);
                } else {
                  _edits[it.key] = v;
                }
              }),
            ),
          ),
          if (it.isSet)
            TextButton(
              onPressed: () => setState(() {
                _ctrls[it.key]?.clear();
                _edits[it.key] = ''; // blank secret = delete it
              }),
              child: Text(_edits[it.key] == '' ? 'Will clear' : 'Clear'),
            ),
        ]);
      default:
        input = TextField(
          controller: _ctrls[it.key] ??= TextEditingController(text: it.value ?? ''),
          keyboardType: it.type == 'INT' ? TextInputType.number : null,
          decoration: InputDecoration(
            labelText: it.label,
            helperText: [
              if (it.type == 'INT' && it.min != null && it.max != null)
                '${it.min} to ${it.max}',
              if (it.source != 'DATABASE') 'from ${it.source.toLowerCase()}',
            ].join(' · '),
          ),
          onChanged: (v) => setState(() {
            if (v == (it.value ?? '')) {
              _edits.remove(it.key);
            } else {
              _edits[it.key] = v;
            }
          }),
        );
    }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          input,
          if (it.help.isNotEmpty)
            Text(it.help, style: _t(11, FontWeight.w600, AppColors.ink3)),
          if (it.restart && edited)
            Text(gt('Applies after a server restart'),
                style: _t(11, FontWeight.w700, AppColors.red)),
          if (err != null) Text(err, style: _t(12, FontWeight.w700, AppColors.red)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _view;
    if (v == null) {
      return _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : const SkeletonRows(rows: 5);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (v.issues.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: AppColors.goldTint,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final i in v.issues)
                  Text('- $i', style: _t(12.5, FontWeight.w700, AppColors.ink)),
              ],
            ),
          ),
        if (_boot.isNotEmpty)
          CardPanel(
            title: _boot.any((b) => b.needsAction)
                ? 'Server start-up settings - action needed'
                : 'Server start-up settings',
            child: Column(
              children: [
                for (final b in _boot)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.circle,
                            size: 10,
                            color: switch (b.state) {
                              'OK' => AppColors.green,
                              'DEFAULT' => AppColors.ink3,
                              'MISSING' => const Color(0xFFE0A100),
                              _ => AppColors.red,
                            }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${b.name} (${b.setBy}): ${b.detail}',
                              style: _t(12, FontWeight.w600, AppColors.ink2)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        for (final g in v.groups) ...[
          const SizedBox(height: 12),
          CardPanel(
            title: g.label,
            child: Column(children: [
              for (final it in g.items) _item(it),
              if (g.group == 'PAYTM')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: AppButton('Paytm machines and Test button',
                      size: BtnSize.sm,
                      variant: BtnVariant.secondary,
                      onTap: () => go('/admin/bank?tab=machines')),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        AppButton(
            _edits.isEmpty ? 'No changes' : 'Save ${_edits.length} change(s)',
            block: true,
            loading: _busy,
            disabled: _edits.isEmpty,
            onTap: _save),
        const SizedBox(height: 12),
        CardPanel(
          title: 'Test the saved settings',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in const ['razorpay', 'fcm', 'sms', 'email'])
                AppButton('Test $t',
                    size: BtnSize.sm,
                    variant: BtnVariant.secondary,
                    onTap: _busy ? null : () => _test(t)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text('Save first - tests use the saved values. Money fields are in paise.',
            style: _t(11.5, FontWeight.w600, AppColors.ink3)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Caches + logs
// ---------------------------------------------------------------------------

class _CachesTab extends StatefulWidget {
  const _CachesTab();

  @override
  State<_CachesTab> createState() => _CachesTabState();
}

class _CachesTabState extends State<_CachesTab> {
  List<CacheStatDto> _caches = const [];
  LogStatusDto? _logs;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await Api.instance.ops.getCaches();
      final l = await Api.instance.ops.getLogStatus();
      if (mounted) {
        setState(() {
          _caches = c;
          _logs = l;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
  }

  Future<void> _refresh(String? name) async {
    setState(() => _busy = true);
    try {
      final c = await Api.instance.ops.refreshCache(name);
      if (mounted) setState(() => _caches = c);
      if (name == null && mounted) {
        StateScope.read(context).refreshStoreProfile(force: true);
      }
      showToast(name == null ? 'All caches emptied' : 'Refreshed $name', 'success');
    } catch (e) {
      showToast(_err(e), 'error');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(_error!, style: _t(13, FontWeight.w700, AppColors.red));
    }
    final logs = _logs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton('Hard refresh - empty every cache',
            block: true,
            loading: _busy,
            variant: BtnVariant.secondary,
            onTap: () => _refresh(null)),
        const SizedBox(height: 12),
        CardPanel(
          title: 'This device',
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gt('This device: store details'),
                        style: _t(13.5, FontWeight.w800, AppColors.ink)),
                    Text(
                        gt('Shop name, logo, address and hours are kept on this device and re-checked with the server.'),
                        style: _t(11.5, FontWeight.w600, AppColors.ink3)),
                    ListenableBuilder(
                      listenable: StoreProfileHub.instance,
                      builder: (_, __) => Text(
                          StoreProfileHub.instance.describeCache(),
                          style: _t(11.5, FontWeight.w600, AppColors.ink2)),
                    ),
                  ],
                ),
              ),
              TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          await StateScope.read(context)
                              .refreshStoreProfile(force: true);
                          if (!mounted) return;
                          setState(() => _busy = false);
                          showToast('Store details cleared and reloaded', 'success');
                        },
                  child: Text(gt('Clear'))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: 'Caches',
          child: Column(
            children: [
              for (final c in _caches)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                style: _t(13.5, FontWeight.w800, AppColors.ink)),
                            Text(c.description,
                                style: _t(11.5, FontWeight.w600, AppColors.ink3)),
                            Text(
                                'TTL ${c.ttlSeconds}s · ${c.entries} held · hit ${c.hitPercent ?? '-'}%',
                                style: _t(11.5, FontWeight.w600, AppColors.ink2)),
                          ],
                        ),
                      ),
                      TextButton(
                          onPressed: _busy ? null : () => _refresh(c.name),
                          child: Text(gt('Refresh'))),
                    ],
                  ),
                ),
              TextButton(
                  onPressed: _busy ? null : () => _refresh('settings'),
                  child: const Text('Reload configuration values')),
            ],
          ),
        ),
        if (logs != null) ...[
          const SizedBox(height: 12),
          CardPanel(
            title: 'Logs',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'App ${logs.levelApp} · Root ${logs.levelRoot} · SQL ${logs.levelSql} · keep ${logs.retentionDays} days',
                    style: _t(12.5, FontWeight.w700, AppColors.ink)),
                Text(
                    logs.fileLogging
                        ? 'File logging on${logs.folder.isEmpty ? '' : ' - ${logs.folder}'}'
                        : 'File logging off',
                    style: _t(12, FontWeight.w600, AppColors.ink3)),
                const SizedBox(height: 6),
                for (final f in logs.files.take(10))
                  Text('${f.name} · ${(f.sizeBytes / 1024).round()} KB',
                      style: _t(11.5, FontWeight.w600, AppColors.ink2)),
                const SizedBox(height: 6),
                Text('Change levels under Configuration > Logging.',
                    style: _t(11.5, FontWeight.w600, AppColors.ink3)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
