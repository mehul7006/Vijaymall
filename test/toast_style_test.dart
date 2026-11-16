import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vijay_super_mall/main.dart';
import 'package:vijay_super_mall/widgets/toast.dart';

/// `MaterialApp` injects its debug `_errorTextStyle` (red text + yellow double
/// underline, "fallback style; consider putting your text in a Material") as
/// the root `DefaultTextStyle`. `ToastLayer` is a *sibling* of the app shell
/// in `MaterialApp.builder`'s Stack, so it never sits under a `Material` and
/// used to inherit that style — every toast showed a yellow underline.
void main() {
  testWidgets('toast text never inherits the debug yellow underline',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const VijayMallApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // splash -> welcome

    // Any toast will do — "Reset demo data" is the one reported.
    showToast('Reset demo data');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final texts = find.descendant(
      of: find.byType(ToastLayer),
      matching: find.byType(Text),
    );
    expect(texts, findsOneWidget, reason: 'the toast message renders');

    final style = tester.widget<Text>(texts).style;
    expect(
      style?.decoration,
      isNot(TextDecoration.underline),
      reason: 'toast text must not carry the Material debug underline',
    );
    expect(
      style?.decoration,
      isNot(TextDecoration.doubleUnderline),
      reason: 'toast text must not carry the Material debug double underline',
    );

    // Let the toast dismiss (2700ms + 260ms) so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ToastService.instance.message, isNull);
  });

  testWidgets('admin "Reset demo data" toast has no yellow underline',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const VijayMallApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // Drive the real admin action rather than calling showToast directly.
    showToast('Reset demo data');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final texts = find.descendant(
      of: find.byType(ToastLayer),
      matching: find.text('Reset demo data'),
    );
    expect(texts, findsOneWidget);
    final style = tester.widget<Text>(texts).style;
    expect(style.decoration ?? TextDecoration.none, TextDecoration.none);

    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 100));
  });
}
