import 'package:flutter/material.dart';

import '../provider/state_scope.dart';
import '../state/gu_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Shown on home and checkout while the admin has paused online orders
/// (`onlineOrdersOpen == false`); carries the server's `onlineOrdersMessage`.
class OrdersPausedBanner extends StatelessWidget {
  const OrdersPausedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StateScope.of(context);
    if (state.onlineOrdersOpen || state.isBackendAdmin) {
      return const SizedBox.shrink();
    }
    final msg = state.onlineOrdersMessage.isNotEmpty
        ? state.onlineOrdersMessage
        : gt('We are not taking online orders right now. Please visit the shop or try again later.');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.red.withValues(alpha: .10),
          const Color(0xFFFFF3DC),
        ]),
        border: Border.all(color: AppColors.red.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFEE4A52), AppColors.red]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
                child:
                    AppIcon('info', size: 16, color: AppColors.white, sw: 2)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.red,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
