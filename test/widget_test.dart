// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sri_krishna_pearls_mobile/main.dart';
import 'package:sri_krishna_pearls_mobile/models/customer_profile.dart';
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

    expect(find.byType(SecondSplashScreen), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ThirdSplashScreen), findsOneWidget);
    expect(find.text('High Quality Pearl\nJewellery'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    expect(find.byType(FourthSplashScreen), findsOneWidget);
    expect(find.text('Hyderabadi Pearls\nExude Elegance'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

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

  testWidgets('Onboarding supports swipe and skip opens login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ThirdSplashScreen()));

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Hyderabadi Pearls\nExude Elegance'), findsOneWidget);

    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.text('Continue as Guest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Welcome, Guest'), findsNothing);
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

  testWidgets('guest checkout requires Shopify login', (
    WidgetTester tester,
  ) async {
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
        home: CartScreen(storefrontService: _ProductService(product)),
      ),
    );
    expect(find.text('Sign in to Checkout'), findsOneWidget);
    await tester.tap(find.text('Sign in to Checkout'));
    await tester.pumpAndSettle();

    expect(find.byType(ShopifyLoginScreen), findsOneWidget);
    store.removeCartItem(cartKey);
  });

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
        home: CartScreen(storefrontService: _ProductService(product)),
      ),
    );
    expect(find.text('Check Out'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
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

class _ProductService extends ShopifyStorefrontService {
  _ProductService(this.product);

  final StorefrontProduct product;

  @override
  Future<StorefrontProduct> fetchProduct(String handle) async => product;

  @override
  Future<List<StorefrontProduct>> fetchRelatedProducts(
    String productId,
  ) async => const [];
}
