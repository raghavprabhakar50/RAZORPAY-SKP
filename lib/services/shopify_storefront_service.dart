import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/shopify_config.dart';
import '../models/discount_banner.dart';
import '../models/home_catalog.dart';
import '../models/home_slide.dart';

class ShopifyStorefrontService {
  ShopifyStorefrontService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _cacheLifetime = Duration(minutes: 5);
  final Map<String, _StorefrontCacheEntry> _cache = {};
  final Map<String, Future<Object>> _inFlightRequests = {};

  static const _homeSlidesQuery = r'''
    query HomeSlides {
      metaobjects(type: "home_slider", first: 20) {
        nodes {
          handle
          title: field(key: "title") { value }
          subtitle: field(key: "subtitle") { value }
          buttonLabel: field(key: "button_label") { value }
          sortOrder: field(key: "sort_order") { value }
          active: field(key: "active") { value }
          image: field(key: "image") {
            reference {
              ... on MediaImage {
                image { url altText width height }
              }
            }
          }
          collection: field(key: "collection") {
            reference {
              ... on Collection {
                id
                handle
                title
                onlineStoreUrl
              }
            }
          }
        }
      }
    }
  ''';

  static const _homeCatalogQuery = r'''
    query HomeCatalog {
      collections(first: 50) {
        nodes {
          id
          handle
          title
          image { url altText }
          products(first: 1) {
            nodes { featuredImage { url altText } }
          }
        }
      }
      products(first: 12, sortKey: CREATED_AT, reverse: true) {
        nodes {
          id
          handle
          title
          productType
          featuredImage { url altText }
          priceRange {
            minVariantPrice { amount currencyCode }
          }
        }
      }
    }
  ''';

  static const _discountBannersQuery = r'''
    query DiscountBanners {
      metaobjects(type: "discount_banner", first: 20) {
        nodes {
          handle
          heading: field(key: "heading") { value }
          subtitle: field(key: "subtitle") { value }
          discountTitle: field(key: "discount_title") { value }
          discountId: field(key: "discount_id") { value }
          sortOrder: field(key: "sort_order") { value }
          active: field(key: "active") { value }
          showOverlay: field(key: "show_overlay") { value }
          startsAt: field(key: "starts_at") { value }
          endsAt: field(key: "ends_at") { value }
          image: field(key: "image") {
            reference {
              ... on MediaImage {
                image { url altText width height }
              }
            }
          }
        }
      }
    }
  ''';

  static const _homeContentQuery = r'''
    query HomeContent {
      homeSlides: metaobjects(type: "home_slider", first: 20) {
        nodes {
          handle
          title: field(key: "title") { value }
          subtitle: field(key: "subtitle") { value }
          buttonLabel: field(key: "button_label") { value }
          sortOrder: field(key: "sort_order") { value }
          active: field(key: "active") { value }
          image: field(key: "image") {
            reference {
              ... on MediaImage {
                image { url altText width height }
              }
            }
          }
          collection: field(key: "collection") {
            reference {
              ... on Collection {
                id
                handle
                title
                onlineStoreUrl
              }
            }
          }
        }
      }
      discountBanners: metaobjects(type: "discount_banner", first: 20) {
        nodes {
          handle
          heading: field(key: "heading") { value }
          subtitle: field(key: "subtitle") { value }
          discountTitle: field(key: "discount_title") { value }
          discountId: field(key: "discount_id") { value }
          sortOrder: field(key: "sort_order") { value }
          active: field(key: "active") { value }
          showOverlay: field(key: "show_overlay") { value }
          startsAt: field(key: "starts_at") { value }
          endsAt: field(key: "ends_at") { value }
          image: field(key: "image") {
            reference {
              ... on MediaImage {
                image { url altText width height }
              }
            }
          }
        }
      }
      collections(first: 50) {
        nodes {
          id
          handle
          title
          image { url altText }
          products(first: 1) {
            nodes { featuredImage { url altText } }
          }
        }
      }
      products(first: 12, sortKey: CREATED_AT, reverse: true) {
        nodes {
          id
          handle
          title
          productType
          featuredImage { url altText }
          priceRange {
            minVariantPrice { amount currencyCode }
          }
        }
      }
    }
  ''';

  static const _productDetailsQuery = r'''
    query ProductDetails($handle: String!) {
      product(handle: $handle) {
        id
        handle
        title
        description
        descriptionHtml
        productType
        shortDescription: metafield(
          namespace: "custom"
          key: "short_description"
        ) { value type }
        shortDescriptionRich: metafield(
          namespace: "custom"
          key: "short_description_rich"
        ) { value type }
        featuredImage { url altText }
        priceRange {
          minVariantPrice { amount currencyCode }
        }
        images(first: 10) {
          nodes { url altText }
        }
        media(first: 20) {
          nodes {
            __typename
            alt
            mediaContentType
            previewImage { url altText }
            ... on MediaImage {
              image { url altText }
            }
            ... on Video {
              sources { url mimeType format height width }
            }
          }
        }
        variants(first: 100) {
          nodes {
            id
            title
            availableForSale
            price { amount currencyCode }
            compareAtPrice { amount currencyCode }
            image { url altText }
            selectedOptions { name value }
          }
        }
      }
    }
  ''';

