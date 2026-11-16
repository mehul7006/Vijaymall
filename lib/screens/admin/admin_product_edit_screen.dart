import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../customer/missing_screen.dart';
import 'admin_purchases_reports.dart' show showPriceHistory;
import '../../data/api/api_exception.dart';
import '../../data/api/api_service.dart' show Api;
import '../../data/api/label_dto.dart' show barcodeError;
import 'admin_labels_barcode.dart';
import '../../data/gst_cache.dart';
import '../../data/models.dart';
import '../../data/validators.dart';
import '../../state/gu_strings.dart';
import '../../data/web_file_picker.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/gst_picker.dart';
import '../../widgets/panels.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';

/// `#/admin/product/:id|new` — create or edit a catalogue product.
class AdminProductEditScreen extends StatelessWidget {
  final String productId;

  const AdminProductEditScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    if (productId != 'new' && state.productById(productId) == null) {
      return const MissingScreen(
        title: 'Product',
        copy: 'We could not find that product.',
        backRoute: '/admin/inventory',
      );
    }
    return _ProductEditBody(productId: productId);
  }
}

class _ProductEditBody extends StatefulWidget {
  final String productId;

  const _ProductEditBody({required this.productId});

  @override
  State<_ProductEditBody> createState() => _ProductEditBodyState();
}

class _ProductEditBodyState extends State<_ProductEditBody> {
  /// Local draft — built once, mutated in place, handed to `saveProduct`.
  Product? _draft;

  // --- photo upload ---
  bool _uploading = false;

  // --- POS & tax (per saved backend pack row) ---
  String? _posLoadedFor; // backend id the form currently reflects
  bool _posSaving = false;
  int _posVariant = 0; // draft.variants index being edited
  String _posSoldBy = 'UNIT';
  String _posPlu = '';
  String _posGst = '0';
  String _posHsn = '';
  int _posGen = 0; // bumps when the stored GST/HSN is (re)loaded
  bool _posReady = false; // stored values read (existing products)
  String _posBarcodes = '';

