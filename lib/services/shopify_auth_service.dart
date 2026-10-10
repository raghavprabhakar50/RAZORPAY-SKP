import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/shopify_config.dart';

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

    await _updateCustomerProfile(firstName: firstName, lastName: lastName);
    await _secureStorage.write(
      key: 'shopify_local_phone_$normalizedEmail',
      value: phone.trim(),
    );
    return true;
  }

  Future<bool> _authenticate({
    required String email,
    required bool signUp,
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
          promptValues: const ['login'],
          loginHint: loginHint,
          additionalParameters: signUp ? const {'screen_hint': 'signup'} : null,
        ),
      );

      final accessToken = result.accessToken;
      if (accessToken == null || accessToken.isEmpty) return false;

      await Future.wait([
        _secureStorage.write(key: 'shopify_access_token', value: accessToken),
        _secureStorage.write(
          key: 'shopify_refresh_token',
          value: result.refreshToken,
        ),
        _secureStorage.write(key: 'shopify_id_token', value: result.idToken),
        _secureStorage.write(
          key: 'shopify_access_token_expiry',
          value: result.accessTokenExpirationDateTime?.toIso8601String(),
        ),
      ]);
      return true;
    } on FlutterAppAuthUserCancelledException {
      return false;
    }
  }

  Future<void> _updateCustomerProfile({
    required String firstName,
    required String lastName,
  }) async {
    final accessToken = await _secureStorage.read(key: 'shopify_access_token');
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Shopify did not return an access token.');
    }

    final response = await _client.post(
      await _customerGraphQlEndpoint(),
      headers: {
        'Authorization': accessToken,
        'Content-Type': 'application/json',
        'Origin': 'https://${ShopifyConfig.storefrontDomain}',
      },
      body: jsonEncode({
        'query': '''
          mutation UpdateCustomerProfile(\$input: CustomerUpdateInput!) {
            customerUpdate(input: \$input) {
              userErrors { field message }
            }
          }
        ''',
        'variables': {
          'input': {'firstName': firstName.trim(), 'lastName': lastName.trim()},
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Shopify profile update failed (${response.statusCode}).',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final graphQlErrors = payload['errors'] as List<dynamic>?;
    final userErrors =
        payload['data']?['customerUpdate']?['userErrors'] as List<dynamic>?;
    final errors = graphQlErrors?.isNotEmpty == true
        ? graphQlErrors
        : userErrors;
    if (errors?.isNotEmpty == true) {
      final first = errors!.first;
      final message = first is Map<String, dynamic>
          ? first['message']?.toString()
          : null;
      throw StateError(message ?? 'Shopify could not update the profile.');
    }
  }

  Future<Uri> _customerGraphQlEndpoint() async {
    try {
      final response = await _client.get(
        Uri.parse(ShopifyConfig.customerApiDiscoveryEndpoint),
      );
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

    await Future.wait([
      _secureStorage.delete(key: 'shopify_access_token'),
      _secureStorage.delete(key: 'shopify_refresh_token'),
      _secureStorage.delete(key: 'shopify_id_token'),
      _secureStorage.delete(key: 'shopify_access_token_expiry'),
    ]);
  }
}
