import 'package:flutter_test/flutter_test.dart';
import 'package:sri_krishna_pearls_mobile/models/customer_profile.dart';

void main() {
  test('customer profile parses Shopify identity and default address', () {
    final profile = CustomerProfile.fromGraphQl({
      'id': 'gid://shopify/Customer/1',
      'firstName': 'Asha',
      'lastName': 'Rao',
      'emailAddress': {'emailAddress': 'asha@example.com'},
      'phoneNumber': {'phoneNumber': '+919999999999'},
      'imageUrl': 'https://example.com/avatar.jpg',
      'defaultAddress': {
        'id': 'gid://shopify/CustomerAddress/1',
        'address1': 'Pearl Street',
        'city': 'Hyderabad',
        'zoneCode': 'TS',
        'countryCode': 'IN',
        'zip': '500001',
        'phoneNumber': '+918888888888',
      },
    });

    expect(profile.displayName, 'Asha Rao');
    expect(profile.email, 'asha@example.com');
    expect(profile.phone, '+918888888888');
    expect(profile.city, 'Hyderabad');
  });

  test('cached profile round trips without changing immutable email', () {
    const original = CustomerProfile(
      email: 'customer@example.com',
      firstName: 'Krishna',
      localImagePath: '/profile/photo.jpg',
      countryCode: 'IN',
    );

    final restored = CustomerProfile.fromJson(original.toJson());

    expect(restored.email, original.email);
    expect(restored.firstName, original.firstName);
    expect(restored.localImagePath, original.localImagePath);
  });

  test('checkout readiness requires contact and delivery details', () {
    const incomplete = CustomerProfile(
      email: 'customer@example.com',
      firstName: 'Krishna',
      countryCode: 'IN',
    );
    const complete = CustomerProfile(
      email: 'customer@example.com',
      firstName: 'Krishna',
      lastName: 'Rao',
      phone: '+919999999999',
      address1: '12 Pearl Street',
      address2: 'Banjara Hills',
      address3: 'Near City Mall',
      city: 'Hyderabad',
      zoneCode: 'TS',
      countryCode: 'IN',
      zip: '500034',
    );

    expect(incomplete.isCheckoutReady, isFalse);
    expect(complete.isCheckoutReady, isTrue);
    expect(complete.formattedAddress, contains('Near City Mall'));
    expect(
      CustomerProfile.fromJson(complete.toJson()).address3,
      'Near City Mall',
    );
  });
}
