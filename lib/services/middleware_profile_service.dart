import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/shopify_config.dart';
import 'shopify_auth_service.dart';

/// The server identifies the customer from the Shopify access token.
class MiddlewareProfileService {
  MiddlewareProfileService({
    http.Client? client,
    Future<String> Function()? tokenProvider,
    Uri? baseUri,
    Future<Directory> Function()? directoryProvider,
  }) : _client = client ?? http.Client(),
       _token = tokenProvider ?? ShopifyAuthService().checkoutAccessToken,
       _baseUri = baseUri ?? Uri.parse(ShopifyConfig.middlewareBaseUrl),
       _directory = directoryProvider ?? getApplicationSupportDirectory;

  final http.Client _client;
  final Future<String> Function() _token;
  final Uri _baseUri;
  final Future<Directory> Function() _directory;

  Uri _endpoint(String suffix) {
    if (_baseUri.host.isEmpty ||
        _baseUri.userInfo.isNotEmpty ||
        _baseUri.hasQuery ||
        _baseUri.hasFragment ||
        (_baseUri.scheme != 'https' &&
            !(kDebugMode && _baseUri.scheme == 'http'))) {
      throw StateError('Secure middleware URL is not configured.');
    }
    return Uri.parse(
      '${_baseUri.toString().replaceFirst(RegExp(r'/+$'), '')}/api/mobile/profile/$suffix',
    );
  }

  Future<void> upload(File image) async {
    if (!await image.exists()) {
      throw StateError('Selected image was not found.');
    }
    if (await image.length() > 3 * 1024 * 1024) {
      throw StateError('Profile image must be smaller than 3 MB.');
    }
    final request = http.MultipartRequest('POST', _endpoint('image'))
      ..followRedirects = false
      ..headers['Authorization'] = 'Bearer ${await _token()}'
      ..headers['Accept'] = 'application/json'
      ..files.add(await http.MultipartFile.fromPath('image', image.path));
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 40)),
    );
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      final status = response.statusCode;
      if (status == 413) {
        throw StateError(
          'The server rejected this profile photo as too large (HTTP 413).',
        );
      }
      if (status >= 300 && status < 400) {
        throw StateError(
          'Profile image request was redirected (HTTP $status). Check the middleware URL and deployment.',
        );
      }
      final contentType = response.headers['content-type']?.split(';').first;
      final typeHint = contentType == null || contentType.isEmpty
          ? ''
          : ' ($contentType)';
      throw StateError(
        'Profile image endpoint returned an unexpected response (HTTP $status$typeHint). Check profile storage setup and server logs.',
      );
    }
    if (response.statusCode != 200 || body is! Map || body['status'] != true) {
      throw StateError(
        body is Map && body['message'] is String
            ? body['message'] as String
            : 'Could not save the profile image. Please try again.',
      );
    }
  }

  /// Save authenticated bytes locally. A unique name prevents old image-cache
  /// entries from appearing when a customer changes their photo.
  Future<String?> download(String customerId) async {
    final id = RegExp(r'^gid://shopify/Customer/([1-9][0-9]{0,24})$')
        .firstMatch(customerId);
    if (id == null) throw StateError('Customer identity is unavailable.');
    final request = http.Request('GET', _endpoint('image-file'))
      ..followRedirects = false
      ..headers['Authorization'] = 'Bearer ${await _token()}'
      ..headers['Accept'] = 'image/jpeg, image/png, image/webp';
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 404) {
      await response.stream.listen((_) {}).cancel();
      return null;
    }
    final mime = (response.headers['content-type'] ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();
    if (response.statusCode != 200 ||
        !{'image/jpeg', 'image/png', 'image/webp'}.contains(mime) ||
        (response.contentLength != null &&
            response.contentLength! > 3 * 1024 * 1024)) {
      await response.stream.listen((_) {}).cancel();
      throw StateError('Unable to load your profile image.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (bytes.length + chunk.length > 3 * 1024 * 1024) {
        throw StateError('Profile image is too large.');
      }
      bytes.add(chunk);
    }
    if (bytes.isEmpty) throw StateError('Unable to load your profile image.');
    final directory = await _directory();
    final extension = switch (mime) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final file = File(
      '${directory.path}${Platform.pathSeparator}customer_${id[1]}_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    final imageBytes = normalizeImageBytes(bytes.takeBytes());
    await file.writeAsBytes(imageBytes, flush: true);
    return file.path;
  }

  /// Some PHP hosting/output-buffer setups prepend whitespace before a
  /// binary image response. Remove only that harmless prefix when the image
  /// signature is immediately after it, so Android's decoder gets real bytes.
  static Uint8List normalizeImageBytes(Uint8List bytes) {
    bool startsAt(int offset, List<int> signature) {
      if (offset + signature.length > bytes.length) return false;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[offset + index] != signature[index]) return false;
      }
      return true;
    }

    var offset = 0;
    while (offset < bytes.length &&
        const {0x09, 0x0a, 0x0d, 0x20}.contains(bytes[offset])) {
      offset++;
    }
    final isPng = startsAt(offset, const [
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    final isJpeg = startsAt(offset, const [0xff, 0xd8, 0xff]);
    final isWebp =
        startsAt(offset, const [0x52, 0x49, 0x46, 0x46]) &&
        startsAt(offset + 8, const [0x57, 0x45, 0x42, 0x50]);
    if (offset > 0 && (isPng || isJpeg || isWebp)) {
      return Uint8List.sublistView(bytes, offset);
    }
    return bytes;
  }

  void close() => _client.close();
}
