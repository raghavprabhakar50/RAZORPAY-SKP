import 'package:flutter_test/flutter_test.dart';
import 'package:sri_krishna_pearls_mobile/models/cart_item.dart';
import 'package:sri_krishna_pearls_mobile/models/home_catalog.dart';

void main() {
  const product = StorefrontProduct(
    id: 'gid://shopify/Product/1',
    handle: 'simple-pearl-necklace',
    title: 'Simple Pearl Necklace',
    amount: 3999,
    currencyCode: 'INR',
    firstVariantId: 'gid://shopify/ProductVariant/1',
  );

  test('gift choice and message form part of the cart line key', () {
    final withoutGift = CartItem.fromProduct(
      product: product,
      giftCard: 'Not Required',
      giftMessage: '',
    );
    final birthdayOne = CartItem.fromProduct(
      product: product,
      giftCard: 'Happy Birthday',
      giftMessage: 'For Aanya',
    );
    final birthdayTwo = CartItem.fromProduct(
      product: product,
      giftCard: 'Happy Birthday',
      giftMessage: 'For Riya',
    );
    final birthdayOneAgain = CartItem.fromProduct(
      product: product,
      giftCard: 'Happy Birthday',
      giftMessage: 'For Aanya',
    );

    expect(withoutGift.key, isNot(birthdayOne.key));
    expect(birthdayOne.key, isNot(birthdayTwo.key));
    expect(birthdayOne.key, birthdayOneAgain.key);
  });

  test('stored cart lines are migrated to the gift-aware key', () {
    final item = CartItem.fromJson({
      'key': 'old-product-and-variant-only-key',
      'productId': product.id,
      'productHandle': product.handle,
      'title': product.title,
      'variantId': product.firstVariantId,
      'unitPrice': product.amount,
      'currencyCode': product.currencyCode,
      'quantity': 1,
      'availableForSale': true,
      'giftCard': 'Happy Anniversary',
      'giftMessage': 'Always together',
    });

    expect(item.key, contains(Uri.encodeComponent('Happy Anniversary')));
    expect(item.key, contains(Uri.encodeComponent('Always together')));
  });
}
