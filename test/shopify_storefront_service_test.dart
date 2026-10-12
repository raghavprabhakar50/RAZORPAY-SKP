import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sri_krishna_pearls_mobile/config/shopify_config.dart';
import 'package:sri_krishna_pearls_mobile/models/home_catalog.dart';
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

  test('fetchDiscountBanners returns only currently visible entries', () async {
    final client = MockClient((request) async {
      expect(request.body, contains('metaobjects(type: \\"discount_banner\\"'));
      return http.Response(
        jsonEncode({
          'data': {
            'metaobjects': {
              'nodes': [
                _discountBannerNode(
                  handle: 'later',
                  heading: 'Later offer',
                  sortOrder: 1,
                  startsAt: '2026-10-12T12:00:00+05:30',
                ),
                _discountBannerNode(
                  handle: 'visible',
                  heading: 'Dussehra Gifts',
                  sortOrder: 2,
                  startsAt: '2026-10-12T09:00:00+05:30',
                  endsAt: '2026-10-13T09:00:00+05:30',
                ),
                _discountBannerNode(
                  handle: 'inactive',
                  heading: 'Inactive offer',
                  sortOrder: 3,
                  active: false,
                ),
              ],
            },
          },
        }),
        200,
      );
    });

    final banners = await ShopifyStorefrontService(client: client)
        .fetchDiscountBanners(now: DateTime.parse('2026-10-12T10:40:00+05:30'));

    expect(banners, hasLength(1));
    expect(banners.single.heading, 'Dussehra Gifts');
    expect(banners.single.discountTitle, 'NAVRATRI30');
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

  test('fetchProduct returns Shopify gallery and variant pricing', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['query'], contains('query ProductDetails'));
      expect(body['variables'], {'handle': 'pearl-set'});
      return http.Response(
        jsonEncode({
          'data': {
            'product': {
              'id': 'gid://shopify/Product/1',
              'handle': 'pearl-set',
              'title': 'Beautiful Blossom Pearls Comboset',
              'description': 'Single line pendent set with finger ring',
              'descriptionHtml': '<p><strong>Pearl necklace</strong></p><ul><li>Freshwater pearls</li></ul>',
              'productType': 'Combo Set',
              'shortDescriptionRich': {
                'type': 'rich_text_field',
                'value': jsonEncode({
                  'type': 'root',
                  'children': [
                    {
                      'type': 'list-item',
                      'children': [
                        {
                          'type': 'text',
                          'value': 'A trusted pearl brand.',
                          'bold': true,
                        },
                      ],
                    },
                  ],
                }),
              },
              'featuredImage': {
                'url': 'https://cdn.shopify.com/main.png',
                'altText': 'Pearl set',
              },
              'priceRange': {
                'minVariantPrice': {'amount': '4999.00', 'currencyCode': 'INR'},
              },
              'images': {
                'nodes': [
                  {
                    'url': 'https://cdn.shopify.com/main.png',
                    'altText': 'Pearl set',
                  },
                  {
                    'url': 'https://cdn.shopify.com/ring.png',
                    'altText': 'Ring',
                  },
                ],
              },
              'media': {
                'nodes': [
                  {
                    '__typename': 'MediaImage',
                    'alt': 'Pearl set',
                    'previewImage': {
                      'url': 'https://cdn.shopify.com/main.png',
                      'altText': 'Pearl set',
                    },
                    'image': {
                      'url': 'https://cdn.shopify.com/main.png',
                      'altText': 'Pearl set',
                    },
                  },
                  {
                    '__typename': 'Video',
                    'alt': 'Pearl set video',
                    'previewImage': {
                      'url': 'https://cdn.shopify.com/video-preview.png',
                      'altText': 'Video preview',
                    },
                    'sources': [
                      {
                        'url': 'https://cdn.shopify.com/product.mp4',
                        'mimeType': 'video/mp4',
                        'format': 'mp4',
                      },
                    ],
                  },
                ],
              },
              'variants': {
                'nodes': [
                  {
                    'id': 'gid://shopify/ProductVariant/1',
                    'title': 'White',
                    'availableForSale': true,
                    'selectedOptions': [
                      {'name': 'Shade', 'value': 'White'},
                    ],
                    'price': {'amount': '4999.00', 'currencyCode': 'INR'},
                    'compareAtPrice': {
                      'amount': '6999.00',
                      'currencyCode': 'INR',
                    },
                  },
                ],
              },
            },
          },
        }),
        200,
      );
    });

    final product = await ShopifyStorefrontService(client: client)
        .fetchProduct('pearl-set');

    expect(product.title, 'Beautiful Blossom Pearls Comboset');
    expect(product.images, hasLength(2));
    expect(product.amount, 4999);
    expect(product.compareAtAmount, 6999);
    expect(product.firstVariantId, 'gid://shopify/ProductVariant/1');
    expect(product.shortDescription, '• A trusted pearl brand.');
    expect(product.shortDescriptionSegments[1].bold, isTrue);
    expect(
      product.descriptionHtml,
      contains('<strong>Pearl necklace</strong>'),
    );
    expect(product.media, hasLength(2));
    expect(product.media.last.type, StorefrontProductMediaType.video);
    expect(product.variants.single.selectedOptions['Shade'], 'White');
  });

  test('fetchRelatedProducts parses Shopify recommendations', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['query'], contains('query RelatedProducts'));
      expect(body['variables'], {'productId': 'gid://shopify/Product/1'});
      return http.Response(
        jsonEncode({
          'data': {
            'productRecommendations': [
              {
                'id': 'gid://shopify/Product/2',
                'handle': 'related-pearl-set',
                'title': 'Related Pearl Set',
                'productType': 'Necklace',
                'featuredImage': {
                  'url': 'https://cdn.shopify.com/related.png',
                  'altText': 'Related set',
                },
                'priceRange': {
                  'minVariantPrice': {
                    'amount': '2999.00',
                    'currencyCode': 'INR',
                  },
                },
              },
            ],
          },
        }),
        200,
      );
    });

    final products = await ShopifyStorefrontService(client: client)
        .fetchRelatedProducts('gid://shopify/Product/1');

    expect(products.single.title, 'Related Pearl Set');
    expect(products.single.amount, 2999);
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
    'showOverlay': {'value': 'false'},
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

Map<String, dynamic> _discountBannerNode({
  required String handle,
  required String heading,
  required int sortOrder,
  bool active = true,
  String? startsAt,
  String? endsAt,
}) {
  return {
    'handle': handle,
    'heading': {'value': heading},
    'subtitle': {'value': 'Fresh picks and special prices'},
    'discountTitle': {'value': 'NAVRATRI30'},
    'discountId': {'value': ''},
    'sortOrder': {'value': '$sortOrder'},
    'active': {'value': '$active'},
    'startsAt': {'value': startsAt},
    'endsAt': {'value': endsAt},
    'image': {
      'reference': {
        'image': {
          'url': 'https://cdn.shopify.com/discount.png',
          'altText': heading,
        },
      },
    },
  };
}
