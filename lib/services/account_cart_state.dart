import '../models/cart_item.dart';

/// Local cart ownership is a verified customer GID, never an email/display name.
/// A nonempty guest cart replaces the next authenticated account's saved cart.
class AccountCartState {
  final Map<String, List<CartItem>> _carts = {};
  final List<void Function()> _beforeLoad = [];
  bool _loaded = false;
  String _owner = 'guest';
  List<CartItem> get items => List.unmodifiable(_carts[_owner] ?? []);

  void _change(void Function() operation) {
    operation();
    if (!_loaded) _beforeLoad.add(operation);
  }

  void selectAccount(String? verifiedId, {bool authenticating = false}) {
    final next =
        verifiedId != null &&
            RegExp(r'^gid://shopify/Customer/[1-9][0-9]*$').hasMatch(verifiedId)
        ? verifiedId
        : authenticating
        ? 'authenticating'
        : 'guest';
    _change(() {
      _owner = next;
      if (next == 'guest' || next == 'authenticating') return;
      final guest = [...?_carts['guest'], ...?_carts['authenticating']];
      _carts['guest'] = [];
      _carts['authenticating'] = [];
      // The current guest shopping session wins over an older saved cart.
      // Empty guest sessions still restore the customer's own saved items.
      if (guest.isNotEmpty) _carts[next] = [];
      for (final item in guest) {
        _add(next, item);
      }
    });
  }

  void _add(String owner, CartItem item) {
    final cart = _carts.putIfAbsent(owner, () => []);
    final index = cart.indexWhere((v) => v.key == item.key);
    if (index < 0) {
      cart.add(item);
    } else {
      cart[index] = cart[index].copyWith(
        quantity: cart[index].quantity + item.quantity,
      );
    }
  }

  void add(CartItem item) {
    final owner = _owner;
    _change(() => _add(owner, item));
  }

  void increment(String key) {
    final owner = _owner;
    _change(() {
      final cart = _carts[owner] ?? [];
      final i = cart.indexWhere((v) => v.key == key);
      if (i >= 0) cart[i] = cart[i].copyWith(quantity: cart[i].quantity + 1);
    });
  }

  void decrement(String key) {
    final owner = _owner;
    _change(() {
      final cart = _carts[owner] ?? [];
      final i = cart.indexWhere((v) => v.key == key);
      if (i < 0) return;
      if (cart[i].quantity <= 1) {
        cart.removeAt(i);
      } else {
        cart[i] = cart[i].copyWith(quantity: cart[i].quantity - 1);
      }
    });
  }

  void remove(String key) {
    final owner = _owner;
    _change(() => _carts[owner]?.removeWhere((v) => v.key == key));
  }

  void restore(Map<String, dynamic> saved) {
    if (_loaded) return;
    _carts.clear();
    _owner = 'guest';
    for (final entry in saved.entries) {
      if (entry.value is! List ||
          (entry.key != 'guest' &&
              entry.key != 'authenticating' &&
              !RegExp(r'^gid://shopify/Customer/[1-9][0-9]*$')
                  .hasMatch(entry.key))) {
        continue;
      }
      final items = <CartItem>[];
      for (final row in entry.value as List) {
        try {
          if (row is! Map) continue;
          final item = CartItem.fromJson(Map<String, dynamic>.from(row));
          if (item.key.isNotEmpty && item.quantity > 0) items.add(item);
        } catch (_) {
          /* Skip a corrupt line, never another account's cart. */
        }
      }
      _carts[entry.key] = items;
    }
    _loaded = true;
    for (final operation in _beforeLoad) {
      operation();
    }
    _beforeLoad.clear();
  }

  Map<String, dynamic> toJson() => _carts.map(
    (key, value) => MapEntry(key, value.map((v) => v.toJson()).toList()),
  );
}
