import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/api/api_client.dart' show newIdempotencyKey;
import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/push_dto.dart';
import '../../nav/nav.dart';
import '../../theme/app_colors.dart';
import '../../state/gu_strings.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import 'admin_flash_common.dart' show flashConfirm;
import 'admin_push_common.dart';
import 'admin_push_segments.dart';

class _Person {
  final String? id; // customer id (null for a typed number)
  final String? mobile;
  final String label;
  const _Person({this.id, this.mobile, required this.label});
  String get key => id ?? 'm:$mobile';
}

/// `#/admin/push?new=1[&segment=<id>][&again=<broadcast id>]` - the
/// four-step "new broadcast" wizard: audience, who, message, confirm. After the
/// server accepts it (202) the progress screen takes over.
class AdminPushWizard extends StatefulWidget {
  final String? segmentId;
  final String? againId;
  const AdminPushWizard({super.key, this.segmentId, this.againId});

  @override
  State<AdminPushWizard> createState() => _AdminPushWizardState();
}

class _AdminPushWizardState extends State<AdminPushWizard> {
  int _step = 0;
  String _audience = 'CUSTOMERS';

  // role audiences
  PushAudienceSize? _size;
  bool _sizeLoading = false;
  String? _sizeError;
  int _sizeSeq = 0;

  // USERS
  final List<_Person> _people = [];
  String _q = '';
  Timer? _qTimer;
  List<_Person> _found = [];
  bool _searching = false;
  String? _searchError;
  String _mobile = '';
  String? _mobileError;
  int _mobileKey = 0;

  // SEGMENT
  bool _inline = false;
  List<PushSegment> _segments = [];
  bool _segLoading = false;
  String? _segError;
  String? _segId;
  PushPreview? _savedPreview;
  bool _savedPreviewLoading = false;
  String? _savedPreviewError;
  final SegmentDraft _draft = SegmentDraft();

  // message
  String _title = '';
  String _body = '';
  String _refMode = 'none'; // none offers product category order custom
  String _refValue = '';
  PushPick? _refPick;
  Map<String, String> _errors = {};

  // confirm / send
  String _idemKey = '';
  String _idemFp = '';
  bool _sending = false;
  String? _sendError;
  DateTime? _blockedUntil;
  Timer? _blockTimer;
  List<String> _skippedHint = [];

  @override
  void initState() {
    super.initState();
    _draft.addListener(_onDraft);
    if (widget.segmentId != null) {
      _audience = 'SEGMENT';
      _segId = widget.segmentId;
      _step = 1;
      _loadSegments();
      _loadSavedPreview();
    } else if (widget.againId != null) {
      _prefill(widget.againId!);
    }
  }

  @override
  void dispose() {
    _draft.removeListener(_onDraft);
    _draft.dispose();
    _qTimer?.cancel();
    _blockTimer?.cancel();
    super.dispose();
  }

  void _onDraft() {
    if (mounted) setState(() {});
  }

  Future<void> _prefill(String id) async {
    try {
      final b = await Api.instance.push.broadcastById(id);
      if (!mounted) return;
      setState(() {
        _title = b.title;
        _body = b.body;
        final r = b.ref ?? '';
        if (r.isNotEmpty) {
          _refMode = 'custom';
          _refValue = r;
        }
        if (b.audience != 'USERS') _audience = b.audience;
        if (b.audience == 'SEGMENT') {
          if (b.segmentId != null) {
            _segId = b.segmentId;
            _loadSegments();
            _loadSavedPreview();
          } else if (b.segment != null) {
            _inline = true;
            _draft.load(b.segment!.match, b.segment!.rules);
          }
        }
      });
    } catch (_) {
      // Start from an empty form.
    }
  }

  // ---- data loaders -------------------------------------------------------

  bool get _isRole => pushRoleAudiences.contains(_audience);

  Future<void> _loadSize() async {
    final seq = ++_sizeSeq;
    setState(() {
      _sizeLoading = true;
      _sizeError = null;
      _size = null;
    });
    try {
      final s = await Api.instance.push.audienceSize(_audience);
      if (!mounted || seq != _sizeSeq) return;
      setState(() {
        _size = s;
        _sizeLoading = false;
      });
    } catch (e) {
      if (!mounted || seq != _sizeSeq) return;
      setState(() {
        _sizeError = pushError(e);
        _sizeLoading = false;
      });
    }
  }

