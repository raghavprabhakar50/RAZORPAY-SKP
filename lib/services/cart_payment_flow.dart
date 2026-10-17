import '../models/cart_item.dart';
import '../models/customer_profile.dart';
import 'middleware_checkout_service.dart';
import 'razorpay_checkout.dart';

class CartPaymentFlow {
  CartPaymentFlow(this.service, this.gateway);
  final MiddlewareCheckoutService service;
  final RazorpayCheckout gateway;
  bool _running = false;
  Future<Map<String, dynamic>> run(
    List<CartItem> items,
    CustomerProfile profile,
    bool Function() sameAccount,
    void Function(String) progress, {
    String discountCode = '',
    void Function(Map<String, dynamic>)? onQuote,
  }) async {
    if (_running) throw StateError('Checkout already open.');
    _running = true;
    void check() {
      if (!sameAccount() || profile.id.isEmpty) {
        throw StateError('Your account changed. Please sign in again.');
      }
    }

    Future<Map<String, dynamic>> accept(Map<String, dynamic> state) async {
      check();
      if (state['paid'] == true) await service.clear(profile.id);
      return state;
    }

    try {
      check();
      progress('Checking payment…');
      var saved = await service.restore(profile.id);
      check();
      if (saved != null &&
          discountCode.trim().isNotEmpty &&
          saved['request']?['discount_code'] != discountCode.trim()) {
        throw StateError(
          'Your saved payment uses its original discount code. Resume that checkout before starting a different payment.',
        );
      }
      if (saved?['quote'] is Map) {
        final id = saved!['quote']['quote_id'];
        Map<String, dynamic> state;
        if (saved['callback'] is Map) {
          try {
            state = await service.post('verify', {
              'quote_id': id,
              ...Map<String, dynamic>.from(saved['callback'] as Map),
            });
          } catch (_) {
            state = await service.post('status', {'quote_id': id});
          }
        } else {
          state = await service.post('status', {'quote_id': id});
        }
        check();
        if (state['paid'] == true ||
            ![
              'created',
              'failed',
              'not_started',
            ].contains(state['payment_status'])) {
          return await accept(state);
        }
        if (state['payment_status'] == 'not_started') {
          await service.clear(profile.id);
          saved = null;
        }
      }
      if (saved == null) {
        // Save request ID before pricing. An ambiguous draft write must reuse it.
        saved = {
          'request': MiddlewareCheckoutService.payload(
            items,
            profile,
            MiddlewareCheckoutService.requestId(),
            discountCode: discountCode,
          ),
        };
        await service.save(profile.id, saved);
      }
      check();
      if (saved['quote'] == null) {
        progress('Checking final total…');
        final quote = await service.post(
          'quote',
          Map<String, dynamic>.from(saved['request'] as Map),
        );
        check();
        saved['quote'] = quote;
        await service.save(profile.id, saved);
      }
      final quote = Map<String, dynamic>.from(saved['quote'] as Map);
      onQuote?.call({
        ...quote,
        'requested_discount_code': saved['request']?['discount_code'] ?? '',
      });
      check();
      progress('Opening Razorpay…');
      final checkout = await service.post('start', {
        'quote_id': quote['quote_id'],
      });
      check();
      if (checkout['mode'] != quote['mode'] ||
          checkout['amount'] != quote['amount'] ||
          checkout['currency'] != quote['currency'] ||
          checkout['engine'] != quote['engine']) {
        throw StateError(
          'Checkout total changed. Check saved payment before retrying.',
        );
      }
      final callback = await gateway.open(checkout, profile);
      saved['callback'] = callback;
      await service.save(profile.id, saved);
      check();
      progress('Verifying payment…');
      return await accept(
        await service.post('verify', {
          'quote_id': quote['quote_id'],
          ...callback,
        }),
      );
    } finally {
      _running = false;
    }
  }
}
