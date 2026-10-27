/// Riverpod wiring for the app's shared dependencies.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/tasks/data/task_repository.dart';
import 'network/api_client.dart';
import 'storage/token_store.dart';

/// Platform secure storage (Keychain on iOS, Keystore-backed on Android).
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Token persistence.
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(secureStorageProvider)),
);

/// One HTTP client for the whole app, closed when the provider is disposed.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// API client. When refresh fails, the app returns to the signed-out state.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(httpClientProvider),
    ref.watch(tokenStoreProvider),
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
});

/// Authentication repository.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);

/// Task repository.
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(apiClientProvider)),
);