  Future<void> _loadSegments() async {
    setState(() {
      _segLoading = true;
      _segError = null;
    });
    try {
      final all = <PushSegment>[];
      var page = 0;
      while (true) {
        final r = await Api.instance.push.segments(page: page, size: 50);
        all.addAll(r.items);
        if (!r.hasMore || page > 20) break;
        page++;
      }
      if (!mounted) return;
      setState(() {
        _segments = all;
        _segLoading = false;
        if (_segId != null && !all.any((s) => s.id == _segId)) _segId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _segError = pushError(e);
        _segLoading = false;
      });
    }
  }

  Future<void> _loadSavedPreview() async {
    final id = _segId;
    if (id == null) return;
    setState(() {
      _savedPreviewLoading = true;
      _savedPreviewError = null;
      _savedPreview = null;
    });
    try {
      final p = await Api.instance.push.preview({'segmentId': id});
      if (!mounted || id != _segId) return;
      setState(() {
        _savedPreview = p;
        _savedPreviewLoading = false;
      });
    } catch (e) {
      if (!mounted || id != _segId) return;
      setState(() {
        _savedPreviewError = pushError(e);
        _savedPreviewLoading = false;
      });
    }
  }

  void _search(String v) {
    _q = v.trim();
    _qTimer?.cancel();
    if (_q.length < 2) {
      setState(() {
        _found = [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    _qTimer = Timer(const Duration(milliseconds: 400), () async {
      final q = _q;
      setState(() {
        _searching = true;
        _searchError = null;
      });
      try {
        final r = await Api.instance.admin.searchCustomers(q: q, size: 10);
        if (!mounted || q != _q) return;
        setState(() {
          _found = [
            for (final c in r.items)
              if (c.active && (c.id ?? '').isNotEmpty)
                _Person(
                  id: c.id,
                  mobile: c.mobile,
                  label: [
                    if ((c.name ?? '').isNotEmpty) c.name!,
                    if ((c.mobile ?? '').isNotEmpty)
                      c.mobile!
                    else if ((c.email ?? '').isNotEmpty)
                      c.email!,
                  ].join(' · '),
                ),
          ];
          _searching = false;
        });
      } catch (e) {
        if (!mounted || q != _q) return;
        setState(() {
          _searchError = pushError(e);
          _searching = false;
        });
      }
    });
  }

  void _addPerson(_Person p) {
    if (_people.any((x) => x.key == p.key)) return;
    if (_people.where((x) => x.id != null).length >= 500 && p.id != null) {
      showToast(gt('You can add up to 500 people'), 'error');
      return;
    }
    setState(() => _people.add(p));
  }

  void _addMobile() {
    final m = _mobile.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(m)) {
      setState(() => _mobileError = gt('Enter a 10-digit mobile number'));
      return;
    }
    if (_people.where((x) => x.id == null).length >= 500) {
      setState(() => _mobileError = gt('You can add up to 500 numbers'));
      return;
    }
    setState(() {
      _addPerson(_Person(mobile: m, label: m));
      _mobile = '';
      _mobileError = null;
      _mobileKey++;
    });
  }

  // ---- request ------------------------------------------------------------

  String? get _ref {
    switch (_refMode) {
      case 'offers':
        return 'offers';
      case 'product':
        return _refPick == null ? null : 'product:${_refPick!.id}';
      case 'category':
        return _refPick == null ? null : 'category:${_refPick!.id}';
      case 'order':
        final v = _refValue.trim();
        return v.isEmpty ? null : 'order:$v';
      case 'custom':
        final v = _refValue.trim();
        return v.isEmpty ? null : v;
    }
    return null;
  }

  Map<String, dynamic> _requestBody() {
    final b = <String, dynamic>{
      'audience': _audience,
      'title': _title.trim(),
      'body': _body.trim(),
    };
    final r = _ref;
    if (r != null) b['ref'] = r;
    if (_audience == 'USERS') {
      final ids = [for (final p in _people) if (p.id != null) p.id!];
      final mobiles = [for (final p in _people) if (p.id == null) p.mobile!];
      if (ids.isNotEmpty) b['userIds'] = ids;
      if (mobiles.isNotEmpty) b['mobiles'] = mobiles;
    } else if (_audience == 'SEGMENT') {
      if (_inline) {
        b['segment'] = _draft.spec.toJson();
      } else {
        b['segmentId'] = _segId;
      }
    }
    return b;
  }

  /// People the broadcast will reach (null = unknown), and whether it is a
  /// floor ("10,000+").
  ({int? n, bool exact}) get _reach {
    if (_isRole) return (n: _size?.recipients, exact: true);
    if (_audience == 'USERS') return (n: _people.length, exact: true);
    final p = _inline ? _draft.preview : _savedPreview;
    return (n: p?.recipients, exact: p?.totalExact ?? true);
  }

  String get _audienceText {
    if (_audience == 'SEGMENT') {
      if (_inline) return gt('A segment built just now');
      final s = _segments.where((x) => x.id == _segId);
      return s.isEmpty ? gt('Customer segment') : '${gt('Segment')}: ${s.first.name}';
    }
    return gt(pushAudienceLabel(_audience));
  }

  // ---- navigation ---------------------------------------------------------

  bool get _canNext {
    switch (_step) {
      case 0:
        return true;
      case 1:
        if (_isRole) return _size != null;
        if (_audience == 'USERS') return _people.isNotEmpty;
        if (_inline) {
          return _draft.ready && (_draft.preview?.recipients ?? 0) > 0;
        }
        return _segId != null &&
            _savedPreview != null &&
            _savedPreview!.recipients > 0;
      case 2:
        return _titleError == null && _bodyError == null && _refError == null;
    }
    return true;
  }

  String? get _titleError {
    final n = _title.trim().length;
    if (n == 0) return gt('Add a title');
    if (n > 80) return gt('Title can be at most 80 characters');
    return null;
  }

  String? get _bodyError {
    final n = _body.trim().length;
    if (n == 0) return gt('Add a message');
    if (n > 500) return gt('Message can be at most 500 characters');
    return null;
  }

  String? get _refError {
    if (_refMode == 'product' || _refMode == 'category') {
      if (_refPick == null) return gt('Choose where the tap should go');
    }
    if ((_ref ?? '').length > 100) return gt('Link can be at most 100 characters');
    if ((_refMode == 'order' || _refMode == 'custom') && _ref == null) {
      return gt('Type the link or choose "Nothing"');
    }
    return null;
  }

  void _next() {
    if (!_canNext) return;
    if (_step == 0) {
      setState(() => _step = 1);
      if (_isRole) {
        _loadSize();
      } else if (_audience == 'SEGMENT') {
        _loadSegments();
        if (_segId != null && _savedPreview == null) _loadSavedPreview();
      }
      return;
    }
    if (_step == 2) {
      final body = _requestBody();
      _idemFp = jsonEncode(body);
      _idemKey = newIdempotencyKey();
    }
    setState(() {
      _step++;
      _sendError = null;
    });
  }

  void _back() {
    if (_step == 0) {
      pushBack();
      return;
    }
    setState(() => _step--);
  }

  // ---- send ---------------------------------------------------------------

  bool get _blocked =>
      _blockedUntil != null && DateTime.now().isBefore(_blockedUntil!);

  Future<void> _send() async {
    if (_sending || _blocked) return;
    final n = _reach.n;
    final ok = await flashConfirm(context,
        title: 'Send this announcement?',
        body:
            'It goes out as soon as you confirm and cannot be recalled. ${n == null ? '' : 'It will reach ${pushCount(n, exact: _reach.exact)} people.'}',
        confirmLabel: 'Send now');
    if (!ok || !mounted) return;

    final body = _requestBody();
    final fp = jsonEncode(body);
    // One key per Send action: kept for retries of the same content, replaced
    // when the content changed.
    if (fp != _idemFp || _idemKey.isEmpty) {
      _idemFp = fp;
      _idemKey = newIdempotencyKey();
    }
    setState(() {
      _sending = true;
      _sendError = null;
      _errors = {};
      _skippedHint = [];
    });
    try {
      ApiException.clearFields();
      final bc = await Api.instance.push.broadcast(body, idempotencyKey: _idemKey);
      if (!mounted) return;
      showToast(gt('Announcement queued'));
      Nav.instance.replace('/admin/push?id=${bc.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      _handleSendError(e);
    } catch (e) {
      if (mounted) setState(() => _sendError = pushError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _handleSendError(ApiException e) {
    final f = e.fields;
    var msg = pushError(e);
    var toStep = -1;
    switch (e.code) {
      case 'IDEMPOTENCY_KEY_REUSED':
        _idemKey = newIdempotencyKey();
        msg = gt('Something changed since you opened this screen. Review it and send again.');
        break;
      case 'NO_RECIPIENTS':
        final sk = e.details?['skipped'];
        if (sk is List) _skippedHint = sk.map((x) => '$x').toList();
        msg = gt('None of those people could be reached.');
        break;
      case 'NOT_FOUND':
        if (_audience == 'SEGMENT' && !_inline) {
          msg = gt('That segment no longer exists. Choose another one.');
          _segId = null;
          _savedPreview = null;
          _loadSegments();
          toStep = 1;
        }
        break;
      case 'RATE_LIMITED':
        final s = e.retryAfterSeconds ?? 60;
        _blockedUntil = DateTime.now().add(Duration(seconds: s));
        _blockTimer?.cancel();
        _blockTimer = Timer(Duration(seconds: s), () {
          if (mounted) setState(() {});
        });
        break;
      default:
        break;
    }
    if (e.statusCode == 400 && f.isNotEmpty) {
      _errors = f;
      if (f.containsKey('title') || f.containsKey('body') || f.containsKey('ref')) {
        toStep = 2;
      } else if (f.keys.any((k) => k.startsWith('segment') || k.startsWith('rules'))) {
        if (_inline) _draft.setErrors(f);
        toStep = 1;
      } else if (f.containsKey('userIds') || f.containsKey('mobiles')) {
        toStep = 1;
      }
    }
    setState(() {
      _sendError = msg;
      if (toStep >= 0) _step = toStep;
    });
    if (e.code != 'RATE_LIMITED') showToast(msg, 'error');
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final last = _step == 3;
    return PushAdminPage(
      title: gt('New broadcast'),
      sub: '${gt('Step')} ${_step + 1} ${gt('of')} 4',
      back: true,
      bottom: AdminSaveBar(child: _bottomBar(last)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepper(),
          const SizedBox(height: 14),
          if (_step == 0) _audienceStep(),
          if (_step == 1) _whoStep(),
          if (_step == 2) _messageStep(),
          if (_step == 3) _confirmStep(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _bottomBar(bool last) {
    if (last) {
      final n = _reach.n;
      final label = n == null
          ? gt('Send')
          : '${gt('Send to')} ${pushCount(n, exact: _reach.exact)} ${gt(n == 1 ? 'person' : 'people')}';
      return Row(children: [
        Expanded(
          child: AppButton('Back',
              variant: BtnVariant.secondary, onTap: _sending ? null : _back),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: AppButton(label,
              loading: _sending,
              disabled: _blocked,
              onTap: (_sending || _blocked) ? null : _send),
        ),
      ]);
    }
    return Row(children: [
      Expanded(
        child: AppButton(_step == 0 ? 'Cancel' : 'Back',
            variant: BtnVariant.secondary, onTap: _back),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: AppButton('Next', disabled: !_canNext, onTap: _canNext ? _next : null),
      ),
    ]);
  }

  Widget _stepper() {
    const names = ['Audience', 'Who', 'Message', 'Confirm'];
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Expanded(
            child: Column(children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: i <= _step ? AppColors.red : AppColors.line,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(height: 5),
              Text(gt(names[i]),
                  style: pushTs(
                      size: 11,
                      color: i == _step ? AppColors.ink : AppColors.ink3)),
            ]),
          ),
          if (i < 3) const SizedBox(width: 6),
        ],
      ],
    );
  }

  // ---- step 0: audience ---------------------------------------------------

  Widget _audienceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(gt('Who should get this?'),
            style: pushTs(size: 16, w: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final a in pushAudiences)
          PushCard(
            selected: _audience == a,
            margin: const EdgeInsets.only(bottom: 8),
            onTap: () => setState(() {
              _audience = a;
              _size = null;
            }),
            child: Row(children: [
              AppRadio(selected: _audience == a),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gt(pushAudienceLabel(a)),
                        style: pushTs(size: 14, w: FontWeight.w800)),
                    Text(gt(_audienceHint(a)),
                        style: pushTs(
                            size: 11.5, w: FontWeight.w600, color: AppColors.ink3)),
                  ],
                ),
              ),
            ]),
          ),
      ],
    );
  }

  String _audienceHint(String a) {
    switch (a) {
      case 'ALL':
        return 'Customers and staff';
      case 'CUSTOMERS':
        return 'Every active customer';
      case 'STAFF':
        return 'Admins and cashiers';
      case 'ADMINS':
        return 'Store admins only';
      case 'CASHIERS':
        return 'Counter staff only';
      case 'USERS':
        return 'Pick customers by name or mobile number';
      case 'SEGMENT':
        return 'Customers who match conditions you set';
    }
    return '';
  }

  // ---- step 1: who --------------------------------------------------------

  Widget _whoStep() {
    if (_isRole) return _roleStep();
    if (_audience == 'USERS') return _usersStep();
    return _segmentStep();
  }

  Widget _roleStep() {
    if (_sizeLoading) return const SkeletonRows(rows: 2);
    if (_sizeError != null) {
      return ErrorRetry(message: _sizeError!, onRetry: _loadSize);
    }
    final s = _size;
    if (s == null) return const SkeletonRows(rows: 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(gt(pushAudienceLabel(_audience)),
            style: pushTs(size: 16, w: FontWeight.w800)),
        const SizedBox(height: 10),
        KpiGrid([
          KpiCard(
              icon: 'users',
              tint: AppColors.navy,
              bg: AppColors.navyTint,
              label: gt('Will reach'),
              value: pushCount(s.recipients)),
          KpiCard(
              icon: 'bell',
              tint: AppColors.green,
              bg: AppColors.greenTint,
              label: gt('Push on'),
              value: pushCount(s.withDevices)),
        ]),
        const SizedBox(height: 10),
        PushNote(
            '${gt('This will reach')} ${pushCount(s.recipients)} ${gt('people')} (${pushCount(s.withDevices)} ${gt('have the app installed with push on')}). ${gt('The rest see it in their app inbox.')}'),
      ],
    );
  }

