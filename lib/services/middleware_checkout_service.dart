import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/shopify_config.dart';
import '../models/cart_item.dart';
import '../models/customer_profile.dart';
import 'shopify_auth_service.dart';

class MiddlewareCheckoutService {
  MiddlewareCheckoutService({
    http.Client? client,
    Future<String> Function()? tokenProvider,
    Uri? baseUri,
    FlutterSecureStorage? storage,
  }) : _client = client ?? http.Client(),
       _token = tokenProvider ?? ShopifyAuthService().checkoutAccessToken,
       baseUri = baseUri ?? Uri.parse(ShopifyConfig.middlewareBaseUrl),
       _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final Future<String> Function() _token;
  final Uri baseUri;
  final FlutterSecureStorage _storage;
  String _key(String customer) =>
      'skp_checkout_v2_${baseUri.host}_${baseUri.path}_$customer';
  static String requestId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static Map<String, dynamic> payload(
    List<CartItem> items,
    CustomerProfile p,
    String request, {
    String discountCode = '',
  }) {
    if (items.isEmpty ||
        items.any(
          (i) => i.variantId == null || !i.availableForSale || i.quantity < 1,
        )) {
      throw StateError('An item is unavailable. Refresh your cart.');
    }
    return {
      'request_id': request,
      'checkout_capabilities': ['native_magic_v1'],
      'discount_code': discountCode.trim(),
      'lines': items
          .map(
            (i) => {
              'variant_id': i.variantId,
              'quantity': i.quantity,
              'gift_card': i.giftCard,
              'gift_message': i.giftMessage,
            },
          )
          .toList(),
      'address': {
        'first_name': p.firstName,
        'last_name': p.lastName,
        'address1': p.address1,
        'address2': [
          p.address2,
          p.address3,
        ].where((s) => s.isNotEmpty).join(', '),
        'city': p.city,
        'province_code': p.zoneCode,
        'country_code': p.countryCode,
        'zip': p.zip,
        'phone': p.phone,
      },
    };
  }

  Future<Map<String, dynamic>> post(
    String action,
    Map<String, dynamic> input,
  ) async {
    if (baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        (baseUri.scheme != 'https' &&
            !(kDebugMode && baseUri.scheme == 'http'))) {
      throw StateError('Secure middleware URL is not configured.');
    }
    final token = await _token();
    final request =
        http.Request(
            'POST',
            Uri.parse(
              '${baseUri.toString().replaceFirst(RegExp(r'/+$'), '')}/api/mobile/${action == 'orders' ? 'orders' : 'checkout/$action'}',
            ),
          )
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          })
          ..body = jsonEncode(input);
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 40)),
    );
    if (!response.headers['content-type'].toString().contains(
      'application/json',
    )) {
      throw StateError(
        'Middleware returned a website page instead of checkout data. Server setup is required.',
      );
    }
    final result = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        result is! Map ||
        result['status'] != true ||
        result['data'] is! Map) {
      throw StateError(
        result is Map && result['message'] is String
            ? result['message'] as String
            : 'Checkout unavailable. Check saved payment before retrying.',
      );
    }
    return Map<String, dynamic>.from(result['data'] as Map);
  }

  Future<Map<String, dynamic>?> restore(String customer) async {
    final raw = await _storage.read(key: _key(customer));
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> save(String customer, Map<String, dynamic> value) =>
      _storage.write(key: _key(customer), value: jsonEncode(value));
  Future<void> clear(String customer) => _storage.delete(key: _key(customer));

  /// Migrate the old native flow without deleting payment recovery evidence.
  /// Only server-confirmed unpaid/not-started attempts may be put aside.
  Future<void> prepareHostedCheckout(String customer) async {
    final saved = await restore(customer);
    if (saved == null) return;
    final quote = saved['quote'];
    if (quote is Map) {
      final state = await post('status', {'quote_id': quote['quote_id']});
      if (state['paid'] != false ||
          ![
            'created',
            'failed',
            'not_started',
          ].contains(state['payment_status'])) {
        throw StateError(
          'Your previous payment is paid or still processing. Check your orders before paying again.',
        );
      }
      saved['last_verified_status'] = state;
    }
    final reference = quote is Map
        ? quote['quote_id']
        : saved['request']?['request_id'];
    if (reference == null) {
      throw StateError('Saved payment needs review before checkout.');
    }
    await _storage.write(
      key: '${_key(customer)}_native_archive_$reference',
      value: jsonEncode(saved),
    );
    await clear(
      customer,
    ); // Removes only the active pointer, not the archive/server ledger.
  }

  void close() => _client.close();
}
