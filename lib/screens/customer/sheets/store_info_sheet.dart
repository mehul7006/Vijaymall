import 'package:flutter/material.dart';

import '../../../data/seed_data.dart' as seed;
import '../../../data/store_profile.dart';
import '../../../data/store_profile_cache.dart';
import '../../../provider/state_scope.dart';
import '../../../state/gu_strings.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/controls.dart';
import '../../../widgets/sheet.dart';
import '../../../widgets/store_actions.dart';
import '../../../widgets/toast.dart';

/// Store info: everything comes from the cached store profile (name, logo,
/// address, phone, hours, links). "Refresh store details" hard-refreshes it.
void showStoreInfoSheet(BuildContext context) {
  final gu = StateScope.read(context).lang == 'gu';

  showAppSheet<void>(
    context: context,
    title: seed.store.name,
    sub: seed.storeLocality(),
    builder: (ctx) => _StoreInfoBody(gu: gu),
    footer: Builder(
      builder: (c) => AppButton(
        'Done',
        variant: BtnVariant.soft,
        block: true,
        onTap: () => Navigator.of(c).maybePop(),
      ),
    ),
  );
}

/// The profile to render: the live one, or the seed card when none loaded.
StoreProfile _current() =>
    StoreProfileHub.instance.profile ??
    StoreProfile(
      shopName: seed.store.name,
      phone: seed.store.phone,
      address: seed.store.address,
      promise: seed.store.promise,
    );

class _StoreInfoBody extends StatelessWidget {
  const _StoreInfoBody({required this.gu});

  final bool gu;

  @override
  Widget build(BuildContext context) {
    final hub = StoreProfileHub.instance;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final p = _current();
        final today = p.todayRow;
        final status = p.openLabel;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(19),
                boxShadow: AppColors.sh1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.goldTint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(child: LogoMark(size: 46)),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gu && p.shopNameGu.isNotEmpty
                                  ? p.shopNameGu
                                  : p.shopName,
                              style: TextStyle(
                                fontFamily: AppTheme.uiFont,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            if (p.promiseFor(gu).isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                p.promiseFor(gu),
                                style: _ts(gu,
                                    size: 12.5,
                                    w: FontWeight.w600,
                                    color: AppColors.ink2),
                              ),
                            ],
                            if (status.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              p.openNow == false
                                  ? Pill.out(gt(status.split(' · ').first) +
                                      (status.contains(' · ')
                                          ? ' · ${status.split(' · ').last}'
                                          : ''))
                                  : Pill.active(gt(status.split(' · ').first) +
                                      (status.contains(' · ')
                                          ? ' · ${status.split(' · ').last}'
                                          : '')),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.line),
                  const SizedBox(height: 10),
                  if (p.addressFor(gu).isNotEmpty) ...[
                    _infoRow('pin', p.addressFor(gu), gu),
                    const SizedBox(height: 8),
                  ],
                  if (p.phone.isNotEmpty) ...[
                    _infoRow('phone', p.phone, gu, link: true),
                    const SizedBox(height: 8),
                  ],
                  if (p.email.isNotEmpty) ...[
                    _infoRow('share', p.email, gu, link: true),
                    const SizedBox(height: 8),
                  ],
                  _infoRow('coin', gt('Coins on every delivered order'), gu),
                ],
              ),
            ),
            if (!p.onlineOrdersOpen) ...[
              const SizedBox(height: 12),
              _notice(
                  p.onlineOrdersMessage.isNotEmpty
                      ? p.onlineOrdersMessage
                      : gt('Online orders are paused right now.'),
                  AppColors.red,
                  gu),
            ],
            if (p.hours.isNotEmpty) ...[
              const SizedBox(height: 12),
              _hoursCard(p, today, gu),
            ],
            if (p.holidayNoteFor(gu).isNotEmpty) ...[
              const SizedBox(height: 10),
              _notice(p.holidayNoteFor(gu), AppColors.navy, gu),
            ],
            if (p.detailsFor(gu).isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(p.detailsFor(gu),
                    style: _ts(gu,
                        size: 12.5,
                        w: FontWeight.w600,
                        color: AppColors.ink2,
                        height: 1.55)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    'Call store',
                    icon: 'phone',
                    onTap: StoreActions.call,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    'WhatsApp',
                    variant: BtnVariant.secondary,
                    icon: 'whatsapp',
                    onTap: StoreActions.whatsapp,
                  ),
                ),
              ],
            ),
            if (p.mapUrl.isNotEmpty || p.email.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (p.mapUrl.isNotEmpty)
                    Expanded(
                      child: AppButton('Open map',
                          variant: BtnVariant.soft,
                          icon: 'pin',
                          onTap: StoreActions.map),
                    ),
                  if (p.mapUrl.isNotEmpty && p.email.isNotEmpty)
                    const SizedBox(width: 8),
                  if (p.email.isNotEmpty)
                    Expanded(
                      child: AppButton('E-mail',
                          variant: BtnVariant.soft,
                          icon: 'share',
                          onTap: StoreActions.email),
                    ),
                ],
              ),
            ],
            if (p.website.isNotEmpty ||
                p.instagram.isNotEmpty ||
                p.facebook.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  if (p.website.isNotEmpty)
                    AppLink(gt('Website'),
                        onTap: () => StoreActions.web(p.website)),
                  if (p.instagram.isNotEmpty)
                    AppLink('Instagram',
                        onTap: () => StoreActions.web(p.instagram)),
                  if (p.facebook.isNotEmpty)
                    AppLink('Facebook',
                        onTap: () => StoreActions.web(p.facebook)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            AppButton(
              'Refresh store details',
              variant: BtnVariant.ghost,
              icon: 'refresh',
              loading: hub.refreshing,
              onTap: () => refreshStoreDetailsWithToast(context),
            ),
          ],
        );
      },
    );
  }
}

