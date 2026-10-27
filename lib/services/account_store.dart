import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models/customer_profile.dart';
import 'shopify_auth_service.dart';

class AccountStore extends ChangeNotifier {
  AccountStore._();

  static final AccountStore instance = AccountStore._();
  static const _profileKey = 'shopify_customer_profile_v1';
  static const _storage = FlutterSecureStorage();

  final ShopifyAuthService _authService = ShopifyAuthService();
  CustomerProfile? _profile;
  Future<void>? _initializing;
  bool _authenticated = false;

  CustomerProfile? get profile => _profile;
  bool get isAuthenticated => _authenticated;
  bool get isGuest => !_authenticated;

  @visibleForTesting
  void debugSetAuthenticated(bool value, {CustomerProfile? profile}) {
    _authenticated = value;
    _profile = value ? profile : null;
    _initializing = SynchronousFuture<void>(null);
    notifyListeners();
  }

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      _profile = await _readCachedProfile();
      _authenticated = await _authService.restoreSession();
      if (_authenticated) {
        notifyListeners();
        await refreshProfile(silent: true);
      } else {
        _profile = null;
      }
    } catch (_) {
      _authenticated = false;
      _profile = null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> completeAuthentication({
    required String fallbackEmail,
    String? expectedEmail,
    String firstName = '',
    String lastName = '',
    String phone = '',
  }) async {
    _authenticated = await _authService.hasSession();
    if (!_authenticated) {
      throw StateError('Shopify login session was not created.');
    }
    _profile = CustomerProfile(
      email: fallbackEmail.trim().toLowerCase(),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone.trim(),
      localImagePath: _profile?.localImagePath,
    );
    await _persistProfile();
    await refreshProfile();
    final requested = (expectedEmail ?? fallbackEmail).trim().toLowerCase();
    final returned = _profile?.email.trim().toLowerCase() ?? '';
    if (requested.isNotEmpty && returned != requested) {
      await signOut();
      throw StateError(
        'Shopify opened a different account ($returned). Sign out of the Shopify browser account and try $requested again.',
      );
    }
    notifyListeners();
  }

  Future<void> continueAsGuest() async {
    await signOut();
  }

  Future<void> refreshProfile({bool silent = false}) async {
    if (!_authenticated) return;
    try {
      _profile = await _authService.fetchCustomerProfile(fallback: _profile);
      await _persistProfile();
      notifyListeners();
    } catch (_) {
      if (!silent) rethrow;
    }
  }

  Future<void> updateProfile(CustomerProfile next) async {
    if (!_authenticated) throw StateError('Please login to update profile.');
    await _authService.updateCustomerName(
      firstName: next.firstName,
      lastName: next.lastName,
    );
    await _authService.updateCustomerAddress(next);
    _profile = next.copyWith(email: _profile?.email ?? next.email);
    await _persistProfile();
    await refreshProfile(silent: true);
    notifyListeners();
  }

  Future<void> saveProfileImage(String sourcePath) async {
    if (!_authenticated) throw StateError('Please login to update profile.');
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('Selected image was not found.');
    }
    final directory = await getApplicationSupportDirectory();
    final extension = sourcePath.contains('.')
        ? '.${sourcePath.split('.').last.toLowerCase()}'
        : '.jpg';
    final destinationPath =
        '${directory.path}${Platform.pathSeparator}customer_profile$extension';
    final previousPath = _profile?.localImagePath;
    if (previousPath != null && previousPath != destinationPath) {
      await _deleteFile(previousPath);
    }
    await source.copy(destinationPath);
    _profile = (_profile ?? const CustomerProfile()).copyWith(
      localImagePath: destinationPath,
    );
    await _persistProfile();
    notifyListeners();
  }

  Future<void> signOut() async {
    final imagePath = _profile?.localImagePath;
    _authenticated = false;
    _profile = null;
    notifyListeners();
    try {
      await _authService.signOut();
    } catch (_) {
      // Local logout still clears every cached identity value.
    }
    try {
      await _storage.delete(key: _profileKey);
    } catch (_) {
      // In-memory logout must still complete if device storage is unavailable.
    }
    if (imagePath != null) await _deleteFile(imagePath);
  }

  Future<CustomerProfile?> _readCachedProfile() async {
    final stored = await _storage.read(key: _profileKey);
    if (stored == null || stored.isEmpty) return null;
    final decoded = jsonDecode(stored);
    return decoded is Map<String, dynamic>
        ? CustomerProfile.fromJson(decoded)
        : null;
  }

  Future<void> _persistProfile() async {
    final profile = _profile;
    if (profile == null) {
      await _storage.delete(key: _profileKey);
      return;
    }
    await _storage.write(key: _profileKey, value: jsonEncode(profile.toJson()));
  }

  static Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A stale local avatar must not block logout or replacement.
    }
  }
}
