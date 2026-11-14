import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/cart_item.dart';
import '../models/home_catalog.dart';
import '../models/wishlist_item.dart';
import 'account_cart_state.dart';
import 'account_store.dart';
import 'push_notification_service.dart';

class ShoppingStore extends ChangeNotifier {
  ShoppingStore._() {
    AccountStore.instance.addListener(_accountChanged);
    _selectAccount();
  }

  static final ShoppingStore instance = ShoppingStore._();
  static const _storageKey = 'shopping_store_v1';
  static const _scopedKey = 'shopping_cart_accounts_v2';
  static const _storage = FlutterSecureStorage();

  final Map<String, WishlistItem> _wishlist = {};
  final AccountCartState _cartState = AccountCartState();
  List<CartItem> get _cart => _cartState.items;
  Future<void> _persistQueue = Future<void>.value();
  Timer? _cartActivityTimer;
  bool _changedBeforeLoad = false;
  bool _initialized = false;
  Future<void>? _initializing;

  void _selectAccount() {
    final account = AccountStore.instance;
    _cartState.selectAccount(
      account.isAuthenticated ? account.profile?.id : null,
      authenticating: account.isAuthenticated,
    );
  }

  void _accountChanged() {
    _selectAccount();
    _commit(); // Scope switches hide the previous account synchronously.
  }

  List<WishlistItem> get wishlist => List.unmodifiable(_wishlist.values);
  List<CartItem> get cart => List.unmodifiable(_cart);
  int get wishlistCount => _wishlist.length;
  int get cartCount => _cart.fold(0, (total, item) => total + item.quantity);
  double get cartSubtotal =>
      _cart.fold(0, (total, item) => total + (item.unitPrice * item.quantity));

  Future<void> initialize() => _initializing ??= _load();
  Future<void> _load() async {
    if (_initialized) return;
    try {
      final stored = await _storage.read(key: _storageKey);
      if (stored != null && stored.isNotEmpty && !_changedBeforeLoad) {
        final decoded = jsonDecode(stored);
        if (decoded is Map<String, dynamic>) {
          final wishlistData = decoded['wishlist'];
          if (wishlistData is List) {
            for (final value in wishlistData.whereType<Map>()) {
              final item = WishlistItem.fromJson(
                Map<String, dynamic>.from(value),
              );
              if (item.handle.isNotEmpty) _wishlist[item.handle] = item;
            }
          }
          // Legacy cart has no owner. Keep its original storage untouched;
          // never assign potentially another customer's items to a new login.
        }
      }
    } catch (_) {
      // A corrupt local value should never stop the storefront from opening.
    } finally {
      try {
        final saved = await _storage.read(key: _scopedKey);
        final decoded = saved == null ? null : jsonDecode(saved);
        _cartState.restore(decoded is Map<String, dynamic> ? decoded : {});
      } catch (_) {
        _cartState.restore({});
      }
      _initialized = true;
      _commit();
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
    if (AccountStore.instance.isAuthenticated) {
      unawaited(
        PushNotificationService.instance.syncWishlistItem(
          WishlistItem.fromProduct(product),
          active: !removed,
        ),
      );
    }
    return !removed;
  }

  void removeFromWishlist(String productHandle) {
    final removed = _wishlist.remove(productHandle);
    if (removed == null) return;
    _changedBeforeLoad = true;
    _commit();
    if (AccountStore.instance.isAuthenticated) {
      unawaited(
        PushNotificationService.instance.syncWishlistItem(
          removed,
          active: false,
        ),
      );
    }
  }

  void refreshWishlistedProduct(StorefrontProduct product) {
    final current = _wishlist[product.handle];
    if (current == null) return;
    final refreshed = WishlistItem.fromProduct(product);
    if (current.id == refreshed.id &&
        current.title == refreshed.title &&
        current.amount == refreshed.amount &&
        current.currencyCode == refreshed.currencyCode &&
        current.imageUrl == refreshed.imageUrl &&
        current.compareAtAmount == refreshed.compareAtAmount &&
        current.firstVariantId == refreshed.firstVariantId &&
        current.availableForSale == refreshed.availableForSale) {
      return;
    }
    _wishlist[product.handle] = refreshed;
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
    _cartState.add(next);
    _commit(trackCart: true);
  }

  void incrementCartItem(String key) {
    final index = _cart.indexWhere((item) => item.key == key);
    if (index < 0) return;
    _changedBeforeLoad = true;
    _cartState.increment(key);
    _commit(trackCart: true);
  }

  void decrementCartItem(String key) {
    final index = _cart.indexWhere((item) => item.key == key);
    if (index < 0) return;
    _changedBeforeLoad = true;
    _cartState.decrement(key);
    _commit(trackCart: true);
  }

  void removeCartItem(String key) {
    final previousLength = _cart.length;
    _cartState.remove(key);
    if (_cart.length == previousLength) return;
    _changedBeforeLoad = true;
    _commit(trackCart: true);
  }

  void replaceCartItem(String key, CartItem replacement) {
    if (!_cart.any((item) => item.key == key)) return;
    _changedBeforeLoad = true;
    _cartState.replace(key, replacement);
    _commit(trackCart: true);
  }

  void _commit({bool trackCart = false}) {
    notifyListeners();
    if (!_initialized) return; // Don't overwrite disk before restore/replay.
    final payload = jsonEncode({
      'wishlist': _wishlist.values.map((item) => item.toJson()).toList(),
    });
    final carts = jsonEncode(_cartState.toJson());
    _persistQueue = _persistQueue
        .then((_) async {
          await _storage.write(key: _scopedKey, value: carts);
          // Keep the unowned legacy cart recoverable, but not visible in any scope.
          final old = await _storage.read(key: _storageKey);
          Map<String, dynamic> legacy;
          try {
            legacy = old == null
                ? {}
                : Map<String, dynamic>.from(jsonDecode(old) as Map);
          } catch (_) {
            legacy = {};
          }
          legacy['wishlist'] = (jsonDecode(payload) as Map)['wishlist'];
          await _storage.write(key: _storageKey, value: jsonEncode(legacy));
        })
        .catchError((_) {});
    if (trackCart) _scheduleCartActivitySync();
  }

  void _scheduleCartActivitySync() {
    _cartActivityTimer?.cancel();
    _cartActivityTimer = Timer(const Duration(milliseconds: 1200), () {
      final account = AccountStore.instance;
      if (!account.isAuthenticated) return;
      final summary = _cart
          .map((item) => '${item.title} x${item.quantity}')
          .join(', ');
      unawaited(
        PushNotificationService.instance.syncCartActivity(
          active: _cart.isNotEmpty,
          summary: summary,
          stateCode: account.profile?.zoneCode ?? '',
        ),
      );
    });
  }
}