  static const _relatedProductsQuery = r'''
    query RelatedProducts($productId: ID!) {
      productRecommendations(productId: $productId) {
        id
        handle
        title
        productType
        featuredImage { url altText }
        priceRange {
          minVariantPrice { amount currencyCode }
        }
      }
    }
  ''';

  static const _collectionsQuery = r'''
    query Collections($after: String) {
      collections(first: 50, after: $after, sortKey: TITLE) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          handle
          title
          image { url altText }
          products(first: 1) {
            nodes { featuredImage { url altText } }
          }
        }
      }
    }
  ''';

  static const _collectionProductsQuery = r'''
    query CollectionProducts($handle: String!, $after: String) {
      collection(handle: $handle) {
        id
        handle
        title
        products(first: 50, after: $after, sortKey: BEST_SELLING) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            handle
            title
            productType
            featuredImage { url altText }
            priceRange {
              minVariantPrice { amount currencyCode }
            }
            variants(first: 1) {
              nodes {
                id
                title
                availableForSale
                price { amount currencyCode }
                compareAtPrice { amount currencyCode }
                image { url altText }
                selectedOptions { name value }
              }
            }
          }
        }
      }
    }
  ''';

  Future<HomeStorefrontContent> fetchHomeContent({bool forceRefresh = false}) {
    return _cached('home-content', () async {
      final payload = await _postGraphQl(_homeContentQuery);
      return HomeStorefrontContent(
        slides: _parseHomeSlides(payload, connectionKey: 'homeSlides'),
        catalog: _parseHomeCatalog(payload),
        discountBanners: _parseDiscountBanners(
          payload,
          connectionKey: 'discountBanners',
        ),
      );
    }, forceRefresh: forceRefresh);
  }

  Future<List<HomeSlide>> fetchHomeSlides({bool forceRefresh = false}) {
    return _cached('home-slides', () async {
      final payload = await _postGraphQl(_homeSlidesQuery);
      return _parseHomeSlides(payload);
    }, forceRefresh: forceRefresh);
  }

  List<HomeSlide> _parseHomeSlides(
    Map<String, dynamic> payload, {
    String connectionKey = 'metaobjects',
  }) {
    final nodes = payload['data']?[connectionKey]?['nodes'];
    if (nodes is! List) {
      throw const ShopifyStorefrontException(
        'Shopify returned an invalid home slider response.',
      );
    }

    final slides =
        nodes
            .whereType<Map<String, dynamic>>()
            .map(HomeSlide.fromGraphQl)
            .where((slide) => slide.active)
            .toList()
          ..sort(
            (first, second) => first.sortOrder.compareTo(second.sortOrder),
          );

    return List.unmodifiable(slides);
  }

  Future<HomeCatalogData> fetchHomeCatalog({bool forceRefresh = false}) {
    return _cached('home-catalog', () async {
      final payload = await _postGraphQl(_homeCatalogQuery);
      return _parseHomeCatalog(payload);
    }, forceRefresh: forceRefresh);
  }

  HomeCatalogData _parseHomeCatalog(Map<String, dynamic> payload) {
    final collectionNodes = payload['data']?['collections']?['nodes'];
    final productNodes = payload['data']?['products']?['nodes'];
    if (collectionNodes is! List || productNodes is! List) {
      throw const ShopifyStorefrontException(
        'Shopify returned an invalid home catalog response.',
      );
    }

    final allCollections = collectionNodes
        .whereType<Map<String, dynamic>>()
        .map(StorefrontCollection.fromGraphQl)
        .where(
          (collection) =>
              collection.handle != 'frontpage' &&
              collection.handle != 'uncategorized',
        )
        .toList(growable: false);
    final matchingPriceCollections =
        allCollections.where(_isPriceCollection).toList()..sort(
          (first, second) =>
              _priceCollectionOrder(first)
                  .compareTo(_priceCollectionOrder(second)),
        );
    final priceCollections = matchingPriceCollections
        .take(4)
        .toList(growable: false);
    final collections = allCollections
        .where(
          (collection) =>
              !_isPriceCollection(collection) && collection.imageUrl != null,
        )
        .take(10)
        .toList(growable: false);
    final products = productNodes
        .whereType<Map<String, dynamic>>()
        .map(StorefrontProduct.fromGraphQl)
        .toList(growable: false);

    return HomeCatalogData(
      collections: collections,
      priceCollections: priceCollections,
      products: products,
    );
  }

