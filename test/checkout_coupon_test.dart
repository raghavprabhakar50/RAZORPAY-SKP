import 'package:flutter_test/flutter_test.dart';
import 'package:sri_krishna_pearls_mobile/models/checkout_coupon.dart';

void main() {
  test(
    'newest-first API order and newest duplicate definition are preserved',
    () {
      Map<String, dynamic> node(String code, String title) => {
        'code': {'value': code},
        'heading': {'value': title},
        'active': {'value': 'true'},
      };
      final list = CheckoutCoupon.published([
        node('NEW', 'Latest offer'),
        node('OLDER', 'Older offer'),
        node('new', 'Outdated duplicate'),
      ], DateTime.utc(2026, 10, 17));
      expect(list.map((c) => c.code), ['NEW', 'OLDER']);
      expect(list.first.title, 'Latest offer');
    },
  );
  Map<String, dynamic> offer(String code, {bool active = true, String? end}) =>
      {
        'code': {'value': code},
        'heading': {'value': 'Public offer'},
        'active': {'value': active.toString()},
        if (end != null) 'endsAt': {'value': end},
      };
  test('coupon list only uses explicitly published codes, not discount titles or Admin IDs', () {
    final list = CheckoutCoupon.published([
      offer('SKP5'),
      offer('skp5'),
      offer('EXPIRED', end: '2020-01-01T00:00:00Z'),
      offer('HIDDEN', active: false),
      offer('gid://shopify/DiscountCodeNode/1'),
      {
        'discountTitle': {'value': 'Not a coupon'},
        'active': {'value': 'true'},
      },
    ], DateTime.utc(2026, 10, 17));
    expect(list.length, 1);
    expect(list.single.code.toUpperCase(), 'SKP5');
  });
}
