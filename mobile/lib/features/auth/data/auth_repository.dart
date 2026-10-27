/// Implements login, registration, and best-effort logout with the API.
library;

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';

/// Coordinates authentication requests and local token persistence.
class AuthRepository {
  /// Creates a repository using [client] and [tokens].
  AuthRepository(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  /// Logs in and persists the returned access and refresh tokens.
  Future<void> login(String email, String password) async {
    final result = await _client.send('POST', 'auth/login', body: {
      'email': email.trim(),
      'password': password,
    });
    await _savePair(result);
  }

  /// Registers an account and persists its returned token pair.
  Future<void> register(String email, String password) async {
    final result = await _client.send('POST', 'auth/register', body: {
      'email': email.trim(),
      'password': password,
    });
    await _savePair(result);
  }

  Future<void> _savePair(Map<String, dynamic> result) async {
    final accessToken = result['accessToken'];
    final refreshToken = result['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw const ApiException('El servidor devolvió datos inesperados.');
    }
    await _tokens.saveTokens(accessToken, refreshToken);
  }

  /// Attempts server-side logout and always clears local tokens.
  Future<void> logout() async {
    try {
      final refreshToken = await _tokens.readRefreshToken();
      if (refreshToken != null) {
        await _client.send('POST', 'auth/logout', body: {
          'refreshToken': refreshToken,
        });
      }
    } on ApiException {
      // Local logout still proceeds when the server cannot be reached.
    } finally {
      await _tokens.clear();
    }
  }

  /// Revokes every session of this user on the server, then clears local tokens.
  Future<void> logoutAll() async {
    try {
      await _client.send('POST', 'auth/logout-all');
    } on ApiException {
      // Still clear locally.
    } finally {
      await _tokens.clear();
    }
  }

  /// Whether a refresh token is stored (a session may be restorable).
  Future<bool> hasSession() async => (await _tokens.readRefreshToken()) != null;
}
