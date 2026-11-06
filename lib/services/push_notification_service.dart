import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../config/shopify_config.dart';
import '../models/customer_profile.dart';
import '../screens/home/home_screen.dart';
import '../screens/orders/my_orders_screen.dart';
import 'shopify_auth_service.dart';

const _channelId = 'skp_general_notifications';
final notificationNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Initializes FCM for Android and displays foreground notifications.
///
class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  final tokenChanged = StreamController<String>.broadcast();
  final _authService = ShopifyAuthService();
  final _client = http.Client();
  String? _latestToken;
  bool _syncInProgress = false;
  bool _initialized = false;
  Map<String, dynamic>? _pendingNavigation;
  int _navigationRetries = 0;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final data = jsonDecode(payload);
            if (data is Map<String, dynamic>) _openNotification(data);
          } catch (error) {
            debugPrint('Notification payload ignored: $error');
          }
        },
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              'Sri Krishna Pearls',
              description: 'Order, payment and offer updates',
              importance: Importance.high,
            ),
          );

      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      FirebaseMessaging.instance.onRegistered.listen((token) {
        _latestToken = token;
        tokenChanged.add(token);
      });
      await FirebaseMessaging.instance.register();

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _openNotification(message.data);
      });
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _pendingNavigation = initialMessage.data;
        WidgetsBinding.instance.addPostFrameCallback((_) => _flushNavigation());
      }
      _initialized = true;
    } catch (error, stackTrace) {
      // Notifications must never prevent the storefront from opening.
      debugPrint('Push notifications unavailable: $error\n$stackTrace');
    }
  }

  void _openNotification(Map<String, dynamic> data) {
    _pendingNavigation = data;
    _navigationRetries = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _flushNavigation());
  }

  void _flushNavigation() {
    final data = _pendingNavigation;
    final navigator = notificationNavigatorKey.currentState;
    if (data == null || navigator == null) {
      if (data != null && _navigationRetries++ < 15) {
        Future<void>.delayed(
          const Duration(milliseconds: 400),
          _flushNavigation,
        );
      } else if (navigator == null) {
        _pendingNavigation = null;
      }
      return;
    }
    _pendingNavigation = null;
    final link = data['deep_link']?.toString().trim().toLowerCase() ?? '';
    if (link == 'orders') {
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const MyOrdersScreen()),
      );
    } else if (link == 'home' || link == 'products') {
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    }
  }

  /// Associates the current FCM token with the authenticated Shopify customer.
  /// A guest session simply skips this call; it will run again after login.
  Future<void> syncWithCustomer(CustomerProfile profile) async {
    final token = _latestToken;
    if (token == null ||
        token.isEmpty ||
        profile.id.isEmpty ||
        _syncInProgress) {
      return;
    }
    _syncInProgress = true;
    try {
      final accessToken = await _authService.checkoutAccessToken();
      final base = ShopifyConfig.middlewareBaseUrl.replaceFirst(
        RegExp(r'/+$'),
        '',
      );
      final response = await _client
          .post(
            Uri.parse('$base/api/mobile/notifications/register-token'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'token': token,
              'platform': 'android',
              'state_code': profile.zoneCode,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Notification token registration failed (${response.statusCode}).',
        );
      }
    } catch (error) {
      debugPrint('Notification token registration skipped: $error');
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> unregisterCurrentCustomer() async {
    final token = _latestToken;
    if (token == null || token.isEmpty) return;
    try {
      final accessToken = await _authService.checkoutAccessToken();
      final base = ShopifyConfig.middlewareBaseUrl.replaceFirst(
        RegExp(r'/+$'),
        '',
      );
      await _client
          .post(
            Uri.parse('$base/api/mobile/notifications/unregister-token'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 4));
    } catch (error) {
      debugPrint('Notification token unregister skipped: $error');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    await _localNotifications.show(
      id: message.hashCode,
      title: title ?? 'Sri Krishna Pearls',
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Sri Krishna Pearls',
          channelDescription: 'Order, payment and offer updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
