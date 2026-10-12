import '../models/home_catalog.dart';

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
