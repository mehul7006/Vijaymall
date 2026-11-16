import 'package:flutter/material.dart';

import '../../data/validators.dart';
import '../../data/api/api_config.dart';
import '../../data/api/api_exception.dart';
import '../../data/seed_data.dart' as seed;
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/customer_wide_parts.dart';
import '../../widgets/desktop_shell.dart';
import '../../widgets/fields.dart';
import '../../widgets/skeleton.dart' show FadeSlideIn;
import '../../widgets/sheet.dart';
import '../../widgets/shopper_menu_parts.dart';
import '../../widgets/store_kit.dart';
import '../../widgets/toast.dart';
import 'sheets/addresses_sheet.dart';
import 'sheets/how_coins_sheet.dart';
import 'sheets/saved_items_sheet.dart';
import 'sheets/store_info_sheet.dart';
import '../../state/gu_strings.dart';

/// Marks where the desktop layout may cut a section list into groups.
const Widget _splitMark = SizedBox.shrink();

/// `#/profile` — account summary, menu links, preferences and store card.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    final gu = state.lang == 'gu';
    final balance = state.coinBalance();
    final orders = state.userOrders().length;
    final saved = state.wishlist.length;
    final address = state.addresses.isNotEmpty
        ? state.addresses.firstWhere(
            (a) => a.id == state.flow.selectedAddressId,
            orElse: () => state.addresses.first,
          )
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const StatusBar(),
                ScreenBar(
                  showBack: false,
                  title: gu ? 'પ્રોફાઇલ' : 'Profile',
                  sub: gu
                      ? 'એકાઉન્ટ અને પસંદગીઓ'
                      : 'Account & preferences',
                  right: IconBtn(
                    'phone',
                    iconSize: 17,
                    onTap: () => showStoreInfoSheet(context),
                  ),
                ),
                Builder(builder: (context) {
                  final wide =
                      DesktopShell.isWide(MediaQuery.sizeOf(context).width);
                  final leftW = <Widget>[
                      FadeSlideIn(
                          child: _heroCard(
                              context, state, gu, orders, balance, saved)),
                      const SizedBox(height: 16),
                      _splitMark,
                      ShopperGroupTitle(
                        gu ? 'મારું એકાઉન્ટ' : 'My account',
                        trailing: gu ? '$balance કોઈન્સ' : '$balance coins',
                      ),
                      ShopperMenuCard(
 gu: gu,
                        icon: 'box',
 toneIndex: 2,
                        title: gu ? 'મારા ઓર્ડર' : 'My orders',
                        sub: gu
                            ? 'ટ્રેક કરો, રદ કરો કે ફરી ઓર્ડર કરો'
                            : 'Track, cancel or reorder',
                        onTap: () => go('/orders'),
                      ),
                      ShopperMenuCard(
 gu: gu,
                        icon: 'heart',
 toneIndex: 0,
                        title: gu ? 'સેવ કરેલી વસ્તુઓ' : 'Saved items',
                        sub: gu
                            ? 'મોલની વસ્તુઓ'
                            : '$saved product${saved == 1 ? '' : 's'} from the mall',
                        onTap: () => showSavedItemsSheet(context),
                      ),
                      ShopperMenuCard(
 gu: gu,
                        icon: 'pin',
 toneIndex: 1,
                        title: gu ? 'ડિલિવરી સરનામાં' : 'Delivery addresses',
                        sub: address == null
                            ? (gu ? 'સરનામું ઉમેરો' : 'Add an address')
                            : '${address.label} · ${_clip(address.full)}',
                        onTap: () => showAddressSheet(context),
                      ),
                      ShopperMenuCard(
 gu: gu,
                        icon: 'wallet',
 toneIndex: 1,
                        title: gu ? 'કોઈન વોલેટ' : 'Coin wallet',
                        sub: gu
                            ? '$balance કોઈન્સની કિંમત ${money(balance)}'
                            : '$balance coins worth ${money(balance)}',
                        onTap: () => go('/wallet'),
                      ),

                  ];
                  final rightW = <Widget>[
                      ShopperGroupTitle(gu ? 'પસંદગીઓ' : 'Preferences'),
                      _languageRow(context, state, gu),
                      ShopperMenuCard(
 gu: gu,
                        icon: 'bell',
 toneIndex: 2,
                        title: gu ? 'ઓર્ડર સૂચનાઓ' : 'Order notifications',
                        sub: gu
                            ? 'સ્થિતિ અપડેટ અને કોઈન એલર્ટ'
                            : 'Status updates and coin alerts',
                        trailing: AppSwitch(
                          value: state.notificationsOn,
                          onChanged: (v) {
                            StateScope.read(context).setNotifications(v);
                            showToast(
                                v ? 'Order notifications on' : 'Order notifications off');
                          },
                        ),
                      ),
                      ShopperMenuCard(
 gu: gu,
                        icon: 'store',
 toneIndex: 2,
                        title: gu ? 'દુકાનની માહિતી' : 'Store information',
                        sub: seed.store.addressFor(gu),
                        onTap: () => showStoreInfoSheet(context),
                      ),
                      ShopperMenuCard(
 gu: gu,
                        icon: 'refresh',
 toneIndex: 2,
                        title: gt('Refresh store details'),
                        sub: gt('Reload the shop name, logo, address and hours'),
                        onTap: () => refreshStoreDetailsWithToast(context),
                      ),
                      ShopperMenuCard(
 gu: gu,
                        icon: 'coin',
 toneIndex: 1,
                        title: gu
                            ? 'કોઈન્સ કેવી રીતે ચાલે'
                            : 'How coins work',
                        sub: gu
                            ? 'કમાણી, વપરાશ અને સમાપ્તિ'
                            : 'Earning, redemption and expiry',
                        onTap: () => showHowCoinsSheet(context),
                      ),

                      const SizedBox(height: 18),
                      _splitMark,
                      // The admin area is only offered to a session that can
                      // actually open it (a real ADMIN JWT in live builds).
                      if (state.isAdminAllowed) ...[
                        ShopperGroupTitle(gu ? 'સ્ટોર એક્સેસ' : 'Store access'),
                        ShopperMenuCard(
 gu: gu,
                          icon: 'chart',
 toneIndex: 2,
                          title: gu ? 'માલિક એડમિન પેનલ' : 'Owner admin panel',
                          sub: gu
                              ? 'ઓર્ડર, સ્ટોક, કોઈન્સ અને રિપોર્ટ'
                              : 'Orders, stock, coins and reports',
                          onTap: () => go('/admin'),
                        ),
                        ],
                      ShopperMenuCard(
 gu: gu,
                        icon: 'logout',
 toneIndex: 0,
                        danger: true,
                        title: gu ? 'સાઇન આઉટ' : 'Sign out',
                        sub: gu
                            ? 'વેલકમ સ્ક્રીન પર પાછા જાઓ'
                            : 'Return to the welcome screen',
                        onTap: () {
                          StateScope.read(context).signOut();
                          go('/welcome');
                          showToast(gt('Signed out'));
                        },
                      ),
                      if (ApiConfig.isLive && state.signedIn &&
                          (state.userRole ?? '').toUpperCase() == 'CUSTOMER') ...[
                          ShopperMenuCard(
 gu: gu,
                          icon: 'trash',
 toneIndex: 0,
                          danger: true,
                          title: gu ? 'એકાઉન્ટ કાઢી નાખો' : 'Delete my account',
                          sub: gu
                              ? 'ડેટા કાયમ માટે ભૂંસાશે, કોઈન્સ જશે'
                              : 'Erases your data for good; coins are lost',
                          onTap: () => _confirmDeleteAccount(context),
                        ),
                      ],

                      _splitMark,
                      const SizedBox(height: 14),
                      _storeMiniCard(gu),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          gu
                              ? '${seed.store.name}\nEN + ગુજરાતી · ${seed.store.promiseFor(gu)}'
                              : '${seed.store.name}\nEN + ગુજરાતી · ${seed.store.promiseFor(gu)}',
                          textAlign: TextAlign.center,
                          style: _ts(gu,
                              size: 12,
                              w: FontWeight.w600,
                              color: AppColors.ink2,
                              height: 1.5),
                        ),
                      ),
                  ];
                  if (CustomerWide.on(context)) {
                    final wideW = MediaQuery.sizeOf(context).width;
                    List<List<Widget>> parts(List<Widget> l) {
                      final out = <List<Widget>>[<Widget>[]];
                      for (final w in l) {
                        if (identical(w, _splitMark)) {
                          out.add(<Widget>[]);
                        } else {
                          out.last.add(w);
                        }
                      }
                      return out;
                    }

                    Widget col(List<Widget> l) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: l,
                        );
                    final lp = parts(leftW); // hero | account
                    final rp = parts(rightW); // prefs | access | tail
                    final stretchGap = wideW >= 1400 ? 24.0 : 20.0;
                    return ScreenScroll(
                      bottom: 124,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: wideW >= 1400 ? 440 : 380,
                            child: col([
                              ...lp[0],
                              ...rp[2],
                            ]),
                          ),
                          SizedBox(width: stretchGap),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: col([
                                  ...lp[1],
                                  ...rp[1],
                                ])),
                                SizedBox(width: stretchGap),
                                Expanded(child: col(rp[0])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ScreenScroll(
                    bottom: 124,
                    child: wide
                        // Desktop: account cards left, preferences right.
                        ? TwoColumns(
                            a: leftW.where((w) => !identical(w, _splitMark)).toList(),
                            b: rightW.where((w) => !identical(w, _splitMark)).toList(),
                            gap: 0)
                        : Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...leftW.where((w) => !identical(w, _splitMark)),
                                  const SizedBox(height: 18),
                                  ...rightW.where((w) => !identical(w, _splitMark)),
                                ],
                              ),
                            ),
                          ),
                  );
                }),
              ],
            ),
            const CustomerNav(active: 'profile'),
          ],
        ),
      ),
    );
  }
}

