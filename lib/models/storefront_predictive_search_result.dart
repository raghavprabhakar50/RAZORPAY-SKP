import 'home_catalog.dart';

class StorefrontPredictiveSearchResult {
  const StorefrontPredictiveSearchResult({
    required this.suggestions,
    required this.products,
  });

  static const empty = StorefrontPredictiveSearchResult(
    suggestions: <String>[],
    products: <StorefrontProduct>[],
  );

  final List<String> suggestions;
  final List<StorefrontProduct> products;

  bool get isEmpty => suggestions.isEmpty && products.isEmpty;
}
