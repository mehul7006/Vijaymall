import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart';
import '../../data/api/push_dto.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';
import 'admin_flash_common.dart'
    show flashConfirm, paiseToRupeesText, rupeesTextToPaise;
import 'admin_push_common.dart';

// ---------------------------------------------------------------------------
// Pickers (product / category), shared with the broadcast wizard
// ---------------------------------------------------------------------------

typedef PushPick = ({String id, String name});

Future<PushPick?> pickPushProduct(BuildContext context) =>
    showAppSheet<PushPick>(
      context: context,
      title: 'Choose a product',
      builder: (ctx) => const _ProductPicker(),
    );

Future<PushPick?> pickPushCategory(BuildContext context) =>
    showAppSheet<PushPick>(
      context: context,
      title: 'Choose a category',
      builder: (ctx) => const _CategoryPicker(),
    );

class _ProductPicker extends StatefulWidget {
  const _ProductPicker();
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  Timer? _t;
  String _q = '';
  List<PushPick> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.instance.admin.listProducts(q: _q, page: 0, size: 20);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final p in r.items)
            if ((p.id ?? '').isNotEmpty)
              (
                id: p.id!,
                name: [
                  p.nameEn ?? '',
                  if ((p.packSize ?? '').isNotEmpty) p.packSize!
                ].join(' · ')
              ),
        ];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = pushError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppField(
          placeholder: 'Search products',
          onChanged: (v) {
            _q = v.trim();
            _t?.cancel();
            _t = Timer(const Duration(milliseconds: 400), _load);
          },
        ),
        const SizedBox(height: 10),
        if (_loading)
          const SkeletonRows(rows: 4)
        else if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (_items.isEmpty)
          EmptyState(
              icon: 'box',
              title: gt('No products found'),
              copy: gt('Try another word.'))
        else
          for (final p in _items)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  Expanded(child: Text(p.name, style: pushTs())),
                  const AppIcon('right', size: 14, color: AppColors.ink3),
                ]),
              ),
            ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker();
  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  List<PushPick> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.instance.catalog.getCategories();
      if (!mounted) return;
      setState(() {
        _items = [
          for (final c in r)
            if ((c.id ?? '').isNotEmpty) (id: c.id!, name: c.nameEn ?? c.id!),
        ];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = pushError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonRows(rows: 4);
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in _items)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(children: [
                Expanded(child: Text(p.name, style: pushTs())),
                const AppIcon('right', size: 14, color: AppColors.ink3),
              ]),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Segment draft: conditions + debounced live preview
// ---------------------------------------------------------------------------

class SegmentDraft extends ChangeNotifier {
  String match = 'ALL';
  final List<PushCondition> rules = [];

  /// `details.fields` of the last failed preview/save (`rules[0].paise` ...).
  Map<String, String> fieldErrors = {};
  PushPreview? preview;
  String? previewError;
  bool previewLoading = false;
  bool previewBlocked = false; // incomplete conditions

  Timer? _debounce;
  Timer? _retry;
  int _seq = 0;
  bool _disposed = false;

  SegmentSpec get spec => SegmentSpec(match: match, rules: rules);

  /// True once the current conditions produced a count.
  bool get ready => preview != null && !previewLoading && previewError == null;

  void load(String m, List<PushCondition> r) {
    match = m;
    rules
      ..clear()
      ..addAll(r.map((c) => c.copy()));
    for (final c in rules) {
      _fillRaw(c);
    }
    schedule();
  }

  static void _fillRaw(PushCondition c) {
    c.params.forEach((k, v) {
      if (v is List) {
        c.raw[k] = v.join(', ');
      } else if (k.toLowerCase().endsWith('paise')) {
        c.raw[k] = v is int ? paiseToRupeesText(v) : '$v';
      } else if (v is! bool) {
        c.raw[k] = '$v';
      }
    });
  }

  void changed() {
    fieldErrors = {};
    schedule();
  }

  void setErrors(Map<String, String> f) {
    fieldErrors = f;
    notifyListeners();
  }

  void schedule() {
    _debounce?.cancel();
    _retry?.cancel();
    notifyListeners();
    if (rules.isEmpty || rules.any((r) => r.type.isEmpty)) {
      _seq++;
      preview = null;
      previewError = null;
      previewLoading = false;
      previewBlocked = rules.isNotEmpty;
      notifyListeners();
      return;
    }
    previewBlocked = false;
    previewLoading = true;
    _debounce = Timer(const Duration(milliseconds: 600), _run);
  }

  Future<void> _run() async {
    final seq = ++_seq;
    ApiException.clearFields();
    try {
      final p = await Api.instance.push.preview(spec.toJson());
      if (_disposed || seq != _seq) return;
      preview = p;
      previewError = null;
      fieldErrors = {};
    } on ApiException catch (e) {
      if (_disposed || seq != _seq) return;
      preview = null;
      if (e.statusCode == 400 && e.fields.isNotEmpty) {
        fieldErrors = e.fields;
        previewError = null;
        previewBlocked = true;
      } else if (e.code == 'PREVIEW_BUSY') {
        previewError = gt('The server is busy counting. Trying again shortly.');
        _retry = Timer(
            Duration(seconds: (e.retryAfterSeconds ?? 2).clamp(1, 10)), () {
          if (!_disposed) schedule();
        });
        notifyListeners();
        return;
      } else {
        previewError = pushError(e);
      }
    } catch (e) {
      if (_disposed || seq != _seq) return;
      preview = null;
      previewError = pushError(e);
    }
    previewLoading = false;
    notifyListeners();
  }

  void addRule() {
    if (rules.length >= 10) return;
    rules.add(PushCondition());
    changed();
  }

  void removeRule(int i) {
    rules.removeAt(i);
    changed();
  }

  void setMatch(String m) {
    match = m;
    changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _retry?.cancel();
    super.dispose();
  }
}

/// Loads the condition catalog once per session.
class PushCatalog {
  static List<PushConditionType>? _cache;
  static Future<List<PushConditionType>> load({bool force = false}) async {
    if (_cache != null && !force) return _cache!;
    final r = await Api.instance.push.conditionTypes();
    _cache = r;
    return r;
  }
}

// ---------------------------------------------------------------------------
// Segment builder widget (editor + wizard)
// ---------------------------------------------------------------------------

class SegmentBuilder extends StatefulWidget {
  final SegmentDraft draft;
  const SegmentBuilder({super.key, required this.draft});

  @override
  State<SegmentBuilder> createState() => _SegmentBuilderState();
}

class _SegmentBuilderState extends State<SegmentBuilder> {
  List<PushConditionType>? _types;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    setState(() => _error = null);
    try {
      final t = await PushCatalog.load();
      if (mounted) setState(() => _types = t);
    } catch (e) {
      if (mounted) setState(() => _error = pushError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ErrorRetry(message: _error!, onRetry: _loadTypes);
    }
    final types = _types;
    if (types == null) return const SkeletonRows(rows: 3);
    return ListenableBuilder(
      listenable: widget.draft,
      builder: (context, _) {
        final d = widget.draft;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(gt('Customers who meet'), style: pushTs(size: 13)),
            const SizedBox(height: 7),
            Segmented(
              options: const [
                SegmentOption('ALL', 'All of these'),
                SegmentOption('ANY', 'Any of these'),
              ],
              value: d.match,
              onChanged: d.setMatch,
            ),
            const SizedBox(height: 12),
            if (d.fieldErrors['rules'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PushNote(d.fieldErrors['rules']!, error: true),
              ),
            for (var i = 0; i < d.rules.length; i++)
              _RuleCard(
                key: ObjectKey(d.rules[i]),
                draft: d,
                index: i,
                types: types,
              ),
            AppButton(
              d.rules.length >= 10 ? 'Up to 10 conditions' : 'Add a condition',
              icon: 'plus',
              variant: BtnVariant.soft,
              block: true,
              disabled: d.rules.length >= 10,
              onTap: d.addRule,
            ),
            const SizedBox(height: 12),
            _PreviewPanel(draft: d),
          ],
        );
      },
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  final SegmentDraft draft;
  const _PreviewPanel({required this.draft});

  @override
  Widget build(BuildContext context) {
    final d = draft;
    Widget body;
    if (d.rules.isEmpty) {
      body = Text(gt('Add a condition to see who it reaches.'),
          style: pushTs(size: 12.5, color: AppColors.ink2));
    } else if (d.previewLoading && d.preview == null) {
      body = const SkeletonBlock(height: 54);
    } else if (d.previewError != null) {
      body = PushNote(d.previewError!, error: true);
    } else if (d.previewBlocked && d.preview == null) {
      body = Text(
          gt('Fill in or fix the highlighted conditions to see the count.'),
          style: pushTs(size: 12.5, color: AppColors.ink2));
    } else if (d.preview != null) {
      final p = d.preview!;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.totalExact
                      ? '${pushCount(p.recipients)} ${gt(p.recipients == 1 ? 'customer matches' : 'customers match')}'
                      : '${gt('More than')} ${pushCount(p.recipients)} ${gt('customers match')}',
                  style: pushTs(size: 15, w: FontWeight.w800),
                ),
              ),
              if (d.previewLoading)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
              '${pushCount(p.withDevices)} ${gt('can receive push')}',
              style: pushTs(size: 12, color: AppColors.ink2)),
          if (p.sample.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final s in p.sample)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                    '${s.name ?? gt('Customer')}  ${s.mobile ?? ''}'.trim(),
                    style: pushTs(
                        size: 12, w: FontWeight.w600, color: AppColors.ink3)),
              ),
          ],
        ],
      );
    } else {
      body = const SkeletonBlock(height: 54);
    }
    return CardPanel(title: gt('Who this reaches'), child: body);
  }
}