  Future<List<DiscountBanner>> fetchDiscountBanners({
    DateTime? now,
    bool forceRefresh = false,
  }) {
    final cacheKey = now == null
        ? 'discount-banners'
        : 'discount-banners-${now.toIso8601String()}';
    return _cached(cacheKey, () async {
      final payload = await _postGraphQl(_discountBannersQuery);
      return _parseDiscountBanners(payload, now: now);
    }, forceRefresh: forceRefresh);
  }

  List<DiscountBanner> _parseDiscountBanners(
    Map<String, dynamic> payload, {
    DateTime? now,
    String connectionKey = 'metaobjects',
  }) {
    final nodes = payload['data']?[connectionKey]?['nodes'];
    if (nodes is! List) {
      throw const ShopifyStorefrontException(
        'Shopify returned an invalid discount banner response.',
      );
    }

    final currentTime = now ?? DateTime.now();
    final banners =
        nodes
            .whereType<Map<String, dynamic>>()
            .map(DiscountBanner.fromGraphQl)
            .where((banner) => banner.isVisibleAt(currentTime))
            .toList()
          ..sort(
            (first, second) => first.sortOrder.compareTo(second.sortOrder),
          );
    return List.unmodifiable(banners);
  }

  Future<StorefrontProduct> fetchProduct(String handle) {
    return _cached('product:$handle', () async {
      final payload = await _postGraphQl(
        _productDetailsQuery,
        variables: {'handle': handle},
      );
      final product = payload['data']?['product'];
      if (product is! Map<String, dynamic>) {
        throw const ShopifyStorefrontException(
          'This Shopify product could not be found.',
        );
      }
      return StorefrontProduct.fromGraphQl(product);
    });
  }

  Future<List<StorefrontProduct>> fetchRelatedProducts(String productId) {
    return _cached('related-products:$productId', () async {
      final payload = await _postGraphQl(
        _relatedProductsQuery,
        variables: {'productId': productId},
      );
      final nodes = payload['data']?['productRecommendations'];
      if (nodes is! List) return const <StorefrontProduct>[];
      return List.unmodifiable(
        nodes.whereType<Map<String, dynamic>>().map(
          StorefrontProduct.fromGraphQl,
        ),
      );
    });
  }

  Future<List<StorefrontCollection>> fetchCollections({
    bool forceRefresh = false,
  }) {
    return _cached('collections', () async {
      final collections = <String, StorefrontCollection>{};
      String? cursor;
      var page = 0;

      do {
        final payload = await _postGraphQl(
          _collectionsQuery,
          variables: {'after': cursor},
        );
        final connection = payload['data']?['collections'];
        final nodes = connection?['nodes'];
        final pageInfo = connection?['pageInfo'];
        if (nodes is! List || pageInfo is! Map<String, dynamic>) {
          throw const ShopifyStorefrontException(
            'Shopify returned an invalid collections response.',
          );
        }

        for (final node in nodes.whereType<Map<String, dynamic>>()) {
          final collection = StorefrontCollection.fromGraphQl(node);
          if (collection.handle.isEmpty ||
              collection.handle == 'frontpage' ||
              collection.handle == 'uncategorized') {
            continue;
          }
          collections[collection.handle] = collection;
        }

        final hasNextPage = pageInfo['hasNextPage'] == true;
        cursor = hasNextPage ? pageInfo['endCursor']?.toString() : null;
        if (hasNextPage && (cursor == null || cursor.isEmpty)) {
          throw const ShopifyStorefrontException(
            'Shopify collections pagination could not continue.',
          );
        }
        page++;
        if (page >= 20) cursor = null;
      } while (cursor != null);

      final result = collections.values.toList()
        ..sort((first, second) {
          final firstIsAll = _isAllProductsCollection(first);
          final secondIsAll = _isAllProductsCollection(second);
          if (firstIsAll != secondIsAll) return firstIsAll ? -1 : 1;
          return first.title.toLowerCase().compareTo(
            second.title.toLowerCase(),
          );
        });
      return List.unmodifiable(result);
    }, forceRefresh: forceRefresh);
  }

