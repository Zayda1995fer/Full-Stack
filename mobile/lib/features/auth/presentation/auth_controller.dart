/// Signed-in / signed-out application state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../tasks/presentation/task_controller.dart';

/// Authentication status shown by the app's root widget.
enum AuthStatus {
  /// Still reading secure storage at startup.
  unknown,

  /// No session: show the login screen.
  signedOut,

  /// Session available: show the task list.
  signedIn,
}

/// Owns the authentication status and the login/logout actions.
class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    // State cannot change during build, so restoration runs right after.
    Future.microtask(_restore);
    return AuthStatus.unknown;
  }

  Future<void> _restore() async {
    bool hasSession;
    try {
      hasSession = await ref.read(authRepositoryProvider).hasSession();
    } catch (_) {
      hasSession = false;
    }
    if (state == AuthStatus.unknown) {
      state = hasSession ? AuthStatus.signedIn : AuthStatus.signedOut;
    }
  }

  /// Logs in. Throws [ApiException] with a safe message on failure.
  Future<void> login(String email, String password) async {
    await ref.read(authRepositoryProvider).login(email, password);
    _signIn();
  }

  /// Registers and signs in. Throws [ApiException] on failure.
  Future<void> register(String email, String password) async {
    await ref.read(authRepositoryProvider).register(email, password);
    _signIn();
  }

  /// Logs out this device (revokes the token family on the server).
  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    _signOut();
  }

  /// Logs out every device of this user.
  Future<void> logoutAll() async {
    await ref.read(authRepositoryProvider).logoutAll();
    _signOut();
  }

  /// Called by [ApiClient] when the refresh token is rejected.
  void onSessionExpired() => _signOut();

  void _signIn() {
    ref.invalidate(taskControllerProvider);
    state = AuthStatus.signedIn;
  }

  void _signOut() {
    // Drop the previous user's tasks from memory.
    ref.invalidate(taskControllerProvider);
    state = AuthStatus.signedOut;
  }
}

/// Global authentication status.
final authControllerProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);
