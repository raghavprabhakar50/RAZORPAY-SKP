import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sri_krishna_pearls_mobile/models/cart_item.dart';
import 'package:sri_krishna_pearls_mobile/services/shopify_storefront_service.dart';

const item = CartItem(
  key: 'fixture',
  productId: '1',
  productHandle: 'pearls',
  title: 'Pearls',
  unitPrice: 1,
  currencyCode: 'INR',
  quantity: 2,
  availableForSale: true,
  variantId: 'gid://shopify/ProductVariant/1',
  giftCard: 'Birthday',
  giftMessage: 'Happy birthday',
);

Map<String, dynamic> result({
  String url = 'https://www.srikrishnapearls.com/cart/c/fixture',
  int quantity = 2,
  bool applicable = true,
}) => {
  'data': {
    'cartCreate': {
      'userErrors': [],
      'warnings': [],
      'cart': {
        'checkoutUrl': url,
        'discountCodes': [
          {'code': 'SKP5', 'applicable': applicable},
        ],
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

void main() {
  test(
    'special instructions survive the website URL and reject excessive input',
    () {
      final url = ShopifyStorefrontService.websiteCartUrl([
        item,
      ], orderNote: '  Please pack carefully\nGift order  ');
      expect(url.queryParameters['note'], 'Please pack carefully\nGift order');
      expect(
        () => ShopifyStorefrontService.websiteCartUrl([
          item,
        ], orderNote: 'x' * 1001),
        throwsStateError,
      );
      expect(
        ShopifyStorefrontService.websiteCartUrl([item]).queryParameters
            .containsKey('note'),
        false,
      );
    },
  );
  test(
    'special instructions are preserved in the authenticated fallback cart',
    () async {
      final service = ShopifyStorefrontService(
        client: MockClient((request) async {
          expect(
            jsonDecode(request.body)['variables']['input']['note'],
            'Pack carefully',
          );
          return http.Response(jsonEncode(result()), 200);
        }),
      );
      await service.createWebCheckout(
        [item],
        customerAccessToken: 'fixture',
        orderNote: ' Pack carefully ',
      );
    },
  );
  test('website cart permalink loads the Online Store theme, never direct checkout or customer tokens', () {
    final url = ShopifyStorefrontService.websiteCartUrl([item]);
    expect(url.scheme, 'https');
    expect(url.path, '/cart/1:2');
    expect(url.queryParameters['storefront'], 'true');
    final props = jsonDecode(
      utf8.decode(base64Url.decode(url.queryParameters['properties']!)),
    );
    expect(props, {'Gift Card': 'Birthday', 'Gift Message': 'Happy birthday'});
    expect(url.queryParameters.containsKey('customerAccessToken'), false);
    expect(url.queryParameters.containsKey('checkout'), false);
  });
  test(
    'permalink never silently loses gift properties on subsequent products',
    () {
      expect(
        () => ShopifyStorefrontService.websiteCartUrl([item, item]),
        throwsUnsupportedError,
      );
      expect(
        () => ShopifyStorefrontService.websiteCartUrl([]),
        throwsStateError,
      );
    },
  );
  test('multiple normal variants and duplicate quantities are preserved', () {
    const plain = CartItem(
      key: 'plain',
      productId: '1',
      productHandle: 'pearls',
      title: 'Pearls',
      unitPrice: 1,
      currencyCode: 'INR',
      quantity: 2,
      availableForSale: true,
      variantId: 'gid://shopify/ProductVariant/1',
    );
    const second = CartItem(
      key: 'second',
      productId: '2',
      productHandle: 'pearls2',
      title: 'Pearls2',
      unitPrice: 2,
      currencyCode: 'INR',
      quantity: 1,
      availableForSale: true,
      variantId: 'gid://shopify/ProductVariant/2',
    );
    final url = ShopifyStorefrontService.websiteCartUrl([plain, second, plain]);
    expect(url.path, '/cart/1:4,2:1');
    expect(url.queryParameters.containsKey('properties'), false);
  });
  test('hosted checkout transfers authenticated buyer, variants, gifts and coupon without local prices', () async {
    final service = ShopifyStorefrontService(
      client: MockClient((request) async {
        final input = jsonDecode(request.body)['variables']['input'];
        expect(
          input['buyerIdentity']['customerAccessToken'],
          'customer_fixture',
        );
        expect(input['discountCodes'], ['SKP5']);
        final line = input['lines'][0];
        expect(line['merchandiseId'], item.variantId);
        expect(line['quantity'], 2);
        expect(line['attributes'], [
          {'key': 'Gift Card', 'value': 'Birthday'},
          {'key': 'Gift Message', 'value': 'Happy birthday'},
        ]);
        expect(line.containsKey('price'), false);
        expect(input.containsKey('amount'), false);
        return http.Response(jsonEncode(result()), 200);
      }),
    );
    final url = await service.createWebCheckout(
      [item],
      customerAccessToken: 'customer_fixture',
      discountCode: ' SKP5 ',
    );
    expect(url.host, 'www.srikrishnapearls.com');
  });

  test('foreign/insecure checkout URLs, changed quantities and rejected coupons never launch', () async {
    for (final payload in [
      result(url: 'https://evil.invalid/pay'),
      result(url: 'http://www.srikrishnapearls.com/cart/c/fixture'),
      result(quantity: 1),
      result(applicable: false),
      {
        'data': {
          'cartCreate': {
            'userErrors': [
              {'message': 'Unavailable'},
            ],
          },
        },
      },
    ]) {
      final service = ShopifyStorefrontService(
        client: MockClient(
          (_) async => http.Response(jsonEncode(payload), 200),
        ),
      );
      await expectLater(
        service.createWebCheckout([
          item,
        ], customerAccessToken: 'customer_fixture'),
        throwsStateError,
      );
    }
  });

  test(
    'empty cart or missing customer authentication fails before any request',
    () async {
      var calls = 0;
      final service = ShopifyStorefrontService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        service.createWebCheckout([], customerAccessToken: 'fixture'),
        throwsStateError,
      );
      await expectLater(
        service.createWebCheckout([item], customerAccessToken: ''),
        throwsStateError,
      );
      expect(calls, 0);
    },
  );
}
