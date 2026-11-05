import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sri_krishna_pearls_mobile/models/customer_profile.dart';
import 'package:sri_krishna_pearls_mobile/services/account_store.dart';
import 'package:sri_krishna_pearls_mobile/services/middleware_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'authenticated avatar is fetched into customer-specific private cache',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'skp_avatar_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final service = MiddlewareProfileService(
        baseUri: Uri.parse('https://middleware.example.invalid'),
        tokenProvider: () async => 'customer-token',
        directoryProvider: () async => directory,
        client: MockClient((request) async {
          expect(request.url.path, '/api/mobile/profile/image-file');
          expect(request.headers['authorization'], 'Bearer customer-token');
          expect(request.followRedirects, isFalse);
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }),
      );
      addTearDown(service.close);
      final path = await service.download('gid://shopify/Customer/123');
      expect(path, contains('customer_123_'));
      expect(await File(path!).readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'avatar upload authenticates and never sends customer identity from app',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'skp_avatar_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final image = File('${directory.path}/photo.jpg');
      await image.writeAsBytes([1, 2, 3]);
      final service = MiddlewareProfileService(
        baseUri: Uri.parse('https://middleware.example.invalid'),
        tokenProvider: () async => 'customer-token',
        client: MockClient((request) async {
          expect(request.url.path, '/api/mobile/profile/image');
          expect(request.headers['authorization'], 'Bearer customer-token');
          expect(request.followRedirects, isFalse);
          expect(request.body, contains('name="image"'));
          expect(request.body, isNot(contains('customer_id')));
          return http.Response(
            '{"status":true,"data":{}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(service.close);
      await service.upload(image);
    },
  );

  test('a new Shopify identity never inherits previous customer avatar', () {
    const previous = CustomerProfile(
      id: 'gid://shopify/Customer/1',
      email: 'first@example.com',
      localImagePath: '/first/photo.jpg',
    );
    final current = CustomerProfile.fromGraphQl({
      'id': 'gid://shopify/Customer/2',
      'emailAddress': {'emailAddress': 'second@example.com'},
    }, fallback: previous);
    expect(current.email, 'second@example.com');
    expect(current.localImagePath, isNull);
  });

  test('offline cached profile belongs only to its saved login session', () {
    final saved = {
      'id': 'gid://shopify/Customer/1',
      'email': 'first@example.com',
      'localImagePath': '/first/photo.jpg',
      'sessionMarker': 'login-one',
    };
    expect(
      AccountStore.cachedProfileForSession(saved, 'login-one')?.localImagePath,
      '/first/photo.jpg',
    );
    expect(AccountStore.cachedProfileForSession(saved, 'login-two'), isNull);
    expect(AccountStore.cachedProfileForSession(saved, null), isNull);
  });
}
