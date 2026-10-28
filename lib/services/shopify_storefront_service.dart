import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/shopify_config.dart';
import '../data/home_catalog_data.dart';
import '../data/home_storefront_content.dart';
import '../models/discount_banner.dart';
import '../models/cart_item.dart';
import '../models/checkout_coupon.dart';
import '../models/home_catalog.dart';
import '../models/home_slide.dart';
import '../models/storefront_predictive_search_result.dart';
import 'shopify_auth_service.dart';

class ShopifyStorefrontService {
  ShopifyStorefrontService({
    http.Client? client,
    Future<String> Function()? checkoutTokenProvider,
  }) : _client = client ?? http.Client(),
       _checkoutToken =
           checkoutTokenProvider ?? ShopifyAuthService().checkoutAccessToken;

  final http.Client _client;
  final Future<String> Function() _checkoutToken;

  /// Evaluate public codes directly with Shopify on an isolated cart. Does not
  /// create an order/payment or alter the cart later opened by checkout.
  Future<List<CheckoutCoupon>> checkCouponEligibility(
    List<CartItem> items,
    List<CheckoutCoupon> coupons,
  ) async {
    if (coupons.isEmpty) return const [];
    if (items.isEmpty ||
        items.length > 50 ||
        coupons.length > 100 ||
        items.any(
          (i) =>
              !RegExp(r'^gid://shopify/ProductVariant/[1-9][0-9]*$')
                  .hasMatch(i.variantId ?? '') ||
              !i.availableForSale ||
              i.quantity < 1 ||
              i.quantity > 20,
        )) {
      throw StateError('Refresh your cart before checking coupons.');
    }
    final expected = <String, int>{};
    for (final item in items) {
      expected.update(
        item.variantId!,
        (q) => q + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    if (expected.values.any((q) => q > 20)) {
      throw StateError('Maximum quantity is 20 per variant.');
    }
    final token = await _checkoutToken();
    if (token.isEmpty) throw StateError('Please sign in again.');
    final response = await _postGraphQl(
      r'''
      mutation CouponCheckCart($input: CartInput!) {
        cartCreate(input: $input) {
          cart { id lines(first: 100) { nodes { quantity merchandise { ... on ProductVariant { id availableForSale } } } } }
          userErrors { message } warnings { code message }
        }
      }
    ''',
      variables: {
        'input': {
          'buyerIdentity': {'customerAccessToken': token, 'countryCode': 'IN'},
          'lines': items
              .map(
                (i) => {
                  'merchandiseId': i.variantId,
                  'quantity': i.quantity,
                  'attributes': [
                    if (i.giftCard != 'Not Required')
                      {'key': 'Gift Card', 'value': i.giftCard},
                    if (i.giftMessage.trim().isNotEmpty)
                      {'key': 'Gift Message', 'value': i.giftMessage.trim()},
                  ],
                },
              )
              .toList(),
        },
      },
    ).timeout(const Duration(seconds: 25));
    final result = response['data']?['cartCreate'];
    const rejectionWarnings = {
      'DISCOUNT_CODE_NOT_HONOURED',
      'DISCOUNT_CURRENTLY_INACTIVE',
      'DISCOUNT_CUSTOMER_NOT_ELIGIBLE',
      'DISCOUNT_CUSTOMER_USAGE_LIMIT_REACHED',
      'DISCOUNT_INCOMPATIBLE_PURCHASE_TYPE',
      'DISCOUNT_NO_ENTITLED_LINE_ITEMS',
      'DISCOUNT_NO_ENTITLED_SHIPPING_LINES',
      'DISCOUNT_NOT_FOUND',
      'DISCOUNT_PURCHASE_NOT_IN_RANGE',
      'DISCOUNT_QUANTITY_NOT_IN_RANGE',
      'DISCOUNT_USAGE_LIMIT_REACHED',
    };
    bool valid(dynamic r, {bool discountCheck = false}) =>
        r is Map &&
        r['cart'] is Map &&
        (r['userErrors'] as List?)?.isNotEmpty != true &&
        ((r['warnings'] as List?) ?? []).every(
          (warning) =>
              discountCheck &&
              warning is Map &&
              rejectionWarnings.contains(warning['code']),
        );
    if (!valid(result) ||
        result['cart']['id'] is! String ||
        result['cart']['lines']?['nodes'] is! List) {
      throw StateError('Refresh your cart before checking coupons.');
    }
    final actual = <String, int>{};
    for (final line in result['cart']['lines']['nodes']) {
      final variant = line['merchandise'];
      if (variant is! Map ||
          variant['id'] is! String ||
          variant['availableForSale'] != true ||
          line['quantity'] is! int) {
        throw StateError('An item is unavailable. Refresh your cart.');
      }
      actual.update(
        variant['id'] as String,
        (q) => q + (line['quantity'] as int),
        ifAbsent: () => line['quantity'] as int,
      );
    }
    if (actual.length != expected.length ||
        expected.entries.any((e) => actual[e.key] != e.value)) {
      throw StateError(
        'Cart quantity changed. Refresh before checking coupons.',
      );
    }
    final checked = <CheckoutCoupon>[];
    final watch = Stopwatch()..start();
    for (var start = 0; start < coupons.length; start += 10) {
      if (watch.elapsed > const Duration(seconds: 25)) {
        throw StateError('Coupon checks timed out. Please retry.');
      }
      final batch = coupons.skip(start).take(10).toList();
      final variables = <String, dynamic>{'id': result['cart']['id']};
      final definitions = <String>[r'$id: ID!'];
      final fields = <String>[];
      for (var i = 0; i < batch.length; i++) {
        definitions.add('\$c$i: [String!]!');
        variables['c$i'] = [batch[i].code];
        fields.add(
          'c$i: cartDiscountCodesUpdate(cartId: \$id, discountCodes: \$c$i) { cart { discountCodes { code applicable } } userErrors { message } warnings { code message } }',
        );
      }
      // Each top-level mutation replaces the prior code on this temporary cart,
      // so incompatible coupon combinations do not produce false negatives.
      final data = await _postGraphQl(
        'mutation CheckCartCoupons(${definitions.join(',')}) { ${fields.join(' ')} }',
        variables: variables,
      ).timeout(const Duration(seconds: 25));
      for (var i = 0; i < batch.length; i++) {
        final row = data['data']?['c$i'];
        if (!valid(row, discountCheck: true) ||
            row['cart']['discountCodes'] is! List) {
          throw StateError('Could not verify coupons. Please retry.');
        }
        bool? applies;
        for (final code in row['cart']['discountCodes']) {
          if (code is Map &&
              code['code'] is String &&
              (code['code'] as String).toUpperCase() ==
                  batch[i].code.toUpperCase() &&
              code['applicable'] is bool) {
            applies = code['applicable'] as bool;
          }
        }
        if (applies == null) {
          throw StateError(
            'Shopify did not confirm coupon eligibility. Please retry.',
          );
        }
        if (applies && (row['warnings'] as List?)?.isNotEmpty == true) {
          throw StateError('Coupon eligibility changed. Please retry.');
        }
        checked.add(
          CheckoutCoupon(
            code: batch[i].code,
            title: batch[i].title,
            description: batch[i].description,
            applicable: applies,
            eligibilityMessage: applies ? 'Available for this cart' : 'Not applicable to this cart. Check minimum purchase and eligible products.',
          ),
        );
      }
    }
    return List.unmodifiable(checked);
  }

  Future<List<CheckoutCoupon>> fetchCheckoutCoupons() =>
      _cached('checkout-coupons', () async {
        try {
          final payload = await _postGraphQl(r'''
        query PublicCheckoutCoupons {
          metaobjects(type: "discount_banner", first: 100, sortKey: "id", reverse: true) {
            nodes {
              code: field(key: "coupon_code") { value }
              heading: field(key: "heading") { value }
              subtitle: field(key: "subtitle") { value }
              active: field(key: "active") { value }
              startsAt: field(key: "starts_at") { value }
              endsAt: field(key: "ends_at") { value }
            }
          }
        }
      ''').timeout(const Duration(seconds: 12));
          final nodes = payload['data']?['metaobjects']?['nodes'];
          final coupons = CheckoutCoupon.published(
            nodes is List ? nodes : [],
            DateTime.now(),
          );
          return coupons.isEmpty ? CheckoutCoupon.publicFallback : coupons;
        } catch (_) {
          return CheckoutCoupon.publicFallback;
        }
      });

  /// Online Store cart, not Storefront API checkoutUrl. This loads the merchant
  /// theme and its existing Magic Checkout button. No customer token in URL.
  static Uri websiteCartUrl(List<CartItem> items, {String orderNote = ''}) {
    final note = normalizeOrderNote(orderNote);
    if (items.isEmpty || items.length > 50) {
      throw StateError('Add between 1 and 50 items before checkout.');
    }
    final quantities = <String, int>{};
    Map<String, String>? firstProperties;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final match = RegExp(r'^gid://shopify/ProductVariant/([1-9][0-9]{0,24})$')
          .firstMatch(item.variantId ?? '');
      if (match == null ||
          !item.availableForSale ||
          item.quantity < 1 ||
          item.quantity > 20) {
        throw StateError('An item is unavailable. Refresh your cart.');
      }
      final variant = match.group(1)!;
      final properties = <String, String>{
        if (item.giftCard != 'Not Required') 'Gift Card': item.giftCard,
        if (item.giftMessage.trim().isNotEmpty)
          'Gift Message': item.giftMessage.trim(),
      };
      // Shopify permalinks support properties on the FIRST product only.
      // Never silently drop gift instructions or merge differently gifted lines.
      if ((index != 0 && properties.isNotEmpty) ||
          (quantities.containsKey(variant) && firstProperties != null)) {
        throw UnsupportedError(
          'This gift cart requires the authenticated Shopify checkout.',
        );
      }
      if (properties.values.any((v) => v.length > 500)) {
        throw StateError('Gift instructions are too long.');
      }
      if (index == 0 && properties.isNotEmpty) firstProperties = properties;
      quantities.update(
        variant,
        (q) => q + item.quantity,
        ifAbsent: () => item.quantity,
      );
      if (quantities[variant]! > 20) {
        throw StateError('Maximum quantity is 20 per variant.');
      }
    }
    final host = ShopifyConfig.storefrontDomain;
    if (host.isEmpty ||
        host.contains('/') ||
        host.contains('@') ||
        host.contains(':')) {
      throw StateError('Storefront address is not configured.');
    }
    final uri = Uri.https(
      host,
      '/cart/${quantities.entries.map((e) => '${e.key}:${e.value}').join(',')}',
      {
        'storefront': 'true',
        if (note.isNotEmpty) 'note': note,
        if (firstProperties != null)
          'properties': base64Url.encode(
            utf8.encode(jsonEncode(firstProperties)),
          ),
      },
    );
    if (uri.toString().length > 7500) {
      throw UnsupportedError('This cart requires Shopify checkout.');
    }
    return uri;
  }

  static String normalizeOrderNote(String value) {
    final note = value.trim();
    if (note.length > 1000 || note.contains('\u0000')) {
      throw StateError('Enter order instructions under 1000 characters.');
    }
    return note;
  }

  /// Uses the existing Shopify hosted checkout and its configured payment apps.
  /// Never creates a middleware draft/Razorpay order or accepts local prices.
  Future<Uri> createWebCheckout(
    List<CartItem> items, {
    required String customerAccessToken,
    String discountCode = '',
    String orderNote = '',
  }) async {
    final note = normalizeOrderNote(orderNote);
    if (customerAccessToken.isEmpty ||
        items.isEmpty ||
        items.length > 50 ||
        items.any(
          (i) =>
              i.variantId == null ||
              !RegExp(r'^gid://shopify/ProductVariant/[1-9][0-9]*$')
                  .hasMatch(i.variantId!) ||
              !i.availableForSale ||
              i.quantity < 1 ||
              i.quantity > 20,
        )) {
      throw StateError('Refresh your cart and sign in before checkout.');
    }
    final response = await _postGraphQl(
      r'''
      mutation AppWebCheckout($input: CartInput!) {
        cartCreate(input: $input) {
          cart {
            checkoutUrl
            discountCodes { code applicable }
            lines(first: 100) { nodes { quantity merchandise { ... on ProductVariant { id availableForSale } } } }
          }
          userErrors { message }
          warnings { message }
        }
      }
    ''',
      variables: {
        'input': {
          if (note.isNotEmpty) 'note': note,
          'buyerIdentity': {
            'customerAccessToken': customerAccessToken,
            'countryCode': 'IN',
          },
          'discountCodes': [
            if (discountCode.trim().isNotEmpty) discountCode.trim(),
          ],
          'lines': items
              .map(
                (i) => {
                  'merchandiseId': i.variantId,
                  'quantity': i.quantity,
                  'attributes': [
                    if (i.giftCard != 'Not Required')
                      {'key': 'Gift Card', 'value': i.giftCard},
                    if (i.giftMessage.trim().isNotEmpty)
                      {'key': 'Gift Message', 'value': i.giftMessage.trim()},
                  ],
                },
              )
              .toList(),
        },
      },
    ).timeout(const Duration(seconds: 35));
    final result = response['data']?['cartCreate'];
    if (result is! Map ||
        (result['userErrors'] as List?)?.isNotEmpty == true ||
        (result['warnings'] as List?)?.isNotEmpty == true ||
        result['cart'] is! Map) {
      throw StateError(
        'Shopify could not prepare every item. Review stock and your coupon.',
      );
    }
    final cart = result['cart'] as Map;
    final expected = <String, int>{};
    for (final i in items) {
      expected.update(
        i.variantId!,
        (q) => q + i.quantity,
        ifAbsent: () => i.quantity,
      );
    }
    final actual = <String, int>{};
    for (final line in cart['lines']['nodes'] as List) {
      final variant = line['merchandise'];
      if (variant['availableForSale'] != true) {
        throw StateError('An item is unavailable. Refresh your cart.');
      }
      actual.update(
        variant['id'] as String,
        (q) => q + (line['quantity'] as int),
        ifAbsent: () => line['quantity'] as int,
      );
    }
    if (actual.length != expected.length ||
        expected.entries.any((e) => actual[e.key] != e.value) ||
        (cart['discountCodes'] as List).any((c) => c['applicable'] != true)) {
      throw StateError(
        'Cart quantity or coupon changed. Please review before paying.',
      );
    }
    final uri = Uri.tryParse(cart['checkoutUrl']?.toString() ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        !{
          ShopifyConfig.shopDomain,
          ShopifyConfig.storefrontDomain,
          'srikrishnapearls.com',
          'checkout.shopify.com',
        }.contains(uri.host)) {
      throw StateError('Shopify returned an unexpected checkout address.');
    }
    return uri;
  }

  /// Prices the same cart shape Shopify will open in hosted checkout. This
  /// includes automatic discounts and the selected public code, while keeping
  /// shipping separate because it is calculated at checkout.
  Future<CheckoutPriceSummary> previewCartTotals(
    List<CartItem> items, {
    required String customerAccessToken,
    String discountCode = '',
  }) async {
    if (customerAccessToken.isEmpty || items.isEmpty) {
      throw StateError('Refresh your cart and sign in before pricing.');
    }
    final response = await _postGraphQl(
      r'''
      mutation PreviewCartTotals($input: CartInput!) {
        cartCreate(input: $input) {
          cart {
            cost {
              subtotalAmount { amount currencyCode }
              totalAmount { amount currencyCode }
            }
            discountCodes { code applicable }
            discountApplications {
              __typename
              ... on CartAutomaticDiscountApplication { title }
            }
            lines(first: 100) {
              nodes {
                discountAllocations {
                  __typename
                  ... on CartAutomaticDiscountAllocation { title }
                }
              }
            }
          }
          userErrors { message }
          warnings { code message }
        }
      }
    ''',
      variables: {
        'input': {
          'buyerIdentity': {
            'customerAccessToken': customerAccessToken,
            'countryCode': 'IN',
          },
          'discountCodes': [
            if (discountCode.trim().isNotEmpty) discountCode.trim(),
          ],
          'lines': items
              .map(
                (i) => {'merchandiseId': i.variantId, 'quantity': i.quantity},
              )
              .toList(),
        },
      },
    ).timeout(const Duration(seconds: 25));
    final result = response['data']?['cartCreate'];
    final cart = result is Map ? result['cart'] : null;
    final errors = result is Map ? result['userErrors'] as List? : null;
    if (cart is! Map || errors?.isNotEmpty == true) {
      throw StateError('Shopify could not calculate this cart total.');
    }
    final cost = cart['cost'];
    final subtotal = cost is Map ? cost['subtotalAmount'] : null;
    final total = cost is Map ? cost['totalAmount'] : null;
    if (subtotal is! Map || total is! Map) {
      throw StateError('Shopify returned an incomplete cart total.');
    }
    final subtotalValue = double.tryParse(subtotal['amount']?.toString() ?? '');
    final totalValue = double.tryParse(total['amount']?.toString() ?? '');
    final currency = total['currencyCode']?.toString() ?? '';
    if (subtotalValue == null || totalValue == null || currency.isEmpty) {
      throw StateError('Shopify returned an invalid cart total.');
    }
    final automaticTitles = <String>{};
    final applications = cart['discountApplications'];
    if (applications is List) {
      for (final application in applications) {
        if (application is Map &&
            application['__typename'].toString().contains(
              'AutomaticDiscountApplication',
            )) {
          final title = application['title']?.toString().trim() ?? '';
          if (title.isNotEmpty) automaticTitles.add(title);
        }
      }
    }
    final lines = cart['lines'];
    if (lines is Map && lines['nodes'] is List) {
      for (final line in lines['nodes']) {
        final allocations = line is Map ? line['discountAllocations'] : null;
        if (allocations is List) {
          for (final allocation in allocations) {
            if (allocation is Map &&
                allocation['__typename'].toString().contains(
                  'AutomaticDiscountAllocation',
                )) {
              final title = allocation['title']?.toString().trim() ?? '';
              if (title.isNotEmpty) automaticTitles.add(title);
            }
          }
        }
      }
    }
    return CheckoutPriceSummary(
      subtotal: subtotalValue,
      discount: (subtotalValue - totalValue).clamp(0, double.infinity),
      total: totalValue,
      currencyCode: currency,
      discountCodes: [
        for (final row in (cart['discountCodes'] as List? ?? const []))
          if (row is Map && row['applicable'] == true) row['code'].toString(),
      ],
      automaticDiscountTitle: automaticTitles.isEmpty
          ? null
          : automaticTitles.join(', '),
    );
  }

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

  static const _predictiveSearchQuery = r'''
    query PredictiveSearch($query: String!) {
      predictiveSearch(
        query: $query
        limit: 6
        limitScope: EACH
        types: [QUERY, PRODUCT]
        unavailableProducts: HIDE
      ) {
        queries { text }
        products {
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

  Future<StorefrontPredictiveSearchResult> predictiveSearch(String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return Future.value(StorefrontPredictiveSearchResult.empty);
    }

    return _cached(
      'predictive-search:${normalizedQuery.toLowerCase()}',
      () async {
        final payload = await _postGraphQl(
          _predictiveSearchQuery,
          variables: {'query': normalizedQuery},
        );
        final result = payload['data']?['predictiveSearch'];
        if (result is! Map<String, dynamic>) {
          throw const ShopifyStorefrontException(
            'Shopify returned an invalid search response.',
          );
        }

        final queryNodes = result['queries'];
        final productNodes = result['products'];
        final suggestions = queryNodes is List
            ? queryNodes
                  .whereType<Map<String, dynamic>>()
                  .map((node) => node['text']?.toString().trim() ?? '')
                  .where((text) => text.isNotEmpty)
                  .toSet()
                  .toList(growable: false)
            : const <String>[];
        final products = productNodes is List
            ? productNodes
                  .whereType<Map<String, dynamic>>()
                  .map(StorefrontProduct.fromGraphQl)
                  .where((product) => product.handle.isNotEmpty)
                  .toList(growable: false)
            : const <StorefrontProduct>[];

        return StorefrontPredictiveSearchResult(
          suggestions: suggestions,
          products: products,
        );
      },
    );
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
