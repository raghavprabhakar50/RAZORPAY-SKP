import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class AddressLookupResult {
  const AddressLookupResult({
    this.address1 = '',
    this.address2 = '',
    this.address3 = '',
    this.city = '',
    this.stateCode = '',
    this.countryCode = '',
    this.postalCode = '',
  });

  final String address1;
  final String address2;
  final String address3;
  final String city;
  final String stateCode;
  final String countryCode;
  final String postalCode;
}

class AddressLookupService {
  AddressLookupService();

  Geocoding? _geocoding;
  Geocoding get _geocoder => _geocoding ??= Geocoding();

  Future<AddressLookupResult> fromCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Please turn on location services and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Location permission is required to pick your address.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is blocked. Enable it from app settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    final places = await _geocoder.placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (places.isEmpty) {
      throw StateError('Address was not found for your current location.');
    }
    return _fromPlacemark(places.first);
  }

  Future<AddressLookupResult> fromPostalCode({
    required String postalCode,
    required String countryName,
  }) async {
    final pin = postalCode.trim();
    if (pin.isEmpty) throw StateError('Enter a PIN or postal code first.');
    final places = await _geocoder.placemarkFromAddress('$pin, $countryName');
    if (places.isEmpty) {
      throw StateError('No city or state was found for this postal code.');
    }
    return _fromPlacemark(places.first);
  }

  static AddressLookupResult _fromPlacemark(Placemark place) {
    final countryCode = _value(place.isoCountryCode).toUpperCase();
    final city = _first([
      place.locality,
      place.subAdministrativeArea,
      place.subLocality,
    ]);
    return AddressLookupResult(
      address1: _first([place.street, place.name]),
      address2: _value(place.subLocality),
      address3: _value(place.subAdministrativeArea) == city
          ? ''
          : _value(place.subAdministrativeArea),
      city: city,
      stateCode: _stateCode(_value(place.administrativeArea), countryCode),
      countryCode: countryCode,
      postalCode: _value(place.postalCode),
    );
  }

  static String _value(String? value) => value?.trim() ?? '';

  static String _first(Iterable<String?> values) {
    for (final value in values) {
      final text = _value(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _stateCode(String state, String countryCode) {
    if (state.isEmpty || countryCode != 'IN') return state;
    return _indiaStateCodes[state.toLowerCase()] ?? state;
  }

  static const _indiaStateCodes = <String, String>{
    'andaman and nicobar islands': 'AN',
    'andhra pradesh': 'AP',
    'arunachal pradesh': 'AR',
    'assam': 'AS',
    'bihar': 'BR',
    'chandigarh': 'CH',
    'chhattisgarh': 'CG',
    'dadra and nagar haveli and daman and diu': 'DH',
    'delhi': 'DL',
    'goa': 'GA',
    'gujarat': 'GJ',
    'haryana': 'HR',
    'himachal pradesh': 'HP',
    'jammu and kashmir': 'JK',
    'jharkhand': 'JH',
    'karnataka': 'KA',
    'kerala': 'KL',
    'ladakh': 'LA',
    'lakshadweep': 'LD',
    'madhya pradesh': 'MP',
    'maharashtra': 'MH',
    'manipur': 'MN',
    'meghalaya': 'ML',
    'mizoram': 'MZ',
    'nagaland': 'NL',
    'odisha': 'OD',
    'puducherry': 'PY',
    'punjab': 'PB',
    'rajasthan': 'RJ',
    'sikkim': 'SK',
    'tamil nadu': 'TN',
    'telangana': 'TS',
    'tripura': 'TR',
    'uttar pradesh': 'UP',
    'uttarakhand': 'UK',
    'west bengal': 'WB',
  };
}
