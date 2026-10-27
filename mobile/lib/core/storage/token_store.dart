/// Stores access and refresh tokens using platform secure storage.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provides asynchronous operations for authentication-token storage.
class TokenStore {
  /// Creates a token store backed by [storage].
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  /// Reads the current access token, if one is stored.
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  /// Reads the current refresh token, if one is stored.
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  /// Saves both authentication tokens.
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  /// Removes both tokens during logout or session expiration.
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
