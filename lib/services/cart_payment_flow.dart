import '../models/cart_item.dart';
import '../models/customer_profile.dart';
import 'middleware_checkout_service.dart';
import 'razorpay_checkout.dart';

class CheckoutPriceChanged extends StateError {
  CheckoutPriceChanged(int amount, String currency)
    : super(
        'Order total changed to $currency ${(amount / 100).toStringAsFixed(2)}. Review the total before tapping Check Out again.',
      );
}

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
      // Captured money still needs the middleware to confirm the Shopify
      // order. Keep the recovery reference until both are confirmed.
      if (state['paid'] == true && state['order_created'] == true) {
        await service.clear(profile.id);
      }
      return state;
    }

    try {
      check();
      progress('Preparing payment...');
      // Every tap is a new checkout attempt. Never restore or inspect a
      // previous quote/payment here; the current cart is always repriced.
      await service.clear(profile.id);
      Map<String, dynamic> saved = {
        'request': MiddlewareCheckoutService.payload(
          items,
          profile,
          MiddlewareCheckoutService.requestId(),
          discountCode: discountCode,
        ),
      };
      await service.save(profile.id, saved);
      check();
      if (saved['quote'] == null) {
        progress('Checking final total...');
        final quote = await service.post(
          'quote',
          Map<String, dynamic>.from(saved['request'] as Map),
        );
        check();
        saved['quote'] = quote;
        await service.save(profile.id, saved);
      }
      var quote = Map<String, dynamic>.from(saved['quote'] as Map);
      onQuote?.call({
        ...quote,
        'requested_discount_code': saved['request']?['discount_code'] ?? '',
      });
      check();
      progress('Opening Razorpay...');
      Map<String, dynamic> checkout;
      try {
        checkout = await service.post('start', {'quote_id': quote['quote_id']});
      } on StateError catch (error) {
        // If the short-lived quote expires between quote and start, simply
        // create a fresh quote for this same cart. No previous checkout is
        // inspected or required.
        if (error.message !=
            'Your price review expired. Review the cart again.') {
          rethrow;
        }
        await service.clear(profile.id);
        saved = {
          'request': MiddlewareCheckoutService.payload(
            items,
            profile,
            MiddlewareCheckoutService.requestId(),
            discountCode: discountCode,
          ),
        };
        await service.save(profile.id, saved);
        check();
        progress('Checking final total...');
        quote = await service.post(
          'quote',
          Map<String, dynamic>.from(saved['request'] as Map),
        );
        check();
        saved['quote'] = quote;
        await service.save(profile.id, saved);
        progress('Opening Razorpay...');
        checkout = await service.post('start', {'quote_id': quote['quote_id']});
      }
      check();
      if (checkout['mode'] != quote['mode'] ||
          checkout['amount'] != quote['amount'] ||
          checkout['currency'] != quote['currency'] ||
          checkout['engine'] != quote['engine']) {
        throw StateError(
          'Checkout total changed. Check saved payment before retrying.',
        );
      }
      Map<String, String> callback;
      try {
        callback = await gateway.open(checkout, profile);
      } on CheckoutCancelled {
        // Cancellation means no payment was submitted. Keep the cart and
        // clear only the local recovery pointer so the next tap creates a
        // fresh payment request.
        await service.clear(profile.id);
        return {'cancelled': true, 'paid': false};
      }
      saved['callback'] = callback;
      await service.save(profile.id, saved);
      check();
      progress('Verifying payment...');
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
