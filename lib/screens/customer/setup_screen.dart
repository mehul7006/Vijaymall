import 'dart:async';

import '../../data/validators.dart';
import 'package:flutter/material.dart';

import '../../data/api/api_config.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/fields.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/store_kit.dart';
import '../../widgets/toast.dart';
import 'missing_screen.dart';
import '../../state/gu_strings.dart';

/// `#/setup` — first-time profile setup, reached straight after a fresh OTP
/// sign-in whose account is still bare (`AppState.needsProfileSetup`).
///
/// It collects what the new customer is missing — name, mobile and an
/// optional default delivery address — and saves them through `PUT /me` +
/// `POST /me/addresses`, both server-first: a rejection stays on screen and
/// the flow never claims success. Only after everything is stored does it
/// announce the store's first-order offer, which is a real backend coupon
/// flagged `firstOrderOnly` (`AppState.firstOrderOffer`) — its value is the
/// shop's, never hardcoded here.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _label = TextEditingController();
  final _line1 = TextEditingController();
  final _area = TextEditingController();
  final _pincode = TextEditingController();

  bool _busy = false;
  String _err = '';

  /// Set once the details (+ address) are confirmed stored by the backend;
  /// the screen then switches to the welcome/offer announcement.
  bool _done = false;
  bool _seeded = false;
  bool _offersAsked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final st = StateScope.read(context);
    if (!_seeded) {
      _seeded = true;
      _name.text = st.userName;
      _mobile.text = digits(st.userPhone);
      _label.text = 'Home';
    }
    // The announcement reads the live offer list (`GET /coupons`); ask for it
    // once so the code shown is what the store is actually running.
    if (!_offersAsked && ApiConfig.isLive) {
      _offersAsked = true;
      unawaited(st.loadPublicOffers());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _label.dispose();
    _line1.dispose();
    _area.dispose();
    _pincode.dispose();
    super.dispose();
  }

  bool get _gu => StateScope.read(context).lang == 'gu';

  /// Server-first save. Any rejection is kept on screen; nothing is
  /// announced until `saveFirstProfile` reports that it all landed.
  Future<void> _save() async {
    if (_busy) return;
    final st = StateScope.read(context);
    final bad = Validators.text(_name.text,
            label: 'Name', required: true, max: 80) ??
        Validators.mobile(digits(_mobile.text)) ??
        Validators.text(_label.text, label: 'Label', max: 30) ??
        Validators.text(_line1.text, label: 'Address', max: 200) ??
        Validators.text(_area.text, label: 'Area', max: 80) ??
        Validators.pincode(_pincode.text.trim());
    if (bad != null) {
      setState(() => _err = gt(bad));
      return;
    }
    setState(() {
      _busy = true;
      _err = '';
    });
    final err = await st.saveFirstProfile(
      name: _name.text,
      mobile: _mobile.text,
      label: _label.text,
      line1: _line1.text,
      area: _area.text,
      pincode: _pincode.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _err = err);
      return;
    }
    setState(() => _done = true);
    showToast(_gu ? 'પ્રોફાઇલ સાચવાયું' : 'Profile saved');
  }

  void _skip() {
    // Skip leaves the flag alone: the next fresh sign-in offers setup again,
    // and nothing was written that could nag a completed profile.
    go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final st = StateScope.of(context);
    // Reached without a session (typed URL, expired sign-in): the flow has
    // nothing to save to, so send the visitor to sign in rather than render a
    // dead form.
    if (!st.signedIn) {
      return MissingScreen(
        title: gt('Sign in required'),
        heading: 'Finish signing in',
        copy: gt('This step finishes your account setup.'),
        backRoute: '/signin',
        buttonLabel: 'Go to sign in',
        buttonRoute: '/signin',
      );
    }

    final gu = st.lang == 'gu';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const StatusBar(),
            ScreenBar(
              title: gu ? 'પ્રોફાઇલ સેટકરો' : 'Set up your profile',
              sub: gu
                  ? 'બે વિગતો અને તમે ઓર્ડર માટે તૈયાર'
                  : 'Two details and you are ready to order',
              onBack: _skip,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: FadeSlideIn(
                  child: _done ? _doneView(st, gu) : _formView(st, gu),
                ),
              ),
            ),
            if (!_done)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  gradient: StoreKit.creamSoft,
                  border: Border(
                      top: BorderSide(
                          color: AppColors.gold.withValues(alpha: .35))),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.red.withValues(alpha: .08),
                        offset: const Offset(0, -6),
                        blurRadius: 16),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      gu ? 'સાચવો અને આગળ વધો' : 'Save & continue',
                      block: true,
                      loading: _busy,
                      onTap: _save,
                    ),
                    const SizedBox(height: 6),
                    AppButton(
                      gu ? 'હમણાં નહીં' : 'Maybe later',
                      variant: BtnVariant.ghost,
                      block: true,
                      onTap: _busy ? null : _skip,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- form ---------------------------------------------------------------

  Widget _formView(AppState st, bool gu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: StoreKit.heroNavyRed,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: AppColors.navy.withValues(alpha: .25),
                  offset: const Offset(0, 10),
                  blurRadius: 22),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, gradient: StoreKit.goldWarm),
                child: const Center(
                    child: AppIcon('user',
                        size: 24, color: AppColors.goldInk, sw: 2)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  gu
                      ? 'બે વિગતો અને તમે ઓર્ડર માટે તૈયાર'
                      : 'Two details and you are ready to order',
                  style: TextStyle(
                    fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHead(
                'user',
                gu ? 'તમારી વિગતો' : 'Your details',
                gu
                    ? 'ડિલિવરી અને ઓર્ડર અપડેટ માટે વાપરીશું'
                    : 'Used for delivery and order updates',
                gu,
              ),
              FieldRow(
                flex: const [3, 2],
                children: [
                  AppField(
                    label: gu ? 'નામ' : 'Name',
                    controller: _name,
                    placeholder: gu ? 'તમારું નામ' : 'Your name',
                    maxLength: 60,
                  ),
                  AppField(
                    label: gu ? 'મોબાઇલ નંબર' : 'Mobile number',
                    controller: _mobile,
                    numeric: true,
                    maxLength: 10,
                    placeholder: '98765 43210',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          accent: AppColors.gold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHead(
                'pin',
                gu ? 'ડિફૉલ્ટ ડિલિવરી સરનામું' : 'Default delivery address',
                gu
                    ? 'વૈકલ્પિક — ઉમેરશો તો ચેકઆઉટ એક ટેપમાં'
                    : 'Optional — add it now and checkout becomes one tap',
                gu,
              ),
              FieldRow(
                children: [
                    AppField(
                      label: gu ? 'લેબલ' : 'Label',
                      controller: _label,
                      placeholder: gu ? 'ઘર' : 'Home',
                      maxLength: 20,
                    ),
                    AppField(
                      label: gu ? 'પિનકોડ' : 'Pincode',
                      controller: _pincode,
                      numeric: true,
                      maxLength: 6,
                      placeholder: '380015',
                    ),
                ],
              ),
              const SizedBox(height: 10),
              AppField(
                label: gu ? 'સરનામું' : 'Address',
                controller: _line1,
                placeholder: gu
                    ? 'ફ્લેટ, સ્ટ્રીટ, લેન્ડમાર્ક'
                    : 'Flat, street, landmark',
                maxLength: 90,
              ),
              const SizedBox(height: 10),
              AppField(
                label: gu ? 'વિસ્તાર' : 'Area',
                controller: _area,
                placeholder: gu ? 'લોકલિટી' : 'Locality',
                maxLength: 40,
              ),
            ],
          ),
        ),
        if (_err.isNotEmpty) ...[
          const SizedBox(height: 12),
          _errorBanner(_err, gu),
        ],
      ],
    );
  }

  // --- announcement -------------------------------------------------------

  Widget _doneView(AppState st, bool gu) {
    final offer = st.firstOrderOffer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _card(
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFD9F5E6), Color(0xFFA6E3C3)]),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: AppIcon('check',
                      size: 30, color: AppColors.green, sw: 2.6),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                gu ? 'પ્રોફાઇલ સાચવાયું' : 'Profile saved',
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                gu
                    ? 'તમારી વિગતો દુકાનમાં સેવ થઈ ગઈ છે.'
                    : 'Your details are saved with the store.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink2,
                ),
              ),
            ],
          ),
        ),
        if (offer != null) ...[
          const SizedBox(height: 12),
          _card(
            tint: AppColors.redTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: AppIcon('ticket',
                            size: 18, color: AppColors.red, sw: 2),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        gu
                            ? 'તમારી પહેલી ઓર્ડરની ઓફર'
                            : 'Your first-order offer',
                        style: const TextStyle(
                          fontFamily: AppTheme.uiFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(
                        color: AppColors.red.withValues(alpha: .35), width: 1.4),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    offer.code,
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 17,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  offer.desc,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  gu
                      ? 'તમારી પહેલી ઓર્ડર પર વાપરો — છૂટ ચેકઆઉટમાં લાગુ થાય છે. '
                          'ફક્ત પહેલી ઓર્ડર માટે.'
                      : 'Use it on your first order — the discount is applied '
                          'at checkout. First order only.',
                  style: TextStyle(
                    fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                    fontSize: 12.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink2,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          gu ? 'ખરીદી શરૂ કરો' : 'Start shopping',
          block: true,
          icon: 'cart',
          onTap: () {
            go('/home');
            if (offer != null) {
              showToast(gu
                  ? '${offer.code} કૂપન તમારી પહેલી ઓર્ડર માટે તૈયાર છે'
                  : 'Coupon ${offer.code} is ready for your first order');
            }
          },
        ),
      ],
    );
  }

  // --- shared pieces ------------------------------------------------------

  Widget _card(
          {required Widget child,
          Color? tint,
          Color accent = AppColors.red}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: tint != null
            ? StoreKit.card(accent: accent, radius: 22, tinted: true)
            : StoreKit.card(accent: accent, radius: 22),
        child: child,
      );

  Widget _sectionHead(String icon, String title, String note, bool gu) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: icon == 'pin'
                      ? [StoreKit.tone(1).$1, StoreKit.tone(1).$2]
                      : [StoreKit.tone(0).$1, StoreKit.tone(0).$2],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                  child: AppIcon(icon,
                      size: 21,
                      color: icon == 'pin'
                          ? StoreKit.tone(1).$3
                          : StoreKit.tone(0).$3,
                      sw: 1.9)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppTheme.uiFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    note,
                    style: TextStyle(
                      fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  /// The rejection, spelled out where the button is — a failed save is never
  /// passed off as success.
  Widget _errorBanner(String msg, bool gu) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.redTint,
          border: Border.all(color: AppColors.red.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppIcon('info', size: 16, color: AppColors.red, sw: 2),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontFamily: AppTheme.uiFont,
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: AppColors.red,
                ),
              ),
            ),
          ],
        ),
      );
}
