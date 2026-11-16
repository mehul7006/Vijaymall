import 'package:flutter/material.dart';

import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/panels.dart';
import '../../state/gu_strings.dart';

/// Missing route / missing order / missing product screen.
class MissingScreen extends StatelessWidget {
  final String? title;
  final String? heading;
  final String copy;
  final String backRoute;
  final String? buttonLabel;
  final String? buttonRoute;

  const MissingScreen({
    super.key,
    this.title,
    this.heading,
    required this.copy,
    this.backRoute = '/home',
    this.buttonLabel,
    this.buttonRoute,
  });

  @override
  Widget build(BuildContext context) {
    final gu = StateScope.of(context).lang == 'gu';
    final screenTitle = title ??
        (gu ? 'મળ્યું નથી' : 'Not found');
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenBar(
              title: screenTitle,
              onBack: () => go(backRoute),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: EmptyState(
                  icon: 'search',
                  title: heading ??
                      (gu ? 'અમને એ મળ્યું નહીં' : 'We could not find that'),
                  copy: copy,
                  actionLabel: buttonLabel,
                  onAction: buttonRoute == null
                      ? null
                      : () => go(buttonRoute!),
                ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (buttonRoute != '/home')
                    AppButton(
                      gt('Go to home'),
                      icon: 'home',
                      block: true,
                      onTap: () => go('/home'),
                    ),
                  if (buttonLabel == null && backRoute != '/home') ...[
                    const SizedBox(height: 10),
                    AppButton(
                      gu ? 'પાછા જાઓ' : 'Go back',
                      onTap: () => go(backRoute),
                      variant: BtnVariant.secondary,
                      block: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
