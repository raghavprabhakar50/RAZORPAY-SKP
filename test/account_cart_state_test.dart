import 'package:flutter_test/flutter_test.dart';
import 'package:sri_krishna_pearls_mobile/models/cart_item.dart';
import 'package:sri_krishna_pearls_mobile/services/account_cart_state.dart';

const a = 'gid://shopify/Customer/101';
const b = 'gid://shopify/Customer/202';
CartItem item(String id, {int quantity = 1, String gift = ''}) => CartItem(
  key: '$id-$gift',
  productId: id,
  productHandle: id,
  title: id,
  unitPrice: 100,
  currencyCode: 'INR',
  quantity: quantity,
  availableForSale: true,
  variantId: 'gid://shopify/ProductVariant/$id',
  giftMessage: gift,
);

void main() {
  test('guest cart is consumed once on login; logout and another account cannot see it', () {
    final state = AccountCartState()..restore({});
    state.add(item('1'));
    state.selectAccount(a);
    expect(state.items.single.productId, '1');
    state.selectAccount(null);
    expect(state.items, isEmpty);
    state.selectAccount(b);
    expect(state.items, isEmpty);
    state.add(item('2'));
    state.selectAccount(a);
    expect(state.items.single.productId, '1');
    state.selectAccount(b);
    expect(state.items.single.productId, '2');
  });
  test('guest cart merges quantity into matching account lines without losing gift variants', () {
    final state = AccountCartState()..restore({});
    state.selectAccount(a);
    state.add(item('1', quantity: 2));
    state.selectAccount(null);
    state.add(item('1'));
    state.add(item('1', gift: 'Birthday'));
    state.selectAccount(a);
    expect(state.items.length, 2);
    expect(state.items.first.quantity, 3);
    expect(state.items.last.giftMessage, 'Birthday');
    state.selectAccount(a);
    expect(state.items.first.quantity, 3);
  });
  test('switching directly between accounts never merges one user cart into another', () {
    final state = AccountCartState()..restore({});
    state.selectAccount(a);
    state.add(item('1'));
    state.selectAccount(b);
    expect(state.items, isEmpty);
    state.selectAccount(a);
    expect(state.items.single.productId, '1');
  });
  test('restore replays early login/mutations on saved owner cart without overwrite or duplicate guest transfer', () {
    final saved = AccountCartState()..restore({});
    saved.selectAccount(a);
    saved.add(item('2'));
    saved.selectAccount(null);
    saved.add(item('1'));
    final state = AccountCartState();
    state.selectAccount(null);
    state.add(item('3'));
    state.selectAccount(a);
    state.restore(saved.toJson());
    expect(state.items.map((i) => i.productId).toSet(), {'1', '2', '3'});
    state.selectAccount(null);
    expect(state.items, isEmpty);
    state.selectAccount(b);
    expect(state.items, isEmpty);
  });
  test('saved scope ownership survives app restart and invalid email identity never claims a cart', () {
    final saved = AccountCartState()..restore({});
    saved.selectAccount(a);
    saved.add(item('1'));
    final state = AccountCartState();
    state.selectAccount(b);
    state.restore(saved.toJson());
    expect(state.items, isEmpty);
    state.selectAccount(a);
    expect(state.items.single.productId, '1');
    state.selectAccount('another@example.invalid');
    expect(state.items, isEmpty);
  });
  test(
    'pending authentication keeps guest items until customer identity is known',
    () {
      final state = AccountCartState()..restore({});
      state.add(item('1'));
      state.selectAccount(null, authenticating: true);
      expect(state.items, isEmpty);
      state.selectAccount(a);
      expect(state.items.single.productId, '1');
      state.selectAccount(null);
      state.selectAccount(b);
      expect(state.items, isEmpty);
    },
  );
}
