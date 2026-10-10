class ShopifyConfig {
  const ShopifyConfig._();

  static const storefrontDomain = String.fromEnvironment(
    'SHOPIFY_STOREFRONT_DOMAIN',
    defaultValue: 'www.srikrishnapearls.com',
  );

  static const shopDomain = String.fromEnvironment(
    'SHOPIFY_SHOP_DOMAIN',
    defaultValue: 'srikrishnapearls.myshopify.com',
  );

  static const customerAccountClientId = String.fromEnvironment(
    'SHOPIFY_CUSTOMER_ACCOUNT_CLIENT_ID',
    defaultValue: 'd8e059e4-7c1e-4d0b-97dd-8fc182074a9a',
  );

  static const storefrontAccessToken = String.fromEnvironment(
    'SHOPIFY_STOREFRONT_ACCESS_TOKEN',
    defaultValue: '7863e20e16666a56c200132ee318836d',
  );

  static const redirectUrl = 'shop.73316171914.app://callback';

  static const authorizationEndpoint =
      'https://shopify.com/authentication/73316171914/oauth/authorize';

  static const tokenEndpoint =
      'https://shopify.com/authentication/73316171914/oauth/token';

  static const logoutEndpoint =
      'https://shopify.com/authentication/73316171914/logout';

  static const storefrontEndpoint =
      'https://$shopDomain/api/2026-10/graphql.json';

  static const openIdDiscoveryEndpoint =
      'https://$storefrontDomain/.well-known/openid-configuration';

  static const customerApiDiscoveryEndpoint =
      'https://$storefrontDomain/.well-known/customer-account-api';

  static const middlewareBaseUrl = String.fromEnvironment(
    'SKP_MIDDLEWARE_BASE_URL',
    defaultValue: 'http://10.0.2.2/qatar/index.php/api/v1',
  );

  static const mobileApiToken = String.fromEnvironment('SKP_MOBILE_API_TOKEN');

  static const customerScopes = <String>[
    'openid',
    'email',
    'customer-account-api:full',
  ];
}
