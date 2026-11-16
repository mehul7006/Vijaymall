import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vijay_super_mall/main.dart';
import 'package:vijay_super_mall/nav/nav.dart';

void main() {
  testWidgets('typing in cancel reason does not reset the cursor',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const VijayMallApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    Nav.instance.setLocation('/admin/order/VSM-1043');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    tester.takeException();

    final field = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Why is this order cancelled?',
    );
    expect(field, findsOneWidget, reason: 'reason field exists');

    // enterText drives the real input connection -> onChanged -> setState ->
    // parent rebuild -> AppField.didUpdateWidget. That path must not clobber
    // the cursor, or the browser drops the previous character.
    await tester.enterText(field, 'a');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final ctrl = tester.widget<TextField>(field).controller!;
    // ignore: avoid_print
    print('after "a": text="${ctrl.text}" selection=${ctrl.selection} '
        'valid=${ctrl.selection.isValid}');

    tester.takeException();
    expect(ctrl.text, 'a');
    expect(ctrl.selection.isValid, isTrue,
        reason: 'cursor must stay valid after the parent rebuilds');
    expect(ctrl.selection.baseOffset, 1,
        reason: 'cursor must be after the typed letter, not reset to -1');
  });
}
