import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/customer_profile.dart';
import '../../services/account_store.dart';
import '../../services/address_lookup_service.dart';
import '../../widgets/account_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({this.requireCompletion = false, super.key});

  final bool requireCompletion;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _brown = Color(0xff9d6043);
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _address3 = TextEditingController();
  final _city = TextEditingController();
  final _stateCode = TextEditingController();
  final _zip = TextEditingController();
  final _picker = ImagePicker();
  final _addressLookup = AddressLookupService();
  Country _country = CountryParser.parseCountryCode('IN');
  Timer? _pinLookupTimer;
  bool _saving = false;
  bool _uploadingImage = false;
  bool _locating = false;
  bool _lookingUpPin = false;

  @override
  void initState() {
    super.initState();
    _fill(AccountStore.instance.profile);
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      await AccountStore.instance.refreshProfile();
      if (mounted) _fill(AccountStore.instance.profile);
    } catch (_) {
      // Cached profile remains editable when the network is unavailable.
    }
  }

  void _fill(CustomerProfile? profile) {
    if (profile == null) return;
    final country = CountryParser.tryParseCountryCode(profile.countryCode);
    if (country != null) _country = country;
    _firstName.text = profile.firstName;
    _lastName.text = profile.lastName;
    _email.text = profile.email;
    _phone.text = _nationalPhone(profile.phone, _country.phoneCode);
    _address1.text = profile.address1;
    _address2.text = profile.address2;
    _address3.text = profile.address3;
    _city.text = profile.city;
    _stateCode.text = profile.zoneCode;
    _zip.text = profile.zip;
    if (mounted) setState(() {});
  }

  Future<void> _pickImage() async {
    if (_uploadingImage) return;
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (image == null) return;
      if (!mounted) return;
      setState(() => _uploadingImage = true);
      await AccountStore.instance.saveProfileImage(image.path);
      if (mounted) _showMessage('Profile photo saved.');
    } catch (error) {
      if (mounted) {
        final message = _message(error);
        if (error is PlatformException &&
            message.toLowerCase().contains('permission')) {
          _showSettingsMessage(message);
        } else {
          _showMessage(message);
        }
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _selectCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      favorite: const ['IN', 'AE', 'US', 'GB'],
      countryListTheme: const CountryListThemeData(
        bottomSheetHeight: 560,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        inputDecoration: InputDecoration(
          labelText: 'Search country',
          prefixIcon: Icon(Icons.search_rounded),
          border: OutlineInputBorder(),
        ),
      ),
      onSelect: (country) => setState(() => _country = country),
    );
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    FocusScope.of(context).unfocus();
    setState(() => _locating = true);
    try {
      final address = await _addressLookup.fromCurrentLocation();
      if (!mounted) return;
      _applyAddress(address, includeLines: true);
      _showMessage('Address filled from your current location.');
    } catch (error) {
      if (mounted) {
        final message = _message(error);
        if (message.toLowerCase().contains('blocked')) {
          _showSettingsMessage(message);
        } else if (message.toLowerCase().contains('turn on location')) {
          _showLocationSettingsMessage(message);
        } else {
          _showMessage(message);
        }
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onPinChanged(String value) {
    _pinLookupTimer?.cancel();
    final digits = value.trim();
    final ready = _country.countryCode == 'IN'
        ? digits.length == 6
        : digits.length >= 3;
    if (!ready) return;
    _pinLookupTimer = Timer(
      const Duration(milliseconds: 800),
      () => _lookupPin(silent: true),
    );
  }

  Future<void> _lookupPin({bool silent = false}) async {
    if (_lookingUpPin || _zip.text.trim().isEmpty) return;
    setState(() => _lookingUpPin = true);
    try {
      final address = await _addressLookup.fromPostalCode(
        postalCode: _zip.text,
        countryName: _country.name,
      );
      if (!mounted) return;
      _applyAddress(address, includeLines: false);
      if (!silent) _showMessage('City and state filled from postal code.');
    } catch (error) {
      if (mounted && !silent) _showMessage(_message(error));
    } finally {
      if (mounted) setState(() => _lookingUpPin = false);
    }
  }

  void _applyAddress(
    AddressLookupResult address, {
    required bool includeLines,
  }) {
    if (includeLines) {
      if (address.address1.isNotEmpty) _address1.text = address.address1;
      if (address.address2.isNotEmpty) _address2.text = address.address2;
      if (address.address3.isNotEmpty) _address3.text = address.address3;
    }
    if (address.city.isNotEmpty) _city.text = address.city;
    if (address.stateCode.isNotEmpty) _stateCode.text = address.stateCode;
    if (address.postalCode.isNotEmpty) _zip.text = address.postalCode;
    final country = CountryParser.tryParseCountryCode(address.countryCode);
    if (country != null) _country = country;
    setState(() {});
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final current = AccountStore.instance.profile ?? const CustomerProfile();
    final next = current.copyWith(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      phone:
          '+${_country.phoneCode}${_phone.text.replaceAll(RegExp(r'\D'), '')}',
      address1: _address1.text.trim(),
      address2: _address2.text.trim(),
      address3: _address3.text.trim(),
      city: _city.text.trim(),
      zoneCode: _stateCode.text.trim().toUpperCase(),
      countryCode: _country.countryCode,
      zip: _zip.text.trim(),
    );
    try {
      await AccountStore.instance.updateProfile(next);
      if (!mounted) return;
      if (widget.requireCompletion) {
        Navigator.of(context).pop(true);
      } else {
        _showMessage('Profile updated successfully.');
      }
    } catch (error) {
      if (mounted) _showMessage(_message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSettingsMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: Geolocator.openAppSettings,
          ),
        ),
      );
  }

  void _showLocationSettingsMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Turn on',
            onPressed: Geolocator.openLocationSettings,
          ),
        ),
      );
  }

  static String _message(Object error) {
    final value = error.toString();
    return value.startsWith('Bad state: ') ? value.substring(11) : value;
  }

  static String _nationalPhone(String value, String phoneCode) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (value.trim().startsWith('+') && digits.startsWith(phoneCode)) {
      return digits.substring(phoneCode.length);
    }
    return digits;
  }

  @override
  void dispose() {
    _pinLookupTimer?.cancel();
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _address1,
      _address2,
      _address3,
      _city,
      _stateCode,
      _zip,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffdfcfb),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          widget.requireCompletion ? 'Complete Profile' : 'My Profile',
          style: const TextStyle(
            color: Color(0xff574335),
            fontFamily: 'Fraunces',
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          children: [
            if (widget.requireCompletion) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xfffff4df),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffffd48b)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, color: _brown, size: 21),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Complete your contact and delivery details before checkout.',
                        style: TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const AccountAvatar(radius: 52),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: IconButton.filled(
                      tooltip: 'Change profile picture',
                      onPressed: _uploadingImage ? null : _pickImage,
                      style: IconButton.styleFrom(
                        backgroundColor: _brown,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const _SectionTitle('Personal details'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ProfileField(
                    controller: _firstName,
                    label: 'First name',
                    icon: Icons.person_outline_rounded,
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProfileField(
                    controller: _lastName,
                    label: 'Last name',
                    validator: _required,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ProfileField(
              controller: _email,
              label: 'Email address',
              icon: Icons.email_outlined,
              readOnly: true,
              helperText: 'Email cannot be changed here',
            ),
            const SizedBox(height: 14),
            _ProfileField(
              controller: _phone,
              label: 'Phone number',
              keyboardType: TextInputType.phone,
              inputFormatters: const [_DigitsOnlyFormatter()],
              prefix: InkWell(
                onTap: _selectCountry,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _country.flagEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 6),
                      Text('+${_country.phoneCode}'),
                      const Icon(Icons.arrow_drop_down_rounded),
                    ],
                  ),
                ),
              ),
              validator: _phoneValidator,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(child: _SectionTitle('Delivery address')),
                TextButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(_locating ? 'Locating...' : 'Use location'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProfileField(
              controller: _address1,
              label: 'Address line 1',
              hintText: 'House / flat / building',
              icon: Icons.home_outlined,
              validator: _required,
            ),
            const SizedBox(height: 14),
            _ProfileField(
              controller: _address2,
              label: 'Address line 2 (optional)',
              hintText: 'Street / area / locality',
              icon: Icons.signpost_outlined,
            ),
            const SizedBox(height: 14),
            _ProfileField(
              controller: _address3,
              label: 'Address line 3 (optional)',
              hintText: 'Landmark / district',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 14),
            _CountrySelector(country: _country, onTap: _selectCountry),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ProfileField(
                    controller: _city,
                    label: 'City',
                    icon: Icons.location_city_outlined,
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProfileField(
                    controller: _stateCode,
                    label: 'State / province code',
                    textCapitalization: TextCapitalization.characters,
                    validator: _required,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ProfileField(
              controller: _zip,
              label: 'PIN / postal code',
              icon: Icons.local_post_office_outlined,
              keyboardType: TextInputType.text,
              inputFormatters: const [_PostalCodeFormatter()],
              onChanged: _onPinChanged,
              onFieldSubmitted: (_) => _lookupPin(),
              suffix: IconButton(
                tooltip: 'Find city and state',
                onPressed: _lookingUpPin ? null : _lookupPin,
                icon: _lookingUpPin
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
              ),
              validator: _required,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _brown,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : widget.requireCompletion
                      ? 'Save & Continue'
                      : 'Save Profile',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _required(String? value) =>
      value?.trim().isEmpty == true ? 'Required' : null;

  String? _phoneValidator(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return 'Required';
    final internationalLength = digits.length + _country.phoneCode.length;
    return internationalLength >= 8 && internationalLength <= 15
        ? null
        : 'Enter a valid number';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xff574335),
        fontFamily: 'Fraunces',
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CountrySelector extends StatelessWidget {
  const _CountrySelector({required this.country, required this.onTap});

  final Country country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _decoration('Country'),
        child: Row(
          children: [
            Text(country.flagEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Text('${country.name} (${country.countryCode})')),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    this.icon,
    this.prefix,
    this.suffix,
    this.readOnly = false,
    this.helperText,
    this.hintText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.inputFormatters,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final Widget? prefix;
  final Widget? suffix;
  final bool readOnly;
  final String? helperText;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      decoration: _decoration(
        label,
        helperText: helperText,
        hintText: hintText,
        prefixIcon: prefix ?? (icon == null ? null : Icon(icon)),
        suffixIcon: suffix,
        fillColor: readOnly ? const Color(0xfff1efed) : null,
      ),
    );
  }
}

InputDecoration _decoration(
  String label, {
  String? helperText,
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  Color? fillColor,
}) {
  return InputDecoration(
    labelText: label,
    helperText: helperText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fillColor ?? const Color(0xfffffbf5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffe5d4c8)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xff9d6043), width: 1.5),
    ),
  );
}

class _DigitsOnlyFormatter extends TextInputFormatter {
  const _DigitsOnlyFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return FilteringTextInputFormatter.digitsOnly.formatEditUpdate(
      oldValue,
      newValue,
    );
  }
}

class _PostalCodeFormatter extends TextInputFormatter {
  const _PostalCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 -]'))
        .formatEditUpdate(oldValue, newValue);
  }
}
