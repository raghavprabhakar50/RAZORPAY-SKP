class CustomerProfile {
  const CustomerProfile({
    this.id = '',
    this.email = '',
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.imageUrl,
    this.localImagePath,
    this.addressId,
    this.address1 = '',
    this.address2 = '',
    this.address3 = '',
    this.city = '',
    this.zoneCode = '',
    this.countryCode = 'IN',
    this.zip = '',
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String? imageUrl;
  final String? localImagePath;
  final String? addressId;
  final String address1;
  final String address2;
  final String address3;
  final String city;
  final String zoneCode;
  final String countryCode;
  final String zip;

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? (email.isEmpty ? 'Customer' : email) : name;
  }

  String get formattedAddress => [
    address1,
    address2,
    address3,
    city,
    zoneCode,
    zip,
    countryCode,
  ].where((value) => value.trim().isNotEmpty).join(', ');

  bool get isCheckoutReady {
    final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
    return firstName.trim().isNotEmpty &&
        lastName.trim().isNotEmpty &&
        phoneDigits.length >= 8 &&
        phoneDigits.length <= 15 &&
        address1.trim().isNotEmpty &&
        city.trim().isNotEmpty &&
        zoneCode.trim().isNotEmpty &&
        countryCode.trim().length == 2 &&
        zip.trim().isNotEmpty;
  }

  CustomerProfile copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? imageUrl,
    String? localImagePath,
    String? addressId,
    String? address1,
    String? address2,
    String? address3,
    String? city,
    String? zoneCode,
    String? countryCode,
    String? zip,
  }) {
    return CustomerProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      addressId: addressId ?? this.addressId,
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      address3: address3 ?? this.address3,
      city: city ?? this.city,
      zoneCode: zoneCode ?? this.zoneCode,
      countryCode: countryCode ?? this.countryCode,
      zip: zip ?? this.zip,
    );
  }

  factory CustomerProfile.fromGraphQl(
    Map<String, dynamic> customer, {
    CustomerProfile? fallback,
  }) {
    final emailAddress = customer['emailAddress'];
    final phoneNumber = customer['phoneNumber'];
    final address = customer['defaultAddress'];
    final emailData = emailAddress is Map<String, dynamic>
        ? emailAddress
        : null;
    final phoneData = phoneNumber is Map<String, dynamic> ? phoneNumber : null;
    final addressData = address is Map<String, dynamic> ? address : null;

    String value(String key, {String fallbackValue = ''}) {
      final remote = customer[key]?.toString().trim() ?? '';
      return remote.isEmpty ? fallbackValue : remote;
    }

    String addressValue(String key, {String fallbackValue = ''}) {
      final remote = addressData?[key]?.toString().trim() ?? '';
      return remote.isEmpty ? fallbackValue : remote;
    }

    final remoteAddress2 = addressValue(
      'address2',
      fallbackValue: fallback?.address2 ?? '',
    );
    final addressLines = _restoreLocalAddress3(
      remoteAddress2,
      fallback?.address3 ?? '',
    );

    return CustomerProfile(
      id: value('id', fallbackValue: fallback?.id ?? ''),
      email: emailData?['emailAddress']?.toString().trim().isNotEmpty == true
          ? emailData!['emailAddress'].toString().trim()
          : fallback?.email ?? '',
      firstName: value('firstName', fallbackValue: fallback?.firstName ?? ''),
      lastName: value('lastName', fallbackValue: fallback?.lastName ?? ''),
      phone: addressValue('phoneNumber').isNotEmpty
          ? addressValue('phoneNumber')
          : phoneData?['phoneNumber']?.toString().trim().isNotEmpty == true
          ? phoneData!['phoneNumber'].toString().trim()
          : fallback?.phone ?? '',
      imageUrl: customer['imageUrl']?.toString().trim().isNotEmpty == true
          ? customer['imageUrl'].toString().trim()
          : fallback?.imageUrl,
      localImagePath: fallback?.localImagePath,
      addressId: addressData?['id']?.toString() ?? fallback?.addressId,
      address1: addressValue(
        'address1',
        fallbackValue: fallback?.address1 ?? '',
      ),
      address2: addressLines.$1,
      address3: addressLines.$2,
      city: addressValue('city', fallbackValue: fallback?.city ?? ''),
      zoneCode: addressValue(
        'zoneCode',
        fallbackValue: fallback?.zoneCode ?? '',
      ),
      countryCode: addressValue(
        'countryCode',
        fallbackValue: fallback?.countryCode ?? 'IN',
      ),
      zip: addressValue('zip', fallbackValue: fallback?.zip ?? ''),
    );
  }

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    String value(String key) => json[key]?.toString() ?? '';
    return CustomerProfile(
      id: value('id'),
      email: value('email'),
      firstName: value('firstName'),
      lastName: value('lastName'),
      phone: value('phone'),
      imageUrl: _optional(json['imageUrl']),
      localImagePath: _optional(json['localImagePath']),
      addressId: _optional(json['addressId']),
      address1: value('address1'),
      address2: value('address2'),
      address3: value('address3'),
      city: value('city'),
      zoneCode: value('zoneCode'),
      countryCode: value('countryCode').isEmpty ? 'IN' : value('countryCode'),
      zip: value('zip'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'imageUrl': imageUrl,
    'localImagePath': localImagePath,
    'addressId': addressId,
    'address1': address1,
    'address2': address2,
    'address3': address3,
    'city': city,
    'zoneCode': zoneCode,
    'countryCode': countryCode,
    'zip': zip,
  };

  static String? _optional(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static (String, String) _restoreLocalAddress3(
    String remoteAddress2,
    String localAddress3,
  ) {
    final thirdLine = localAddress3.trim();
    if (thirdLine.isEmpty) return (remoteAddress2, '');
    final suffix = ', $thirdLine';
    if (remoteAddress2.endsWith(suffix)) {
      return (
        remoteAddress2.substring(0, remoteAddress2.length - suffix.length),
        thirdLine,
      );
    }
    if (remoteAddress2 == thirdLine) return ('', thirdLine);
    return (remoteAddress2, thirdLine);
  }
}
