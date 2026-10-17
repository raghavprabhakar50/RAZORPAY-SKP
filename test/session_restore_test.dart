import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sri_krishna_pearls_mobile/services/shopify_auth_service.dart';

class RefreshAuth extends FlutterAppAuth {
  int refreshes = 0;
  @override
  Future<TokenResponse> token(TokenRequest request) async {
    refreshes++;
    expect(request.refreshToken, 'existing_refresh');
    return TokenResponse(
      'new_access',
      null,
      DateTime.now().add(const Duration(hours: 1)),
      null,
      'Bearer',
      null,
      null,
    );
  }

  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) => throw StateError('Must not open login for token refresh');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('expired checkout session refreshes without reopening sign-in and preserves refresh token', () async {
    FlutterSecureStorage.setMockInitialValues({
      'shopify_access_token': 'old_access',
      'shopify_refresh_token': 'existing_refresh',
      'shopify_access_token_expiry': DateTime.now()
          .subtract(const Duration(minutes: 2))
          .toIso8601String(),
    });
    final native = RefreshAuth();
    final service = ShopifyAuthService(appAuth: native);
    expect(await service.checkoutAccessToken(), 'new_access');
    expect(native.refreshes, 1);
    expect(
      await const FlutterSecureStorage().read(key: 'shopify_refresh_token'),
      'existing_refresh',
    );
  });
  test(
    'valid session reuses the existing token without native browser',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'shopify_access_token': 'current_access',
        'shopify_access_token_expiry': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      });
      final native = RefreshAuth();
      expect(
        await ShopifyAuthService(appAuth: native).checkoutAccessToken(),
        'current_access',
      );
      expect(native.refreshes, 0);
    },
  );
}
