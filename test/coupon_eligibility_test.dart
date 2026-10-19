import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sri_krishna_pearls_mobile/models/cart_item.dart';
import 'package:sri_krishna_pearls_mobile/models/checkout_coupon.dart';
import 'package:sri_krishna_pearls_mobile/services/shopify_storefront_service.dart';

const item = CartItem(
  key: 'line',
  productId: 'product',
  productHandle: 'pearls',
  title: 'Pearls',
  unitPrice: 3399,
  currencyCode: 'INR',
  quantity: 1,
  availableForSale: true,
  variantId: 'gid://shopify/ProductVariant/42',
);
const coupons = [
  CheckoutCoupon(code: 'MIN5000', title: 'Minimum 5000', description: 'Terms'),
  CheckoutCoupon(code: 'OK', title: 'Offer', description: 'Terms'),
];
Map<String, dynamic> cart({int quantity = 1, bool warning = false}) => {
  'data': {
    'cartCreate': {
      'userErrors': [],
      'warnings': warning
          ? [
              {'message': 'Stock changed'},
            ]
          : [],
      'cart': {
        'id': 'temporary-test-cart',
        'lines': {
          'nodes': [
            {
              'quantity': quantity,
              'merchandise': {'id': item.variantId, 'availableForSale': true},
            },
          ],
        },
      },
    },
  },
};
Map<String, dynamic> result(String code, dynamic applicable) => {
  'cart': {
    'discountCodes': [
      {'code': code, 'applicable': applicable},
    ],
  },
  'userErrors': [],
  'warnings': [],
};

void main() {
  test('normal discount-rejection warnings produce grey offers instead of hiding the list', () async {
    for (final warning in [
      'DISCOUNT_CODE_NOT_HONOURED',
      'DISCOUNT_PURCHASE_NOT_IN_RANGE',
      'DISCOUNT_NO_ENTITLED_LINE_ITEMS',
      'DISCOUNT_CUSTOMER_USAGE_LIMIT_REACHED',
    ]) {
      var calls = 0;
      final service = ShopifyStorefrontService(
        checkoutTokenProvider: () async => 'customer-fixture',
        client: MockClient((_) async {
          calls++;
          if (calls == 1) return http.Response(jsonEncode(cart()), 200);
          final rejected = result('MIN5000', false);
          rejected['warnings'] = [
            {'code': warning, 'message': 'Discount does not apply'},
          ];
          return http.Response(
            jsonEncode({
              'data': {'c0': rejected, 'c1': result('OK', true)},
            }),
            200,
          );
        }),
      );
      final checked = await service.checkCouponEligibility([item], coupons);
      expect(checked.length, 2);
      expect(checked.first.applicable, false);
      expect(checked.last.applicable, true);
    }
  });
  test('stock warnings, unknown warnings, contradictory success and user errors still fail closed', () async {
    for (final mode in [
      'MERCHANDISE_OUT_OF_STOCK',
      'UNKNOWN_WARNING',
      'success',
      'userError',
    ]) {
      var calls = 0;
      final service = ShopifyStorefrontService(
        checkoutTokenProvider: () async => 'customer-fixture',
        client: MockClient((_) async {
          calls++;
          if (calls == 1) return http.Response(jsonEncode(cart()), 200);
          final rejected = result('MIN5000', mode == 'success');
          if (mode == 'userError') {
            rejected['userErrors'] = [
              {'message': 'Cart not found'},
            ];
          } else {
            rejected['warnings'] = [
              {'code': mode == 'success' ? 'DISCOUNT_CODE_NOT_HONOURED' : mode},
            ];
          }
          return http.Response(
            jsonEncode({
              'data': {'c0': rejected, 'c1': result('OK', true)},
            }),
            200,
          );
        }),
      );
      await expectLater(
        service.checkCouponEligibility([item], coupons),
        throwsStateError,
      );
    }
  });
  test('eligibility goes directly to Shopify and each code is checked independently', () async {
    var calls = 0;
    final service = ShopifyStorefrontService(
      checkoutTokenProvider: () async => 'current-customer-token',
      client: MockClient((r) async {
        calls++;
        expect(r.url.host, 'srikrishnapearls.myshopify.com');
        expect(r.url.path, contains('/graphql.json'));
        expect(r.headers.containsKey('X-Shopify-Access-Token'), isFalse);
        final body = jsonDecode(r.body);
        if (calls == 1) {
          final input = body['variables']['input'];
          expect(
            input['buyerIdentity']['customerAccessToken'],
            'current-customer-token',
          );
          expect(input['lines'][0]['quantity'], 1);
          expect(input['lines'][0]['merchandiseId'], item.variantId);
          expect(input.containsKey('amount'), isFalse);
          expect(input.containsKey('customer_id'), isFalse);
          return http.Response(jsonEncode(cart()), 200);
        }
        expect(body['variables']['id'], 'temporary-test-cart');
        expect(body['variables']['c0'], ['MIN5000']);
        expect(body['variables']['c1'], ['OK']);
        expect(body['query'], contains('cartDiscountCodesUpdate'));
        return http.Response(
          jsonEncode({
            'data': {'c0': result('MIN5000', false), 'c1': result('OK', true)},
          }),
          200,
        );
      }),
    );
    final checked = await service.checkCouponEligibility([item], coupons);
    expect(calls, 2);
    expect(checked.first.applicable, false);
    expect(checked.last.applicable, true);
    expect(coupons.first.applicable, isNull);
  });
  test('stock changes, missing applicability and API errors never fabricate eligibility', () async {
    for (final mode in ['quantity', 'warning', 'missing', 'error']) {
      var calls = 0;
      final service = ShopifyStorefrontService(
        checkoutTokenProvider: () async => 'customer-fixture',
        client: MockClient((r) async {
          calls++;
          if (calls == 1) {
            return http.Response(
              jsonEncode(
                cart(
                  quantity: mode == 'quantity' ? 2 : 1,
                  warning: mode == 'warning',
                ),
              ),
              200,
            );
          }
          return http.Response(
            jsonEncode(
              mode == 'error'
                  ? {
                      'errors': [
                        {'message': 'unavailable'},
                      ],
                    }
                  : {
                      'data': {
                        'c0': result('MIN5000', null),
                        'c1': result('OK', true),
                      },
                    },
            ),
            200,
          );
        }),
      );
      await expectLater(
        service.checkCouponEligibility([item], coupons),
        mode == 'error'
            ? throwsA(isA<ShopifyStorefrontException>())
            : throwsStateError,
      );
    }
  });
  test('empty offers do not create a cart or request a token; invalid lines fail before network', () async {
    final service = ShopifyStorefrontService(
      checkoutTokenProvider: () async => throw StateError('No token expected'),
      client: MockClient((_) async => throw StateError('No request expected')),
    );
    expect(await service.checkCouponEligibility([item], []), isEmpty);
    await expectLater(
      service.checkCouponEligibility([], coupons),
      throwsStateError,
    );
  });
}
