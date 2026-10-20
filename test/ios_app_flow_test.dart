import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sri_krishna_pearls_mobile/config/shopify_config.dart';
import 'package:sri_krishna_pearls_mobile/models/cart_item.dart';
import 'package:sri_krishna_pearls_mobile/models/checkout_coupon.dart';
import 'package:sri_krishna_pearls_mobile/models/customer_profile.dart';
import 'package:sri_krishna_pearls_mobile/models/home_catalog.dart';
import 'package:sri_krishna_pearls_mobile/screens/cart/cart_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/login/shopify_login_screen.dart';
import 'package:sri_krishna_pearls_mobile/services/account_store.dart';
import 'package:sri_krishna_pearls_mobile/services/middleware_checkout_service.dart';
import 'package:sri_krishna_pearls_mobile/services/shopping_store.dart';
import 'package:sri_krishna_pearls_mobile/services/shopify_storefront_service.dart';

class _IosCouponList extends MiddlewareCheckoutService {
  @override
  Future<List<CheckoutCoupon>> fetchCoupons() async => const [
    CheckoutCoupon(
      code: 'MIN5000',
      title: 'Minimum purchase 5000',
      description: 'Terms',
    ),
    CheckoutCoupon(
      code: 'OK',
      title: 'Current cart offer',
      description: 'Terms',
    ),
  ];
}

class _IosStorefront extends ShopifyStorefrontService {
  @override
  Future<List<CheckoutCoupon>> checkCouponEligibility(
    List<CartItem> items,
    List<CheckoutCoupon> coupons,
  ) async => [
    CheckoutCoupon(
      code: coupons[0].code,
      title: coupons[0].title,
      description: 'Terms',
      applicable: false,
    ),
    CheckoutCoupon(
      code: coupons[1].code,
      title: coupons[1].title,
      description: 'Terms',
      applicable: true,
    ),
  ];
}

void main() {
  setUp(() {
    AccountStore.instance.debugSetAuthenticated(false);
  });

  test('iOS static configuration keeps callback, app-scoped keychain and HTTPS safety', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    final entitlements = File('ios/Runner/Runner.entitlements')
        .readAsStringSync();
    expect(
      plist,
      contains(
        '<string>${Uri.parse(ShopifyConfig.redirectUrl).scheme}</string>',
      ),
    );
    expect(plist, contains('NSPhotoLibraryUsageDescription'));
    expect(plist, contains('NSLocationWhenInUseUsageDescription'));
    expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
    expect(
      entitlements,
      contains(r'$(AppIdentifierPrefix)$(CFBundleIdentifier)'),
    );
    expect(
      RegExp(r'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;')
          .allMatches(project)
          .length,
      3,
    );
    expect(project, contains('FlutterGeneratedPluginSwiftPackage'));
    final script = File('scripts/ios_live.sh').readAsStringSync();
    expect(script, contains('BYPASS_PERMISSION_LOCATION_ALWAYS=1'));
    expect(script, contains('https://shri-middleware.ekarigar.com'));
  });

  testWidgets(
    'iOS guest login returns to the same Cart without opening checkout',
    (tester) async {
      // Exercise the real scoped store with a product fixture, not a separate iOS cart.
      final store = ShoppingStore.instance;
      store.addToCart(
        product: const StorefrontProduct(
          id: 'gid://shopify/Product/42',
          handle: 'ios-flow',
          title: 'Pearls',
          amount: 3399,
          currencyCode: 'INR',
        ),
      );
      final key = store.cart
          .firstWhere((i) => i.productHandle == 'ios-flow')
          .key;
      final api = _IosCouponList();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: CartScreen(
            storefrontService: _IosStorefront(),
            checkoutService: api,
          ),
        ),
      );
      expect(find.text('COUPON OFFER'), findsNothing);
      await tester.tap(find.text('Sign in to Checkout'));
      await tester.pumpAndSettle();
      expect(find.byType(ShopifyLoginScreen), findsOneWidget);
      AccountStore.instance.debugSetAuthenticated(
        true,
        profile: const CustomerProfile(id: 'gid://shopify/Customer/99001'),
      );
      Navigator.of(tester.element(find.byType(ShopifyLoginScreen))).pop(true);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CartScreen), findsOneWidget);
      expect(find.text('Check Out'), findsOneWidget);
      expect(find.text('Complete your profile'), findsNothing);
      expect(store.cart.any((i) => i.key == key), isTrue);
      expect(find.text('OK'), findsNWidgets(2));
      store.removeCartItem(key);
      await tester.pumpWidget(const SizedBox());
      api.close();
      AccountStore.instance.debugSetAuthenticated(false);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