/// `DELETE /me` behind a confirmation. Refused (409) while orders are open or
/// credit is owed — the reason is shown and the user stays signed in.
Future<void> _confirmDeleteAccount(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(gt('Delete your account?')),
      content: Text(gt(
          'This permanently erases your name, mobile, addresses and saved '
          'items. Any coins you have are lost. This cannot be undone.')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(gt('Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(gt('Delete'),
              style: const TextStyle(color: AppColors.red)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final err = await StateScope.read(context).deleteMyAccount();
  if (err != null) {
    showToast(err, 'error');
    return;
  }
  go('/welcome');
  showToast(gt('Your account was deleted'));
}

// ---------------------------------------------------------------------------
// Edit profile (name + mobile → `PUT /me`)
// ---------------------------------------------------------------------------

void _editProfileSheet(BuildContext context, AppState state) {
  final nameCtrl = TextEditingController(text: state.userName);
  final phoneCtrl = TextEditingController(text: state.userPhone);
  String? nameErr;
  String? phoneErr;
  showAppSheet(
    context: context,
    title: gt('Edit profile'),
    sub: gt('Your name and mobile number'),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldRow(
            flex: const [3, 2],
            children: [
          AppField(
            label: gt('Name'),
            controller: nameCtrl,
            error: nameErr,
            placeholder: gt('Your name'),
          ),
          AppField(
            label: gt('Mobile'),
            controller: phoneCtrl,
            error: phoneErr,
            numeric: true,
            placeholder: '98250 11223',
            // A mobile-only account signed in with this number (OTP-verified),
            // so the backend refuses to change it (409 MOBILE_VERIFIED).
            readOnly: ApiConfig.isLive &&
                (state.userEmail ?? '').isEmpty &&
                state.userPhone.isNotEmpty,
          ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            'Save profile',
            block: true,
            onTap: () async {
              final name = nameCtrl.text.trim();
              // The backend wants exactly 10 digits (no spaces / +91).
              final phone = digits(phoneCtrl.text);
              final nMsg = Validators.text(name,
                  label: 'Name', required: true, max: 80);
              final pMsg = Validators.mobile(phone);
              if (nMsg != null || pMsg != null) {
                setS(() {
                  nameErr = nMsg == null ? null : gt(nMsg);
                  phoneErr = pMsg == null ? null : gt(pMsg);
                });
                return;
              }
              ApiException.clearFields();
              final err = await state.updateProfile(name: name, phone: phone);
              if (!ctx.mounted) return;
              final f = err == null ? <String, String>{} : ApiException.takeFields();
              if (f.isNotEmpty) {
                // Keep the sheet open and highlight the rejected inputs.
                setS(() {
                  nameErr = ApiException.fieldError(f, ['name']);
                  phoneErr = ApiException.fieldError(f, ['mobile', 'phone']);
                });
                showToast(err!, 'error');
                return;
              }
              Navigator.of(ctx).pop();
              if (err != null) {
                // The backend rejects a changed, already-verified mobile.
                showToast(err, 'error');
              } else {
                showToast(gt('Profile updated'));
              }
            },
          ),
        ],
      ),
    )),
  ).then((_) {
    nameCtrl.dispose();
    phoneCtrl.dispose();
  });
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

Widget _heroCard(BuildContext context, AppState state, bool gu, int orders,
    int balance, int saved) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: StoreKit.heroNavyRed,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: AppColors.navy.withValues(alpha: .28),
                offset: const Offset(0, 12),
                blurRadius: 28),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: StoreKit.goldWarm,
              ),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.avatarGradient,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    _initials(state.userName),
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(gu,
                        size: 19,
                        w: FontWeight.w800,
                        color: AppColors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.userPhone.isEmpty
                        ? (gu
                            ? '${seed.store.name} સભ્ય'
                            : '${seed.store.name} member')
                        : '+91 ${state.userPhone}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(gu,
                        size: 12,
                        w: FontWeight.w600,
                        color: AppColors.gold2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconBtn(
              'edit',
              size: 38,
              iconSize: 16,
              color: AppColors.white,
              onTap: () => _editProfileSheet(context, state),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ShopperShortcutTile(
                icon: 'box',
                value: '$orders',
                label: gu ? 'ઓર્ડર' : 'Orders',
                gu: gu,
                toneIndex: 2,
                onTap: () => go('/orders'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ShopperShortcutTile(
                icon: 'coin',
                value: '$balance',
                label: gu ? 'કોઈન્સ' : 'Coins',
                gu: gu,
                toneIndex: 1,
                onTap: () => go('/wallet'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ShopperShortcutTile(
                icon: 'heart',
                value: '$saved',
                label: gu ? 'સેવ કરેલા' : 'Saved',
                gu: gu,
                toneIndex: 0,
                onTap: () => showSavedItemsSheet(context),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Section heads / language / store card
// ---------------------------------------------------------------------------

Widget _languageRow(BuildContext context, AppState state, bool gu) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: StoreKit.card(accent: AppColors.navy, radius: 18),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [StoreKit.tone(5).$1, StoreKit.tone(5).$2]),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: AppIcon('more', size: 22, color: StoreKit.tone(5).$3, sw: 1.9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gu ? 'એપ ભાષા' : 'App language',
                style: _ts(gu,
                    size: 14, w: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                gu ? 'અંગ્રેજી અને ગુજરાતી' : 'English & ગુજરાતી',
                style: _ts(gu,
                    size: 12.5, w: FontWeight.w600, color: AppColors.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              _langBtn(context, 'EN', 'en', state.lang == 'en'),
              const SizedBox(width: 4),
              _langBtn(context, 'ગુ', 'gu', state.lang == 'gu'),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _langBtn(BuildContext context, String label, String key, bool selected) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => StateScope.read(context).setLang(key),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.red : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.uiFont,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: selected ? AppColors.white : AppColors.ink2,
        ),
      ),
    ),
  );
}

Widget _storeMiniCard(bool gu) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: StoreKit.card(accent: AppColors.gold, radius: 20, tinted: true),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LogoMark(size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gu
                    ? '${seed.store.name} · ${seed.store.nameGu}'
                    : '${seed.store.name} · ${seed.store.nameGu}',
                style: _ts(gu,
                    size: 14, w: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 5),
              Text(
                seed.store.addressFor(gu),
                style: _ts(gu,
                    size: 12,
                    w: FontWeight.w600,
                    color: AppColors.ink2,
                    height: 1.4),
              ),
              const SizedBox(height: 5),
              Text(
                gu
                    ? 'મફત હોમ ડિલિવરી · ${seed.store.phone}'
                    : 'FREE home delivery · ${seed.store.phone}',
                style: _ts(gu,
                    size: 11.5,
                    w: FontWeight.w700,
                    color: AppColors.green),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const AppIcon('phone', size: 18, color: AppColors.navy, sw: 2),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'V';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

String _clip(String detail) =>
    detail.length > 30 ? '${detail.substring(0, 30)}…' : detail;

TextStyle _ts(
  bool gu, {
  double size = 13,
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
