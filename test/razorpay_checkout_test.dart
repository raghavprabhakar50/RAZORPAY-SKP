import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sri_krishna_pearls_mobile/models/cart_item.dart';
import 'package:sri_krishna_pearls_mobile/models/customer_profile.dart';
import 'package:sri_krishna_pearls_mobile/services/cart_payment_flow.dart';
import 'package:sri_krishna_pearls_mobile/services/middleware_checkout_service.dart';
import 'package:sri_krishna_pearls_mobile/services/razorpay_checkout.dart';

const profile = CustomerProfile(
  id: 'gid://shopify/Customer/1',
  email: 'fixture@example.invalid',
  firstName: 'Test',
  lastName: 'Customer',
);
const item = CartItem(
  key: 'fixture',
  productId: '1',
  productHandle: 'pearls',
  title: 'Pearls',
  unitPrice: 1,
  currencyCode: 'INR',
  quantity: 1,
  availableForSale: true,
  variantId: 'gid://shopify/ProductVariant/1',
);
Map<String, dynamic> provider() => {
  'mode': 'live',
  'key_id': 'rzp_live_fixture',
  'razorpay_order_id': 'order_fixture',
  'amount': 339900,
  'currency': 'INR',
};

class FakeGateway extends RazorpayCheckout {
  int opens = 0;
  bool cancel = false;
  @override
  Future<Map<String, String>> open(
    Map<String, dynamic> data,
    CustomerProfile customer,
  ) async {
    opens++;
    if (cancel) throw CheckoutCancelled();
    return {
      'razorpay_order_id':
          data['razorpay_order_id']?.toString() ?? 'order_fixture',
      'razorpay_payment_id': 'pay_fixture',
      'razorpay_signature': 'signature',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('Magic SDK flags require an explicitly marked server-created order', () {
    final standard = RazorpayCheckout.options(provider(), profile);
    expect(standard.containsKey('one_click_checkout'), false);
    final magic = RazorpayCheckout.options({
      ...provider(),
      'engine': 'magic',
      'one_click_checkout': true,
      'show_coupons': true,
    }, profile);
    expect(magic['one_click_checkout'], true);
    expect(magic['show_coupons'], true);
    expect(magic['order_id'], 'order_fixture');
    for (final fields in [
      {'engine': 'magic'},
      {'one_click_checkout': true},
      {'show_coupons': true},
    ]) {
      expect(
        () => RazorpayCheckout.options({...provider(), ...fields}, profile),
        throwsStateError,
      );
    }
    expect(
      MiddlewareCheckoutService.payload(
        [item],
        profile,
        'request',
      )['checkout_capabilities'],
      ['native_magic_v1'],
    );
  });
  test(
    'live SDK options use server order and amount, not local price or secrets',
    () {
      final options = RazorpayCheckout.options(provider(), profile);
      expect(options['amount'], 339900);
      expect(options['order_id'], 'order_fixture');
      expect(options['description'], 'Order payment');
      expect(options.containsKey('key_secret'), false);
      expect(
        MiddlewareCheckoutService.payload(
          [item],
          profile,
          'request',
        ).containsKey('amount'),
        false,
      );
    },
  );
  test('invalid key-mode, amount and order are rejected', () {
    for (final change in [
      {'key_id': 'rzp_test_fixture'},
      {'amount': 0},
      {'currency': 'USD'},
      {'razorpay_order_id': 'invalid'},
    ]) {
      expect(
        () => RazorpayCheckout.options({...provider(), ...change}, profile),
        throwsStateError,
      );
    }
  });
  test(
    'SDK opens native Razorpay and returns callback for backend verification',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      Map? sent;
      const channel = MethodChannel('razorpay_flutter');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'resync') return null;
            sent = call.arguments as Map;
            return {
              'type': 0,
              'data': {
                'razorpay_order_id': 'order_fixture',
                'razorpay_payment_id': 'pay_fixture',
                'razorpay_signature': 'signature',
              },
            };
          });
      final gateway = RazorpayCheckout();
      addTearDown(gateway.dispose);
      final callback = await gateway.open(provider(), profile);
      expect(sent?['key'], 'rzp_live_fixture');
      expect(callback['razorpay_signature'], 'signature');
      expect(callback.containsKey('paid'), false);
    },
  );
  test('direct flow persists before starting, verifies callback, clears only after server success', () async {
    final calls = <String>[];
    late MiddlewareCheckoutService service;
    service = MiddlewareCheckoutService(
      baseUri: Uri.parse('https://middleware.example.invalid'),
      tokenProvider: () async => 'customer_token',
      client: MockClient((r) async {
        expect(r.headers['Authorization'], 'Bearer customer_token');
        final action = r.url.path.split('/').last;
        calls.add(action);
        final body = jsonDecode(r.body) as Map;
        if (action == 'quote') expect(body['discount_code'], 'SAVE10');
        if (action == 'start') {
          expect((await service.restore(profile.id))?['quote'], isNotNull);
        }
        final data = action == 'quote'
            ? {
                'quote_id': 'quote_fixture',
                'mode': 'live',
                'amount': 339900,
                'currency': 'INR',
                'discount': '100.00',
                'discount_codes': ['SAVE10'],
              }
            : action == 'start'
            ? provider()
            : {
                'paid': true,
                'payment_status': 'captured',
                'mode': 'live',
                'order_created': true,
              };
        if (action == 'verify') expect(body['razorpay_signature'], 'signature');
        return http.Response(
          jsonEncode({'status': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(service.close);
    final gateway = FakeGateway();
    Map<String, dynamic>? displayedQuote;
    final result = await CartPaymentFlow(service, gateway).run(
      [item],
      profile,
      () => true,
      (_) {},
      discountCode: ' SAVE10 ',
      onQuote: (q) => displayedQuote = q,
    );
    expect(displayedQuote?['discount'], '100.00');
    expect(displayedQuote?['discount_codes'], ['SAVE10']);
    expect(result['paid'], true);
    expect(gateway.opens, 1);
    expect(calls, ['quote', 'start', 'verify']);
    expect(await service.restore(profile.id), null);
  });
  test(
    'cancel clears recovery and the next checkout can start fresh',
    () async {
      var authorized = false;
      final service = MiddlewareCheckoutService(
        baseUri: Uri.parse('https://middleware.example.invalid'),
        tokenProvider: () async => 'customer_token',
        client: MockClient((r) async {
          final action = r.url.path.split('/').last;
          final data = action == 'quote'
              ? {
                  'quote_id': 'quote_fixture',
                  'mode': 'live',
                  'amount': 339900,
                  'currency': 'INR',
                }
              : action == 'start'
              ? provider()
              : {
                  'paid': false,
                  'payment_status': authorized ? 'authorized' : 'created',
                };
          return http.Response(
            jsonEncode({'status': true, 'data': data}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(service.close);
      final gateway = FakeGateway()..cancel = true;
      final flow = CartPaymentFlow(service, gateway);
      final cancelled = await flow.run([item], profile, () => true, (_) {});
      expect(cancelled['cancelled'], true);
      expect(await service.restore(profile.id), isNull);
      gateway.cancel = false;
      authorized = true;
      final state = await flow.run([item], profile, () => true, (_) {});
      expect(state['payment_status'], 'authorized');
      expect(gateway.opens, 2);
    },
  );
  test('each checkout tap quotes the current cart without restoring a previous checkout', () async {
    final calls = <String>[];
    final service = MiddlewareCheckoutService(
      baseUri: Uri.parse('https://middleware.example.invalid'),
      tokenProvider: () async => 'customer_token',
      client: MockClient((r) async {
        final action = r.url.path.split('/').last;
        calls.add(action);
        final data = action == 'quote'
            ? {
                'quote_id': 'new_quote',
                'mode': 'live',
                'amount': 339900,
                'currency': 'INR',
              }
            : action == 'start'
            ? provider()
            : {
                'paid': true,
                'payment_status': 'captured',
                'order_created': true,
              };
        return http.Response(
          jsonEncode({'status': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(service.close);
    await service.save(profile.id, {
      'request': MiddlewareCheckoutService.payload([item], profile, 'old'),
      'quote': {'quote_id': 'old_quote', 'amount': 999999},
    });
    final gateway = FakeGateway();
    final result = await CartPaymentFlow(
      service,
      gateway,
    ).run([item.copyWith(quantity: 2)], profile, () => true, (_) {});
    expect(result['paid'], true);
    expect(calls, ['quote', 'start', 'verify']);
    expect(gateway.opens, 1);
  });
  test('HTML endpoint fails clearly without SDK or exposing tokens', () async {
    final service = MiddlewareCheckoutService(
      baseUri: Uri.parse('https://middleware.example.invalid'),
      tokenProvider: () async => 'customer_token',
      client: MockClient(
        (_) async => http.Response(
          '<html>Login</html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      ),
    );
    addTearDown(service.close);
    await expectLater(service.post('quote', {}), throwsStateError);
  });
  test(
    'captured payment without confirmed Shopify order keeps recovery',
    () async {
      final service = MiddlewareCheckoutService(
        baseUri: Uri.parse('https://middleware.example.invalid'),
        tokenProvider: () async => 'customer_token',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'status': true,
              'data': {'paid': true, 'payment_status': 'captured'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(service.close);
      await service.save(profile.id, {
        'request': MiddlewareCheckoutService.payload([item], profile, 'old'),
        'quote': {'quote_id': 'old_quote', 'amount': 339900},
      });
      final gateway = FakeGateway();
      final result = await CartPaymentFlow(
        service,
        gateway,
      ).run([item], profile, () => true, (_) {});
      expect(result['paid'], true);
      expect(result['order_created'], isNot(true));
      expect(await service.restore(profile.id), isNotNull);
      expect(gateway.opens, 1);
    },
  );
  test('quote expiring before start is repriced immediately', () async {
    final calls = <String>[];
    var quotes = 0;
    var starts = 0;
    final service = MiddlewareCheckoutService(
      baseUri: Uri.parse('https://middleware.example.invalid'),
      tokenProvider: () async => 'customer_token',
      client: MockClient((r) async {
        final action = r.url.path.split('/').last;
        calls.add(action);
        if (action == 'start' && ++starts == 1) {
          return http.Response(
            jsonEncode({
              'status': false,
              'message': 'Your price review expired. Review the cart again.',
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        final data = action == 'quote'
            ? {
                'quote_id': 'quote_${++quotes}',
                'mode': 'live',
                'amount': 339900,
                'currency': 'INR',
              }
            : action == 'status'
            ? {'paid': false, 'payment_status': 'not_started'}
            : action == 'start'
            ? provider()
            : {
                'paid': true,
                'payment_status': 'captured',
                'order_created': true,
              };
        return http.Response(
          jsonEncode({'status': true, 'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(service.close);
    final gateway = FakeGateway();
    final result = await CartPaymentFlow(
      service,
      gateway,
    ).run([item], profile, () => true, (_) {});
    expect(result['order_created'], true);
    expect(calls, ['quote', 'start', 'quote', 'start', 'verify']);
    expect(gateway.opens, 1);
  });
}