// ---------------------------------------------------------------------------
// One condition card
// ---------------------------------------------------------------------------

class _RuleCard extends StatelessWidget {
  final SegmentDraft draft;
  final int index;
  final List<PushConditionType> types;

  const _RuleCard({
    super.key,
    required this.draft,
    required this.index,
    required this.types,
  });

  PushCondition get c => draft.rules[index];

  PushConditionType? get _type {
    for (final t in types) {
      if (t.type == c.type) return t;
    }
    return null;
  }

  Future<void> _pickType(BuildContext context) async {
    final t = await showAppSheet<PushConditionType>(
      context: context,
      title: 'Choose a condition',
      builder: (ctx) => _TypeList(types: types, current: c.type),
    );
    if (t == null) return;
    c.type = t.type;
    c.negate = false;
    c.params.clear();
    c.raw.clear();
    c.labels.clear();
    c.errors.clear();
    for (final p in t.params) {
      if (p.required && p.kind == 'ENUM' && p.options.isNotEmpty) {
        c.params[p.name] = p.options.first;
      } else if (p.required && p.kind == 'BOOLEAN') {
        c.params[p.name] = true;
      }
    }
    draft.changed();
  }

  /// A type with `op` + `paise` / `minPaise` + `maxPaise` shows only the amount
  /// inputs the chosen comparison uses.
  bool _visible(PushConditionType t, PushConditionParam p) {
    final hasBetween = t.params.any((x) => x.name == 'minPaise');
    if (hasBetween) {
      final between = c.params['op'] == 'BETWEEN';
      if (p.name == 'paise') return !between;
      if (p.name == 'minPaise' || p.name == 'maxPaise') return between;
    }
    return true;
  }

