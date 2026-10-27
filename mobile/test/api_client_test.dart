/// Verifies ApiClient refresh-and-retry behavior using MockClient.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';

import 'fake_token_store.dart';

void main() {
  test('refreshes once on 401 and retries the original request once', () async {
    var originalCalls = 0;
    var refreshCalls = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshCalls++;
        return http.Response(jsonEncode({
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
        }), 200);
      }
      originalCalls++;
      if (originalCalls == 1) return http.Response('{}', 401);
      expect(request.headers['authorization'], 'Bearer new-access');
      return http.Response(jsonEncode({'items': []}), 200);
    });
    final tokens = FakeTokenStore(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
    );
    final client = ApiClient(mock, tokens);

    await client.send('GET', 'tasks');

    expect(refreshCalls, 1);
    expect(originalCalls, 2);
    expect(tokens.savedAccessToken, 'new-access');
    expect(tokens.savedRefreshToken, 'new-refresh');
  });

  test('failed refresh clears tokens and notifies session expiry', () async {
    var expired = 0;
    final mock = MockClient((request) async => http.Response('{}', 401));
    final tokens = FakeTokenStore(accessToken: 'a', refreshToken: 'r');
    final client = ApiClient(mock, tokens, onSessionExpired: () => expired++);

    await expectLater(
      client.send('GET', 'tasks'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(tokens.cleared, isTrue);
    expect(expired, 1);
  });

  test('concurrent 401s share a single refresh (single-flight)', () async {
    var refreshCalls = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(
          jsonEncode({'accessToken': 'new', 'refreshToken': 'new-r'}),
          200,
        );
      }
      if (request.headers['authorization'] == 'Bearer new') {
        return http.Response(jsonEncode({'items': []}), 200);
      }
      return http.Response('{}', 401);
    });
    final client = ApiClient(mock, FakeTokenStore(accessToken: 'old', refreshToken: 'r'));

    await Future.wait([
      client.send('GET', 'tasks'),
      client.send('GET', 'tasks'),
      client.send('GET', 'tasks'),
    ]);
    expect(refreshCalls, 1);
  });

  test('query parameters are encoded as a query, not into the path', () async {
    late Uri seen;
    final mock = MockClient((request) async {
      seen = request.url;
      return http.Response(jsonEncode({'items': []}), 200);
    });
    final client = ApiClient(
      mock,
      FakeTokenStore(accessToken: 'a', refreshToken: 'r'),
      baseUrl: 'http://localhost:3000/api/v1',
    );

    await client.send('GET', 'tasks', query: {'page': '1', 'limit': '20'});
    expect(seen.path, '/api/v1/tasks');
    expect(seen.queryParameters, {'page': '1', 'limit': '20'});
  });

  test('errors never expose raw server bodies or tokens', () async {
    final mock = MockClient((request) async =>
        http.Response('{"stack":"at secret.js:1","token":"leak"}', 500));
    final client = ApiClient(mock, FakeTokenStore(accessToken: 'secret-token'));

    try {
      await client.send('GET', 'tasks');
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.message, isNot(contains('stack')));
      expect(e.message, isNot(contains('leak')));
      expect(e.message, isNot(contains('secret-token')));
      expect(e.statusCode, 500);
    }
  });

  test('login path never triggers a refresh on 401', () async {
    var refreshCalls = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) refreshCalls++;
      return http.Response('{}', 401);
    });
    final client = ApiClient(mock, FakeTokenStore());

    await expectLater(
      client.send('POST', 'auth/login', body: {'email': 'a@b.c', 'password': 'x'}),
      throwsA(isA<ApiException>()),
    );
    expect(refreshCalls, 0);
  });

  test('204 responses decode to an empty map', () async {
    final mock = MockClient((request) async => http.Response('', 204));
    final client = ApiClient(mock, FakeTokenStore(accessToken: 'a'));
    expect(await client.send('DELETE', 'tasks/abc'), isEmpty);
  });
}
