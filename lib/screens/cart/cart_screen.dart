import 'package:flutter/material.dart';

import '../../services/shopping_store.dart';
import '../../services/shopify_storefront_service.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/storefront_bottom_navigation.dart';
import '../category/categories_screen.dart';
import '../wishlist/wishlist_screen.dart';

const _cartBrown = Color(0xffa66042);
const _cartText = Color(0xff574335);

class CartScreen extends StatelessWidget {
  const CartScreen({required this.storefrontService, super.key});

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
          'Cart',
          style: TextStyle(
            color: _cartText,
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
          final store = ShoppingStore.instance;
          if (store.cart.isEmpty) return const _EmptyCart();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              ...store.cart.map((item) => _CartLineCard(item: item)),
              const SizedBox(height: 16),
              _CartSummary(store: store),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Checkout will connect to Razorpay Magic Checkout through the middleware.',
                          ),
                        ),
                      );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _cartBrown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Check Out',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: StorefrontBottomNavigation(
        selectedIndex: 3,
        onHome: () => _goHome(context),
        onCategories: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                CategoriesScreen(storefrontService: storefrontService),
          ),
        ),
        onWishlist: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                WishlistScreen(storefrontService: storefrontService),
          ),
        ),
      ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final store = ShoppingStore.instance;
    final hasGiftCard =
        item.giftCard.trim().isNotEmpty && item.giftCard != 'Not Required';
    final hasGiftMessage = item.giftMessage.trim().isNotEmpty;
    return Dismissible(
      key: ValueKey(item.key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => store.removeCartItem(item.key),
      background: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xffb95045),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                height: 88,
                child: item.imageUrl == null
                    ? const ColoredBox(
                        color: Color(0xfff3eeea),
                        child: Icon(Icons.diamond_outlined),
                      )
                    : ShimmerNetworkImage(url: item.imageUrl!, maxWidth: 400),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _cartText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        onPressed: () => store.removeCartItem(item.key),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xffa59a93),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  if (_visibleVariantTitle(item.variantTitle) != null)
                    Text(
                      _visibleVariantTitle(item.variantTitle)!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff8a807a),
                        fontSize: 11,
                      ),
                    ),
                  if (hasGiftCard || hasGiftMessage) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xfffff7e9),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.card_giftcard_rounded,
                            color: _cartBrown,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasGiftCard)
                                  Text(
                                    'Gift Card: ${item.giftCard}',
                                    style: const TextStyle(
                                      color: _cartText,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (hasGiftMessage)
                                  Text(
                                    'Message: ${item.giftMessage.trim()}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xff776e68),
                                      fontSize: 10,
                                      height: 1.3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatPrice(item.unitPrice, item.currencyCode),
                          style: const TextStyle(
                            color: _cartBrown,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _QuantityControl(item: item),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _visibleVariantTitle(String? value) {
    final title = value?.trim();
    if (title == null || title.isEmpty || title == 'Default Title') return null;
    return title;
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final store = ShoppingStore.instance;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffffd58c)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () => store.decrementCartItem(item.key),
            icon: const Icon(Icons.remove, size: 17),
          ),
          Container(
            width: 38,
            height: double.infinity,
            alignment: Alignment.center,
            color: const Color(0xffffe8b9),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                color: _cartText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: () => store.incrementCartItem(item.key),
            icon: const Icon(Icons.add, size: 17),
          ),
        ],
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.store});

  final ShoppingStore store;

  @override
  Widget build(BuildContext context) {
    final currency = store.cart.first.currencyCode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffeadfd7)),
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: 'Items (${store.cartCount})',
            value: _formatPrice(store.cartSubtotal, currency),
          ),
          const SizedBox(height: 10),
          const _SummaryRow(label: 'Shipping', value: 'Calculated at checkout'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1),
          ),
          _SummaryRow(
            label: 'Total Price',
            value: _formatPrice(store.cartSubtotal, currency),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: emphasized ? _cartText : const Color(0xff8c827c),
            fontSize: emphasized ? 13 : 12,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: emphasized ? _cartBrown : const Color(0xff665d57),
              fontSize: emphasized ? 13 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              color: Color(0xffb99578),
              size: 68,
            ),
            SizedBox(height: 15),
            Text(
              'Your cart is empty',
              style: TextStyle(
                color: _cartText,
                fontFamily: 'Fraunces',
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Add a product and it will appear here.',
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
