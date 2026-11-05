import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/shopify_config.dart';
import '../models/customer_profile.dart';

class ShopifyAuthService {
  ShopifyAuthService({
    FlutterAppAuth? appAuth,
    FlutterSecureStorage? secureStorage,
    http.Client? client,
  }) : _appAuth = appAuth ?? const FlutterAppAuth(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client();

  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _secureStorage;
  final http.Client _client;
  Future<bool>? _refreshing;
  static const _sessionMarkerKey = 'shopify_auth_session_marker';

  Future<String?> sessionMarker() =>
      _secureStorage.read(key: _sessionMarkerKey);

  /// Binds cached customer data to one locally-created login session.
  Future<String> ensureSessionMarker() async {
    final existing = await sessionMarker();
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final value = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _secureStorage.write(key: _sessionMarkerKey, value: value);
    return value;
  }

  /// A customer token, never an Admin API or shared payment secret.
  Future<String> checkoutAccessToken() async {
    if (!await restoreSession()) throw StateError('Please sign in again.');
    final token = await _secureStorage.read(key: 'shopify_access_token');
    if (token == null || token.isEmpty) {
      throw StateError('Please sign in again.');
    }
    return token;
  }

  Future<bool> hasSession() async {
    try {
      final token = await _secureStorage.read(key: 'shopify_access_token');
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> restoreSession() async {
    final token = await _secureStorage.read(key: 'shopify_access_token');
    if (token == null || token.isEmpty) return false;
    final expiryValue = await _secureStorage.read(
      key: 'shopify_access_token_expiry',
    );
    final expiry = DateTime.tryParse(expiryValue ?? '');
    if (expiry == null ||
        expiry.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return true;
    }

    final pending = _refreshing;
    if (pending != null) return pending;
    final refresh = _refreshSession();
    _refreshing = refresh;
    try {
      return await refresh;
    } finally {
      _refreshing = null;
    }
  }

  Future<bool> _refreshSession() async {
    final refreshToken = await _secureStorage.read(
      key: 'shopify_refresh_token',
    );
    if (refreshToken == null || refreshToken.isEmpty) return false;
    // A token refresh is non-interactive: never open a browser at checkout/startup.
    final result = await _appAuth.token(
      TokenRequest(
        ShopifyConfig.customerAccountClientId,
        ShopifyConfig.redirectUrl,
        refreshToken: refreshToken,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: ShopifyConfig.authorizationEndpoint,
          tokenEndpoint: ShopifyConfig.tokenEndpoint,
        ),
        scopes: ShopifyConfig.customerScopes,
      ),
    );
    if (result.accessToken?.isNotEmpty != true) return false;
    await _saveTokens(result);
    return true;
  }

  Future<bool> signIn({required String email}) async {
    await _clearPreviousSession();
    return _authenticate(email: email, signUp: false);
  }

  Future<bool> signUp({
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _clearPreviousSession();
    final success = await _authenticate(email: normalizedEmail, signUp: true);
    if (!success) return false;
    await updateCustomerName(firstName: firstName, lastName: lastName);
    return true;
  }

  Future<bool> _authenticate({
    required String email,
    required bool signUp,
    bool silent = false,
  }) async {
    try {
      final loginHint = email.trim().toLowerCase();
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          ShopifyConfig.customerAccountClientId,
          ShopifyConfig.redirectUrl,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: ShopifyConfig.authorizationEndpoint,
            tokenEndpoint: ShopifyConfig.tokenEndpoint,
          ),
          scopes: ShopifyConfig.customerScopes,
          promptValues: [silent ? 'none' : 'login'],
          loginHint: loginHint.isEmpty ? null : loginHint,
          additionalParameters: signUp ? const {'screen_hint': 'signup'} : null,
        ),
      );

      final accessToken = result.accessToken;
      if (accessToken == null || accessToken.isEmpty) return false;

      await _saveTokens(result);
      await ensureSessionMarker();
      return true;
    } on FlutterAppAuthUserCancelledException {
      return false;
    }
  }

  Future<CustomerProfile> fetchCustomerProfile({
    CustomerProfile? fallback,
  }) async {
    final payload = await _postCustomerGraphQl(
      query: r'''
        query CustomerProfile {
          customer {
            id
            displayName
            firstName
            lastName
            imageUrl
            emailAddress { emailAddress }
            phoneNumber { phoneNumber }
            defaultAddress {
              id
              address1
              address2
              city
              zoneCode
              countryCode
              zip
              phoneNumber
            }
          }
        }
      ''',
    );
    final customer = payload['data']?['customer'];
    if (customer is! Map<String, dynamic>) {
      throw StateError('Shopify did not return the customer profile.');
    }
    return CustomerProfile.fromGraphQl(customer, fallback: fallback);
  }

  Future<void> updateCustomerName({
    required String firstName,
    required String lastName,
  }) async {
    final payload = await _postCustomerGraphQl(
      query: r'''
        mutation UpdateCustomerProfile($input: CustomerUpdateInput!) {
          customerUpdate(input: $input) {
            userErrors { field message }
          }
        }
      ''',
      variables: {
        'input': {'firstName': firstName.trim(), 'lastName': lastName.trim()},
      },
    );
    _throwUserErrors(payload, 'customerUpdate');
  }

