class CheckoutCoupon {
  const CheckoutCoupon({
    required this.code,
    required this.title,
    required this.description,
    this.applicable,
    this.eligibilityMessage = '',
  });
  final String code;
  final String title;
  final String description;
  final bool? applicable;
  final String eligibilityMessage;

  // Merchant's publicly advertised website coupon. Never enumerate private
  // Admin discount codes or invent eligibility/savings from the code's name.
  static const publicFallback = [
    CheckoutCoupon(
      code: 'SKP5',
      title: 'Website coupon',
      description: '5% off entire order • Minimum purchase of ₹1,500.00',
    ),
  ];

  static List<CheckoutCoupon> published(List<dynamic> nodes, DateTime now) {
    String field(Map node, String name) =>
        node[name] is Map ? node[name]['value']?.toString().trim() ?? '' : '';
    final offers = <String, CheckoutCoupon>{};
    for (final node in nodes.whereType<Map>()) {
      final code = field(node, 'code');
      final start = DateTime.tryParse(field(node, 'startsAt'));
      final end = DateTime.tryParse(field(node, 'endsAt'));
      if (field(node, 'active') != 'true' ||
          !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$').hasMatch(code) ||
          (start != null && now.isBefore(start)) ||
          (end != null && !now.isBefore(end))) {
        continue;
      }
      // API supplies newest-created entries first. Keep the newest definition
      // of duplicate codes rather than overwriting it with an older banner.
      offers.putIfAbsent(
        code.toUpperCase(),
        () => CheckoutCoupon(
          code: code,
          title: field(node, 'heading'),
          description: field(node, 'subtitle'),
        ),
      );
    }
    return List.unmodifiable(offers.values);
  }
}

class CheckoutPriceSummary {
  const CheckoutPriceSummary({
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.currencyCode,
    this.shipping,
    this.includedTax,
    this.discountCodes = const [],
    this.automaticDiscountTitle,
  });

  final double subtotal;
  final double discount;
  final double total;
  final String currencyCode;
  final double? shipping;
  final double? includedTax;
  final List<String> discountCodes;
  final String? automaticDiscountTitle;

  CheckoutPriceSummary copyWith({
    List<String>? discountCodes,
    String? automaticDiscountTitle,
    double? shipping,
    double? includedTax,
  }) => CheckoutPriceSummary(
    subtotal: subtotal,
    discount: discount,
    total: total,
    currencyCode: currencyCode,
    shipping: shipping ?? this.shipping,
    includedTax: includedTax ?? this.includedTax,
    discountCodes: discountCodes ?? this.discountCodes,
    automaticDiscountTitle:
        automaticDiscountTitle ?? this.automaticDiscountTitle,
  );
}
