import 'package:flutter/material.dart';

import '../../models/home_catalog.dart';
import '../../services/shopify_storefront_service.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/storefront_bottom_navigation.dart';
import '../cart/cart_screen.dart';
import '../product/product_details_screen.dart';
import '../wishlist/wishlist_screen.dart';

const _categoryBrown = Color(0xff9d6043);
const _categoryText = Color(0xff574335);

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({required this.storefrontService, super.key});

  final ShopifyStorefrontService storefrontService;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<StorefrontCollection>> _collections;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _collections = widget.storefrontService.fetchCollections();
  }

  void _retry() {
    setState(() {
      _collections = widget.storefrontService.fetchCollections(
        forceRefresh: true,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffdfcfb),
      appBar: _catalogAppBar(context, 'Categories'),
      body: Column(
        children: [
          _CategorySearchBar(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            onClear: () {
              _searchController.clear();
              setState(() {});
            },
          ),
          Expanded(
            child: FutureBuilder<List<StorefrontCollection>>(
              future: _collections,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _CategoryGridShimmer();
                }
                if (snapshot.hasError) {
                  return _CatalogError(
                    message: 'Categories could not be loaded.',
                    onRetry: _retry,
                  );
                }
                final query = _searchController.text.trim().toLowerCase();
                final collections = (snapshot.data ?? const [])
                    .where(
                      (collection) =>
                          query.isEmpty ||
                          collection.title.toLowerCase().contains(query),
                    )
                    .toList(growable: false);
                if (collections.isEmpty) {
                  return _CatalogEmpty(
                    message: query.isEmpty
                        ? 'No categories found.'
                        : 'No category found for "${_searchController.text.trim()}".',
                  );
                }
                return RefreshIndicator(
                  color: _categoryBrown,
                  onRefresh: () async {
                    _retry();
                    await _collections;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                    itemCount: collections.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 15,
                          childAspectRatio: .88,
                        ),
                    itemBuilder: (context, index) {
                      final collection = collections[index];
                      return _CategoryCard(
                        collection: collection,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CollectionProductsScreen(
                              collection: collection,
                              storefrontService: widget.storefrontService,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: StorefrontBottomNavigation(
        selectedIndex: 1,
        onHome: () => Navigator.of(context).popUntil((route) => route.isFirst),
        onWishlist: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                WishlistScreen(storefrontService: widget.storefrontService),
          ),
        ),
        onCart: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                CartScreen(storefrontService: widget.storefrontService),
          ),
        ),
      ),
    );
  }
}

class _CategorySearchBar extends StatelessWidget {
  const _CategorySearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search categories',
          hintStyle: const TextStyle(color: Color(0xffb2a7a0)),
          prefixIcon: const Icon(Icons.search_rounded, color: _categoryBrown),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  color: _categoryText,
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xffeadfd7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: _categoryBrown, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class CollectionProductsScreen extends StatefulWidget {
  const CollectionProductsScreen({
    required this.collection,
    required this.storefrontService,
    super.key,
  });

  final StorefrontCollection collection;
  final ShopifyStorefrontService storefrontService;

  @override
  State<CollectionProductsScreen> createState() =>
      _CollectionProductsScreenState();
}

class _CollectionProductsScreenState extends State<CollectionProductsScreen> {
  late Future<List<StorefrontProduct>> _products;

  @override
  void initState() {
    super.initState();
    _products = _loadProducts();
  }

  Future<List<StorefrontProduct>> _loadProducts({bool forceRefresh = false}) {
    return widget.storefrontService.fetchCollectionProducts(
      widget.collection.handle,
      forceRefresh: forceRefresh,
    );
  }

  void _retry() {
    setState(() {
      _products = _loadProducts(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffdfcfb),
      appBar: _catalogAppBar(context, widget.collection.title),
      body: FutureBuilder<List<StorefrontProduct>>(
        future: _products,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ProductGridShimmer();
          }
          if (snapshot.hasError) {
            return _CatalogError(
              message: 'Products could not be loaded.',
              onRetry: _retry,
            );
          }
          final products = snapshot.data ?? const [];
          if (products.isEmpty) {
            return const _CatalogEmpty(
              message: 'No products available in this category.',
            );
          }
          return RefreshIndicator(
            color: _categoryBrown,
            onRefresh: () async {
              _retry();
              await _products;
            },
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: .68,
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                return _CollectionProductCard(
                  product: product,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailsScreen(
                        product: product,
                        storefrontService: widget.storefrontService,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

PreferredSizeWidget _catalogAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 1,
    leading: IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      color: _categoryText,
    ),
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _categoryText,
        fontFamily: 'Fraunces',
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.collection, required this.onTap});

  final StorefrontCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      elevation: 2,
      shadowColor: const Color(0x18000000),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: collection.imageUrl == null
                  ? const ColoredBox(
                      color: Color(0xfff5f0eb),
                      child: Icon(
                        Icons.diamond_outlined,
                        color: Color(0xffb99578),
                        size: 48,
                      ),
                    )
                  : ShimmerNetworkImage(
                      url: collection.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xfff5f0eb),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xffb99578),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      collection.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _categoryText,
                        fontFamily: 'Fraunces',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _categoryBrown,
                    size: 15,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionProductCard extends StatelessWidget {
  const _CollectionProductCard({required this.product, required this.onTap});

  final StorefrontProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compareAt = product.compareAtAmount;
    final onSale = compareAt != null && compareAt > product.amount;
    final discount = onSale
        ? (((compareAt - product.amount) / compareAt) * 100).round()
        : 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      elevation: 2,
      shadowColor: const Color(0x14000000),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: product.imageUrl == null
                          ? const ColoredBox(
                              color: Color(0xfff5f0eb),
                              child: Icon(Icons.diamond_outlined),
                            )
                          : ShimmerNetworkImage(
                              url: product.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                    if (onSale)
                      Positioned(
                        top: 7,
                        left: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _categoryBrown,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$discount% OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _categoryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _formatPrice(product.amount, product.currencyCode),
                    style: const TextStyle(
                      color: _categoryBrown,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (onSale)
                    Text(
                      _formatPrice(compareAt, product.currencyCode),
                      style: const TextStyle(
                        color: Color(0xff9a8f88),
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatPrice(double amount, String currency) {
    final value = amount.round().toString();
    return currency == 'INR' ? 'Rs $value' : '$currency $value';
  }
}

class _CategoryGridShimmer extends StatelessWidget {
  const _CategoryGridShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 15,
          childAspectRatio: .88,
        ),
        itemBuilder: (_, _) => const ShimmerBox(borderRadius: 15),
      ),
    );
  }
}

class _ProductGridShimmer extends StatelessWidget {
  const _ProductGridShimmer();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: .68,
        ),
        itemBuilder: (_, _) => const ShimmerBox(borderRadius: 13),
      ),
    );
  }
}

class _CatalogEmpty extends StatelessWidget {
  const _CatalogEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xff776e68), fontSize: 15),
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: _categoryBrown,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _categoryBrown),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
