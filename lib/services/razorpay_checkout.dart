import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../models/customer_profile.dart';

/// Raised when the customer explicitly closes/cancels the Razorpay sheet.
class CheckoutCancelled extends StateError {
  CheckoutCancelled() : super('Payment cancelled.');
}

class RazorpayCheckout {
  Razorpay? _sdk;
  Completer<Map<String, String>>? _pending;
  String? _order;
  static Map<String, dynamic> options(
    Map<String, dynamic> data,
    CustomerProfile profile,
  ) {
    final mode = data['mode'];
    final key = data['key_id'];
    final order = data['razorpay_order_id'];
    final magic = data['engine'] == 'magic';
    if (!['live', 'test'].contains(mode) ||
        key is! String ||
        !RegExp('^rzp_${mode}_[A-Za-z0-9]+\$').hasMatch(key) ||
        order is! String ||
        !RegExp(r'^order_[A-Za-z0-9]+$').hasMatch(order) ||
        data['amount'] is! int ||
        (data['amount'] as int) < 100 ||
        data['currency'] != 'INR' ||
        (magic &&
            (data['one_click_checkout'] != true ||
                data['show_coupons'] != true ||
                mode != 'live')) ||
        (!magic &&
            (data['one_click_checkout'] == true ||
                data['show_coupons'] == true))) {
      throw StateError(
        'Invalid server checkout details. Do not pay again; check payment status.',
      );
    }
    return {
      'key': key,
      'order_id': order,
      'amount': data['amount'],
      'currency': 'INR',
      'name': 'Sri Krishna Pearls',
      'description': mode == 'live'
          ? 'Order payment'
          : 'Test payment - no real charge',
      'prefill': {
        'name': profile.displayName,
        'email': profile.email,
        'contact': profile.phone,
      },
      'theme': {'color': '#a66042'},
      if (magic) 'one_click_checkout': true,
      if (magic) 'show_coupons': true,
    };
  }

  Future<Map<String, String>> open(
    Map<String, dynamic> data,
    CustomerProfile profile,
  ) {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      throw StateError('Open the Android or iPhone app to pay with Razorpay.');
    }
    if (_pending != null) throw StateError('A payment is already open.');
    final config = options(data, profile);
    _sdk ??= Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        final p = _pending;
        final order = _order;
        _pending = null;
        _order = null;
        if (p == null || p.isCompleted) return;
        if (r.orderId != order ||
            r.paymentId?.isNotEmpty != true ||
            r.signature?.isNotEmpty != true) {
          p.completeError(
            StateError(
              'Incomplete payment response. Check saved payment before retrying.',
            ),
          );
        } else {
          p.complete({
            'razorpay_order_id': r.orderId!,
            'razorpay_payment_id': r.paymentId!,
            'razorpay_signature': r.signature!,
          });
        }
      })
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        if (r.code == 0) {
          _failError(CheckoutCancelled());
        } else {
          _fail(
            'Payment was not completed. Tap Check Out to retry or verify the previous payment.',
          );
        }
      })
      ..on(
        Razorpay.EVENT_EXTERNAL_WALLET,
        (ExternalWalletResponse r) => _fail(
          'Continue in your wallet, then tap Check Out to check payment status.',
        ),
      );
    final pending = Completer<Map<String, String>>();
    _pending = pending;
    _order = config['order_id'] as String;
    try {
      _sdk!.open(config);
    } catch (_) {
      _fail('Unable to open Razorpay. Check saved payment before retrying.');
    }
    return pending.future;
  }

  void _fail(String message) {
    _failError(StateError(message));
  }

  void _failError(Object error) {
    final p = _pending;
    _pending = null;
    _order = null;
    if (p != null && !p.isCompleted) p.completeError(error);
  }

  void dispose() {
    _sdk?.clear();
    _sdk = null;
    _fail('Checkout closed. Check saved payment on return.');
  }
}
