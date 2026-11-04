// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sri_krishna_pearls_mobile/main.dart';
import 'package:sri_krishna_pearls_mobile/models/customer_profile.dart';
import 'package:sri_krishna_pearls_mobile/models/checkout_coupon.dart';
import 'package:sri_krishna_pearls_mobile/models/cart_item.dart';
import 'package:sri_krishna_pearls_mobile/models/home_catalog.dart';
import 'package:sri_krishna_pearls_mobile/screens/cart/cart_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/home/home_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/login/login_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/login/shopify_login_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/profile/profile_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/signup/signup_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/product/product_details_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/splash_screens/first_splash_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/splash_screens/fourth_splash_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/splash_screens/second_splash_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/splash_screens/third_splash_screen.dart';
import 'package:sri_krishna_pearls_mobile/services/account_store.dart';
import 'package:sri_krishna_pearls_mobile/services/middleware_checkout_service.dart';
import 'package:sri_krishna_pearls_mobile/services/shopping_store.dart';
import 'package:sri_krishna_pearls_mobile/services/shopify_storefront_service.dart';

void main() {
  setUp(() {
    AccountStore.instance.debugSetAuthenticated(false);
  });

  testWidgets('Splash screen renders branded artwork', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    expect(find.byType(FirstSplashScreen), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 400));
    // Startup now waits for session restoration before choosing onboarding.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SecondSplashScreen), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ThirdSplashScreen), findsOneWidget);
    expect(find.text('High Quality Pearl\nJewellery'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    expect(find.byType(FourthSplashScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.text('New customer signup'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);

    await tester.tap(find.text('Signup with Shopify'));
    await tester.pump();

    expect(find.text('First name is required'), findsOneWidget);
  });

  testWidgets('Continue with Us opens the Shopify login form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Continue with Us'));
    await tester.pumpAndSettle();

    expect(find.byType(ShopifyLoginScreen), findsOneWidget);
    expect(find.text('Login with Shopify'), findsOneWidget);

    await tester.tap(find.text('Login with Shopify'));
    await tester.pump();

    expect(find.text('Email address is required'), findsOneWidget);
  });

  testWidgets('Onboarding skips splash four and skip opens login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ThirdSplashScreen()));

    expect(find.byType(FourthSplashScreen), findsNothing);
    expect(find.text('Hyderabadi Pearls\nExude Elegance'), findsNothing);

    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.text('Continue as Guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Welcome, Guest'), findsNothing);
  });

  testWidgets('splash three automatically opens login without splash four', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ThirdSplashScreen()));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(FourthSplashScreen), findsNothing);
  });

  testWidgets('Gift card sheet opens and closes without lifecycle errors', (
    WidgetTester tester,
  ) async {
    const product = StorefrontProduct(
      id: 'gid://shopify/Product/1',
      handle: 'pearl-set',
      title: 'Pearl Set',
      amount: 3999,
      currencyCode: 'INR',
      description: 'Pearl necklace',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailsScreen(
          product: product,
          storefrontService: _ProductService(product),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Choose Gift Card'));
    await tester.tap(find.text('Choose Gift Card'));
    await tester.pumpAndSettle();

    expect(find.text('Complimentary Message Card'), findsWidgets);
    expect(find.text('Happy Birthday'), findsOneWidget);

    await tester.tap(find.text('Save Selection'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ProductDetailsScreen), findsOneWidget);
  });

  testWidgets('restored login session opens home instead of login', (
    WidgetTester tester,
  ) async {
    AccountStore.instance.debugSetAuthenticated(
      true,
      profile: const CustomerProfile(email: 'customer@example.com'),
    );
    await tester.pumpWidget(const MaterialApp(home: ThirdSplashScreen()));

    await tester.tap(find.text('SKIP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('signed-in startup skips onboarding screens automatically', (
    tester,
  ) async {
    AccountStore.instance.debugSetAuthenticated(
      true,
      profile: const CustomerProfile(email: 'customer@example.com'),
    );
    await tester.pumpWidget(const MaterialApp(home: FirstSplashScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SecondSplashScreen), findsNothing);
    expect(find.byType(ThirdSplashScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final signup in [false, true]) {
    testWidgets(
      'guest ${signup ? 'signup' : 'login'} returns to cart and requires another checkout tap',
      (WidgetTester tester) async {
        const product = StorefrontProduct(
          id: 'gid://shopify/Product/checkout-test',
          handle: 'checkout-test',
          title: 'Checkout Test Pearl Set',
          amount: 3999,
          currencyCode: 'INR',
        );
        final store = ShoppingStore.instance;
        store.addToCart(product: product);
        final cartKey = store.cart
            .firstWhere((item) => item.productHandle == product.handle)
            .key;

        await tester.pumpWidget(
          MaterialApp(
            home: CartScreen(
              storefrontService: _ProductService(product),
              checkoutService: _CouponCheckoutService(),
            ),
          ),
        );
        expect(find.text('Sign in to Checkout'), findsOneWidget);
        expect(find.text('COUPON OFFER'), findsNothing);
        expect(find.textContaining('View available'), findsNothing);
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
        await tester.tap(find.text('Sign in to Checkout'));
        await tester.pumpAndSettle();

        expect(find.byType(ShopifyLoginScreen), findsOneWidget);
        if (signup) {
          await tester.ensureVisible(find.text('New customer? Create account'));
          await tester.tap(find.text('New customer? Create account'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SignupScreen>(find.byType(SignupScreen))
                .returnToPrevious,
            isTrue,
          );
        }
        AccountStore.instance.debugSetAuthenticated(
          true,
          profile: const CustomerProfile(
            id: 'gid://shopify/Customer/90001',
            email: 'customer@example.com',
            firstName: 'Krishna',
          ),
        );
        Navigator.of(
          tester.element(
            find.byType(signup ? SignupScreen : ShopifyLoginScreen),
          ),
        ).pop(true);
        await tester.pumpAndSettle();

        expect(find.byType(CartScreen), findsOneWidget);
        expect(find.byType(ShopifyLoginScreen), findsNothing);
        expect(find.text('Complete your profile'), findsNothing);
        expect(find.text('Check Out'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
        expect(store.cart.any((item) => item.key == cartKey), isTrue);

        // Only a fresh checkout tap may continue to profile/payment steps.
        await tester.tap(find.text('Check Out'));
        await tester.pumpAndSettle();
        expect(find.text('Complete your profile'), findsOneWidget);
        store.removeCartItem(cartKey);
      },
    );
  }

  testWidgets('checkout button shows loading and resets after an error', (
    tester,
  ) async {
    const product = StorefrontProduct(
      id: 'gid://shopify/Product/loading-test',
      handle: 'loading-test',
      title: 'Loading Pearl Set',
      amount: 3999,
      currencyCode: 'INR',
    );
    AccountStore.instance.debugSetAuthenticated(
      true,
      profile: const CustomerProfile(
        id: 'gid://shopify/Customer/90002',
        firstName: 'Test',
        lastName: 'Customer',
        phone: '+919876543210',
        address1: 'Test address',
        city: 'Ambala',
        zoneCode: 'HR',
        zip: '133001',
      ),
    );
    final store = ShoppingStore.instance;
    store.addToCart(product: product);
    final key = store.cart
        .firstWhere((i) => i.productHandle == product.handle)
        .key;
    final service = _PendingCheckoutService();
    await tester.pumpWidget(
      MaterialApp(
        home: CartScreen(
          storefrontService: _ProductService(product),
          checkoutService: service,
        ),
      ),
    );
    await tester.tap(find.text('Check Out'));
    await tester.pump();
    final button = find.ancestor(
      of: find.byType(CircularProgressIndicator),
      matching: find.byType(FilledButton),
    );
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.textContaining('Shopify checkout opened.'), findsNothing);
    service.pending.completeError(
      StateError('Checkout unavailable. Please retry.'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Check Out'), findsOneWidget);
    expect(find.text('Checkout unavailable. Please retry.'), findsOneWidget);
    store.removeCartItem(key);
    await tester.pumpWidget(const SizedBox());
    service.close();
  });

  testWidgets(
    'cart changes recheck coupons and clear a no-longer-valid selection',
    (tester) async {
      const product = StorefrontProduct(
        id: 'gid://shopify/Product/qty-coupon',
        handle: 'qty-coupon',
        title: 'Pearls',
        amount: 3399,
        currencyCode: 'INR',
      );
      AccountStore.instance.debugSetAuthenticated(
        true,
        profile: const CustomerProfile(id: 'gid://shopify/Customer/90003'),
      );
      final store = ShoppingStore.instance;
      store.addToCart(product: product);
      final key = store.cart.single.key;
      final service = _QuantityCouponService();
      final storefront = _QuantityProductService(product);
      await tester.pumpWidget(
        MaterialApp(
          home: CartScreen(
            storefrontService: storefront,
            checkoutService: service,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pump();
      expect(find.text('SELECTED'), findsOneWidget);
      store.incrementCartItem(key);
      await tester.pump();
      expect(find.text('Loading coupon offers...'), findsOneWidget);
      expect(find.text('SELECTED'), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      expect(storefront.quantities, [1, 2]);
      expect(find.text('Not eligible'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('coupon-use-ONE')))
            .onPressed,
        isNull,
      );
      store.removeCartItem(key);
      await tester.pumpWidget(const SizedBox());
      service.close();
    },
  );

  testWidgets('checkout requires a complete customer profile', (
    WidgetTester tester,
  ) async {
    const product = StorefrontProduct(
      id: 'gid://shopify/Product/profile-checkout-test',
      handle: 'profile-checkout-test',
      title: 'Profile Checkout Test Pearl Set',
      amount: 4999,
      currencyCode: 'INR',
    );
    AccountStore.instance.debugSetAuthenticated(
      true,
      profile: const CustomerProfile(
        email: 'customer@example.com',
        firstName: 'Krishna',
      ),
    );
    final store = ShoppingStore.instance;
    store.addToCart(product: product);
    final cartKey = store.cart
        .firstWhere((item) => item.productHandle == product.handle)
        .key;

    await tester.pumpWidget(
      MaterialApp(
        home: CartScreen(
          storefrontService: _ProductService(product),
          checkoutService: _CouponCheckoutService(),
        ),
      ),
    );
    expect(find.text('Check Out'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('COUPON OFFER'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    await tester.tap(find.text('Check Out'));
    await tester.pumpAndSettle();

    expect(find.text('Complete your profile'), findsOneWidget);
    await tester.tap(find.text('Complete Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Complete Profile'), findsOneWidget);
    store.removeCartItem(cartKey);
  });
}

class _QuantityCouponService extends MiddlewareCheckoutService {
  @override
  Future<List<CheckoutCoupon>> fetchCoupons() async {
    return [
      CheckoutCoupon(code: 'ONE', title: 'Fixture', description: 'Fixture'),
    ];
  }
}

class _CouponCheckoutService extends MiddlewareCheckoutService {
  @override
  Future<List<CheckoutCoupon>> fetchCoupons() async =>
      CheckoutCoupon.publicFallback;
}

class _PendingCheckoutService extends _CouponCheckoutService {
  final pending = Completer<Map<String, dynamic>?>();

  @override
  Future<Map<String, dynamic>?> restore(String customer) => pending.future;
}

class _ProductService extends ShopifyStorefrontService {
  _ProductService(this.product);

  final StorefrontProduct product;

  @override
  Future<List<CheckoutCoupon>> checkCouponEligibility(
    List<CartItem> items,
    List<CheckoutCoupon> coupons,
  ) async => coupons;

  @override
  Future<StorefrontProduct> fetchProduct(String handle) async => product;

  @override
  Future<List<StorefrontProduct>> fetchRelatedProducts(
    String productId,
  ) async => const [];
}

class _QuantityProductService extends _ProductService {
  _QuantityProductService(super.product);
  final quantities = <int>[];
  @override
  Future<List<CheckoutCoupon>> checkCouponEligibility(
    List<CartItem> items,
    List<CheckoutCoupon> coupons,
  ) async {
    quantities.add(items.single.quantity);
    return coupons
        .map(
          (c) => CheckoutCoupon(
            code: c.code,
            title: c.title,
            description: c.description,
            applicable: items.single.quantity == 1,
          ),
        )
        .toList();
  }
}
