/// Sends authenticated requests to the versioned Task Manager API.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/token_store.dart';

/// A safe API failure with a user-displayable message.
class ApiException implements Exception {
  /// Creates an API exception.
  const ApiException(this.message, {this.statusCode});

  /// A safe message that does not contain server internals or tokens.
  final String message;

  /// HTTP status code, when available.
  final int? statusCode;

  @override
  String toString() => message;
}

/// Builds requests, attaches tokens, and performs one refresh-and-retry cycle.
class ApiClient {
  /// Creates a client with injectable HTTP and token-storage dependencies.
  ApiClient(
    this._http,
    this._tokens, {
    this.onSessionExpired,
    String? baseUrl,
  }) : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _http;
  final TokenStore _tokens;
  final String _baseUrl;

  /// Called after refresh fails and local credentials have been cleared.
  final VoidCallback? onSessionExpired;

  Future<bool>? _refreshInFlight;

  /// Routes that never carry an access token and never trigger a refresh.
  static const _publicPaths = {
    'auth/refresh',
    'auth/login',
    'auth/register',
    'auth/logout',
  };

  static const _sessionExpired = 'Tu sesión expiró. Inicia sesión de nuevo.';

  /// Builds a fresh request so the request can safely be retried.
  ///
  /// CORRECCIÓN respecto al documento: los parámetros de consulta se pasan en
  /// [query]. Si se incluyen en [path] ("tasks?page=1"), `Uri.replace(path:)`
  /// codifica el `?` como `%3F` y el servidor responde 404.
  Future<http.Request> _buildRequest(
    String method,
    String path,
    Map<String, dynamic>? body, {
    Map<String, String>? query,
    bool withAuth = true,
  }) async {
    final base = Uri.parse(_baseUrl);
    final joinedPath = '${base.path}/$path'.replaceAll(RegExp(r'/+'), '/');
    final uri = base.replace(
      path: joinedPath,
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final request = http.Request(method, uri)
      ..headers['accept'] = 'application/json'
      ..headers['content-type'] = 'application/json';

    if (withAuth) {
      final token = await _tokens.readAccessToken();
      if (token != null) request.headers['authorization'] = 'Bearer $token';
    }
    if (body != null) request.body = jsonEncode(body);
    return request;
  }

  /// Sends a JSON request and returns its decoded response object.
  ///
  /// A protected request that receives 401 may refresh once and retry once.
  /// Throws [ApiException] for unsuccessful responses or malformed JSON.
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final isPublic = _publicPaths.contains(path);
    var response = await _sendRequest(
      await _buildRequest(method, path, body, query: query, withAuth: !isPublic),
    );

    if (response.statusCode == 401 && !isPublic) {
      if (!await _refreshTokens()) {
        throw const ApiException(_sessionExpired, statusCode: 401);
      }
      response = await _sendRequest(
        await _buildRequest(method, path, body, query: query),
      );
      if (response.statusCode == 401) {
        // Even the fresh token was rejected: end the local session.
        await _expireSession();
        throw const ApiException(_sessionExpired, statusCode: 401);
      }
    }

    return _decodeResponse(response, isPublic: isPublic);
  }

  Future<http.Response> _sendRequest(http.Request request) async {
    try {
      final streamed = await _http.send(request).timeout(
            const Duration(seconds: 15),
          );
      return await http.Response.fromStream(streamed);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }

  /// Maps a status code to a fixed, safe message (never the raw server body).
  String _messageFor(int status, {required bool isPublic}) {
    switch (status) {
      case 400:
        return 'Revisa los datos enviados.';
      case 401:
        return isPublic ? 'Correo o contraseña incorrectos.' : _sessionExpired;
      case 404:
        return 'No se encontró el elemento. Puede que ya se haya eliminado.';
      case 409:
        return 'Ya existe una cuenta con ese correo.';
      case 429:
        return 'Demasiados intentos. Espera unos minutos y vuelve a intentarlo.';
      default:
        return 'No se pudo completar la solicitud. Inténtalo de nuevo.';
    }
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response, {
    required bool isPublic,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _messageFor(response.statusCode, isPublic: isPublic),
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 204 || response.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('El servidor devolvió datos inesperados.');
      }
      return decoded;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('El servidor devolvió datos inesperados.');
    }
  }

  /// Refreshes credentials once; concurrent callers share the same operation
  /// (single-flight), so an old refresh token is never sent twice.
  Future<bool> _refreshTokens() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    try {
      final refreshToken = await _tokens.readRefreshToken();
      if (refreshToken == null) throw const ApiException('Session expired.');
      final request = await _buildRequest(
        'POST',
        'auth/refresh',
        {'refreshToken': refreshToken},
        withAuth: false,
      );
      final response = await _sendRequest(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ApiException('Session expired.');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = decoded['accessToken'];
      final newRefreshToken = decoded['refreshToken'];
      if (accessToken is! String || newRefreshToken is! String) {
        throw const ApiException('Session expired.');
      }
      await _tokens.saveTokens(accessToken, newRefreshToken);
      return true;
    } catch (_) {
      await _expireSession();
      return false;
    }
  }

  Future<void> _expireSession() async {
    await _tokens.clear();
    onSessionExpired?.call();
  }
}
