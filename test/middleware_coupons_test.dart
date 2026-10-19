import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sri_krishna_pearls_mobile/services/middleware_checkout_service.dart';

void main() {
  test(
    'coupons use authenticated middleware endpoint, keep order and deduplicate',
    () async {
      final service = MiddlewareCheckoutService(
        baseUri: Uri.parse('https://middleware.example.invalid'),
        tokenProvider: () async => 'customer-token-fixture',
        client: MockClient((r) async {
          expect(r.url.path, '/api/mobile/coupons');
          expect(r.method, 'POST');
          expect(r.headers['Authorization'], 'Bearer customer-token-fixture');
          expect(jsonDecode(r.body), {});
          return http.Response(
            jsonEncode({
              'status': true,
              'data': {
                'source': 'middleware',
                'coupons': [
                  {
                    'code': 'NEW',
                    'title': '10% off selected products',
                    'description': 'Minimum purchase applies',
                  },
                  {'code': 'OLD', 'title': 'Older offer'},
                  {'code': 'new'},
                  {'code': ''},
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final coupons = await service.fetchCoupons();
      expect(coupons.map((c) => c.code), ['NEW', 'OLD']);
      expect(coupons.first.description, 'Minimum purchase applies');
      service.close();
    },
  );
  test('empty coupons remain empty and authorization errors are not replaced by SKP5', () async {
    for (final denied in [false, true]) {
      final service = MiddlewareCheckoutService(
        baseUri: Uri.parse('https://middleware.example.invalid'),
        tokenProvider: () async => 'customer-token-fixture',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(
              denied
                  ? {'status': false, 'message': 'Please sign in to continue.'}
                  : {
                      'status': true,
                      'data': {'source': 'middleware', 'coupons': []},
                    },
            ),
            denied ? 401 : 200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      if (denied) {
        await expectLater(service.fetchCoupons(), throwsStateError);
      } else {
        expect(await service.fetchCoupons(), isEmpty);
      }
      service.close();
    }
  });
}