  void _onEnum(PushConditionType t, PushConditionParam p, String v) {
    c.params[p.name] = v;
    if (p.name == 'op' && t.params.any((x) => x.name == 'minPaise')) {
      final between = v == 'BETWEEN';
      for (final n in between ? ['paise'] : ['minPaise', 'maxPaise']) {
        c.params.remove(n);
        c.raw.remove(n);
        c.errors.remove(n);
      }
    }
    draft.changed();
  }

  void _onText(PushConditionParam p, String text) {
    c.raw[p.name] = text;
    c.errors.remove(p.name);
    final t = text.trim();
    switch (p.kind) {
      case 'INT':
        final n = int.tryParse(t);
        if (t.isEmpty) {
          c.params.remove(p.name);
        } else if (n == null) {
          c.params.remove(p.name);
          c.errors[p.name] = gt('Enter a whole number');
        } else {
          c.params[p.name] = n;
        }
        break;
      case 'AMOUNT_PAISE':
        final n = rupeesTextToPaise(t);
        if (t.isEmpty) {
          c.params.remove(p.name);
        } else if (n == null) {
          c.params.remove(p.name);
          c.errors[p.name] = gt('Enter an amount in rupees');
        } else {
          c.params[p.name] = n;
        }
        break;
      case 'STRING_LIST':
        final items = t
            .split(RegExp(r'[\s,;]+'))
            .where((s) => s.isNotEmpty)
            .toList();
        if (items.isEmpty) {
          c.params.remove(p.name);
        } else {
          c.params[p.name] = items;
        }
        break;
      default: // STRING
        if (t.isEmpty) {
          c.params.remove(p.name);
        } else {
          c.params[p.name] = t.toUpperCase();
        }
    }
    draft.changed();
  }

