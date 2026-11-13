import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/shopify_config.dart';
import '../models/customer_profile.dart';
import 'shopify_storefront_service.dart';
import '../screens/home/home_screen.dart';
import '../screens/orders/my_orders_screen.dart';
import '../screens/product/product_details_screen.dart';
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
  static const _permissionPromptKey = 'push_permission_prompt_seen_v1';
  static const _firstLaunchPermissionPromptKey =
      'push_permission_first_launch_seen_v1';
  static const _storage = FlutterSecureStorage();
  final tokenChanged = StreamController<String>.broadcast();
  final _authService = ShopifyAuthService();
  final _client = http.Client();
  String? _latestToken;
  bool _syncInProgress = false;
  bool _initialized = false;
  Future<void>? _initializing;
  Map<String, dynamic>? _pendingNavigation;
  int _navigationRetries = 0;

  Future<void> initialize() {
    if (_initialized || kIsWeb) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
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
    } finally {
      _initializing = null;
    }
  }

  Future<AuthorizationStatus> permissionStatus() async {
    if (kIsWeb) return AuthorizationStatus.denied;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// Requests notification permission once on the first app launch, including
  /// for guests. The navigator context survives the splash-to-home transition.
  Future<void> requestPermissionOnFirstLaunch() async {
    if (kIsWeb) return;
    await initialize();
    if (!_initialized) return;

    final status = await permissionStatus();
    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      return;
    }
    if (await _storage.read(key: _firstLaunchPermissionPromptKey) == '1') {
      return;
    }

    // MaterialApp's Navigator can become available a frame after runApp.
    for (var attempt = 0; attempt < 10; attempt++) {
      final context = notificationNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        await requestPermissionFromUser(context, force: true);
        await _storage.write(
          key: _firstLaunchPermissionPromptKey,
          value: '1',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Shows an explanation before Android/iOS displays its permission prompt.
  /// The automatic prompt is shown once; Profile can call this with [force]
  /// when the customer explicitly wants to change notification access.
  Future<bool> requestPermissionFromUser(
    BuildContext context, {
    bool force = false,
  }) async {
    if (kIsWeb) return false;
    await initialize();
    if (!_initialized) return false;
    final status = await permissionStatus();
    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      return true;
    }
    if (!force && await _storage.read(key: _permissionPromptKey) == '1') {
      return false;
    }
    if (!context.mounted) return false;

    final allow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Allow notifications?'),
        content: const Text(
          'Get payment, order delivery, back-in-stock and new offer updates. '
          'You can change this permission later from your phone settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    await _storage.write(key: _permissionPromptKey, value: '1');
    if (allow != true) return false;

    final result = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted =
        result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted && force && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'Notifications are blocked. Enable them from app settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: Geolocator.openAppSettings,
            ),
          ),
        );
    }
    return granted;
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
    } else if (link.startsWith('product:')) {
      final handle = link.substring('product:'.length).trim();
      if (handle.isNotEmpty) {
        unawaited(_openProductNotification(navigator, handle));
      }
    }
  }

  Future<void> _openProductNotification(
    NavigatorState navigator,
    String handle,
  ) async {
    final storefront = ShopifyStorefrontService();
    try {
      final product = await storefront.fetchProduct(handle);
      if (!navigator.mounted) return;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailsScreen(
            product: product,
            storefrontService: storefront,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Notification product could not be opened: $error');
      if (!navigator.mounted) return;
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
              'platform': Platform.isIOS ? 'ios' : 'android',
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
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
