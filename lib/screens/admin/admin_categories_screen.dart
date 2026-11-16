import 'package:flutter/material.dart';

import '../../data/validators.dart';
import '../../data/api/dto.dart';
import '../../data/web_file_picker.dart';
import '../../provider/state_scope.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';

/// `#/admin/categories` — manage store categories (`/admin/categories`).
///
/// Lists every category including hidden ones, with an on/off switch, add and
/// rename, a picture upload and delete. The backend refuses a delete with
/// `409 CATEGORY_IN_USE` while a product or coupon still uses the category;
/// the message tells the admin to move them or hide the category instead.
class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  bool _loaded = false;
  String? _busyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    StateScope.read(context).refreshAdminCategories();
  }

  Future<void> _toggle(CategoryDto c, bool v) async {
    final id = c.id;
    if (id == null || _busyId != null) return;
    setState(() => _busyId = id);
    final err = await StateScope.read(context).saveAdminCategory(
      id: id,
      nameEn: c.nameEn ?? '',
      nameGu: c.nameGu ?? '',
      sortOrder: c.sortOrder,
      active: v,
    );
    if (!mounted) return;
    setState(() => _busyId = null);
    if (err != null) showToast(err, 'error');
  }

  void _edit(CategoryDto? c) {
    showAppSheet<void>(
      context: context,
      title: c == null ? gt('New category') : '${gt('Edit')} ${c.nameEn ?? ''}',
      builder: (ctx) => _CategoryEditor(
        category: c,
        onDone: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = StateScope.of(context).adminCategoryRows;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Categories'),
                  sub: '${rows.length} ${gt(rows.length == 1 ? 'category' : 'categories')}'
                      ' · ${gt('incl. hidden')}',
                  bell: false,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: IconBtn(
                        'plus',
                        size: 38,
                        iconSize: 17,
                        onTap: () => _edit(null),
                      ),
                    ),
                  ],
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rows.isNotEmpty) ...[
                        KpiGrid([
                          KpiCard(
                            icon: 'grid',
                            tint: AppColors.navy2,
                            bg: AppColors.navyTint,
                            label: gt('Categories'),
                            value: '${rows.length}',
                          ),
                          KpiCard(
                            icon: 'check',
                            tint: AppColors.green,
                            bg: AppColors.greenTint,
                            label: gt('Visible'),
                            value: '${rows.where((c) => c.active).length}',
                          ),
                          KpiCard(
                            icon: 'close',
                            tint: AppColors.red,
                            bg: AppColors.redTint,
                            label: gt('Hidden'),
                            value: '${rows.where((c) => !c.active).length}',
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      if (rows.isEmpty)
                        AdminLoadingOrElse(
                          fallback: CardPanel(
                            title: gt('Category list'),
                            child: const Hint(
                                'No categories yet. Tap + to add one.'),
                          ),
                        )
                      else
                      CardPanel(
                        title: gt('Category list'),
                        child: Column(
                                children: [
                                  for (var i = 0; i < rows.length; i++)
                                    _row(rows[i], last: i == rows.length - 1),
                                ],
                              ),
                      ),
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Hint(
                          'A hidden category disappears from the shop but its '
                          'products keep it. A category can only be deleted '
                          'when no product or coupon uses it.',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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

  Widget _row(CategoryDto c, {required bool last}) {
    final img = c.imageUrl ?? '';
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 42,
              height: 42,
              child: img.isEmpty
                  ? const ColoredBox(color: AppColors.line)
                  : ProductArtView(img, size: 42),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.nameEn ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (!c.active)
                  Text(
                    gt('Hidden from customers'),
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 11.5,
                      color: AppColors.red,
                    ),
                  ),
              ],
            ),
          ),
          AppSwitch(
            value: c.active,
            onChanged: _busyId == c.id ? null : (v) => _toggle(c, v),
          ),
          const SizedBox(width: 10),
          AppButton('Edit',
              variant: BtnVariant.secondary, onTap: () => _edit(c)),
        ],
      ),
    );
  }
}

/// Sheet editor: names, active flag, picture, delete.
class _CategoryEditor extends StatefulWidget {
  final CategoryDto? category;
  final VoidCallback onDone;

  const _CategoryEditor({required this.category, required this.onDone});

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late String _en;
  late String _gu;
  late bool _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _en = widget.category?.nameEn ?? '';
    _gu = widget.category?.nameGu ?? '';
    _active = widget.category?.active ?? true;
  }

  String? _enErr;
  String? _guErr;

  Future<void> _save() async {
    if (_busy) return;
    final e1 = Validators.text(_en,
        label: 'Name', required: true, min: 2, max: 120);
    final e2 = Validators.text(_gu, label: 'Name', max: 120);
    setState(() {
      _enErr = e1 == null ? null : gt(e1);
      _guErr = e2 == null ? null : gt(e2);
    });
    if (e1 != null || e2 != null) return;
    setState(() => _busy = true);
    final c = widget.category;
    final err = await StateScope.read(context).saveAdminCategory(
      id: c?.id,
      nameEn: _en,
      nameGu: _gu,
      sortOrder: c?.sortOrder,
      active: _active,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    showToast(c == null ? gt('Category added') : gt('Category saved'));
    widget.onDone();
  }

  Future<void> _photo() async {
    final id = widget.category?.id;
    if (id == null || _busy) return;
    final picked = await pickImageFile();
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    final err = await StateScope.read(context)
        .uploadAdminCategoryImage(id, picked.bytes, picked.name);
    if (!mounted) return;
    setState(() => _busy = false);
    showToast(err ?? gt('Photo uploaded'), err == null ? 'success' : 'error');
  }

  Future<void> _delete() async {
    final id = widget.category?.id;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    final err = await StateScope.read(context).deleteAdminCategory(id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    showToast(gt('Category deleted'));
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.category == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            label: gt('Name (English)'),
            value: _en,
            maxLength: 120,
            error: _enErr,
            onChanged: (v) => _en = v,
          ),
          const SizedBox(height: 10),
          AppField(
            label: gt('Name (Gujarati)'),
            value: _gu,
            placeholder: 'Same as English if empty',
            maxLength: 120,
            error: _guErr,
            onChanged: (v) => _gu = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  gt('Shown to customers'),
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink2,
                  ),
                ),
              ),
              AppSwitch(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!isNew) ...[
            AppButton('Upload photo',
                variant: BtnVariant.secondary,
                block: true,
                onTap: _busy ? null : _photo),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: AppButton(isNew ? 'Add category' : 'Save',
                    block: true, loading: _busy, onTap: _busy ? null : _save),
              ),
              if (!isNew) ...[
                const SizedBox(width: 10),
                AppButton('Delete',
                    variant: BtnVariant.danger,
                    onTap: _busy ? null : _delete),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