  Future<void> updateCustomerAddress(CustomerProfile profile) async {
    final hasAddressContent =
        profile.addressId?.isNotEmpty == true ||
        profile.phone.trim().isNotEmpty ||
        profile.address1.trim().isNotEmpty ||
        profile.address2.trim().isNotEmpty ||
        profile.address3.trim().isNotEmpty ||
        profile.city.trim().isNotEmpty ||
        profile.zoneCode.trim().isNotEmpty ||
        profile.zip.trim().isNotEmpty;
    if (!hasAddressContent) return;

    final address = <String, dynamic>{
      'firstName': profile.firstName.trim(),
      'lastName': profile.lastName.trim(),
      'address1': profile.address1.trim(),
      'address2': [
        profile.address2.trim(),
        profile.address3.trim(),
      ].where((line) => line.isNotEmpty).join(', '),
      'city': profile.city.trim(),
      'zoneCode': profile.zoneCode.trim().toUpperCase(),
      'countryCode': profile.countryCode.trim().toUpperCase(),
      'zip': profile.zip.trim(),
      'phoneNumber': _normalizedPhone(
        profile.phone,
        profile.countryCode.trim().toUpperCase(),
      ),
    }..removeWhere((_, value) => value is String && value.isEmpty);

    if (address.isEmpty) return;
    final hasAddress = profile.addressId?.isNotEmpty == true;
    final payload = await _postCustomerGraphQl(
      query: hasAddress
          ? r'''
              mutation UpdateCustomerAddress(
                $addressId: ID!
                $address: CustomerAddressInput!
              ) {
                customerAddressUpdate(
                  addressId: $addressId
                  address: $address
                  defaultAddress: true
                ) {
                  customerAddress { id }
                  userErrors { field message }
                }
              }
            '''
          : r'''
              mutation CreateCustomerAddress($address: CustomerAddressInput!) {
                customerAddressCreate(
                  address: $address
                  defaultAddress: true
                ) {
                  customerAddress { id }
                  userErrors { field message }
                }
              }
            ''',
      variables: {
        if (hasAddress) 'addressId': profile.addressId,
        'address': address,
      },
    );
    _throwUserErrors(
      payload,
      hasAddress ? 'customerAddressUpdate' : 'customerAddressCreate',
    );
  }

  Future<Map<String, dynamic>> _postCustomerGraphQl({
    required String query,
    Map<String, dynamic> variables = const {},
  }) async {
    final accessToken = await _secureStorage.read(key: 'shopify_access_token');
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Please login to continue.');
    }

    final response = await _client
        .post(
          await _customerGraphQlEndpoint(),
          headers: {
            'Authorization': accessToken,
            'Content-Type': 'application/json',
            'Origin': 'https://${ShopifyConfig.storefrontDomain}',
          },
          body: jsonEncode({'query': query, 'variables': variables}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Shopify profile request failed (${response.statusCode}).',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final graphQlErrors = payload['errors'] as List<dynamic>?;
    if (graphQlErrors?.isNotEmpty == true) {
      final first = graphQlErrors!.first;
      final message = first is Map<String, dynamic>
          ? first['message']?.toString()
          : null;
      throw StateError(message ?? 'Shopify could not load the profile.');
    }
    return payload;
  }

  void _throwUserErrors(Map<String, dynamic> payload, String mutationKey) {
    final userErrors =
        payload['data']?[mutationKey]?['userErrors'] as List<dynamic>?;
    if (userErrors?.isNotEmpty != true) return;
    final first = userErrors!.first;
    final message = first is Map<String, dynamic>
        ? first['message']?.toString()
        : null;
    throw StateError(message ?? 'Shopify could not update the profile.');
  }

  Future<Uri> _customerGraphQlEndpoint() async {
    try {
      final response = await _client
          .get(Uri.parse(ShopifyConfig.customerApiDiscoveryEndpoint))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final endpoint = payload['graphql_api']?.toString();
        if (endpoint != null && endpoint.isNotEmpty) {
          return Uri.parse(endpoint);
        }
      }
    } catch (_) {
      // Use the versioned endpoint when discovery is unavailable.
    }

    return Uri.parse(
      'https://${ShopifyConfig.shopDomain}/customer/api/2026-10/graphql',
    );
  }

  Future<void> _clearPreviousSession() async {
    final idToken = await _secureStorage.read(key: 'shopify_id_token');
    if (idToken != null && idToken.isNotEmpty) {
      try {
        await _client
            .get(
              Uri.parse(ShopifyConfig.logoutEndpoint).replace(
                queryParameters: {
                  'id_token_hint': idToken,
                  'post_logout_redirect_uri': ShopifyConfig.redirectUrl,
                },
              ),
            )
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // Local cleanup must continue even if Shopify logout is unavailable.
      }
    }

    await _clearLocalTokens();
  }

  Future<void> _saveTokens(TokenResponse result) async {
    await Future.wait([
      _secureStorage.write(
        key: 'shopify_access_token',
        value: result.accessToken,
      ),
      if (result.refreshToken?.isNotEmpty == true)
        _secureStorage.write(
          key: 'shopify_refresh_token',
          value: result.refreshToken,
        ),
      if (result.idToken?.isNotEmpty == true)
        _secureStorage.write(key: 'shopify_id_token', value: result.idToken),
      _secureStorage.write(
        key: 'shopify_access_token_expiry',
        value: result.accessTokenExpirationDateTime?.toIso8601String(),
      ),
    ]);
  }

  Future<void> _clearLocalTokens() async {
    await Future.wait([
      _secureStorage.delete(key: 'shopify_access_token'),
      _secureStorage.delete(key: 'shopify_refresh_token'),
      _secureStorage.delete(key: 'shopify_id_token'),
      _secureStorage.delete(key: 'shopify_access_token_expiry'),
      _secureStorage.delete(key: _sessionMarkerKey),
    ]);
  }

  Future<void> signOut() => _clearPreviousSession();

  static String _normalizedPhone(String value, String countryCode) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.startsWith('+')) return trimmed;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (countryCode == 'IN' && digits.length == 10) return '+91$digits';
    return trimmed;
  }
}
