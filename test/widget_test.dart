import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vijay_super_mall/main.dart';
import 'package:vijay_super_mall/nav/nav.dart';
import 'package:vijay_super_mall/screens/customer/home_screen.dart';
import 'package:vijay_super_mall/screens/customer/signin_screen.dart';
import 'package:vijay_super_mall/screens/customer/splash_screen.dart';
import 'package:vijay_super_mall/screens/customer/welcome_screen.dart';
import 'package:vijay_super_mall/state/app_state.dart';

void main() {
  testWidgets('boots into splash, then routes to welcome after 1800ms',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VijayMallApp());
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  test('seed cart totals match the prototype (1,349 − 50 − 120 = 1,179)',
      () {
    final state = AppState();
    final t = state.cartTotals();

    expect(t.subtotal, 1349);
    expect(t.discount, 50);
    expect(t.coinDiscount, 120);
    expect(t.total, 1179);
    expect(state.cartCoupon, 'FESTIVE50');
    expect(state.coinBalance(), greaterThan(0));
  });

  test('placeOrder() follows the prototype flow (bill, stock, ledger, cart)',
      () {
    final state = AppState();

    // next order number = highest seed number + 1
    expect(state.nextOrderNumber(), 'VSM-1044');

    final before = state.cartTotals();
    final almonds = state.productById('almonds')!;
    final stockBefore = almonds.variants[1].stock;
    final festive = state.coupons.firstWhere((c) => c.code == 'FESTIVE50');
    final usesBefore = festive.uses;
    final balanceBefore = state.coinBalance();

    final res = state.placeOrder();
    expect(res.error, isNull);
    expect(res.number, 'VSM-1044');

    // cart emptied, order landed at the top with the exact bill
    expect(state.cartItems, isEmpty);
    expect(state.cartTotals().details, isEmpty);
    final order = state.orders.first;
    expect(order.number, 'VSM-1044');
    expect(order.status, 'Placed');
    expect(order.payment, 'Cash on delivery');
    expect(order.paymentState, 'Pending');
    expect(order.bill.subtotal, 1349);
    expect(order.bill.couponDiscount, 50);
    expect(order.bill.coinsUsed, 120);
    expect(order.bill.total, 1179);
    expect(order.coinsUsed, 120);
    expect(order.coinsEarned, before.coinsEarned);
    expect(order.stockReserved, isTrue);

    // stock reserved on the shelf
    expect(almonds.variants[1].stock, stockBefore - 1);

    // ledger: redeemed −120 (spent) and pending earn entry
    // (both unshifted, pending last → sits at index 0, as in app.js)
    final redeem = state.ledger.firstWhere((l) => l.id == 'lg-redeem-VSM-1044');
    expect(redeem.coins, -120);
    expect(redeem.status, 'spent');
    expect(state.ledger.first.id, 'lg-pending-VSM-1044');
    expect(state.ledger.first.status, 'pending');
    expect(state.ledger.first.coins, order.coinsEarned);

    // pending coins are not spendable, redeemed coins leave the balance
    expect(state.coinBalance(), balanceBefore - 120);

    // coupon usage counted
    expect(state.coupons.firstWhere((c) => c.code == 'FESTIVE50').uses,
        usesBefore + 1);

    // empty cart guard — exact prototype string
    final again = state.placeOrder();
    expect(again.number, isNull);
    expect(again.error, 'Your cart is empty');
  });

  test('order status ladder matches app.js (delivery + pickup)', () {
    final state = AppState();
    final delivery = state.orders.firstWhere((o) => o.mode == 'delivery');
    expect(state.orderSteps(delivery),
        ['Placed', 'Confirmed', 'Packed', 'Out for Delivery', 'Delivered']);
    expect(state.nextStatus(delivery), 'Confirmed');
    delivery.status = 'Packed';
    expect(state.nextStatus(delivery), 'Out for Delivery');

    final pickup = state.orders.firstWhere((o) => o.mode == 'pickup');
    expect(state.orderSteps(pickup),
        ['Placed', 'Confirmed', 'Packed', 'Ready for Pickup', 'Picked Up']);
    pickup.status = 'Packed';
    expect(state.nextStatus(pickup), 'Ready for Pickup');
  });

  testWidgets(
      'desktop 1440x900: demo-OTP sign-in reaches /home, no layout errors',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const VijayMallApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // splash -> welcome
    Nav.instance.setLocation('/signin');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SigninScreen), findsOneWidget);

    await tester.tap(find.text('Use demo OTP'));
    await tester.pump();
    await tester.tap(find.text('Verify & continue'));
    await tester.pump();
    // Let the route notification propagate and the transition finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(Nav.instance.route, '/home');
    expect(find.byType(HomeScreen), findsOneWidget);

    // Stay on /home over the next second (no bounced route).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      expect(Nav.instance.route, '/home');
    }
    // Let the sign-in toast dismiss so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 3200));
    expect(Nav.instance.route, '/home');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
