import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sri_krishna_pearls_mobile/models/checkout_coupon.dart';
import 'package:sri_krishna_pearls_mobile/widgets/cart_coupon_offers.dart';

const first = CheckoutCoupon(
  code: 'SKP5',
  title: 'Website coupon',
  description: 'Shopify verifies eligibility.',
);
const second = CheckoutCoupon(
  code: 'PUBLIC10',
  title: 'Another public offer',
  description: 'Fixture only.',
);

void main() {
  testWidgets('one coupon also exposes the available coupon list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CartCouponOffers(
            coupons: const [first],
            selectedCode: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('SKP5'), findsNWidgets(2));
    expect(find.text('View available (1)'), findsOneWidget);
  });
  testWidgets(
    'multiple coupons open a scrollable list and selection updates the preview',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => CartCouponOffers(
                coupons: const [first, second],
                selectedCode: selected,
                onChanged: (value) => update(() => selected = value),
              ),
            ),
          ),
        ),
      );
      expect(find.text('PUBLIC10'), findsNothing);
      await tester.tap(find.text('View available (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Available coupons'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('coupon-use-PUBLIC10')));
      await tester.pumpAndSettle();
      expect(selected, 'PUBLIC10');
      expect(find.text('Available coupons'), findsNothing);
      expect(find.text('PUBLIC10'), findsNWidgets(2));
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    },
  );
  testWidgets('working checkout disables Apply and View all', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CartCouponOffers(
            coupons: const [first, second],
            selectedCode: null,
            enabled: false,
            onChanged: (_) => fail('Must remain disabled'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apply'));
    await tester.tap(find.text('View available (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Available coupons'), findsNothing);
  });
}
