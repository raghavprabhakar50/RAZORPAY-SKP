import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models/customer_profile.dart';
import 'middleware_profile_service.dart';
import 'push_notification_service.dart';
import 'shopify_auth_service.dart';

class AccountStore extends ChangeNotifier {
  AccountStore._() {
    PushNotificationService.instance.tokenChanged.stream.listen((_) {
      final current = _profile;
      if (_authenticated && current != null) {
        unawaited(PushNotificationService.instance.syncWithCustomer(current));
      }
    });
  }

  static final AccountStore instance = AccountStore._();
  static const _profileKey = 'shopify_customer_profile_v1';
  static const _storage = FlutterSecureStorage();

  final ShopifyAuthService _authService = ShopifyAuthService();
  final MiddlewareProfileService _profileService = MiddlewareProfileService();
  CustomerProfile? _profile;
  Future<void>? _initializing;
  bool _authenticated = false;
  int _sessionGeneration = 0;
  int _imageRevision = 0;

  CustomerProfile? get profile => _profile;
  bool get isAuthenticated => _authenticated;
  bool get isGuest => !_authenticated;

  @visibleForTesting
  void debugSetAuthenticated(bool value, {CustomerProfile? profile}) {
    _sessionGeneration++;
    _authenticated = value;
    _profile = value ? profile : null;
    _initializing = SynchronousFuture<void>(null);
    notifyListeners();
  }

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      final cached = await _readCachedProfile();
      _authenticated = await _authService.restoreSession();
      if (_authenticated) {
        try {
          _profile = await _authService.fetchCustomerProfile(fallback: cached);
          await _authService.ensureSessionMarker();
          await _persistProfile();
          unawaited(
            PushNotificationService.instance.syncWithCustomer(_profile!),
          );
          unawaited(_refreshProfileImage(_profile!, _sessionGeneration));
        } catch (_) {
          // Cached details were bound to this login session before use.
          _profile = cached;
        }
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
    _sessionGeneration++;
    _authenticated = await _authService.hasSession();
    if (!_authenticated) {
      throw StateError('Shopify login session was not created.');
    }
    _profile = CustomerProfile(
      email: fallbackEmail.trim().toLowerCase(),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone.trim(),
    );
    await _persistProfile();
    await refreshProfile();
    if (_profile != null) {
      unawaited(PushNotificationService.instance.syncWithCustomer(_profile!));
    }
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
    final generation = _sessionGeneration;
    try {
      final profile = await _authService.fetchCustomerProfile(
        fallback: _profile,
      );
      if (!_authenticated || generation != _sessionGeneration) return;
      _profile = profile;
      await _authService.ensureSessionMarker();
      await _persistProfile();
      notifyListeners();
      unawaited(PushNotificationService.instance.syncWithCustomer(profile));
      unawaited(_refreshProfileImage(profile, generation));
    } catch (_) {
      if (!silent) rethrow;
    }
  }

  Future<void> _refreshProfileImage(
    CustomerProfile profile,
    int generation,
  ) async {
    final revision = _imageRevision;
    try {
      final path = await _profileService.download(profile.id);
      if (!_authenticated ||
          generation != _sessionGeneration ||
          revision != _imageRevision ||
          _profile?.id != profile.id) {
        if (path != null) await _deleteFile(path);
        return;
      }
      if (path != null) {
        final previous = _profile?.localImagePath;
        _profile = _profile!.copyWith(localImagePath: path);
        await _persistProfile();
        notifyListeners();
        if (previous != null && previous != path) await _deleteFile(previous);
      }
    } catch (_) {
      // Shopify profile and a previously cached image remain usable offline.
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
    final customerId = _profile?.id ?? '';
    final id = RegExp(r'^gid://shopify/Customer/([1-9][0-9]{0,24})$')
        .firstMatch(customerId);
    if (id == null) {
      throw StateError('Please refresh your profile and try again.');
    }
    final generation = _sessionGeneration;
    _imageRevision++;
    final extension = sourcePath.split('.').last.toLowerCase();
    final safeExtension =
        const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? (extension == 'jpeg' ? 'jpg' : extension)
        : 'jpg';
    final directory = await getApplicationSupportDirectory();
    final destinationPath =
        '${directory.path}${Platform.pathSeparator}customer_${id[1]}_${DateTime.now().microsecondsSinceEpoch}.$safeExtension';
    final selectedBytes = MiddlewareProfileService.normalizeImageBytes(
      await source.readAsBytes(),
    );
    final destination = File(destinationPath);
    await destination.writeAsBytes(selectedBytes, flush: true);
    try {
      // Upload the same normalized bytes that the app previews. This also
      // avoids platform-specific picker/output-buffer prefixes on iOS.
      await _profileService.upload(destination);
    } catch (_) {
      await _deleteFile(destinationPath);
      rethrow;
    }
    if (!_authenticated ||
        generation != _sessionGeneration ||
        _profile?.id != customerId) {
      await _deleteFile(destinationPath);
      return;
    }
    final previousPath = _profile?.localImagePath;
    if (!_authenticated ||
        generation != _sessionGeneration ||
        _profile?.id != customerId) {
      await _deleteFile(destinationPath);
      return;
    }
    _profile = _profile!.copyWith(localImagePath: destinationPath);
    final savedProfile = _profile!;
    await _persistProfile();
    notifyListeners();
    if (previousPath != null && previousPath != destinationPath) {
      await _deleteFile(previousPath);
    }
    // Confirm/read the middleware copy and refresh the same account on this
    // device. Other devices fetch this image when their profile refreshes.
    unawaited(_refreshProfileImage(savedProfile, generation));
  }

  Future<void> signOut() async {
    _sessionGeneration++;
    final imagePath = _profile?.localImagePath;
    if (_authenticated) {
      await PushNotificationService.instance
          .unregisterCurrentCustomer()
          .timeout(const Duration(seconds: 5), onTimeout: () {});
    }
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
    final marker = await _authService.sessionMarker();
    return cachedProfileForSession(decoded, marker);
  }

  @visibleForTesting
  static CustomerProfile? cachedProfileForSession(
    dynamic decoded,
    String? marker,
  ) {
    if (decoded is! Map<String, dynamic> ||
        marker == null ||
        marker.isEmpty ||
        decoded['sessionMarker'] != marker) {
      return null;
    }
    return CustomerProfile.fromJson(decoded);
  }

  Future<void> _persistProfile() async {
    final profile = _profile;
    if (profile == null) {
      await _storage.delete(key: _profileKey);
      return;
    }
    final marker = await _authService.sessionMarker();
    if (marker == null || marker.isEmpty) return;
    await _storage.write(
      key: _profileKey,
      value: jsonEncode({...profile.toJson(), 'sessionMarker': marker}),
    );
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