  Future<void> _pickId(BuildContext context, PushConditionParam p) async {
    final r = p.kind == 'CATEGORY_ID'
        ? await pickPushCategory(context)
        : await pickPushProduct(context);
    if (r == null) return;
    c.params[p.name] = r.id;
    c.labels[p.name] = r.name;
    draft.changed();
  }

  @override
  Widget build(BuildContext context) {
    final t = _type;
    final fields = draft.fieldErrors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.sh1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectField(
                  label: '${gt('Condition')} ${index + 1}',
                  value: t == null
                      ? ''
                      : (t.shownLabel.isNotEmpty ? t.shownLabel : gt(t.label)),
                  placeholder: gt('Choose a condition'),
                  onTap: () => _pickType(context),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: IconBtn(
                  'trash',
                  size: 44,
                  iconSize: 18,
                  onTap: () => draft.removeRule(index),
                ),
              ),
            ],
          ),
          if (fields['rules[$index].type'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(fields['rules[$index].type']!,
                  style: pushTs(size: 12, color: AppColors.red)),
            ),
          if (t != null) ...[
            if (t.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                  t.shownDescription.isNotEmpty
                      ? t.shownDescription
                      : t.description.replaceAll('(paise)', '(Rs)'),
                  style: pushTs(
                      size: 11.5, w: FontWeight.w600, color: AppColors.ink3)),
            ],
            for (final p in t.params)
              if (_visible(t, p))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _paramInput(context, p),
                ),
            if (t.supportsNegate) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(gt('Not (the opposite)'),
                        style: pushTs(size: 13)),
                  ),
                  AppSwitch(
                    value: c.negate,
                    onChanged: (v) {
                      c.negate = v;
                      draft.changed();
                    },
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _paramInput(BuildContext context, PushConditionParam p) {
    final err = pushRuleError(draft.fieldErrors, index, p.name) ??
        c.errors[p.name];
    final label =
        p.shownLabel.isNotEmpty ? p.shownLabel : pushParamLabel(p.label);
    switch (p.kind) {
      case 'ENUM':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: pushTs(size: 13)),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in p.options)
                  AppChip(p.optionGu(o).isNotEmpty ? p.optionGu(o) : pushOptionLabel(o),
                      selected: c.params[p.name] == o,
                      onTap: () => _onEnum(_type!, p, o)),
              ],
            ),
            if (err != null) _err(err),
          ],
        );
      case 'BOOLEAN':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(label, style: pushTs(size: 13))),
              AppSwitch(
                value: c.params[p.name] == true,
                onChanged: (v) {
                  c.params[p.name] = v;
                  draft.changed();
                },
              ),
            ]),
            if (err != null) _err(err),
          ],
        );
      case 'PRODUCT_ID':
      case 'CATEGORY_ID':
        final has = c.params[p.name] != null;
        return SelectField(
          label: label,
          value: has ? (c.labels[p.name] ?? '${c.params[p.name]}') : '',
          placeholder: gt(p.kind == 'CATEGORY_ID'
              ? 'Choose a category'
              : 'Choose a product'),
          onTap: () => _pickId(context, p),
        ).withError(err);
      default:
        final rangeHint = (p.min != null && p.max != null && p.kind != 'AMOUNT_PAISE')
            ? '${p.min}-${p.max}'
            : null;
        return AppField(
          label: label,
          value: c.raw[p.name] ?? '',
          placeholder: p.kind == 'STRING_LIST'
              ? gt('Separate with commas')
              : (p.kind == 'AMOUNT_PAISE' ? 'Rs' : rangeHint),
          keyboardType: p.kind == 'INT' || p.kind == 'AMOUNT_PAISE'
              ? TextInputType.number
              : TextInputType.text,
          error: err,
          onChanged: (v) => _onText(p, v),
        );
    }
  }

  Widget _err(String s) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(s, style: pushTs(size: 12, color: AppColors.red)),
      );
}

