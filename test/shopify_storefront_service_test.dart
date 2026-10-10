import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sri_krishna_pearls_mobile/config/shopify_config.dart';
import 'package:sri_krishna_pearls_mobile/services/shopify_storefront_service.dart';

void main() {
  test('fetchHomeSlides returns active slides in configured order', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), ShopifyConfig.storefrontEndpoint);
      expect(
        request.headers['X-Shopify-Storefront-Access-Token'],
        ShopifyConfig.storefrontAccessToken,
      );
      expect(request.body, contains('metaobjects(type: \\"home_slider\\"'));

      return http.Response(
        jsonEncode({
          'data': {
            'metaobjects': {
              'nodes': [
                _slideNode(
                  handle: 'hyderabadi-pearls-exude-elegance',
                  title: 'Hyderabadi Pearls Exude Elegance',
                  sortOrder: 2,
                  collectionHandle: 'all-products',
                  collectionTitle: 'all products',
                ),
                _slideNode(
                  handle: 'hidden-slide',
                  title: 'Hidden slide',
                  sortOrder: 3,
                  collectionHandle: 'all-products',
                  collectionTitle: 'all products',
                  active: false,
                ),
                _slideNode(
                  handle: 'high-quality-pearl-jewellery',
                  title: 'High Quality Pearl Jewellery',
                  sortOrder: 1,
                  collectionHandle: 'hyderabadi-pearls',
                  collectionTitle: 'Hyderabadi Pearls',
                ),
              ],
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final slides = await ShopifyStorefrontService(client: client)
        .fetchHomeSlides();

    expect(slides, hasLength(2));
    expect(slides.first.title, 'High Quality Pearl Jewellery');
    expect(slides.first.collectionHandle, 'hyderabadi-pearls');
    expect(slides.last.title, 'Hyderabadi Pearls Exude Elegance');
    expect(slides.last.collectionHandle, 'all-products');
  });

  test('fetchHomeSlides surfaces Shopify GraphQL errors', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'errors': [
            {'message': 'Metaobject access denied'},
          ],
        }),
        200,
      ),
    );

    expect(
      ShopifyStorefrontService(client: client).fetchHomeSlides(),
      throwsA(
        isA<ShopifyStorefrontException>().having(
          (error) => error.message,
          'message',
          'Metaobject access denied',
        ),
      ),
    );
  });

  test('fetchHomeCatalog separates Shopify price collections', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'data': {
            'collections': {
              'nodes': [
                {
                  'id': 'price-1',
                  'handle': 'under-rs-1000',
                  'title': 'Under Rs 1000',
                  'image': null,
                  'products': {'nodes': []},
                },
                {
                  'id': 'category-1',
                  'handle': 'rings',
                  'title': 'Rings',
                  'image': {
                    'url': 'https://cdn.shopify.com/rings.png',
                    'altText': 'Rings',
                  },
                  'products': {'nodes': []},
                },
              ],
            },
            'products': {'nodes': []},
          },
        }),
        200,
      ),
    );

    final catalog = await ShopifyStorefrontService(client: client)
        .fetchHomeCatalog();

    expect(catalog.priceCollections.single.title, 'Under Rs 1000');
    expect(catalog.collections.single.title, 'Rings');
  });
}

Map<String, dynamic> _slideNode({
  required String handle,
  required String title,
  required int sortOrder,
  required String collectionHandle,
  required String collectionTitle,
  bool active = true,
}) {
  return {
    'handle': handle,
    'title': {'value': title},
    'subtitle': {'value': 'Subtitle'},
    'buttonLabel': {'value': 'SHOP NOW'},
    'sortOrder': {'value': '$sortOrder'},
    'active': {'value': '$active'},
    'image': {
      'reference': {
        'image': {
          'url': 'https://cdn.shopify.com/banner.png',
          'altText': title,
          'width': 744,
          'height': 744,
        },
      },
    },
    'collection': {
      'reference': {
        'id': 'gid://shopify/Collection/$sortOrder',
        'handle': collectionHandle,
        'title': collectionTitle,
        'onlineStoreUrl':
            'https://srikrishnapearls.com/collections/$collectionHandle',
      },
    },
  };
}
