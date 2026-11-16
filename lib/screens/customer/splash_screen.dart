import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/store_text.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';

/// `#/splash` — full-bleed brand screen (no status bar / app bar / nav).
///
/// 1800 ms after the first build it routes to `/home` when signed in,
/// otherwise `/welcome`; the timer is cancelled on dispose.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: SafeArea(child: _SplashStage()),
    );
  }
}

class _SplashStage extends StatefulWidget {
  const _SplashStage();

  @override
  State<_SplashStage> createState() => _SplashStageState();
}

class _SplashStageState extends State<_SplashStage> {
  Timer? _timer;
  bool _signedIn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _signedIn = StateScope.read(context).signedIn;
    _timer ??= Timer(const Duration(milliseconds: 1800), () {
      // Read the session when the timer fires, not at first build: the stored
      // session can finish restoring after the splash appeared, which sent a
      // signed-in user to the welcome screen once.
      if (!mounted) return;
      final signedIn = StateScope.read(context).signedIn || _signedIn;
      go(signedIn ? '/home' : '/welcome');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _ring(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.white.withOpacity(opacity),
          width: 1.4,
        ),
      ),
    );
  }

  Widget _dot(double opacity) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white.withOpacity(opacity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = StateScope.of(context).lang == 'gu';
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                _ring(300, .10),
                _ring(224, .16),
                _ring(150, .24),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, c) => Opacity(
                    opacity: t,
                    child: Transform.scale(scale: .88 + .12 * t, child: c),
                  ),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoMark(size: 58, color: AppColors.white),
                    const SizedBox(height: 18),
                    Text(
                      brandTop(),
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontSize: 40,
                        height: 1.02,
                        letterSpacing: 4,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      brandBottom(),
                      style: TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                        color: AppColors.white.withOpacity(.82),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      brandLocalityLine(),
                      style: AppTheme.guj(
                        size: 13,
                        w: FontWeight.w600,
                        color: AppColors.white.withOpacity(.75),
                      ),
                    ),
                  ],
                ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (context, t, c) => Opacity(opacity: t, child: c),
              child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_dot(.35), _dot(.6), _dot(1)],
                ),
                const SizedBox(height: 14),
                Text(
                  gu
                      ? 'તાજું · સ્થાનિક · મફત ડિલિવરી'
                      : 'Fresh · Local · Delivered free',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: gu ? AppTheme.gujaratiFont : AppTheme.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: gu ? 0 : .3,
                    color: AppColors.white.withOpacity(.9),
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}
