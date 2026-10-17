import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sri_krishna_pearls_mobile/services/middleware_checkout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  MiddlewareCheckoutService service(Map<String, dynamic> state) =>
      MiddlewareCheckoutService(
        baseUri: Uri.parse('https://middleware.example.invalid'),
        tokenProvider: () async => 'customer_token',
        client: MockClient((request) async {
          expect(request.url.path, endsWith('/status'));
          return http.Response(
            jsonEncode({'status': true, 'data': state}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

  test(
    'server-confirmed unpaid native attempt is archived without recovery popup',
    () async {
      for (final status in ['created', 'failed', 'not_started']) {
        final api = service({'paid': false, 'payment_status': status});
        await api.save('customer', {
          'quote': {'quote_id': 'quote_$status'},
          'callback': {'signature': 'saved_evidence'},
        });
        await api.prepareHostedCheckout('customer');
        expect(await api.restore('customer'), null);
        final all = await const FlutterSecureStorage().readAll();
        final archived = all.entries
            .where((e) => e.key.endsWith('_native_archive_quote_$status'))
            .single;
        expect(
          jsonDecode(archived.value)['callback']['signature'],
          'saved_evidence',
        );
        api.close();
      }
    },
  );

  test('paid, authorized and ambiguous payments stay saved and block a second checkout', () async {
    for (final state in [
      {'paid': true, 'payment_status': 'captured'},
      {'paid': false, 'payment_status': 'authorized'},
      {'paid': false, 'payment_status': 'creation_unknown'},
      {'payment_status': 'created'},
    ]) {
      final api = service(state);
      await api.save('customer', {
        'quote': {'quote_id': 'quote_saved'},
      });
      await expectLater(
        api.prepareHostedCheckout('customer'),
        throwsStateError,
      );
      expect(await api.restore('customer'), isNotNull);
      api.close();
    }
  });
}
