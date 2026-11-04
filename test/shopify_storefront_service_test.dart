import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sri_krishna_pearls_mobile/config/shopify_config.dart';
import 'package:sri_krishna_pearls_mobile/models/cart_item.dart';
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

  test('predictiveSearch returns query suggestions and products', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['query'], contains('query PredictiveSearch'));
      expect(body['query'], contains('types: [QUERY, PRODUCT]'));
      expect(body['variables'], {'query': 'fancy'});
      return http.Response(
        jsonEncode({
          'data': {
            'predictiveSearch': {
              'queries': [
                {'text': 'fancy baroque pearl'},
                {'text': 'fancy pearl set'},
              ],
              'products': [
                {
                  'id': 'gid://shopify/Product/9',
                  'handle': 'fancy-baroque-pearl-set',
                  'title': 'Fancy Baroque Pearl Set',
                  'productType': 'Necklace',
                  'featuredImage': {
                    'url': 'https://cdn.shopify.com/fancy.png',
                    'altText': 'Fancy Baroque Pearl Set',
                  },
                  'priceRange': {
                    'minVariantPrice': {
                      'amount': '4499.00',
                      'currencyCode': 'INR',
                    },
                  },
                },
              ],
            },
          },
        }),
        200,
      );
    });

    final results = await ShopifyStorefrontService(client: client)
        .predictiveSearch(' fancy ');

    expect(results.suggestions, ['fancy baroque pearl', 'fancy pearl set']);
    expect(results.products.single.title, 'Fancy Baroque Pearl Set');
    expect(results.products.single.amount, 4499);
  });

  test('fetchCollections paginates and includes price collections', () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['query'], contains('query Collections'));
      final variables = body['variables'] as Map<String, dynamic>;
      final secondPage = variables['after'] == 'next-page';
      return http.Response(
        jsonEncode({
          'data': {
            'collections': {
              'pageInfo': {
                'hasNextPage': !secondPage,
                'endCursor': secondPage ? null : 'next-page',
              },
              'nodes': secondPage
                  ? [
                      {
                        'id': 'gid://shopify/Collection/2',
                        'handle': 'akoya-pearls',
                        'title': 'Akoya Pearls',
                        'image': {
                          'url': 'https://cdn.shopify.com/akoya.png',
                          'altText': 'Akoya Pearls',
                        },
                      },
                    ]
                  : [
                      {
                        'id': 'gid://shopify/Collection/all',
                        'handle': 'all-products',
                        'title': 'all products',
                      },
                      {
                        'id': 'gid://shopify/Collection/1',
                        'handle': 'freshwater-pearls',
                        'title': 'Freshwater Pearls',
                      },
                      {
                        'id': 'gid://shopify/Collection/price',
                        'handle': 'under-1000',
                        'title': 'Under 1000',
                      },
                    ],
            },
          },
        }),
        200,
      );
    });

    final collections = await ShopifyStorefrontService(client: client)
        .fetchCollections();

    expect(requestCount, 2);
    expect(collections.map((collection) => collection.title), [
      'all products',
      'Akoya Pearls',
      'Freshwater Pearls',
      'Under 1000',
    ]);
  });

  test(
    'fetchCollectionProducts returns products for selected category',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['query'], contains('query CollectionProducts'));
        expect(body['variables'], {
          'handle': 'freshwater-pearls',
          'after': null,
        });
        return http.Response(
          jsonEncode({
            'data': {
              'collection': {
                'id': 'gid://shopify/Collection/1',
                'handle': 'freshwater-pearls',
                'title': 'Freshwater Pearls',
                'products': {
                  'pageInfo': {'hasNextPage': false, 'endCursor': null},
                  'nodes': [
                    {
                      'id': 'gid://shopify/Product/3',
                      'handle': 'freshwater-necklace',
                      'title': 'Freshwater Pearl Necklace',
                      'productType': 'Necklace',
                      'featuredImage': {
                        'url': 'https://cdn.shopify.com/freshwater.png',
                        'altText': 'Freshwater necklace',
                      },
                      'priceRange': {
                        'minVariantPrice': {
                          'amount': '3499.00',
                          'currencyCode': 'INR',
                        },
                      },
                      'variants': {
                        'nodes': [
                          {
                            'id': 'gid://shopify/ProductVariant/3',
                            'title': 'Default Title',
                            'availableForSale': true,
                            'price': {
                              'amount': '3499.00',
                              'currencyCode': 'INR',
                            },
                            'compareAtPrice': {
                              'amount': '3999.00',
                              'currencyCode': 'INR',
                            },
                            'selectedOptions': [
                              {'name': 'Title', 'value': 'Default Title'},
                            ],
                          },
                        ],
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

      final products = await ShopifyStorefrontService(client: client)
          .fetchCollectionProducts('freshwater-pearls');

      expect(products.single.title, 'Freshwater Pearl Necklace');
      expect(products.single.amount, 3499);
      expect(products.single.compareAtAmount, 3999);
    },
  );

  test('previewCartTotals rejects a Shopify-trimmed cart quantity', () async {
    const variantId = 'gid://shopify/ProductVariant/50651354824842';
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final variables = body['variables'] as Map<String, dynamic>;
      final input = variables['input'] as Map<String, dynamic>;
      final lines = input['lines'] as List<dynamic>;
      expect(lines.single, {'merchandiseId': variantId, 'quantity': 4});

      return http.Response(
        jsonEncode({
          'data': {
            'cartCreate': {
              'cart': {
                'cost': {
                  'subtotalAmount': {
                    'amount': '31999.00',
                    'currencyCode': 'INR',
                  },
                  'totalAmount': {'amount': '25599.20', 'currencyCode': 'INR'},
                },
                'discountCodes': <dynamic>[],
                'discountApplications': <dynamic>[],
                'lines': {
                  'nodes': [
                    {
                      'quantity': 1,
                      'merchandise': {
                        'id': variantId,
                        'availableForSale': true,
                        'quantityAvailable': 1,
                      },
                      'discountAllocations': <dynamic>[],
                    },
                  ],
                },
              },
              'userErrors': <dynamic>[],
              'warnings': <dynamic>[],
            },
          },
        }),
        200,
      );
    });

    const item = CartItem(
      key: 'nizami',
      productId: 'gid://shopify/Product/1',
      productHandle: 'nizami-pearls-with-real-ruby-necklace-set',
      title: 'Nizami Pearls with Real Ruby Necklace Set',
      variantId: variantId,
      unitPrice: 31999,
      currencyCode: 'INR',
      quantity: 4,
      availableForSale: true,
    );

    expect(
      ShopifyStorefrontService(
        client: client,
      ).previewCartTotals(const [item], customerAccessToken: 'customer-token'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('requested quantity'),
        ),
      ),
    );
  });

  test('acceptsVariantQuantity allows Shopify CONTINUE inventory', () async {
    const variantId = 'gid://shopify/ProductVariant/50651354824842';
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['variables'], {
        'input': {
          'buyerIdentity': {'countryCode': 'IN'},
          'lines': [
            {'merchandiseId': variantId, 'quantity': 2},
          ],
        },
      });
      return http.Response(
        jsonEncode({
          'data': {
            'cartCreate': {
              'cart': {
                'lines': {
                  'nodes': [
                    {
                      'quantity': 2,
                      'merchandise': {
                        'id': variantId,
                        'availableForSale': true,
                      },
                    },
                  ],
                },
              },
              'warnings': <dynamic>[],
              'userErrors': <dynamic>[],
            },
          },
        }),
        200,
      );
    });
    const item = CartItem(
      key: 'nizami',
      productId: 'gid://shopify/Product/1',
      productHandle: 'nizami-pearls-with-real-ruby-necklace-set',
      title: 'Nizami Pearls with Real Ruby Necklace Set',
      variantId: variantId,
      unitPrice: 31999,
      currencyCode: 'INR',
      quantity: 1,
      availableForSale: true,
      quantityAvailable: 1,
    );

    expect(
      await ShopifyStorefrontService(client: client)
          .acceptsVariantQuantity(item, 2),
      isTrue,
    );
  });

  test(
    'previewCartTotals includes Shopify shipping and included tax',
    () async {
      const variantId = 'gid://shopify/ProductVariant/47311834808458';
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final variables = body['variables'] as Map<String, dynamic>;
        final input = variables['input'] as Map<String, dynamic>;
        expect(input['delivery'], {
          'addresses': [
            {
              'selected': true,
              'oneTimeUse': true,
              'address': {
                'deliveryAddress': {
                  'address1': 'Charminar',
                  'city': 'Hyderabad',
                  'provinceCode': 'TS',
                  'zip': '500001',
                  'countryCode': 'IN',
                },
              },
            },
          ],
        });
        return http.Response(
          jsonEncode({
            'data': {
              'cartCreate': {
                'cart': {
                  'cost': {
                    'subtotalAmount': {
                      'amount': '499.00',
                      'currencyCode': 'INR',
                    },
                    'totalAmount': {'amount': '699.00', 'currencyCode': 'INR'},
                  },
                  'discountCodes': <dynamic>[],
                  'discountApplications': <dynamic>[],
                  'deliveryGroups': {
                    'nodes': [
                      {
                        'selectedDeliveryOption': {
                          'title': 'Standard',
                          'estimatedCost': {
                            'amount': '200.00',
                            'currencyCode': 'INR',
                          },
                        },
                      },
                    ],
                  },
                  'lines': {
                    'nodes': [
                      {
                        'quantity': 1,
                        'merchandise': {
                          'id': variantId,
                          'availableForSale': true,
                          'quantityAvailable': 10,
                        },
                        'discountAllocations': <dynamic>[],
                      },
                    ],
                  },
                },
                'warnings': <dynamic>[],
                'userErrors': <dynamic>[],
              },
            },
          }),
          200,
        );
      });
      const item = CartItem(
        key: 'studs',
        productId: 'gid://shopify/Product/2',
        productHandle: 'beautiful-brown-pearl-studds',
        title: 'Beautiful Brown Pearl Studds',
        variantId: variantId,
        unitPrice: 499,
        currencyCode: 'INR',
        quantity: 1,
        availableForSale: true,
      );

      final summary = await ShopifyStorefrontService(client: client)
          .previewCartTotals(
            const [item],
            customerAccessToken: 'customer-token',
            deliveryAddress: const {
              'address1': 'Charminar',
              'city': 'Hyderabad',
              'provinceCode': 'TS',
              'zip': '500001',
              'countryCode': 'IN',
            },
          );

      expect(summary.shipping, 200);
      expect(summary.total, 699);
      expect(summary.discount, 0);
      expect(summary.includedTax, closeTo(14.53, 0.01));
    },
  );
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
