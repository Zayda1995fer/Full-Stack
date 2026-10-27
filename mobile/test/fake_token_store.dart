/// In-memory TokenStore for tests (no platform channels).
library;

import 'package:mobile/core/storage/token_store.dart';

/// Records reads and writes so tests can assert on them.
class FakeTokenStore implements TokenStore {
  /// Creates a fake with optional initial tokens.
  FakeTokenStore({this.accessToken, this.refreshToken});

  /// Current access token.
  String? accessToken;

  /// Current refresh token.
  String? refreshToken;

  /// Last access token passed to [saveTokens].
  String? savedAccessToken;

  /// Last refresh token passed to [saveTokens].
  String? savedRefreshToken;

  /// Whether [clear] was called.
  bool cleared = false;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens(String access, String refresh) async {
    savedAccessToken = access;
    savedRefreshToken = refresh;
    accessToken = access;
    refreshToken = refresh;
  }

  @override
  Future<void> clear() async {
    cleared = true;
    accessToken = null;
    refreshToken = null;
  }
}
