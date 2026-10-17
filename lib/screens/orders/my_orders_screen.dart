import 'package:flutter/material.dart';

import '../../services/account_store.dart';
import '../../services/middleware_checkout_service.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({this.service, super.key});
  final MiddlewareCheckoutService? service;
  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late final _api = widget.service ?? MiddlewareCheckoutService();
  late final _customer = AccountStore.instance.profile?.id;
  final _orders = <Map<String, dynamic>>[];
  bool _busy = false;
  int? _next;
  String? _error;
  @override
  void initState() {
    super.initState();
    AccountStore.instance.addListener(_accountChanged);
    _load(refresh: true);
  }

  bool get _sameAccount =>
      AccountStore.instance.isAuthenticated &&
      _customer != null &&
      AccountStore.instance.profile?.id == _customer;
  void _accountChanged() {
    if (!_sameAccount) {
      setState(() {
        _orders.clear();
        _next = null;
        _error = 'Sign in to view your orders.';
      });
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_busy) return;
    if (!_sameAccount) {
      setState(() => _error = 'Sign in to view your orders.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _api.post('orders', {
        'offset': refresh ? 0 : _next ?? 0,
      });
      if (!mounted || !_sameAccount) return;
      if (response['source'] != 'middleware' || response['orders'] is! List) {
        throw StateError('Middleware orders endpoint needs updating.');
      }
      final rows = (response['orders'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      setState(() {
        if (refresh) _orders.clear();
        for (final row in rows) {
          if (!_orders.any((o) => o['id'] == row['id'])) _orders.add(row);
        }
        _next = response['has_more'] == true
            ? response['next_offset'] as int?
            : null;
      });
    } catch (e) {
      if (mounted && _sameAccount) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'Unable to load orders. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    AccountStore.instance.removeListener(_accountChanged);
    if (widget.service == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfffdfcfb),
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'My Orders',
        style: TextStyle(
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w600,
          color: Color(0xff574335),
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Refresh orders',
          onPressed: _busy ? null : () => _load(refresh: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: _busy ? null : () => _load(refresh: true),
              child: const Text('Retry'),
            ),
          ],
          if (!_busy && _error == null && _orders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No orders found yet.', textAlign: TextAlign.center),
            ),
          for (final order in _orders)
            _OrderCard(key: ValueKey(order['id']), order: order),
          if (_next != null)
            TextButton(
              onPressed: _busy ? null : () => _load(),
              child: const Text('Load more'),
            ),
        ],
      ),
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, super.key});
  final Map<String, dynamic> order;
  static const _brown = Color(0xffa66042);
  String _money(dynamic value) {
    final amount = double.tryParse('$value');
    final text = amount == null ? '$value' : amount.toStringAsFixed(2);
    return '${order['currency'] == 'INR' ? '₹' : '${order['currency']} '}$text';
  }

  Widget _badge(String prefix, dynamic status, bool positive) {
    final raw = (status ?? '').toString().replaceAll('_', ' ').trim();
    final value = raw.isEmpty ? 'unknown' : raw;
    final color = positive ? const Color(0xff27714f) : _brown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: positive ? const Color(0xffedf7f0) : const Color(0xfffaf0e9),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$prefix: ${value[0].toUpperCase()}${value.substring(1)}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = order['items'] as List? ?? [];
    final date = DateTime.tryParse(order['created_at']?.toString() ?? '');
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateText = date == null
        ? ''
        : '${date.day} ${months[date.month - 1]} ${date.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffeddfd6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xfffaf0e9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: _brown,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['name']?.toString() ?? 'Order',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Color(0xff574335),
                        ),
                      ),
                      if (dateText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'Placed on $dateText',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _badge(
                  'Payment',
                  order['payment_status'],
                  order['payment_status'] == 'paid',
                ),
                _badge(
                  'Delivery',
                  order['fulfillment_status'],
                  order['fulfillment_status'] == 'fulfilled',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xfff1e9e2)),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'].toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Qty ${item['quantity']} · Unit price ${_money(item['price'])}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Container(
            color: const Color(0xfffffaf6),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Order total',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xff574335),
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    _money(order['total']),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _brown,
                    ),
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
