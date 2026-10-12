import 'package:flutter/material.dart';

import '../../services/shopping_store.dart';
import '../../services/shopify_storefront_service.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/storefront_bottom_navigation.dart';
import '../cart/cart_screen.dart';
import '../category/categories_screen.dart';
import '../product/product_details_screen.dart';

const _wishlistBrown = Color(0xffa66042);
const _wishlistText = Color(0xff574335);

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({required this.storefrontService, super.key});

  final ShopifyStorefrontService storefrontService;

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffdfcfb),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Wishlist',
          style: TextStyle(
            color: _wishlistText,
            fontFamily: 'Fraunces',
            fontSize: 25,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: ShoppingStore.instance,
        builder: (context, _) {
          final items = ShoppingStore.instance.wishlist;
          if (items.isEmpty) return const _EmptyWishlist();
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: .62,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final product = item.toProduct();
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 2,
                shadowColor: const Color(0x16000000),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailsScreen(
                        product: product,
                        storefrontService: storefrontService,
                      ),
                    ),
                  ),
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
                                borderRadius: BorderRadius.circular(10),
                                child: item.imageUrl == null
                                    ? const ColoredBox(
                                        color: Color(0xfff3eeea),
                                        child: Icon(Icons.diamond_outlined),
                                      )
                                    : ShimmerNetworkImage(
                                        url: item.imageUrl!,
                                        maxWidth: 600,
                                      ),
                              ),
                              Positioned(
                                right: 7,
                                top: 7,
                                child: Material(
                                  color: Colors.white.withValues(alpha: .94),
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => ShoppingStore.instance
                                        .removeFromWishlist(item.handle),
                                    icon: const Icon(
                                      Icons.favorite,
                                      color: _wishlistBrown,
                                      size: 21,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _wishlistText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatPrice(item.amount, item.currencyCode),
                          style: const TextStyle(
                            color: _wishlistBrown,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 9),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: item.availableForSale
                                ? () {
                                    ShoppingStore.instance.addToCart(
                                      product: product,
                                    );
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(
                                          content: Text('Added to cart.'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                  }
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: _wishlistBrown,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                            ),
                            icon: const Icon(
                              Icons.shopping_cart_outlined,
                              size: 17,
                            ),
                            label: Text(
                              item.availableForSale
                                  ? 'Add to Cart'
                                  : 'Out of Stock',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: StorefrontBottomNavigation(
        selectedIndex: 2,
        onHome: () => _goHome(context),
        onCategories: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                CategoriesScreen(storefrontService: storefrontService),
          ),
        ),
        onCart: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => CartScreen(storefrontService: storefrontService),
          ),
        ),
      ),
    );
  }
}

class _EmptyWishlist extends StatelessWidget {
  const _EmptyWishlist();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, color: Color(0xffb99578), size: 65),
            SizedBox(height: 15),
            Text(
              'Your wishlist is empty',
              style: TextStyle(
                color: _wishlistText,
                fontFamily: 'Fraunces',
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Tap the heart on a product to save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff887d76), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPrice(double amount, String currencyCode) {
  final value = amount.round().toString();
  return currencyCode == 'INR' ? 'Rs $value' : '$currencyCode $value';
}
