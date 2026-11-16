import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/store_text.dart';
import '../../data/validators.dart';
import '../../data/api/api_exception.dart';

import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/fields.dart';
import '../../widgets/toast.dart';

/// `#/signin` — brand auth header + phone/OTP card over the hero gradient.
class SigninScreen extends StatelessWidget {
  const SigninScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1038),
              Color(0xFF1B2A7A),
              Color(0xFF3447B5),
              Color(0xFF5B7BFF),
            ],
            stops: [0.0, 0.45, 0.78, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -140,
              right: -120,
              child: IgnorePointer(
                child: Container(
                  width: 460,
                  height: 460,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF9DB4FF).withValues(alpha: .38),
                      const Color(0xFF9DB4FF).withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -160,
              left: -140,
              child: IgnorePointer(
                child: Container(
                  width: 480,
                  height: 480,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF2FA8FF).withValues(alpha: .30),
                      const Color(0xFF2FA8FF).withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
            ),
            _body(wide),
          ],
        ),
      ),
    );
  }

  Widget _body(bool wide) {
    return wide
            // Web: the form owns its two-column layout (brand panel left,
            // white form card right) — full display, no phone frame.
            ? const SafeArea(child: _SigninForm(wide: true))
            : SafeArea(
                child: Column(
                  children: [
                    const StatusBar(light: true),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                        child: const _SigninForm(),
                      ),
                    ),
                  ],
                ),
              );
  }
}

class _SigninForm extends StatefulWidget {
  /// Wide (web) two-column layout vs. the stacked mobile column.
  final bool wide;

  const _SigninForm({this.wide = false});

  @override
  State<_SigninForm> createState() => _SigninFormState();
}

class _SigninFormState extends State<_SigninForm> {
  late List<TextEditingController> _otp;
  String _phone = '';
  String _email = '';
  String _mode = 'email'; // email | mobile
  bool _sending = false;
  bool _seeded = false;
  bool _codeSent = false; // presentation only: drives the step indicator

  // Resend cooldown + inline errors.
  static const int _cooldownSecs = 30;
  int _cooldown = 0;
  Timer? _timer;
  bool _smsDown = false; // 503 SMS_NOT_CONFIGURED
  String? _emailError;
  String? _phoneError;
  String? _otpError;