extension _WithError on Widget {
  Widget withError(String? err) {
    if (err == null) return this;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        this,
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(err, style: pushTs(size: 12, color: AppColors.red)),
        ),
      ],
    );
  }
}

class _TypeList extends StatelessWidget {
  final List<PushConditionType> types;
  final String current;
  const _TypeList({required this.types, required this.current});

  @override
  Widget build(BuildContext context) {
    final groups = <String>[];
    for (final t in types) {
      if (!groups.contains(t.group)) groups.add(t.group);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(gt(g).toUpperCase(),
                style: pushTs(size: 11, color: AppColors.ink3)),
          ),
          for (final t in types.where((x) => x.group == g))
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Text(t.shownLabel.isNotEmpty ? t.shownLabel : gt(t.label),
                        style: pushTs(
                            color: t.type == current
                                ? AppColors.red
                                : AppColors.ink)),
                  ),
                  if (t.type == current)
                    const AppIcon('check', size: 15, color: AppColors.red),
                ]),
              ),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Saved segments list
// ---------------------------------------------------------------------------

class PushSegmentsList extends StatefulWidget {
  const PushSegmentsList({super.key});
  @override
  State<PushSegmentsList> createState() => _PushSegmentsListState();
}

class _PushSegmentsListState extends State<PushSegmentsList> {
  final List<PushSegment> _rows = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _rows.isEmpty;
      _error = null;
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
        _rows
          ..clear()
          ..addAll(all);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = pushError(e);
        _loading = false;
      });
    }
  }

  Future<void> _delete(PushSegment s) async {
    final ok = await flashConfirm(context,
        title: 'Delete this segment?',
        body:
            'Broadcasts already sent keep their own copy of the conditions. This cannot be undone.',
        confirmLabel: 'Delete segment',
        danger: true);
    if (!ok || !mounted) return;
    setState(() => _busyId = s.id);
    try {
      await Api.instance.push.deleteSegment(s.id);
      if (!mounted) return;
      showToast(gt('Segment deleted'));
      _rows.removeWhere((x) => x.id == s.id);
    } catch (e) {
      if (mounted) showToast(pushError(e), 'error');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonRows(rows: 3);
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton('New segment',
            icon: 'plus', onTap: () => go('/admin/push?seg=new')),
        const SizedBox(height: 12),
        if (_rows.isEmpty)
          EmptyState(
            icon: 'users',
            title: gt('No saved segments'),
            copy: gt(
                'Save a group of customers, such as big spenders or people who have not bought for a month, and message them in one go.'),
          )
        else
          for (final s in _rows) _row(s),
      ],
    );
  }

  Widget _row(PushSegment s) {
    final n = s.rules.length;
    return PushCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.name, style: pushTs(size: 14.5, w: FontWeight.w800)),
          if (s.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(s.description,
                style: pushTs(size: 12, w: FontWeight.w600, color: AppColors.ink2)),
          ],
          const SizedBox(height: 4),
          Text(
              '$n ${gt(n == 1 ? 'condition' : 'conditions')} · ${gt(s.match == 'ANY' ? 'any' : 'all')} · ${pushWhen(s.updatedAt)}',
              style: pushTs(size: 11.5, w: FontWeight.w600, color: AppColors.ink3)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton('Use in a broadcast',
                  size: BtnSize.sm,
                  icon: 'bell',
                  onTap: () => go('/admin/push?new=1&segment=${s.id}')),
              AppButton('Edit',
                  size: BtnSize.sm,
                  icon: 'edit',
                  variant: BtnVariant.secondary,
                  onTap: () => go('/admin/push?seg=${s.id}')),
              AppButton('Delete',
                  size: BtnSize.sm,
                  icon: 'trash',
                  variant: BtnVariant.dangerSoft,
                  loading: _busyId == s.id,
                  onTap: _busyId == null ? () => _delete(s) : null),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Segment editor (create / edit)
// ---------------------------------------------------------------------------

class PushSegmentEditor extends StatefulWidget {
  /// `null` = new segment.
  final String? id;
  const PushSegmentEditor({super.key, this.id});

  @override
  State<PushSegmentEditor> createState() => _PushSegmentEditorState();
}

class _PushSegmentEditorState extends State<PushSegmentEditor> {
  final SegmentDraft _draft = SegmentDraft();
  String _name = '';
  String _desc = '';
  bool _loading = false;
  bool _saving = false;
  String? _loadError;
  Map<String, String> _errors = {};

  bool get _isNew => widget.id == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _draft.addRule();
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final s = await Api.instance.push.segment(widget.id!);
      if (!mounted) return;
      _name = s.name;
      _desc = s.description;
      _draft.load(s.match, s.rules);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = pushError(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.trim();
    if (name.isEmpty) {
      setState(() => _errors = {'name': gt('Give the segment a name')});
      return;
    }
    if (_draft.rules.any((r) => r.type.isEmpty)) {
      showToast(gt('Choose a type for every condition'), 'error');
      return;
    }
    setState(() {
      _saving = true;
      _errors = {};
    });
    final body = {
      'name': name,
      'description': _desc.trim(),
      ..._draft.spec.toJson(),
    };
    try {
      ApiException.clearFields();
      if (_isNew) {
        await Api.instance.push.createSegment(body);
      } else {
        await Api.instance.push.updateSegment(widget.id!, body);
      }
      if (!mounted) return;
      showToast(gt('Segment saved'));
      go('/admin/push?tab=segments');
    } on ApiException catch (e) {
      if (!mounted) return;
      final f = Map<String, String>.from(e.fields);
      if (e.code == 'SEGMENT_NAME_TAKEN') {
        f['name'] = gt('Another segment already has this name');
      }
      _draft.setErrors(f);
      setState(() => _errors = f);
      showToast(f.isNotEmpty && e.code == 'SEGMENT_NAME_TAKEN'
          ? f['name']!
          : e.messageWithRef, 'error');
    } catch (e) {
      if (mounted) showToast(pushError(e), 'error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const SkeletonRows(rows: 4);
    } else if (_loadError != null) {
      body = ErrorRetry(message: _loadError!, onRetry: _load);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            label: 'Segment name',
            value: _name,
            maxLength: 60,
            placeholder: 'Big spenders',
            error: _errors['name'],
            onChanged: (v) => _name = v,
          ),
          const SizedBox(height: 12),
          AppField(
            label: 'Description (optional)',
            value: _desc,
            maxLength: 300,
            error: _errors['description'],
            onChanged: (v) => _desc = v,
          ),
          if (_errors['match'] != null) ...[
            const SizedBox(height: 8),
            PushNote(_errors['match']!, error: true),
          ],
          const SizedBox(height: 16),
          SegmentBuilder(draft: _draft),
          const SizedBox(height: 12),
        ],
      );
    }
    return PushAdminPage(
      title: gt(_isNew ? 'New segment' : 'Edit segment'),
      sub: gt('Pick customers by what they did'),
      back: true,
      bottom: AdminSaveBar(
        child: AppButton('Save segment',
            block: true,
            loading: _saving,
            onTap: (_loading || _loadError != null) ? null : _save),
      ),
      child: body,
    );
  }
}