/// Hard-refreshes the cached store profile and toasts the outcome. Shared by
/// the store sheet and the profile screen.
Future<void> refreshStoreDetailsWithToast(BuildContext context) async {
  final state = StateScope.read(context);
  final before = StoreProfileHub.instance.profile != null;
  final changed = await state.refreshStoreProfile(force: true);
  final ok = StoreProfileHub.instance.profile != null &&
      StoreProfileHub.instance.fetchedAt != null &&
      DateTime.now()
              .difference(StoreProfileHub.instance.fetchedAt!)
              .inSeconds <
          30;
  if (ok) {
    showToast(gt(changed ? 'Store details updated' : 'Store details are up to date'),
        'success');
  } else {
    showToast(
        gt(before
            ? 'Could not reach the server. Showing saved store details.'
            : 'Could not load store details.'),
        'error');
  }
}

Widget _hoursCard(StoreProfile p, StoreHoursRow? today, bool gu) {
  const names = {
    'MON': 'Monday',
    'TUE': 'Tuesday',
    'WED': 'Wednesday',
    'THU': 'Thursday',
    'FRI': 'Friday',
    'SAT': 'Saturday',
    'SUN': 'Sunday',
  };
  return Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
    decoration: BoxDecoration(
      color: AppColors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const AppIcon('clock', size: 16, color: AppColors.ink2, sw: 1.9),
          const SizedBox(width: 8),
          Text(gt('Opening hours'),
              style: _ts(gu, size: 13, w: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        for (final h in p.hours)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: today?.day == h.day ? AppColors.goldTint : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Expanded(
                child: Text(gt(names[h.day] ?? h.day),
                    style: _ts(gu,
                        size: 12.5,
                        w: today?.day == h.day
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: AppColors.ink)),
              ),
              Text(h.closed ? gt('Closed') : '${h.open} - ${h.close}',
                  style: _ts(gu,
                      size: 12.5,
                      w: today?.day == h.day
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: h.closed ? AppColors.red : AppColors.ink2)),
            ]),
          ),
      ],
    ),
  );
}

Widget _notice(String text, Color color, bool gu) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text,
        style: _ts(gu,
            size: 12.5, w: FontWeight.w700, color: color, height: 1.5)),
  );
}

/// Icon + hint row; [link] paints the value like `.link`.
Widget _infoRow(String icon, String value, bool gu, {bool link = false}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppIcon(icon, size: 17, color: AppColors.ink2, sw: 1.9),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          value,
          style: _ts(gu,
              size: 13,
              w: FontWeight.w600,
              color: link ? AppColors.red : AppColors.ink2,
              height: 1.4),
        ),
      ),
    ],
  );
}

/// Bilingual text style — Gujarati falls back to the Hind Vadodara family.
TextStyle _ts(
  bool gu, {
  double size = 11.5,
  FontWeight w = FontWeight.w600,
  Color color = AppColors.ink,
  double? height,
}) {
  if (gu) return AppTheme.guj(size: size, w: w, color: color);
  return TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
  );
}
