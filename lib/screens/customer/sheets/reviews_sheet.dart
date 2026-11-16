import 'package:flutter/material.dart';

import '../../../data/api/api_exception.dart' show ApiException;
import '../../../data/api/api_service.dart';
import '../../../data/api/dto.dart';
import '../../../data/api/mappers.dart' show PackRef;
import '../../../data/models.dart';
import '../../../provider/state_scope.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/fields.dart';
import '../../../widgets/sheet.dart';
import '../../../widgets/skeleton.dart' show ListSkeleton;
import '../../../widgets/toast.dart';
import '../../../state/gu_strings.dart';

/// §3.6 `Reviews` — the backend-backed review list for a product plus a
/// write-review form (stars 1–5 + comment → `POST /products/{id}/reviews`).
///
/// Reviews live on the **backend pack id** (first in-stock/default pack of
/// the grouped product). In demo mode the sheet shows the local rating only.
void showReviewsSheet(BuildContext context, Product p) {
  final st = StateScope.read(context);
  final packId = st.packIndex.values
          .firstWhere(
            (ref) => ref.product.id == p.id,
            orElse: () => PackRef(p, 0, p.variants.isEmpty ? Variant(label: '', price: 0, mrp: 0, unit: '') : p.variants.first),
          )
          .variant
          .backendId ??
      '';

  showAppSheet<void>(
    context: context,
    title: gt('Ratings & reviews'),
    sub: p.reviews > 0
        ? '${p.rating.toStringAsFixed(1)} ★ · ${p.reviews} reviews'
        : 'Be the first to review',
    builder: (ctx) => _ReviewsBody(product: p, packId: packId),
  );
}

class _ReviewsBody extends StatefulWidget {
  const _ReviewsBody({required this.product, required this.packId});

  final Product product;
  final String packId;

  @override
  State<_ReviewsBody> createState() => _ReviewsBodyState();
}

class _ReviewsBodyState extends State<_ReviewsBody> {
  List<ReviewDto> _items = [];
  double _rating = 0;
  int _count = 0;
  bool _loading = false;
  String? _error;

  // write-review form
  int _myRating = 0;
  final _comment = TextEditingController();
  bool _posting = false;

