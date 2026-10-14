import 'home_catalog.dart';

class CartItem {
  const CartItem({
    required this.key,
    required this.productId,
    required this.productHandle,
    required this.title,
    required this.unitPrice,
    required this.currencyCode,
    required this.quantity,
    required this.availableForSale,
    this.variantId,
    this.variantTitle,
    this.imageUrl,
    this.compareAtAmount,
    this.productType,
    this.giftCard = 'Not Required',
    this.giftMessage = '',
  });

  final String key;
  final String productId;
  final String productHandle;
  final String title;
  final String? variantId;
  final String? variantTitle;
  final String? imageUrl;
  final double unitPrice;
  final double? compareAtAmount;
  final String currencyCode;
  final int quantity;
  final bool availableForSale;
  final String? productType;
  final String giftCard;
  final String giftMessage;

  factory CartItem.fromProduct({
    required StorefrontProduct product,
    StorefrontProductVariant? variant,
    required String giftCard,
    required String giftMessage,
  }) {
    final variantId = variant?.id ?? product.firstVariantId;
    final normalizedGiftCard = _normalizeGiftCard(giftCard);
    final normalizedGiftMessage = normalizedGiftCard == 'Not Required'
        ? ''
        : giftMessage.trim();
    return CartItem(
      key: buildKey(
        productHandle: product.handle,
        variantId: variantId,
        giftCard: normalizedGiftCard,
        giftMessage: normalizedGiftMessage,
      ),
      productId: product.id,
      productHandle: product.handle,
      title: product.title,
      variantId: variantId,
      variantTitle: variant?.title,
      imageUrl: variant?.imageUrl ?? product.imageUrl,
      unitPrice: variant?.amount ?? product.amount,
      compareAtAmount: variant?.compareAtAmount ?? product.compareAtAmount,
      currencyCode: variant?.currencyCode ?? product.currencyCode,
      quantity: 1,
      availableForSale: variant?.availableForSale ?? product.availableForSale,
      productType: product.productType,
      giftCard: normalizedGiftCard,
      giftMessage: normalizedGiftMessage,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productHandle = json['productHandle']?.toString() ?? '';
    final variantId = json['variantId']?.toString();
    final giftCard = _normalizeGiftCard(json['giftCard']?.toString() ?? '');
    final giftMessage = giftCard == 'Not Required'
        ? ''
        : json['giftMessage']?.toString().trim() ?? '';
    return CartItem(
      key: buildKey(
        productHandle: productHandle,
        variantId: variantId,
        giftCard: giftCard,
        giftMessage: giftMessage,
      ),
      productId: json['productId']?.toString() ?? '',
      productHandle: productHandle,
      title: json['title']?.toString() ?? '',
      variantId: variantId,
      variantTitle: json['variantTitle']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      compareAtAmount: (json['compareAtAmount'] as num?)?.toDouble(),
      currencyCode: json['currencyCode']?.toString() ?? 'INR',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      availableForSale: json['availableForSale'] as bool? ?? true,
      productType: json['productType']?.toString(),
      giftCard: giftCard,
      giftMessage: giftMessage,
    );
  }

  static String buildKey({
    required String productHandle,
    required String? variantId,
    required String giftCard,
    required String giftMessage,
  }) {
    final card = _normalizeGiftCard(giftCard);
    final message = card == 'Not Required' ? '' : giftMessage.trim();
    return <String>[
      productHandle,
      variantId ?? 'default',
      card,
      message,
    ].map(Uri.encodeComponent).join('::');
  }

  static String _normalizeGiftCard(String value) {
    final card = value.trim();
    return card.isEmpty ? 'Not Required' : card;
  }

  StorefrontProduct toProduct() {
    return StorefrontProduct(
      id: productId,
      handle: productHandle,
      title: title,
      amount: unitPrice,
      currencyCode: currencyCode,
      productType: productType,
      imageUrl: imageUrl,
      compareAtAmount: compareAtAmount,
      firstVariantId: variantId,
      availableForSale: availableForSale,
    );
  }

  CartItem copyWith({int? quantity, String? giftCard, String? giftMessage}) {
    return CartItem(
      key: key,
      productId: productId,
      productHandle: productHandle,
      title: title,
      variantId: variantId,
      variantTitle: variantTitle,
      imageUrl: imageUrl,
      unitPrice: unitPrice,
      compareAtAmount: compareAtAmount,
      currencyCode: currencyCode,
      quantity: quantity ?? this.quantity,
      availableForSale: availableForSale,
      productType: productType,
      giftCard: giftCard ?? this.giftCard,
      giftMessage: giftMessage ?? this.giftMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'productId': productId,
    'productHandle': productHandle,
    'title': title,
    'variantId': variantId,
    'variantTitle': variantTitle,
    'imageUrl': imageUrl,
    'unitPrice': unitPrice,
    'compareAtAmount': compareAtAmount,
    'currencyCode': currencyCode,
    'quantity': quantity,
    'availableForSale': availableForSale,
    'productType': productType,
    'giftCard': giftCard,
    'giftMessage': giftMessage,
  };
}