  Widget _usersStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(gt('Choose people'), style: pushTs(size: 16, w: FontWeight.w800)),
        const SizedBox(height: 10),
        AppField(
          label: 'Search customers',
          placeholder: 'Name, mobile or email',
          onChanged: _search,
        ),
        if (_searching)
          const Padding(
              padding: EdgeInsets.only(top: 10), child: SkeletonRows(rows: 2))
        else if (_searchError != null)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: PushNote(_searchError!, error: true))
        else if (_q.length >= 2 && _found.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(gt('No customers found'),
                style: pushTs(size: 12.5, color: AppColors.ink2)),
          )
        else
          for (final p in _found)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _addPerson(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Expanded(child: Text(p.label, style: pushTs())),
                  if (_people.any((x) => x.key == p.key))
                    const AppIcon('check', size: 16, color: AppColors.green)
                  else
                    const AppIcon('plus', size: 16, color: AppColors.red),
                ]),
              ),
            ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppField(
                key: ValueKey('mob$_mobileKey'),
                label: 'Or type a mobile number',
                placeholder: '10 digits',
                numeric: true,
                maxLength: 10,
                error: _mobileError,
                onChanged: (v) => _mobile = v,
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 25),
              child: AppButton('Add', onTap: _addMobile),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('${gt('Chosen')}: ${_people.length}',
            style: pushTs(size: 13, w: FontWeight.w800)),
        const SizedBox(height: 8),
        if (_people.isEmpty)
          Text(gt('Nobody chosen yet.'),
              style: pushTs(size: 12.5, color: AppColors.ink2))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _people)
                GestureDetector(
                  onTap: () => setState(() => _people.remove(p)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.navyTint,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                          child: Text(p.label,
                              overflow: TextOverflow.ellipsis,
                              style: pushTs(size: 12, color: AppColors.navy))),
                      const SizedBox(width: 6),
                      const AppIcon('close', size: 12, color: AppColors.navy),
                    ]),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        Text(
            gt('People who are blocked or not found are skipped and listed after sending.'),
            style: pushTs(size: 11.5, w: FontWeight.w600, color: AppColors.ink3)),
      ],
    );
  }

  Widget _segmentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segmented(
          options: const [
            SegmentOption('saved', 'Saved segment'),
            SegmentOption('build', 'Build now'),
          ],
          value: _inline ? 'build' : 'saved',
          onChanged: (v) {
            setState(() => _inline = v == 'build');
            if (_inline && _draft.rules.isEmpty) _draft.addRule();
          },
        ),
        const SizedBox(height: 14),
        if (_inline)
          SegmentBuilder(draft: _draft)
        else
          _savedSegments(),
      ],
    );
  }

  Widget _savedSegments() {
    if (_segLoading) return const SkeletonRows(rows: 3);
    if (_segError != null) {
      return ErrorRetry(message: _segError!, onRetry: _loadSegments);
    }
    if (_segments.isEmpty) {
      return Column(children: [
        EmptyState(
          icon: 'users',
          title: gt('No saved segments'),
          copy: gt('Build one now, or save segments from the Segments tab.'),
        ),
        AppButton('Build now',
            variant: BtnVariant.soft,
            onTap: () {
              setState(() => _inline = true);
              if (_draft.rules.isEmpty) _draft.addRule();
            }),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in _segments)
          PushCard(
            selected: _segId == s.id,
            margin: const EdgeInsets.only(bottom: 8),
            onTap: () {
              setState(() => _segId = s.id);
              _loadSavedPreview();
            },
            child: Row(children: [
              AppRadio(selected: _segId == s.id),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: pushTs(size: 14, w: FontWeight.w800)),
                    if (s.description.isNotEmpty)
                      Text(s.description,
                          style: pushTs(
                              size: 11.5,
                              w: FontWeight.w600,
                              color: AppColors.ink3)),
                  ],
                ),
              ),
            ]),
          ),
        if (_segId != null) ...[
          const SizedBox(height: 4),
          if (_savedPreviewLoading)
            const SkeletonBlock(height: 54)
          else if (_savedPreviewError != null)
            PushNote(_savedPreviewError!, error: true)
          else if (_savedPreview != null)
            PushNote(
                '${_savedPreview!.totalExact ? '' : '${gt('More than')} '}${pushCount(_savedPreview!.recipients)} ${gt('customers match')} · ${pushCount(_savedPreview!.withDevices)} ${gt('can receive push')}'),
        ],
      ],
    );
  }

  // ---- step 2: message ----------------------------------------------------

  Widget _messageStep() {
    final tl = _title.trim().length;
    final bl = _body.trim().length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(gt('Write the message'),
            style: pushTs(size: 16, w: FontWeight.w800)),
        const SizedBox(height: 10),
        AppField(
          label: 'Title',
          value: _title,
          placeholder: 'Diwali offers',
          error: _errors['title'] ?? (tl > 80 ? _titleError : null),
          onChanged: (v) => setState(() {
            _title = v;
            _errors.remove('title');
          }),
        ),
        _counter(tl, 80),
        const SizedBox(height: 10),
        AppField(
          label: 'Message',
          value: _body,
          placeholder: 'Flat 10% off till Sunday',
          error: _errors['body'] ?? (bl > 500 ? _bodyError : null),
          onChanged: (v) => setState(() {
            _body = v;
            _errors.remove('body');
          }),
        ),
        _counter(bl, 500),
        const SizedBox(height: 14),
        Text(gt('When tapped, open'), style: pushTs(size: 13, w: FontWeight.w800)),
        const SizedBox(height: 7),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in const [
            ('none', 'Nothing'),
            ('offers', 'Offers'),
            ('product', 'A product'),
            ('category', 'A category'),
            ('order', 'An order'),
            ('custom', 'Custom'),
          ])
            AppChip(m.$2,
                selected: _refMode == m.$1,
                onTap: () => setState(() {
                      _refMode = m.$1;
                      _refPick = null;
                      _refValue = '';
                      _errors.remove('ref');
                    })),
        ]),
        if (_refMode == 'product' || _refMode == 'category') ...[
          const SizedBox(height: 10),
          SelectField(
            value: _refPick?.name ?? '',
            placeholder: gt(_refMode == 'product'
                ? 'Choose a product'
                : 'Choose a category'),
            onTap: () async {
              final r = _refMode == 'product'
                  ? await pickPushProduct(context)
                  : await pickPushCategory(context);
              if (r != null && mounted) setState(() => _refPick = r);
            },
          ),
        ],
        if (_refMode == 'order' || _refMode == 'custom') ...[
          const SizedBox(height: 10),
          AppField(
            value: _refValue,
            placeholder: _refMode == 'order' ? 'Order number' : 'offers, coins ...',
            maxLength: 100,
            onChanged: (v) => setState(() => _refValue = v),
          ),
        ],
        if (_errors['ref'] != null || (_refError != null && _refMode != 'none'))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_errors['ref'] ?? _refError!,
                style: pushTs(size: 12, color: AppColors.red)),
          ),
        const SizedBox(height: 16),
        Text(gt('How it looks in the inbox'),
            style: pushTs(size: 13, w: FontWeight.w800)),
        const SizedBox(height: 8),
        _inboxPreview(),
      ],
    );
  }

  Widget _counter(int n, int max) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text('$n / $max',
              style: pushTs(
                  size: 11.5,
                  w: FontWeight.w700,
                  color: n > max ? AppColors.red : AppColors.ink3)),
        ),
      );

  Widget _inboxPreview() {
    final t = _title.trim();
    final b = _body.trim();
    return PushCard(
      margin: EdgeInsets.zero,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
              color: AppColors.navyTint, shape: BoxShape.circle),
          child: const Center(
              child: AppIcon('bell', size: 17, color: AppColors.navy, sw: 1.9)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.isEmpty ? gt('Title') : t,
                  style: pushTs(
                      size: 13,
                      w: FontWeight.w800,
                      color: t.isEmpty ? AppColors.ink3 : AppColors.ink)),
              const SizedBox(height: 2),
              Text(b.isEmpty ? gt('Your message appears here.') : b,
                  style: pushTs(
                      size: 12,
                      w: FontWeight.w600,
                      color: AppColors.ink2,
                      height: 1.4)),
            ],
          ),
        ),
      ]),
    );
  }

  // ---- step 3: confirm ----------------------------------------------------

  Widget _confirmStep() {
    final r = _reach;
    final n = r.n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(gt('Check and send'), style: pushTs(size: 16, w: FontWeight.w800)),
        const SizedBox(height: 10),
        CardPanel(
          child: Column(children: [
            PushKv('Audience', _audienceText),
            PushKv(
                'People',
                n == null
                    ? '-'
                    : r.exact
                        ? pushCount(n)
                        : '${gt('More than')} ${pushCount(n)}'),
            PushKv('Title', _title.trim()),
            PushKv('Message', _body.trim()),
            PushKv('Opens', _ref ?? gt('Nothing (inbox only)')),
          ]),
        ),
        const SizedBox(height: 10),
        _inboxPreview(),
        if (_blocked) ...[
          const SizedBox(height: 10),
          PushNote(_sendError ?? gt('Too many announcements. Try again later.'),
              warn: true),
        ] else if (_sendError != null) ...[
          const SizedBox(height: 10),
          PushNote(_sendError!, error: true),
        ],
        if (_skippedHint.isNotEmpty) ...[
          const SizedBox(height: 8),
          PushNote('${gt('Not found or blocked')}: ${_skippedHint.join(', ')}',
              warn: true),
        ],
        for (final k in const ['userIds', 'mobiles', 'segment'])
          if (_errors[k] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PushNote(_errors[k]!, error: true),
            ),
      ],
    );
  }
}
