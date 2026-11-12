import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screens/first_splash_screen.dart';
import 'services/account_store.dart';
import 'services/push_notification_service.dart';
import 'services/shopping_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xfffae9cb),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  unawaited(AccountStore.instance.initialize());
  unawaited(ShoppingStore.instance.initialize());
  unawaited(PushNotificationService.instance.initialize());
  runApp(const MyApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      PushNotificationService.instance.requestPermissionOnFirstLaunch(),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: notificationNavigatorKey,
      title: 'Sri Krishna Pearls',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffa85f36)),
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      home: const FirstSplashScreen(),
    );
  }
}