  /// Pack the signed-in customer may review (`GET .../reviews/mine` said
  /// `canReview`, or they already wrote a review for it). Reviews belong to a
  /// single pack, so for a multi-pack product this is the pack they bought.
  String _reviewPackId = '';
  bool _canReview = false;
  bool _checkedMine = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.packId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // All packs of the product together (`/product-groups/{id}/reviews`);
      // fall back to the single pack if the group call is unavailable.
      ReviewListDto list;
      try {
        list = await Api.instance.catalog
            .getGroupReviews(widget.packId, size: 50);
      } on ApiException {
        list = await Api.instance.catalog.getReviews(widget.packId, size: 50);
      }
      if (!mounted) return;
      // `GET .../reviews/mine` per pack: show the form only for a pack the
      // customer received (`canReview`) and prefill an existing review.
      final st = StateScope.read(context);
      if (st.signedIn && !_checkedMine) {
        final ids = <String>{
          for (final v in widget.product.variants)
            if ((v.backendId ?? '').isNotEmpty) v.backendId!,
          if (widget.packId.isNotEmpty) widget.packId,
        };
        String? canId;
        for (final id in ids) {
          final mine = await st.myReviewFor(id);
          if (!mounted) return;
          if (mine == null) continue;
          if (mine.review != null) {
            _reviewPackId = id;
            _canReview = true;
            if (_myRating == 0 && _comment.text.isEmpty) {
              _myRating = mine.review!.rating;
              _comment.text = mine.review!.comment ?? '';
            }
            canId = null;
            break;
          }
          if (mine.canReview) canId ??= id;
        }
        if (canId != null) {
          _reviewPackId = canId;
          _canReview = true;
        }
        _checkedMine = true;
      }
      setState(() {
        _items = list.items;
        _rating = list.rating;
        _count = list.reviewCount > 0 ? list.reviewCount : list.total;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load reviews.';
        _loading = false;
      });
    }
  }

  Future<void> _post() async {
    if (_posting) return;
    final st = StateScope.read(context);
    if (!st.signedIn) {
      showToast(gt('Sign in to write a review'), 'error');
      return;
    }
    if (_myRating < 1 || _myRating > 5) {
      showToast(gt('Tap the stars to pick a rating'), 'error');
      return;
    }
    setState(() => _posting = true);
    try {
      await Api.instance.catalog.postReview(
        _reviewPackId.isNotEmpty ? _reviewPackId : widget.packId,
        rating: _myRating,
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      // Keep the posted rating and comment in the form: a review now exists
      // (one per product), and posting again replaces it.
      setState(() {
        _posting = false;
        _canReview = true;
      });
      showToast(gt('Thanks for your review!'));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      showToast(e.message, 'error');
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      showToast(gt('Could not post the review.'), 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gu = StateScope.of(context).lang == 'gu';
    final p = widget.product;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- aggregate header --------------------------------------------
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Column(
                children: [
                  Text(
                    _rating > 0 ? _rating.toStringAsFixed(1) : '–',
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        AppIcon(
                          'star',
                          size: 12,
                          color: i <= _rating.round()
                              ? AppColors.gold
                              : AppColors.line,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_count ${gu ? 'સમીક્ષાઓ' : 'reviews'}',
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  p.reviews == 0 && _count == 0
                      ? (gu
                          ? 'આ પ્રોડક્ટની હજી સમીક્ષા નથી. પહેલી સમીક્ષા લખો!'
                          : 'No reviews yet — write the first one!')
                      : (gu
                          ? 'ગ્રાહકોની સમીક્ષાઓ વાંચો અને તમારી લખો.'
                          : 'Read what customers say, then share your own.'),
                  style: TextStyle(
                    fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                    fontSize: 11.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // --- write-review form -------------------------------------------
        if (!_canReview) ...[
          // Only customers who received the product may review it
          // (`REVIEW_NOT_ALLOWED` otherwise), so say so instead of offering a
          // form that is certain to be refused.
          _note(
            !StateScope.of(context).signedIn
                ? (gu
                    ? 'સમીક્ષા લખવા સાઇન ઇન કરો.'
                    : 'Sign in to review products you have received.')
                : (gu
                    ? 'ડિલિવરી પછી તમે આ પ્રોડક્ટની સમીક્ષા લખી શકશો.'
                    : 'You can review this product after it has been delivered to you.'),
            AppColors.navy,
            AppColors.navyTint,
          ),
          const SizedBox(height: 18),
        ] else ...[
        _sectionTitle(gu ? 'તમારી સમીક્ષા' : 'Write a review'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _myRating = i),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: AppIcon(
                    'star',
                    size: 26,
                    color: i <= _myRating ? AppColors.gold : AppColors.line,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AppField(
          controller: _comment,
          maxLength: 1000,
          placeholder: gu
              ? 'બંધારણ, ગુણવત્તા, ડિલિવરી વિશે લખો…'
              : 'How was the pack, quality, delivery?',
        ),
        const SizedBox(height: 10),
        AppButton(
          _posting ? 'Posting…' : (gu ? 'સમીક્ષા મોકલો' : 'Post review'),
          block: true,
          loading: _posting,
          onTap: _posting ? () {} : _post,
        ),
        const SizedBox(height: 18),
        ],

        // --- review list --------------------------------------------------
        _sectionTitle(gu ? 'સમીક્ષાઓ' : 'All reviews'),
        const SizedBox(height: 8),
        if (_loading)
          const ListSkeleton(count: 3, rowHeight: 78)
        else if (_error != null)
          _note(_error!, AppColors.red, AppColors.redTint)
        else if (_items.isEmpty)
          _note(
            gu
                ? 'હજી કોઈ સમીક્ષા નથી. પહેલી સમીક્ષા તમે લખો!'
                : 'No reviews yet. Yours will be the first!',
            AppColors.navy,
            AppColors.navyTint,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.line),
                  _ReviewRow(review: _items[i], gu: gu),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: AppTheme.uiFont,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      );

  Widget _note(String text, Color ink, Color bg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: AppTheme.uiFont,
            fontSize: 11.5,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
      );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review, required this.gu});

  final ReviewDto review;
  final bool gu;

  @override
  Widget build(BuildContext context) {
    final when = review.createdDateTime;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.reviewer ?? 'Customer',
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    AppIcon(
                      'star',
                      size: 11,
                      color: i <= review.rating
                          ? AppColors.gold
                          : AppColors.line,
                    ),
                ],
              ),
            ],
          ),
          if (review.verified) ...[
            const SizedBox(height: 2),
            Text(
              gu ? 'ચકાસાયેલ ખરીદી' : 'Verified purchase',
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.green,
              ),
            ),
          ],
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.comment!,
              style: TextStyle(
                fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.ink2,
              ),
            ),
          ],
          if (when != null) ...[
            const SizedBox(height: 3),
            Text(
              whenLabel(when),
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
