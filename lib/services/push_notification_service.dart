import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../config/shopify_config.dart';
import '../models/customer_profile.dart';
import 'shopify_auth_service.dart';

const _channelId = 'skp_general_notifications';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Initializes FCM for Android and displays foreground notifications.
///
/// The token is intentionally kept local for now; the middleware registration
/// endpoint can be connected without changing the notification UI later.
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

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          // Deep-link routing can consume this payload when screens are ready.
          debugPrint('Notification opened: ${response.payload}');
        },
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            'Sri Krishna Pearls',
            description: 'Order, payment and offer updates',
            importance: Importance.high,
          ));

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
        debugPrint('Notification opened with data: ${jsonEncode(message.data)}');
      });
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from notification: ${jsonEncode(initialMessage.data)}');
      }
      _initialized = true;
    } catch (error, stackTrace) {
      // Notifications must never prevent the storefront from opening.
      debugPrint('Push notifications unavailable: $error\n$stackTrace');
    }
  }

  /// Associates the current FCM token with the authenticated Shopify customer.
  /// A guest session simply skips this call; it will run again after login.
  Future<void> syncWithCustomer(CustomerProfile profile) async {
    final token = _latestToken;
    if (token == null || token.isEmpty || profile.id.isEmpty || _syncInProgress) return;
    _syncInProgress = true;
    try {
      final accessToken = await _authService.checkoutAccessToken();
      final base = ShopifyConfig.middlewareBaseUrl.replaceFirst(RegExp(r'/+$'), '');
      final response = await _client.post(
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
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Notification token registration failed (${response.statusCode}).');
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
      final base = ShopifyConfig.middlewareBaseUrl.replaceFirst(RegExp(r'/+$'), '');
      await _client.post(
        Uri.parse('$base/api/mobile/notifications/unregister-token'),
        headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Notification token unregister skipped: $error');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) return;
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
