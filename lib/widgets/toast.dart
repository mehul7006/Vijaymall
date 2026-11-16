import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_icon.dart';
import '../state/gu_strings.dart';

/// Prototype toast: `#appToast` — visible 2700ms, then `is-out` (260ms fade).
class ToastService extends ChangeNotifier {
  ToastService._();
  static final ToastService instance = ToastService._();

  String? message;
  String type = 'success'; // success | error | info
  int _seq = 0;
  Timer? _timer;
  Timer? _outTimer;
  bool leaving = false;

  void show(String message, {String type = 'success'}) {
    _seq += 1;
    final seq = _seq;
    _timer?.cancel();
    _outTimer?.cancel();
    this.message = gt(message);
    this.type = type;
    leaving = false;
    notifyListeners();
    _timer = Timer(const Duration(milliseconds: 2700), () {
      if (seq != _seq) return;
      leaving = true;
      notifyListeners();
      _outTimer = Timer(const Duration(milliseconds: 260), () {
        if (seq != _seq) return;
        this.message = null;
        leaving = false;
        notifyListeners();
      });
    });
  }

  /// Convenience: `Toast(msg)` / `Toast(msg, 'error')` from the spec.
  static void call(String message, [String type = 'success']) =>
      instance.show(message, type: type);
}

/// Shorthand used across screens: `showToast('Signed out')`.
void showToast(String message, [String type = 'success']) =>
    ToastService.instance.show(message, type: type);

/// Stack layer mounted by `MaterialApp.builder`; renders the live toast.
class ToastLayer extends StatelessWidget {
  const ToastLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: ToastService.instance,
        builder: (context, _) {
          final msg = ToastService.instance.message;
          if (msg == null) return const SizedBox.shrink();
          final type = ToastService.instance.type;
          final leaving = ToastService.instance.leaving;
          final isError = type == 'error';
          final icon = isError
              ? 'info'
              : type == 'info'
                  ? 'info'
                  : 'check';
          final bg = isError ? AppColors.red3 : AppColors.ink;
          return Align(
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              opacity: leaving ? 0 : 1,
              duration: const Duration(milliseconds: 240),
              child: Container(
                margin: const EdgeInsets.only(top: 64),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppColors.sh2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(icon, size: 17, color: AppColors.white, sw: 2),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        msg,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