  /// Server answers `PLU_TAKEN` / `BARCODE_TAKEN` shown under the input.
  String? _posPluSrv;
  String? _posBcSrv;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Units power the per-pack unit picker. The bootstraps normally read them
    // already; this covers a deep link straight into the editor.
    StateScope.read(context).refreshUnits();
  }

  Product _draftFor(AppState state) {
    return _draft ??= widget.productId == 'new'
        ? Product(
            id: 'new',
            name: '',
            nameGu: '',
            category: state.categories.isNotEmpty
                ? state.categories.first.id
                : 'grocery',
            unit: '',
            desc: '',
            descGu: '',
            rating: 0,
            reviews: 0,
            art: '',
            tone: 'mint',
            stock: 0,
            lowStock: 6,
            available: true,
            earnsCoins: true,
            allowCoins: true,
            variants: <Variant>[],
            defaultVariant: 0,
          )
        : state.productById(widget.productId)!.deepCopy();
  }

  /// Money field: keeps up to 2 decimals (paise precision).
  static num _toMoney(String s, num fallback) {
    final d = double.tryParse(s.trim());
    if (d == null || d.isNaN || d < 0) return fallback;
    final p = (d * 100).round();
    return p % 100 == 0 ? p ~/ 100 : p / 100;
  }

  static int _toInt(String s, int fallback) {
    final d = double.tryParse(s.trim());
    if (d == null || d.isNaN) return fallback;
    final r = d.round();
    return r < 0 ? 0 : r;
  }

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final draft = _draftFor(state);
    final isNew = widget.productId == 'new';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: isNew ? 'Add product' : 'Edit product',
                  sub: '${draft.category} · ${draft.variants.length} pack${draft.variants.length == 1 ? '' : 's'}',
                  bell: false,
                ),
                ScreenScroll(
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardPanel(
                        title: 'Basics',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FieldRow(
                              flex: const [3, 2],
                              children: [
                                AppField(
                                  label: 'Product name',
                                  placeholder: 'e.g. Premium Almonds',
                                  value: draft.name,
                                  error: _localErr['name'] ??
                                      ApiException.fieldError(_fieldErr, ['nameEn', 'name']),
                                  onChanged: (v) =>
                                      setState(() => draft.name = v),
                                ),
                                SelectField(
                                  label: 'Category',
                                  value: _catName(state, draft.category),
                                  placeholder: 'Pick a category',
                                  onTap: () => _pickCategory(state),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ---- GST & HSN (new product: defaulted from the GST master) ----
                      if (isNew && state.backendMode && !_hasBackendPack(draft)) ...[
                        CardPanel(
                          title: 'GST & HSN',
                          child: _gstBlock(state, draft),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ---- Pricing & packs ----
                      CardPanel(
                        title: 'Pricing & packs',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Hint(
                              'Prices accept exact paise, e.g. 49.50. Each pack '
                              'has its own price, MRP and stock.',
                            ),
                            const SizedBox(height: 12),
                            for (var i = 0; i < draft.variants.length; i++)
                              _variantRow(draft, i),
                            if (draft.variants.isEmpty)
                              const Hint(
                                  'Add at least one pack with a price.'),
                            if (draft.variants.isNotEmpty)
                              const SizedBox(height: 4),
                            AppButton(
                              'Add variant',
                              variant: BtnVariant.secondary,
                              icon: 'plus',
                              block: true,
                              onTap: () => setState(() {
                                draft.variants.add(Variant(
                                  label: '',
                                  price: 0,
                                  mrp: 0,
                                  unit: '',
                                  stock: 0,
                                ));
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ---- Stock alert ----
                      CardPanel(
                        title: 'Stock alert',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Low-stock alert level (backend `lowThreshold`, sent
                            // on every pack of this product).
                            FieldRow(
                              children: [
                                AppField(
                                  label: 'Low-stock alert at',
                                  value: '${draft.lowStock}',
                                  numeric: true,
                                  placeholder: 'e.g. 6',
                                  onChanged: (s) => setState(() =>
                                      draft.lowStock = _toInt(s, draft.lowStock)),
                                ),
                                const SizedBox.shrink(),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Hint(
                              'Shows as low stock in Inventory and alerts '
                              'when total stock falls to this number.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ---- Options ----
                      CardPanel(
                        title: 'Options',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _switchRow(
                              'Earn coins on this product',
                              draft.earnsCoins,
                              (v) => setState(() => draft.earnsCoins = v),
                            ),
                            _switchRow(
                              'Allow coins on this product',
                              draft.allowCoins,
                              (v) => setState(() => draft.allowCoins = v),
                            ),
                            _switchRow(
                              'Available for sale',
                              draft.available,
                              (v) => setState(() => draft.available = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ---- Photo (uploaded product image) ----
                      _photoCard(state, draft),
                      const SizedBox(height: 14),

                      // ---- POS & tax (till/barcode/GST) ----
                      if (_hasBackendPack(draft)) ...[
                        _posCard(state, draft),
                        const SizedBox(height: 14),
                      ],

                      // ---- Stock lots (batches, expiry, lot pricing) ----
                      if (_hasBackendPack(draft)) ...[
                        _lotsCard(draft),
                        const SizedBox(height: 14),
                      ],

                    ],
                  ),
                ),
                AdminSaveBar(
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          'Save product',
                          block: true,
                          onTap: _save,
                        ),
                      ),
                      const SizedBox(width: 10),
                      AppButton(
                        'Cancel',
                        variant: BtnVariant.secondary,
                        onTap: () => Nav.instance.pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const AdminNav(active: 'inventory'),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Photo
  // ---------------------------------------------------------------------------

  bool _hasBackendPack(Product draft) =>
      draft.variants.any((v) => v.backendId != null);

  /// First pack row that exists on the backend (photo + POS attach to it).
  String? _backendId(Product draft) {
    for (final v in draft.variants) {
      if (v.backendId != null) return v.backendId;
    }
    return null;
  }

  /// Entry to the stock-lots screen (lots, expiry, lot-priced switches).
  Widget _lotsCard(Product draft) {
    return CardPanel(
      title: gt('Stock lots and expiry'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              gt('See the batches of each pack with cost, quantity left and expiry, and switch on lot pricing or expiry tracking.'),
              style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink3)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in draft.variants)
                if (v.backendId != null)
                  AppButton(
                      '${gt('Lots')}: ${v.label.isEmpty ? gt('Pack') : v.label}',
                      size: BtnSize.sm,
                      variant: BtnVariant.secondary,
                      onTap: () => go(
                          '/admin/stock-lots?variant=${v.backendId}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoCard(AppState state, Product draft) {
    final id = _backendId(draft);
    final art = draft.art;
    final showUpload = state.backendMode && kIsWeb;
    return CardPanel(
      title: 'Photo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 84,
                height: 84,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: art.isEmpty
                    ? const Center(
                        child: Text(
                          'No photo',
                          style: TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 11,
                            color: AppColors.ink3,
                          ),
                        ),
                      )
                    : ProductArtView(art, size: 84),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showUpload)
                      AppButton(
                        _uploading ? 'Uploading…' : 'Upload photo',
                        variant: BtnVariant.secondary,
                        icon: 'plus',
                        loading: _uploading,
                        // Enabled even before the product exists: on a new
                        // item the tap saves the product first and then
                        // attaches the photo (it used to be disabled here,
                        // which read as "upload does not work").
                        onTap:
                            _uploading ? null : () => _uploadPhoto(draft),
                      ),
                    const SizedBox(height: 8),
                    Hint(
                      !state.backendMode
                          ? 'Photos are stored by the backend — sign in with '
                              'the live API to upload.'
                          : id == null
                              ? 'New item: pick the photo and it saves the '
                                  'product first, then attaches the photo.'
                              : 'JPG or PNG. Shown on the shop, cart and '
                                  'receipts.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _uploadPhoto(Product draft) async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      // Pick first: dismissing the dialog must not create anything.
      final picked = await pickImageFile();
      if (picked == null) return;
      if (!mounted) return;
      final state = StateScope.read(context);

      var id = _backendId(draft);
      if (id == null) {
        // New item — the photo attaches to a saved pack row, so save the
        // product now (locally, then on the backend) and use its id.
        // `persistToServer: false` keeps this call to the local write: the
        // awaited save below is the single POST, so a 2-pack product is not
        // created twice (once fire-and-forget, once awaited).
        final err = state.saveProduct(
          draft,
          existingId: widget.productId == 'new' ? null : widget.productId,
          persistToServer: false,
        );
        if (err != null) {
          showToast(err, 'error');
          return;
        }
        final saveErr = await state.saveProductToServer(draft);
        if (!mounted) return;
        if (saveErr != null) {
          showToast(saveErr, 'error');
          return;
        }
        id = _backendId(draft);
        if (id == null) {
          showToast(
              'The product could not be saved, so the photo was not '
              'uploaded. Fix the highlighted fields and try again.',
              'error');
          return;
        }
        // The pack/POS cards appear now that the row exists on the server.
        if (mounted) setState(() {});
      }

      final r = await state.uploadProductImage(id, picked.bytes, picked.name);
      if (!mounted) return;
      if (r.error != null) {
        showToast(r.error!, 'error');
        return;
      }
      if (r.url != null) setState(() => draft.art = r.url!);
      showToast('Photo uploaded');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // POS & tax
  // ---------------------------------------------------------------------------

  Widget _posCard(AppState state, Product draft) {
    final backendPacks = <int>[
      for (var i = 0; i < draft.variants.length; i++)
        if (draft.variants[i].backendId != null) i,
    ];
    if (!backendPacks.contains(_posVariant)) {
      _posVariant = backendPacks.isEmpty ? 0 : backendPacks.first;
    }

    // Load the selected pack's server-side attributes once available.
    final id = draft.variants[_posVariant].backendId;
    if (id != null && _posLoadedFor != id) {
      _posLoadedFor = id; // set synchronously to avoid repeat scheduling
      _posReady = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadPos(id));
      });
    }

    return CardPanel(
      title: 'POS & tax',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (backendPacks.length > 1) ...[
            SelectField(
              label: 'Applies to pack',
              value: draft.variants[_posVariant].label,
              placeholder: 'Pick a pack',
              onTap: () => _pickPosPack(draft, backendPacks),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Sold by',
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
              SegmentOption('UNIT', 'Unit'),
              SegmentOption('WEIGHT', 'Weight'),
            ],
            value: _posSoldBy == 'WEIGHT' ? 'WEIGHT' : 'UNIT',
            onChanged: (v) => setState(() => _posSoldBy = v),
          ),
          const SizedBox(height: 12),
          FieldRow(
            flex: const [3, 2],
            children: [
              AppField(
                label: _posSoldBy == 'WEIGHT' ? 'PLU (required)' : 'PLU',
                value: _posPlu,
                placeholder: 'Weighed item code, 1 to 6 digits',
                numeric: true,
                maxLength: 6,
                error: _pluError() ?? _posPluSrv,
                onChanged: (v) => setState(() {
                  _posPlu = v;
                  _posPluSrv = null;
                }),
              ),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 12),
          _gstBlock(state, draft),
          const SizedBox(height: 12),
          AppField(
            label: 'Barcodes (comma separated)',
            value: _posBarcodes,
            placeholder: '8901234567890, 8901234567891',
            error: _barcodesError() ?? _posBcSrv,
            onChanged: (v) => setState(() {
              _posBarcodes = v;
              _posBcSrv = null;
            }),
          ),
          if (_posSoldBy == 'WEIGHT') ...[
            const SizedBox(height: 8),
            const Hint(
                'A weighed item is counter-only. Its price is per 1000 g and its stock is kept in grams (set both in the catalog). '
                'Do not give it a 13-digit barcode that starts with the shop\'s weighed prefix.'),
          ],
          if (id != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                'Generate store barcode',
                size: BtnSize.sm,
                variant: BtnVariant.secondary,
                onTap: () async {
                  final r = await showGenerateBarcodeSheet(context,
                      variantId: id,
                      name: '${draft.name} ${draft.variants[_posVariant].label}');
                  if (r == null || !mounted) return;
                  final have = _posBarcodes
                      .split(',')
                      .map((b) => b.trim())
                      .where((b) => b.isNotEmpty)
                      .toList();
                  // The server saved it already; show every barcode it holds.
                  for (final b in r.barcodes) {
                    if (!have.contains(b)) have.add(b);
                  }
                  setState(() => _posBarcodes = have.join(', '));
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          AppButton(
            'Save POS details',
            variant: BtnVariant.secondary,
            block: true,
            loading: _posSaving,
            onTap: _posSaving
                ? null
                : () => _savePos(
                      draft,
                      backendId: draft.variants[_posVariant].backendId,
                    ),
          ),
        ],
      ),
    );
  }

  /// Check digit of every typed 8/12/13-digit barcode (same rule as the
  /// server, `72-barcode-labels.md`); null when all are fine.
  String? _barcodesError() {
    for (final b in _posBarcodes.split(',')) {
      final t = b.trim();
      if (t.isEmpty) continue;
      // Server rule: 4 to 32 letters, digits or dashes.
      if (!RegExp(r'^[A-Za-z0-9\-]{4,32}$').hasMatch(t)) {
        return gt('Barcode $t must be 4 to 32 letters, digits or dashes');
      }
      final m = barcodeError(t);
      if (m != null) return gt(m);
    }
    return null;
  }

  /// PLU: 1 to 6 digits, required when the product is sold by weight.
  String? _pluError() {
    final t = _posPlu.trim();
    if (t.isEmpty) {
      return _posSoldBy == 'WEIGHT'
          ? gt('Enter the item code (PLU) of this weighed item')
          : null;
    }
    if (!RegExp(r'^\d{1,6}$').hasMatch(t)) {
      return gt('PLU must be 1 to 6 digits');
    }
    return null;
  }

  Future<void> _loadPos(String id) async {
    final dto = await StateScope.read(context).loadPosAttributes(id);
    if (!mounted) return;
    if (dto == null) {
      setState(() => _posReady = true);
      return;
    }
    setState(() {
      _posReady = true;
      _posGen++;
      _posLoadedFor = id;
      _posSoldBy = (dto.soldBy ?? 'UNIT') == 'WEIGHT' ? 'WEIGHT' : 'UNIT';
      _posPlu = dto.plu ?? '';
      _posGst = '${dto.gstPercent}';
      _posHsn = dto.hsn ?? '';
      _posBarcodes = dto.barcodes.join(', ');
    });
  }

  Future<void> _savePos(Product draft, {String? backendId}) async {
    final id = backendId ?? _backendId(draft);
    if (id == null) {
      showToast('Save the product first — POS details attach to a saved pack.',
          'error');
      return;
    }
    if (_posSaving) return;
    // Never turn an unreadable tax rate into 0 % silently; the server only
    // accepts 0, 3, 5, 12, 18 or 28.
    final gst = int.tryParse(_posGst.trim());
    final gstMsg = Validators.gstSlab(gst);
    if (gstMsg != null) {
      showToast(gt(gstMsg), 'error');
      return;
    }
    final hsnMsg = _hsnError();
    if (hsnMsg != null) {
      showToast(hsnMsg, 'error');
      return;
    }
    final bcMsg = _barcodesError();
    if (bcMsg != null) {
      showToast(bcMsg, 'error');
      return;
    }
    final pluMsg = _pluError();
    if (pluMsg != null) {
      showToast(pluMsg, 'error');
      return;
    }
    setState(() {
      _posSaving = true;
      _posPluSrv = null;
      _posBcSrv = null;
    });
    String? err;
    try {
      await Api.instance.admin.savePosAttributes(
        id,
        soldBy: _posSoldBy,
        plu: _posPlu.trim(),
        gstPercent: gst!,
        hsn: _posHsn.trim(),
        barcodes: {
          for (final b in _posBarcodes.split(','))
            if (b.trim().isNotEmpty) b.trim()
        }.toList(),
      );
    } on ApiException catch (e) {
      err = e.message;
      if (e.code == 'PLU_TAKEN') {
        _posPluSrv = gt('Another product already uses this PLU');
      } else if (e.code == 'BARCODE_TAKEN') {
        _posBcSrv =
            '${gt('This barcode is already on another product')}: ${e.details?['barcode'] ?? ''}';
      } else {
        _posPluSrv = ApiException.fieldError(e.fields, ['plu']);
        _posBcSrv = ApiException.fieldError(e.fields, ['barcodes']);
      }
    } catch (_) {
      err = 'Could not save the POS details.';
    }
    if (!mounted) return;
    setState(() => _posSaving = false);
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    setState(() => _posLoadedFor = id);
    unawaited(GstCache.load(force: true));
    showToast('POS details saved');
  }

  /// New products get their pack rows a moment after save — wait for the
  /// server ids, then persist the POS/tax details onto the first pack.
  Future<void> _savePosWhenReady(AppState state, Product draft) async {
    for (var attempt = 0; attempt < 30; attempt++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final id = _backendId(draft);
      if (id == null) continue;
      final err = await state.savePosAttributes(
        id,
        soldBy: _posSoldBy,
        plu: _posPlu,
        gstPercent: int.tryParse(_posGst.trim()) ?? 0,
        hsn: _posHsn,
        barcodes: _posBarcodes
            .split(',')
            .map((b) => b.trim())
            .where((b) => b.isNotEmpty)
            .toList(),
      );
      if (mounted && err == null) showToast('POS details saved');
      if (mounted && err != null) showToast(err, 'error');
      return;
    }
  }

  void _pickPosPack(Product draft, List<int> backendPacks) {
    showAppSheet(
      context: context,
      title: 'Pack',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in backendPacks)
            SheetOption(
              title: draft.variants[i].label,
              selected: _posVariant == i,
              onTap: () {
                setState(() => _posVariant = i);
                Navigator.of(ctx).pop();
              },
            ),
        ],
      ),
    );
  }

  void _pickCategory(AppState state) {
    final draft = _draft;
    if (draft == null) return;
    showAppSheet(
      context: context,
      title: 'Category',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in state.pickerCategories)
            SheetOption(
              title: c.name,
              leading: c.icon,
              selected: draft.category == c.id,
              onTap: () {
                setState(() => draft.category = c.id);
                Navigator.of(ctx).pop();
              },
            ),
          SheetOption(
            title: '＋ New type…',
            leading: 'plus',
            selected: false,
            onTap: () {
              Navigator.of(ctx).pop();
              unawaited(_addCategorySheet(state, draft));
            },
          ),
        ],
      ),
    );
  }

  /// Prompt for a new category name → `POST /admin/categories`, then select
  /// the freshly created type on this draft.
  Future<void> _addCategorySheet(AppState state, Product draft) async {
    final ctrl = TextEditingController();
    final name = await showAppSheet<String>(
      context: context,
      title: 'New type',
      sub: 'Adds a category to the catalogue',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppField(
              label: 'Type name',
              placeholder: 'e.g. Snacks',
              controller: ctrl,
            ),
            const SizedBox(height: 14),
            AppButton(
              'Add type',
              block: true,
              onTap: () => Navigator.of(ctx).pop(ctrl.text),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (name == null || !mounted) return;
    final res = await state.addCategory(name);
    if (!mounted) return;
    if (res.error != null) {
      showToast(res.error!, 'error');
      return;
    }
    setState(() => draft.category = res.id ?? draft.category);
    showToast('Type added');
  }

  Map<String, String> _fieldErr = const {};
  Map<String, String> _localErr = const {};

  String _halfRate() {
    final g = int.tryParse(_posGst.trim()) ?? 0;
    return g.isEven ? '${g ~/ 2}' : '${g / 2}';
  }

  /// HSN is optional; when given it is 4, 6 or 8 digits (2 allowed for
  /// chapter-level codes).
  String? _hsnError() => GstPicker.hsnErrorFor(_posHsn);

  /// GST rate + HSN with the GST-master suggestion. New products fill from
  /// the master until the user edits; saved products keep their stored
  /// values and only get an optional suggestion when the HSN was blank.
  Widget _gstBlock(AppState state, Product draft) {
    final isNew = widget.productId == 'new' && !_hasBackendPack(draft);
    if (!isNew && !_posReady) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Hint(gt('Loading GST details...')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GstPicker(
          key: ValueKey('gst-$isNew-$_posVariant-$_posGen'),
          productName: draft.name,
          category: _catName(state, draft.category),
          price: _posVariant < draft.variants.length
              ? draft.variants[_posVariant].price.toDouble()
              : null,
          initialGst: int.tryParse(_posGst.trim()) ?? 0,
          initialHsn: _posHsn,
          autoApply: isNew,
          suggestOnlyIfBlank: !isNew,
          onChanged: (g, h) => setState(() {
            _posGst = '$g';
            _posHsn = h;
          }),
        ),
        const SizedBox(height: 6),
        Hint('Split equally as CGST + SGST (${_halfRate()}% each) on bills. '
            'Applies to the pack chosen above.'),
      ],
    );
  }

  /// Local checks that mirror Swagger limits (name 120, pack 40, amounts up
  /// to Rs 10,00,000). Shown under each field; blocks the save.
  Map<String, String> _validateDraft(Product d) {
    final e = <String, String>{};
    final n = Validators.text(d.name,
        label: 'Product name', required: true, min: 2, max: 120);
    if (n != null) e['name'] = gt(n);
    for (var i = 0; i < d.variants.length; i++) {
      final v = d.variants[i];
      final l = Validators.text(v.label, label: 'Pack name', max: 40);
      if (l != null) e['pack$i.label'] = gt(l);
      if (v.price < 0 || v.price > 1000000) {
        e['pack$i.price'] = gt('Price must be between 0 and 10,00,000');
      }
      if (v.mrp < 0 || v.mrp > 1000000) {
        e['pack$i.mrp'] = gt('MRP must be between 0 and 10,00,000');
      } else if (v.mrp > 0 && v.price > v.mrp) {
        e['pack$i.price'] = gt('Price cannot be more than the MRP');
      }
      if (v.stock < 0) e['pack$i.stock'] = gt('Stock cannot be negative');
    }
    final h = _hsnError();
    if (h != null) e['hsn'] = h;
    return e;
  }

  Future<void> _save() async {
    final state = StateScope.read(context);
    final draft = _draft;
    if (draft == null) return;
    final isNew = widget.productId == 'new';
    final localErr = _validateDraft(draft);
    setState(() => _localErr = localErr);
    if (localErr.isNotEmpty) {
      showToast(localErr.values.first, 'error');
      return;
    }
    final err = state.saveProduct(
      draft,
      existingId: isNew ? null : widget.productId,
      persistToServer: false,
    );
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    if (state.backendMode) {
      // Wait for the server so a rejected field is highlighted here.
      ApiException.clearFields();
      final saveErr = await state.saveProductToServer(draft);
      if (!mounted) return;
      if (saveErr != null) {
        setState(() => _fieldErr = ApiException.takeFields());
        showToast(saveErr, 'error');
        return;
      }
      if (_fieldErr.isNotEmpty) setState(() => _fieldErr = const {});
    }
    // Carry the POS/tax details along with the product save.
    if (state.backendMode && _hasBackendPack(draft)) {
      unawaited(_savePosSilent(draft));
    } else if (state.backendMode && isNew) {
      unawaited(_savePosWhenReady(state, draft));
    }
    showToast('Product saved');
    go('/admin/inventory');
  }

  /// Re-save the POS/tax form for an existing product without a success
  /// toast (the card has its own save button that reports explicitly).
  Future<void> _savePosSilent(Product draft) async {
    final id = _backendId(draft);
    if (id == null) return;
    final err = await StateScope.read(context).savePosAttributes(
      id,
      soldBy: _posSoldBy,
      plu: _posPlu,
      gstPercent: int.tryParse(_posGst.trim()) ?? 0,
      hsn: _posHsn,
      barcodes: _posBarcodes
          .split(',')
          .map((b) => b.trim())
          .where((b) => b.isNotEmpty)
          .toList(),
    );
    if (mounted && err != null) showToast(err, 'error');
  }

  /// One editable pack: name + price / mrp / stock + remove.
  Widget _variantRow(Product draft, int i) {
    final v = draft.variants[i];
    // Per-pack server errors (one request per pack); falls back to the
    // single recorded map when the save produced none per row.
    final st = StateScope.read(context);
    final packErr = st.productPackErrors.isNotEmpty
        ? (st.productPackErrors[i] ?? const <String, String>{})
        : _fieldErr;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: packErr.isNotEmpty ? AppColors.redTint : AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: packErr.isNotEmpty
                ? AppColors.red.withValues(alpha: .4)
                : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                StatusChip('Pack ${i + 1}',
                    fg: AppColors.navy2, bg: AppColors.navyTint),
                if (packErr.isEmpty) const Spacer(),
                if (packErr.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppColors.red),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text('Fix the highlighted fields',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppTheme.uiFont,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red)),
                  ),
                ],
                IconBtn(
                  'trash',
                  size: 34,
                  iconSize: 14,
                  onTap: () =>
                      setState(() => draft.variants.removeAt(i)),
                ),
              ],
            ),
          ),
          FieldRow(
            children: [
              AppField(
                label: 'Pack name',
                placeholder: 'e.g. 500 g',
                value: v.label,
                error: _localErr['pack$i.label'] ??
                    ApiException.fieldError(packErr, ['packSize']),
                onChanged: (s) => setState(() => v.label = s),
              ),
              SelectField(
                label: 'Unit',
                value: _unitLabel(v.unit),
                placeholder: 'Pick a unit',
                onTap: () => _pickUnit(draft, i),
              ),
            ],
          ),
          if (v.unit.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Price and MRP are per ${_unitLabel(v.unit).toLowerCase()}',
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 11.5,
                  color: AppColors.ink3,
                ),
              ),
            ),
          const SizedBox(height: 10),
          FieldRow(
            children: [
              AppField(
                label: 'Price',
                value: '${v.price}',
                error: _localErr['pack$i.price'] ??
                    ApiException.fieldError(packErr, ['pricePaise', 'price']),
                numeric: true,
                onChanged: (s) =>
                    setState(() => v.price = _toMoney(s, v.price)),
              ),
              AppField(
                label: 'MRP',
                value: '${v.mrp}',
                error: _localErr['pack$i.mrp'] ??
                    ApiException.fieldError(packErr, ['mrpPaise', 'mrp']),
                numeric: true,
                onChanged: (s) =>
                    setState(() => v.mrp = _toMoney(s, v.mrp)),
              ),
              AppField(
                label: 'Stock',
                value: '${v.stock}',
                error: _localErr['pack$i.stock'] ??
                    ApiException.fieldError(packErr, ['qtyOnHand', 'stock']),
                numeric: true,
                onChanged: (s) =>
                    setState(() => v.stock = _toInt(s, v.stock)),
              ),
            ],
          ),
          if (v.backendId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppLink('Purchase price history',
                  onTap: () => showPriceHistory(context, v.backendId!,
                      '${draft.name}${v.label.isEmpty ? '' : ' · ${v.label}'}')),
            ),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  String _catName(AppState state, String id) {
    for (final c in state.pickerCategories) {
      if (c.id == id) return c.name;
    }
    return id;
  }

  /// Display name for a stored unit code; empty means "not picked yet", which
  /// [SelectField] renders as its placeholder.
  String _unitLabel(String code) {
    if (code.isEmpty) return '';
    for (final u in StateScope.read(context).units) {
      if (u.code == code) return u.label;
    }
    // Unknown code (row edited elsewhere): still show something sensible.
    return code;
  }

  /// Pick the unit of measure for one pack. The backend only accepts a unit
  /// that exists in `GET /units`, so this is a picker, never a free field.
  void _pickUnit(Product draft, int i) {
    final state = StateScope.read(context);
    final units = state.activeUnits;
    if (units.isEmpty) {
      showToast('No units yet — add kg / piece / dozen under Units first', 'error');
      go('/admin/units');
      return;
    }
    final current = draft.variants[i].unit;
    showAppSheet<void>(
      context: context,
      title: 'Unit',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final u in units)
            SheetOption(
              title: u.label,
              sub: '${u.code} · price per ${u.label.toLowerCase()} · ${u.soldBy == 'WEIGHT' ? 'sold by weight' : 'sold by count'}',
              selected: current == u.code,
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() => draft.variants[i].unit = u.code);
              },
            ),
        ],
      ),
    );
  }
}
