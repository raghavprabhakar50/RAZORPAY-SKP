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
    return CartItem(
      key: '${product.handle}::${variantId ?? 'default'}',
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
      giftCard: giftCard,
      giftMessage: giftMessage,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      key: json['key']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productHandle: json['productHandle']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      variantId: json['variantId']?.toString(),
      variantTitle: json['variantTitle']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      compareAtAmount: (json['compareAtAmount'] as num?)?.toDouble(),
      currencyCode: json['currencyCode']?.toString() ?? 'INR',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      availableForSale: json['availableForSale'] as bool? ?? true,
      productType: json['productType']?.toString(),
      giftCard: json['giftCard']?.toString() ?? 'Not Required',
      giftMessage: json['giftMessage']?.toString() ?? '',
    );
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