  Future<List<StorefrontProduct>> fetchCollectionProducts(
    String collectionHandle, {
    bool forceRefresh = false,
  }) {
    return _cached('collection-products:$collectionHandle', () async {
      final products = <String, StorefrontProduct>{};
      String? cursor;
      var page = 0;

      do {
        final payload = await _postGraphQl(
          _collectionProductsQuery,
          variables: {'handle': collectionHandle, 'after': cursor},
        );
        final collection = payload['data']?['collection'];
        if (collection is! Map<String, dynamic>) {
          throw const ShopifyStorefrontException(
            'This Shopify collection could not be found.',
          );
        }
        final connection = collection['products'];
        final nodes = connection?['nodes'];
        final pageInfo = connection?['pageInfo'];
        if (nodes is! List || pageInfo is! Map<String, dynamic>) {
          throw const ShopifyStorefrontException(
            'Shopify returned an invalid collection products response.',
          );
        }

        for (final node in nodes.whereType<Map<String, dynamic>>()) {
          final product = StorefrontProduct.fromGraphQl(node);
          if (product.handle.isNotEmpty) products[product.handle] = product;
        }

        final hasNextPage = pageInfo['hasNextPage'] == true;
        cursor = hasNextPage ? pageInfo['endCursor']?.toString() : null;
        if (hasNextPage && (cursor == null || cursor.isEmpty)) {
          throw const ShopifyStorefrontException(
            'Shopify products pagination could not continue.',
          );
        }
        page++;
        if (page >= 20) cursor = null;
      } while (cursor != null);

      return List.unmodifiable(products.values);
    }, forceRefresh: forceRefresh);
  }

  static bool _isPriceCollection(StorefrontCollection collection) {
    final value = '${collection.title} ${collection.handle}'.toLowerCase();
    final hasPriceDirection =
        value.contains('under') ||
        value.contains('above') ||
        value.contains('below') ||
        value.contains('between') ||
        value.contains(' to ') ||
        value.contains('-to-');
    final hasNumber = RegExp(r'\d').hasMatch(value);
    return hasPriceDirection && hasNumber;
  }

  static bool _isAllProductsCollection(StorefrontCollection collection) {
    final handle = collection.handle.toLowerCase();
    final title = collection.title.trim().toLowerCase();
    return handle == 'all-products' || title == 'all products';
  }

  static int _priceCollectionOrder(StorefrontCollection collection) {
    final value = '${collection.title} ${collection.handle}'.toLowerCase();
    if (value.contains('under') || value.contains('below')) return 0;
    final number = RegExp(r'[\d,]+').firstMatch(value)?.group(0);
    return int.tryParse(number?.replaceAll(',', '') ?? '') ?? 999999999;
  }

  Future<T> _cached<T>(
    String key,
    Future<T> Function() loader, {
    bool forceRefresh = false,
  }) {
    final now = DateTime.now();
    final cached = _cache[key];
    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.createdAt) < _cacheLifetime) {
      return Future<T>.value(cached.value as T);
    }

    final inFlight = _inFlightRequests[key];
    if (!forceRefresh && inFlight != null) {
      return inFlight.then((value) => value as T);
    }

    late final Future<Object> request;
    request = loader()
        .then<Object>((value) {
          _cache[key] = _StorefrontCacheEntry(
            value: value as Object,
            createdAt: DateTime.now(),
          );
          return value as Object;
        })
        .whenComplete(() {
          if (identical(_inFlightRequests[key], request)) {
            _inFlightRequests.remove(key);
          }
        });
    _inFlightRequests[key] = request;
    return request.then((value) => value as T);
  }

  Future<Map<String, dynamic>> _postGraphQl(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    final response = await _client.post(
      Uri.parse(ShopifyConfig.storefrontEndpoint),
      headers: const {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token':
            ShopifyConfig.storefrontAccessToken,
      },
      body: jsonEncode({
        'query': query,
        'variables': variables ?? const <String, dynamic>{},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ShopifyStorefrontException(
        'Shopify Storefront request failed (${response.statusCode}).',
      );
    }

    final payload = _decodePayload(response.body);
    final errors = payload['errors'];
    if (errors is List && errors.isNotEmpty) {
      final firstError = errors.first;
      final message = firstError is Map<String, dynamic>
          ? firstError['message']?.toString()
          : null;
      throw ShopifyStorefrontException(
        message ?? 'Shopify returned a GraphQL error.',
      );
    }

    return payload;
  }

  static Map<String, dynamic> _decodePayload(String body) {
    try {
      final payload = jsonDecode(body);
      if (payload is Map<String, dynamic>) return payload;
    } on FormatException {
      // A consistent domain exception is thrown below.
    }
    throw const ShopifyStorefrontException(
      'Shopify returned an unreadable response.',
    );
  }
}

class HomeStorefrontContent {
  const HomeStorefrontContent({
    required this.slides,
    required this.catalog,
    required this.discountBanners,
  });

  final List<HomeSlide> slides;
  final HomeCatalogData catalog;
  final List<DiscountBanner> discountBanners;
}

class _StorefrontCacheEntry {
  const _StorefrontCacheEntry({required this.value, required this.createdAt});

  final Object value;
  final DateTime createdAt;
}

class ShopifyStorefrontException implements Exception {
  const ShopifyStorefrontException(this.message);

  final String message;

  @override
  String toString() => message;
}
