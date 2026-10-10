// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sri_krishna_pearls_mobile/main.dart';
import 'package:sri_krishna_pearls_mobile/screens/home/home_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/login/login_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/login/shopify_login_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/signup/signup_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/splash_screens/first_splash_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/splash_screens/fourth_splash_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/splash_screens/second_splash_screen.dart';
import 'package:sri_krishna_pearls_mobile/screens/splash_screens/third_splash_screen.dart';

void main() {
  testWidgets('Splash screen renders branded artwork', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    expect(find.byType(FirstSplashScreen), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SecondSplashScreen), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));

    await tester.pump(const Duration(seconds: 4));
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
}
