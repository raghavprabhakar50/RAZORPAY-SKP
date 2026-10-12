import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/home_catalog.dart';

class ShoppingStore extends ChangeNotifier {
  ShoppingStore._();

  static final ShoppingStore instance = ShoppingStore._();
  static const _storageKey = 'shopping_store_v1';
  static const _storage = FlutterSecureStorage();

  final Map<String, WishlistItem> _wishlist = {};
  final List<CartItem> _cart = [];
  Future<void> _persistQueue = Future<void>.value();
  bool _changedBeforeLoad = false;
  bool _initialized = false;

  List<WishlistItem> get wishlist => List.unmodifiable(_wishlist.values);
  List<CartItem> get cart => List.unmodifiable(_cart);
  int get wishlistCount => _wishlist.length;
  int get cartCount => _cart.fold(0, (total, item) => total + item.quantity);
  double get cartSubtotal =>
      _cart.fold(0, (total, item) => total + (item.unitPrice * item.quantity));

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final stored = await _storage.read(key: _storageKey);
      if (stored != null && stored.isNotEmpty && !_changedBeforeLoad) {
        final decoded = jsonDecode(stored);
        if (decoded is Map<String, dynamic>) {
          final wishlistData = decoded['wishlist'];
          final cartData = decoded['cart'];
          if (wishlistData is List) {
            for (final value in wishlistData.whereType<Map>()) {
              final item = WishlistItem.fromJson(
                Map<String, dynamic>.from(value),
              );
              if (item.handle.isNotEmpty) _wishlist[item.handle] = item;
            }
          }
          if (cartData is List) {
            for (final value in cartData.whereType<Map>()) {
              final item = CartItem.fromJson(Map<String, dynamic>.from(value));
              if (item.key.isNotEmpty && item.quantity > 0) _cart.add(item);
            }
          }
        }
      }
    } catch (_) {
      // A corrupt local value should never stop the storefront from opening.
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  bool isWishlisted(String productHandle) =>
      _wishlist.containsKey(productHandle);

  bool toggleWishlist(StorefrontProduct product) {
    _changedBeforeLoad = true;
    final removed = _wishlist.remove(product.handle) != null;
    if (!removed) {
      _wishlist[product.handle] = WishlistItem.fromProduct(product);
    }
    _commit();
    return !removed;
  }

  void removeFromWishlist(String productHandle) {
    if (_wishlist.remove(productHandle) == null) return;
    _changedBeforeLoad = true;
    _commit();
  }

  void addToCart({
    required StorefrontProduct product,
    StorefrontProductVariant? variant,
    String giftCard = 'Not Required',
    String giftMessage = '',
  }) {
    _changedBeforeLoad = true;
    final next = CartItem.fromProduct(
      product: product,
      variant: variant,
      giftCard: giftCard,
      giftMessage: giftMessage,
    );
    final index = _cart.indexWhere((item) => item.key == next.key);
    if (index < 0) {
      _cart.add(next);
    } else {
      final current = _cart[index];
      _cart[index] = current.copyWith(
        quantity: current.quantity + 1,
        giftCard: next.giftCard == 'Not Required'
            ? current.giftCard
            : next.giftCard,
        giftMessage: next.giftMessage.trim().isEmpty
            ? current.giftMessage
            : next.giftMessage,
      );
    }
    _commit();
  }

  void incrementCartItem(String key) {
    final index = _cart.indexWhere((item) => item.key == key);
    if (index < 0) return;
    _changedBeforeLoad = true;
    _cart[index] = _cart[index].copyWith(quantity: _cart[index].quantity + 1);
    _commit();
  }

  void decrementCartItem(String key) {
    final index = _cart.indexWhere((item) => item.key == key);
    if (index < 0) return;
    _changedBeforeLoad = true;
    if (_cart[index].quantity <= 1) {
      _cart.removeAt(index);
    } else {
      _cart[index] = _cart[index].copyWith(quantity: _cart[index].quantity - 1);
    }
    _commit();
  }

  void removeCartItem(String key) {
    final previousLength = _cart.length;
    _cart.removeWhere((item) => item.key == key);
    if (_cart.length == previousLength) return;
    _changedBeforeLoad = true;
    _commit();
  }

  void _commit() {
    notifyListeners();
    final payload = jsonEncode({
      'wishlist': _wishlist.values.map((item) => item.toJson()).toList(),
      'cart': _cart.map((item) => item.toJson()).toList(),
    });
    _persistQueue = _persistQueue
        .then((_) => _storage.write(key: _storageKey, value: payload))
        .catchError((_) {});
  }
}

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
