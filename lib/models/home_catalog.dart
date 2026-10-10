class HomeCatalogData {
  const HomeCatalogData({
    required this.collections,
    required this.priceCollections,
    required this.products,
  });

  final List<StorefrontCollection> collections;
  final List<StorefrontCollection> priceCollections;
  final List<StorefrontProduct> products;
}

class StorefrontCollection {
  const StorefrontCollection({
    required this.id,
    required this.handle,
    required this.title,
    this.imageUrl,
    this.imageAltText,
  });

  final String id;
  final String handle;
  final String title;
  final String? imageUrl;
  final String? imageAltText;

  factory StorefrontCollection.fromGraphQl(Map<String, dynamic> node) {
    final image = node['image'];
    final imageData = image is Map<String, dynamic> ? image : null;
    final products = node['products']?['nodes'];
    final firstProduct = products is List && products.isNotEmpty
        ? products.first
        : null;
    final fallbackImage = firstProduct is Map<String, dynamic>
        ? firstProduct['featuredImage']
        : null;
    final fallbackImageData = fallbackImage is Map<String, dynamic>
        ? fallbackImage
        : null;

    return StorefrontCollection(
      id: node['id']?.toString() ?? '',
      handle: node['handle']?.toString() ?? '',
      title: node['title']?.toString() ?? '',
      imageUrl:
          imageData?['url']?.toString() ??
          fallbackImageData?['url']?.toString(),
      imageAltText:
          imageData?['altText']?.toString() ??
          fallbackImageData?['altText']?.toString(),
    );
  }
}

class StorefrontProduct {
  const StorefrontProduct({
    required this.id,
    required this.handle,
    required this.title,
    required this.amount,
    required this.currencyCode,
    this.productType,
    this.imageUrl,
    this.imageAltText,
  });

  final String id;
  final String handle;
  final String title;
  final double amount;
  final String currencyCode;
  final String? productType;
  final String? imageUrl;
  final String? imageAltText;

  factory StorefrontProduct.fromGraphQl(Map<String, dynamic> node) {
    final image = node['featuredImage'];
    final imageData = image is Map<String, dynamic> ? image : null;
    final minimumPrice = node['priceRange']?['minVariantPrice'];
    final priceData = minimumPrice is Map<String, dynamic>
        ? minimumPrice
        : null;

    return StorefrontProduct(
      id: node['id']?.toString() ?? '',
      handle: node['handle']?.toString() ?? '',
      title: node['title']?.toString() ?? '',
      amount: double.tryParse(priceData?['amount']?.toString() ?? '') ?? 0,
      currencyCode: priceData?['currencyCode']?.toString() ?? 'INR',
      productType: _optionalString(node['productType']),
      imageUrl: _optionalString(imageData?['url']),
      imageAltText: _optionalString(imageData?['altText']),
    );
  }

  static String? _optionalString(Object? value) {
    final parsed = value?.toString().trim();
    return parsed == null || parsed.isEmpty ? null : parsed;
  }
}
