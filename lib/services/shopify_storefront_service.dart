import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/shopify_config.dart';
import '../models/home_catalog.dart';
import '../models/home_slide.dart';

class ShopifyStorefrontService {
  ShopifyStorefrontService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

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

  Future<List<HomeSlide>> fetchHomeSlides() async {
    final payload = await _postGraphQl(_homeSlidesQuery);
    final nodes = payload['data']?['metaobjects']?['nodes'];
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

  Future<HomeCatalogData> fetchHomeCatalog() async {
    final payload = await _postGraphQl(_homeCatalogQuery);
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

  static int _priceCollectionOrder(StorefrontCollection collection) {
    final value = '${collection.title} ${collection.handle}'.toLowerCase();
    if (value.contains('under') || value.contains('below')) return 0;
    final number = RegExp(r'[\d,]+').firstMatch(value)?.group(0);
    return int.tryParse(number?.replaceAll(',', '') ?? '') ?? 999999999;
  }

  Future<Map<String, dynamic>> _postGraphQl(String query) async {
    final response = await _client.post(
      Uri.parse(ShopifyConfig.storefrontEndpoint),
      headers: const {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token':
            ShopifyConfig.storefrontAccessToken,
      },
      body: jsonEncode({'query': query}),
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

class ShopifyStorefrontException implements Exception {
  const ShopifyStorefrontException(this.message);

  final String message;

  @override
  String toString() => message;
}
