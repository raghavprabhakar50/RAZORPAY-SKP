import 'home_catalog.dart';

class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.handle,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.availableForSale,
    this.productType,
    this.imageUrl,
    this.compareAtAmount,
    this.firstVariantId,
  });

  final String id;
  final String handle;
  final String title;
  final double amount;
  final String currencyCode;
  final String? productType;
  final String? imageUrl;
  final double? compareAtAmount;
  final String? firstVariantId;
  final bool availableForSale;

  factory WishlistItem.fromProduct(StorefrontProduct product) {
    return WishlistItem(
      id: product.id,
      handle: product.handle,
      title: product.title,
      amount: product.amount,
      currencyCode: product.currencyCode,
      productType: product.productType,
      imageUrl: product.imageUrl,
      compareAtAmount: product.compareAtAmount,
      firstVariantId: product.firstVariantId,
      availableForSale: product.availableForSale,
    );
  }

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currencyCode: json['currencyCode']?.toString() ?? 'INR',
      productType: json['productType']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      compareAtAmount: (json['compareAtAmount'] as num?)?.toDouble(),
      firstVariantId: json['firstVariantId']?.toString(),
      availableForSale: json['availableForSale'] as bool? ?? true,
    );
  }

  StorefrontProduct toProduct() {
    return StorefrontProduct(
      id: id,
      handle: handle,
      title: title,
      amount: amount,
      currencyCode: currencyCode,
      productType: productType,
      imageUrl: imageUrl,
      compareAtAmount: compareAtAmount,
      firstVariantId: firstVariantId,
      availableForSale: availableForSale,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'handle': handle,
    'title': title,
    'amount': amount,
    'currencyCode': currencyCode,
    'productType': productType,
    'imageUrl': imageUrl,
    'compareAtAmount': compareAtAmount,
    'firstVariantId': firstVariantId,
    'availableForSale': availableForSale,
  };
}
