import 'package:flutter/material.dart';

import '../models/checkout_coupon.dart';

class CartCouponOffers extends StatelessWidget {
  const CartCouponOffers({
    required this.coupons,
    required this.selectedCode,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<CheckoutCoupon> coupons;
  final String? selectedCode;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  static const _brown = Color(0xffa66042);

  Future<void> _viewAll(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      minChildSize: .3,
      maxChildSize: .9,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text(
            'Available coupons',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${coupons.length} public offers · Eligibility checked at checkout',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          for (final coupon in coupons)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffc8cbd4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _offerRow(coupon, () {
                    onChanged(selectedCode == coupon.code ? null : coupon.code);
                    Navigator.of(sheetContext).pop();
                  }),
                  if (coupon.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      coupon.description,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    ),
  );

  Widget _offerRow(CheckoutCoupon coupon, VoidCallback select) => Row(
    children: [
      const Icon(Icons.discount_rounded, color: Color(0xff00bd83), size: 30),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              coupon.code,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: 1,
                color: Color(0xff080f20),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              coupon.title.isEmpty ? 'Public website offer' : coupon.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xff00a979)),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      TextButton(
        key: ValueKey('coupon-use-${coupon.code}'),
        onPressed: enabled ? select : null,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xff080f20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: Text(
          selectedCode == coupon.code ? 'Remove' : 'Apply',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (coupons.isEmpty) return const SizedBox.shrink();
    final preview = coupons.firstWhere(
      (c) => c.code == selectedCode,
      orElse: () => coupons.first,
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffc8cbd4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff080f20),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    selectedCode == null ? 'COUPON OFFER' : 'SELECTED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: enabled ? () => _viewAll(context) : null,
                  style: TextButton.styleFrom(foregroundColor: _brown),
                  child: Text('View available (${coupons.length})'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 16),
            child: _offerRow(
              preview,
              () =>
                  onChanged(selectedCode == preview.code ? null : preview.code),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xffeef0fc),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
            ),
            child: Column(
              children: [
                const SizedBox(
                  height: 7,
                  width: double.infinity,
                  child: CustomPaint(painter: _CouponPerforation()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview.description.isEmpty
                              ? 'Eligibility and discount verified at Shopify checkout.'
                              : preview.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xff62718f),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          preview.code,
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            color: Color(0xff18213b),
                          ),
                        ),
                      ),
                      if (selectedCode != null && preview.code != selectedCode)
                        IconButton(
                          onPressed: enabled ? () => onChanged(null) : null,
                          tooltip: 'Remove selected coupon',
                          icon: const Icon(Icons.close, size: 18),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponPerforation extends CustomPainter {
  const _CouponPerforation();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (double x = 8; x < size.width; x += 20) {
      canvas.drawCircle(Offset(x, 0), 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
