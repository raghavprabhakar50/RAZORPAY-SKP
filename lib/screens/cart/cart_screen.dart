import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/cart_item.dart';
import '../../models/checkout_coupon.dart';
import '../../services/account_store.dart';
import '../../services/middleware_checkout_service.dart';
import '../../services/razorpay_checkout.dart';
import '../../services/shopping_store.dart';
import '../../services/shopify_storefront_service.dart';
import '../../services/shopify_auth_service.dart';
import '../../utils/navigation.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/cart_coupon_offers.dart';
import '../../widgets/storefront_bottom_navigation.dart';
import '../category/categories_screen.dart';
import '../login/shopify_login_screen.dart';
import '../profile/profile_screen.dart';
import '../wishlist/wishlist_screen.dart';

const _cartBrown = Color(0xffa66042);
const _cartText = Color(0xff574335);

class _CouponOffersFailure implements Exception {
  const _CouponOffersFailure(this.message);
  final String message;
}

class CartScreen extends StatefulWidget {
  const CartScreen({
    required this.storefrontService,
    this.checkoutService,
    this.paymentGateway,
    super.key,
  });

  final ShopifyStorefrontService storefrontService;
  final MiddlewareCheckoutService? checkoutService;
  final RazorpayCheckout? paymentGateway;
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final _service = widget.checkoutService ?? MiddlewareCheckoutService();
  ShopifyStorefrontService get storefrontService => widget.storefrontService;
  bool _working = false;
  bool _openingCheckout = false;
  String _progress = 'Open payment checkout';
  String? _notice;
  final _orderInstructions = TextEditingController();
  String? _selectedCoupon;
  Future<List<CheckoutCoupon>>? _coupons;
  String? _couponCustomer;
  String? _couponCart;