  void _startCooldown(int secs) {
    _timer?.cancel();
    setState(() => _cooldown = secs);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown = _cooldown - 1);
      if (_cooldown <= 0) t.cancel();
    });
  }

  /// Reads the last sign-in failure: field highlights, SMS-not-configured
  /// switch and the 429 retry time. [sent] is true for a send-code call.
  void _applyAuthError(AppState state, {required bool sent}) {
    final e = state.lastAuthError;
    final f = ApiException.takeFields();
    _emailError = ApiException.fieldError(f, ['email']);
    _phoneError = ApiException.fieldError(f, ['mobile', 'phone']);
    _otpError = ApiException.fieldError(f, ['otp', 'code']);
    _smsDown = e != null && (e.code == 'SMS_NOT_CONFIGURED' || (e.statusCode == 503 && !e.isServiceBusy && _mode == 'mobile'));
    if (e != null && e.isRateLimited && sent) {
      final s = e.retryAfterSeconds;
      _startCooldown(s != null && s > 0 ? s : _cooldownSecs);
    }
  }

  @override
  void initState() {
    super.initState();
    // One shared 5-box OTP row for both channels (email + mobile).
    _otp = List.generate(5, (_) => TextEditingController());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _seeded = true;
      _phone = digits(StateScope.read(context).userPhone);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otp) {
      c.dispose();
    }
    super.dispose();
  }

  String get _code => _otp.map((c) => c.text).join();

  void _setMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      // Both channels use the same 5-digit OTP row; switching just clears any
      // half-typed digits. Clearing (not disposing) keeps the still-attached
      // text fields safe.
      for (final c in _otp) {
        c.clear();
      }
    });
  }

  /// Validates the e-mail / mobile with the shared rules and shows the
  /// message under the field. Returns true when it is fine.
  bool _checkContact() {
    final msg = _mode == 'mobile'
        ? Validators.mobile(_phone, required: true)
        : Validators.email(_email, required: true);
    setState(() {
      _emailError = _mode == 'email' && msg != null ? gt(msg) : null;
      _phoneError = _mode == 'mobile' && msg != null ? gt(msg) : null;
    });
    return msg == null;
  }

  /// Send the OTP: `/auth/otp/send` (email) or `/auth/otp/send-mobile`.
  /// The backend's error (e.g. `SMS_NOT_CONFIGURED`) surfaces as a toast.
  Future<void> _sendCode() async {
    if (_sending || _cooldown > 0) return;
    final state = StateScope.read(context);
    if (!_checkContact()) return;
    setState(() => _sending = true);
    final err = _mode == 'mobile'
        ? await state.sendMobileOtpSignIn(_phone)
        : await state.sendOtp(_email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _emailError = null;
      _phoneError = null;
      _smsDown = false;
      if (err != null) _applyAuthError(state, sent: true);
    });
    if (err == null) {
      _startCooldown(_cooldownSecs);
      setState(() => _codeSent = true);
    }
    if (err != null) {
      showToast(err, 'error');
    } else {
      showToast(_mode == 'mobile'
          ? 'Code sent · check your messages'
          : 'Code sent · check your inbox');
    }
  }

  Future<void> _submit() async {
    if (_sending) return;
    final state = StateScope.read(context);
    if (_mode == 'mobile') {
      final d = digits(_phone);
      if (!_checkContact()) return;
      if (!RegExp(r'^\d{4,8}$').hasMatch(_code)) {
        showToast('Enter the code from your messages', 'error');
        return;
      }
      setState(() => _sending = true);
      final err = await state.verifyMobileOtpSignIn(d, _code);
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (err != null) _applyAuthError(state, sent: false);
      });
      if (err != null) {
        showToast(err, 'error');
        return;
      }
      _goAfterSignIn(state);
      return;
    }

    // email mode -> real backend OTP verification
    if (!_checkContact()) return;
    if (!RegExp(r'^\d{4,8}$').hasMatch(_code)) {
      showToast('Enter the code from your email', 'error');
      return;
    }
    setState(() => _sending = true);
    final err = await state.verifyOtpSignIn(_email, _code);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (err != null) _applyAuthError(state, sent: false);
    });
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    _goAfterSignIn(state);
  }

  /// Where a fresh session lands: admins to the panel, counter staff (the
  /// backend's CASHIER role) straight to the Orders screens they are
  /// allowed to work, a bare new customer to `#/setup` (first-time login),
  /// everyone else to `#/home`.
  String _landing(AppState state) {
    final back = Nav.instance.returnTo;
    if (state.isBackendAdmin) {
      Nav.instance.returnTo = null;
      return '/admin';
    }
    if (state.isBackendStaff) {
      Nav.instance.returnTo = null;
      return '/admin/orders';
    }
    if (state.needsProfileSetup) {
      Nav.instance.returnTo = null;
      return '/setup';
    }
    // A customer who was stopped at an account page goes back to it.
    Nav.instance.returnTo = null;
    return back ?? '/home';
  }

  void _goAfterSignIn(AppState state) {
    go(_landing(state));
    showToast(state.isBackendAdmin
        ? 'Signed in · admin'
        : state.isBackendStaff
            ? 'Signed in · counter staff'
            : (state.needsProfileSetup
                ? 'Welcome! One step to go'
                : 'Signed in · welcome back'));
  }

  /// Segmented Email / Mobile OTP switch.
  Widget _modeToggle(bool gu) {
    Widget chip(String value, String label) {
      final selected = _mode == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setMode(value),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.white : AppColors.ink2,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          chip('email', gu ? 'ઇમેઇલ' : 'Email'),
          const SizedBox(width: 4),
          chip('mobile', gu ? 'મોબાઇલ' : 'Mobile'),
        ],
      ),
    );
  }

  /// Two-step progress: 1 enter email/mobile + send code, 2 enter the code.
  Widget _steps(bool gu) {
    final onTwo = _codeSent;
    Widget dot(int n, String label, bool active, bool done) {
      return Expanded(
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppColors.green
                    : (active ? AppColors.red : AppColors.bg),
                border: Border.all(
                    color: (done || active) ? Colors.transparent : AppColors.stepLine,
                    width: 1.4),
              ),
              alignment: Alignment.center,
              child: done
                  ? const AppIcon('check',
                      size: 13, color: AppColors.white, sw: 2.6)
                  : Text(
                      '$n',
                      style: TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: active ? AppColors.white : AppColors.ink2,
                      ),
                    ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: (active || done) ? AppColors.ink : AppColors.ink2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        dot(1, gu ? 'કોડ મોકલો' : 'Get code', !onTwo, onTwo),
        Container(
          width: 18,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          color: onTwo ? AppColors.green : AppColors.stepLine,
        ),
        dot(2, gu ? 'ચકાસો' : 'Verify', onTwo, false),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: AppTheme.uiFont,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final gu = StateScope.of(context).lang == 'gu';
    final hintStyle = TextStyle(
      fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
      fontSize: 15,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: AppColors.white.withOpacity(.92),
    );

    // ---- shared pieces -------------------------------------------------
    final brand = Row(
      children: [
        LogoMark(size: widget.wide ? 72 : 44, color: AppColors.white),
        SizedBox(width: widget.wide ? 18 : 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              brandTop(),
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: widget.wide ? 38 : 24,
                fontWeight: FontWeight.w800,
                letterSpacing: widget.wide ? 3.4 : 2.4,
                color: AppColors.white,
                height: 1.05,
              ),
            ),
            Text(
              brandBottom(),
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: widget.wide ? 17 : 13,
                fontWeight: FontWeight.w800,
                letterSpacing: widget.wide ? 3.6 : 2.6,
                color: AppColors.white.withOpacity(.9),
              ),
            ),
          ],
        ),
      ],
    );

    final headline = Text(
      gu ? 'પાછા સ્વાગત છે.' : 'Welcome back.',
      style: gu
          ? AppTheme.guj(
              size: widget.wide ? 52 : 36,
              w: FontWeight.w800,
              color: AppColors.white)
          : TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: widget.wide ? 56 : 36,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: AppColors.white,
            ),
    );

    final subcopy = Text(
      gu
          ? 'દુકાનમાં વપરાતા નંબરથી સાઇન ઇન કરો.'
          : 'Sign in with the number you use at the store.',
      style: TextStyle(
        fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
        fontSize: widget.wide ? 19 : 16,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: AppColors.white.withOpacity(.92),
      ),
    );

    final card = Container(
      padding: EdgeInsets.fromLTRB(widget.wide ? 32 : 20, widget.wide ? 24 : 22, widget.wide ? 32 : 20, widget.wide ? 24 : 22),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.sh2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(gu ? 'સાઇન ઇન' : 'Sign in to your account',
              style: TextStyle(
                  fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                  fontSize: widget.wide ? 24 : 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(
              gu
                  ? 'કોડ મેળવો, ચકાસો અને ખરીદી શરૂ કરો.'
                  : 'Get a code, verify it and start shopping.',
              style: TextStyle(
                  fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink2)),
          SizedBox(height: widget.wide ? 12 : 20),
          _steps(gu),
          SizedBox(height: widget.wide ? 12 : 18),
          _modeToggle(gu),
          SizedBox(height: widget.wide ? 10 : 16),
          if (_mode == 'email') ...[
            AppField(
              label: gu ? 'ઇમેઇલ' : 'Email',
              value: _email,
              onChanged: (v) => _email = v,
              error: _emailError,
              keyboardType: TextInputType.emailAddress,
              placeholder: 'you@example.com',
            ),
            SizedBox(height: widget.wide ? 4 : 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    gu ? 'ઇમેઇલમાં કોડ મોકલો' : 'Send the code to your inbox',
                    style: TextStyle(
                      fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink2,
                    ),
                  ),
                ),
                AppLink(
                  _sending
                      ? 'Sending…'
                      : _cooldown > 0
                          ? (gu ? '$_cooldown સેકન્ડ' : 'Wait ${_cooldown}s')
                          : (gu ? 'કોડ મોકલો' : 'Send code'),
                  onTap: _sending || _cooldown > 0 ? () {} : _sendCode,
                  size: 15,
                  minHeight: 44,
                ),
              ],
            ),
          ] else ...[
            _label(gu ? 'મોબાઇલ નંબર' : 'Mobile number'),
            const SizedBox(height: 7),
            PhoneField(
              value: _phone,
              onChanged: (v) => _phone = digits(v),
            ),
            if (_phoneError != null) ...[
              const SizedBox(height: 6),
              Text(_phoneError!,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.red)),
            ],
            if (_smsDown) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      gt('Mobile sign-in is not available right now.'),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.red),
                    ),
                  ),
                  AppLink(
                    gt('Use e-mail instead'),
                    onTap: () => _setMode('email'),
                    size: 13,
                    minHeight: 44,
                  ),
                ],
              ),
            ],
            SizedBox(height: widget.wide ? 4 : 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    gu ? 'એસએમએસમાં કોડ મોકલો' : 'Send the code to your messages',
                    style: TextStyle(
                      fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink2,
                    ),
                  ),
                ),
                AppLink(
                  _sending
                      ? 'Sending…'
                      : _cooldown > 0
                          ? (gu ? '$_cooldown સેકન્ડ' : 'Wait ${_cooldown}s')
                          : (gu ? 'કોડ મોકલો' : 'Send code'),
                  onTap: _sending || _cooldown > 0 ? () {} : _sendCode,
                  size: 15,
                  minHeight: 44,
                ),
              ],
            ),
          ],
          SizedBox(height: widget.wide ? 8 : 16),
          _label(gu ? 'વન-ટાઇમ પાસવર્ડ' : 'One-time password'),
          const SizedBox(height: 7),
          OtpRow(
              controllers: _otp,
              error: _otpError != null,
              onCompleted: (_) {}),
          if (_otpError != null) ...[
            const SizedBox(height: 6),
            Text(_otpError!,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.red)),
          ],
          SizedBox(height: widget.wide ? 2 : 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  gu ? 'કોડ નથી મળ્યો?' : 'Didn’t receive the code?',
                  style: TextStyle(
                    fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink2,
                  ),
                ),
              ),
              AppLink(
                _cooldown > 0
                    ? (gu ? '$_cooldown સેકન્ડમાં રીસેન્ડ' : 'Resend in ${_cooldown}s')
                    : (gu ? 'રીસેન્ડ કરો' : 'Resend code'),
                onTap: _sending || _cooldown > 0 ? () {} : _sendCode,
                size: 15,
                minHeight: 44,
              ),
            ],
          ),
          SizedBox(height: widget.wide ? 8 : 16),
          AppButton(
            gu ? 'ચકાસો અને આગળ વધો' : 'Verify & continue',
            onTap: _submit,
            icon: 'arrow',
            size: BtnSize.lg,
            block: true,
          ),
          SizedBox(height: widget.wide ? 12 : 18),
          Container(
            padding: EdgeInsets.symmetric(vertical: widget.wide ? 8 : 12, horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.greenTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon('shield', size: 18, color: AppColors.green, sw: 2),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    gu
                        ? 'તમારી માહિતી સુરક્ષિત છે'
                        : 'Your details are safe with us',
                    style: TextStyle(
                      fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget perk(String icon, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: AppIcon(icon, size: 20, color: AppColors.gold2, sw: 1.9)),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Text(t,
                    style: hintStyle.copyWith(
                        fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
        );
    final hints = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.wide) ...[
          perk('truck', gu ? 'મફત ડિલિવરી ઘર સુધી' : 'Free delivery to your door'),
          perk('coin', gu ? 'દરેક ઓર્ડર પર કોઈન્સ' : 'Earn coins on every order'),
          perk('flame', gu ? 'રોજ નવા ઑફર' : 'Fresh deals every day'),
          const SizedBox(height: 10),
        ],
        // secure hint
        _hint('shield', hintStyle, gu
            ? 'OTP સુરક્ષિત · પાસવર્ડની જરૂર નથી'
            : 'OTP protected · no password needed'),
      ],
    );

    if (widget.wide) {
      // Web: brand + hints on the gradient left, white form card right.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 48, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      brand,
                      const SizedBox(height: 36),
                      headline,
                      const SizedBox(height: 10),
                      subcopy,
                      const SizedBox(height: 28),
                      hints,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEAF0FF),
                    Color(0xFFD3E0FF),
                    Color(0xFFF5F8FF),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 40,
                      offset: Offset(0, 18)),
                ],
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: card,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        brand,
        const SizedBox(height: 26),
        headline,
        const SizedBox(height: 8),
        subcopy,
        const SizedBox(height: 22),
        card,
        const SizedBox(height: 18),
        hints,
      ],
    );
  }

  Widget _hint(String icon, TextStyle style, String? text,
      {String? bold, String? rest}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: AppIcon(icon, size: 13, color: AppColors.white, sw: 1.8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: text != null
              ? Text(text, style: style)
              : Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      TextSpan(
                        text: bold,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold2,
                        ),
                      ),
                      TextSpan(text: rest),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
