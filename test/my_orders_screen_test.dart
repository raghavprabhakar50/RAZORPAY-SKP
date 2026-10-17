import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sri_krishna_pearls_mobile/models/customer_profile.dart';
import 'package:sri_krishna_pearls_mobile/screens/orders/my_orders_screen.dart';
import 'package:sri_krishna_pearls_mobile/services/account_store.dart';
import 'package:sri_krishna_pearls_mobile/services/middleware_checkout_service.dart';

void main() {
  setUp(
    () => AccountStore.instance.debugSetAuthenticated(
      true,
      profile: const CustomerProfile(
        id: 'gid://shopify/Customer/42',
        email: 'fixture@example.invalid',
        firstName: 'Fixture',
      ),
    ),
  );
  tearDown(() => AccountStore.instance.debugSetAuthenticated(false));
  testWidgets(
    'My Orders uses authenticated middleware records, supports paging and clears on logout',
    (tester) async {
      var calls = 0;
      final api = MiddlewareCheckoutService(
        baseUri: Uri.parse('https://middleware.example.invalid'),
        tokenProvider: () async => 'customer_fixture',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/mobile/orders');
          expect(request.headers['Authorization'], 'Bearer customer_fixture');
          final input = jsonDecode(request.body);
          expect(input.containsKey('customer_id'), false);
          final offset = input['offset'];
          return http.Response(
            jsonEncode({
              'status': true,
              'data': {
                'source': 'middleware',
                'orders': [
                  {
                    'id': '$offset',
                    'name': '#ORDER$offset',
                    'created_at': '2026-10-17T10:00:00Z',
                    'payment_status': 'paid',
                    'fulfillment_status': 'unfulfilled',
                    'currency': 'INR',
                    'total': '100.00',
                    'items': [
                      {'title': 'Pearls', 'quantity': 1, 'price': '100.00'},
                    ],
                  },
                ],
                'has_more': offset == 0,
                'next_offset': offset == 0 ? 20 : null,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(MaterialApp(home: MyOrdersScreen(service: api)));
      await tester.pumpAndSettle();
      expect(find.text('#ORDER0'), findsOneWidget);
      expect(find.textContaining('Synced via middleware'), findsNothing);
      expect(find.text('Payment: Paid'), findsOneWidget);
      expect(find.text('Order total'), findsOneWidget);
      expect(find.text('₹100.00'), findsOneWidget);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('#ORDER20'), findsOneWidget);
      expect(calls, 2);
      AccountStore.instance.debugSetAuthenticated(false);
      await tester.pumpAndSettle();
      expect(find.text('#ORDER0'), findsNothing);
      expect(find.text('Sign in to view your orders.'), findsOneWidget);
    },
  );
  testWidgets(
    'failed middleware request shows Retry and no fabricated orders',
    (tester) async {
      final api = MiddlewareCheckoutService(
        baseUri: Uri.parse('https://middleware.example.invalid'),
        tokenProvider: () async => 'fixture',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'status': false, 'message': 'Orders unavailable'}),
            503,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(MaterialApp(home: MyOrdersScreen(service: api)));
      await tester.pumpAndSettle();
      expect(find.text('Orders unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No orders found yet.'), findsNothing);
    },
  );
}
