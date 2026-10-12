import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/cart_item.dart';
import '../models/home_catalog.dart';
import '../models/wishlist_item.dart';

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