  Future<void> _begin(BuildContext context) async {
    if (_working) return;
    setState(() {
      _working = true;
      _notice = null;
    });
    try {
      await _checkout(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _notice = error is StateError ? error.message.toString() : 'Unable to complete checkout. Tap Check Out to recover your saved payment before retrying.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _openingCheckout = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _orderInstructions.dispose();
    if (widget.checkoutService == null) _service.close();
    super.dispose();
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _checkout(BuildContext context) async {
    if (!AccountStore.instance.isAuthenticated) {
      final loggedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const ShopifyLoginScreen(returnToPrevious: true),
        ),
      );
      if (loggedIn != true || !context.mounted) return;
      // Signing in completes this action. Let the customer review their current
      // cart and coupons before explicitly starting checkout with another tap.
      return;
    }
    final profile = AccountStore.instance.profile;
    if (profile == null || !profile.isCheckoutReady) {
      final completeProfile = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.person_pin_circle_outlined,
            color: _cartBrown,
            size: 34,
          ),
          title: const Text('Complete your profile'),
          content: const Text(
            'Please add your name, phone number and complete delivery address before checkout.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: _cartBrown),
              child: const Text('Complete Profile'),
            ),
          ],
        ),
      );
      if (completeProfile != true || !context.mounted) return;
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const ProfileScreen(requireCompletion: true),
        ),
      );
      if (completed != true || !context.mounted) return;
    }
    if (!context.mounted) return;
    final checkoutProfile = AccountStore.instance.profile;
    if (checkoutProfile == null ||
        !checkoutProfile.isCheckoutReady ||
        ShoppingStore.instance.cart.isEmpty) {
      return;
    }
    setState(() => _openingCheckout = true);
    await _service.prepareHostedCheckout(checkoutProfile.id);
    if (!mounted) return;
    setState(() => _progress = 'Open payment checkout');
    final items = List<CartItem>.unmodifiable(ShoppingStore.instance.cart);
    final token = await ShopifyAuthService().checkoutAccessToken();
    final checkout = await storefrontService.createWebCheckout(
      items,
      customerAccessToken: token,
      orderNote: _orderInstructions.text,
      discountCode: _selectedCoupon ?? '',
    );
    if (!mounted ||
        AccountStore.instance.profile?.id != checkoutProfile.id ||
        !AccountStore.instance.isAuthenticated) {
      return;
    }
    final opened = await launchUrl(checkout, mode: LaunchMode.inAppBrowserView);
    if (!opened) {
      throw StateError('Unable to open Shopify checkout. Please try again.');
    }
    // Opening/closing a browser is not payment proof. Keep the cart intact;
    // Shopify owns payment confirmation and existing order/webhook sync.
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
        animation: Listenable.merge([
          ShoppingStore.instance,
          AccountStore.instance,
        ]),
        builder: (context, _) {
          final store = ShoppingStore.instance;
          if (store.cart.isEmpty) return const _EmptyCart();
          final customer = AccountStore.instance.isAuthenticated
              ? AccountStore.instance.profile?.id
              : null;
          final cartSignature = store.cart
              .map((i) => '${i.key}:${i.quantity}:${i.variantId}')
              .join('|');
          if (_couponCustomer != customer || _couponCart != cartSignature) {
            _couponCustomer = customer;
            _couponCart = cartSignature;
            _coupons = null;
            _selectedCoupon = null;
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              ...store.cart.map((item) => _CartLineCard(item: item)),
              const SizedBox(height: 16),
              _CartSummary(store: store),
              const SizedBox(height: 16),
              if (AccountStore.instance.isAuthenticated) ...[
                FutureBuilder<List<CheckoutCoupon>>(
                  key: ValueKey('$customer:$cartSignature'),
                  future: _coupons ??=
                      Future<void>.delayed(
                        const Duration(milliseconds: 350),
                      ).then((_) async {
                        if (!mounted ||
                            _couponCustomer != customer ||
                            _couponCart != cartSignature) {
                          return <CheckoutCoupon>[];
                        }
                        final items = List<CartItem>.unmodifiable(store.cart);
                        final List<CheckoutCoupon> offers;
                        try {
                          offers = await _service.fetchCoupons();
                        } catch (_) {
                          throw const _CouponOffersFailure(
                            'Unable to load coupon offers.',
                          );
                        }
                        if (!mounted ||
                            _couponCustomer != customer ||
                            _couponCart != cartSignature) {
                          return <CheckoutCoupon>[];
                        }
                        try {
                          return await storefrontService.checkCouponEligibility(
                            items,
                            offers,
                          );
                        } catch (_) {
                          throw const _CouponOffersFailure(
                            'Unable to check coupons for this cart.',
                          );
                        }
                      }),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              snapshot.error is _CouponOffersFailure
                                  ? (snapshot.error as _CouponOffersFailure)
                                        .message
                                  : 'Unable to load coupon offers.',
                            ),
                          ),
                          TextButton(
                            onPressed: _working
                                ? null
                                : () => setState(() => _coupons = null),
                            child: const Text('Retry coupons'),
                          ),
                        ],
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Text('Loading coupon offers...');
                    }
                    final coupons = snapshot.data!;
                    if (_selectedCoupon != null &&
                        !coupons.any(
                          (c) =>
                              c.code == _selectedCoupon &&
                              c.applicable != false,
                        )) {
                      _selectedCoupon = null;
                    }
                    return CartCouponOffers(
                      coupons: coupons,
                      selectedCode: _selectedCoupon,
                      enabled: !_working,
                      onChanged: (code) =>
                          setState(() => _selectedCoupon = code),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _orderInstructions,
                enabled: !_working,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Order special instructions',
                  hintText: 'Add delivery or order instructions (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([
              ShoppingStore.instance,
              AccountStore.instance,
            ]),
            builder: (context, _) => ShoppingStore.instance.cart.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _working ? null : () => _begin(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: _cartBrown,
                              disabledBackgroundColor: _cartBrown,
                              disabledForegroundColor: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_openingCheckout) ...[
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                      semanticsLabel: 'Opening checkout',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ] else if (!AccountStore
                                    .instance
                                    .isAuthenticated) ...[
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    _working
                                        ? _progress
                                        : AccountStore.instance.isAuthenticated
                                        ? 'Check Out'
                                        : 'Sign in to Checkout',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_notice != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_notice!, textAlign: TextAlign.center),
                          ),
                      ],
                    ),
                  ),
          ),
          StorefrontBottomNavigation(
            selectedIndex: 3,
            onHome: () => _goHome(context),
            onCategories: () => Navigator.of(context).pushReplacement(
              instantPageRoute<void>(
                builder: (_) =>
                    CategoriesScreen(storefrontService: storefrontService),
              ),
            ),
            onWishlist: () => Navigator.of(context).pushReplacement(
              instantPageRoute<void>(
                builder: (_) =>
                    WishlistScreen(storefrontService: storefrontService),
              ),
            ),
          ),
        ],
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
