/// Login and registration form.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'auth_controller.dart';

/// Lets the user sign in or create an account.
class LoginPage extends ConsumerStatefulWidget {
  /// Creates the login page.
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_registerMode) {
        await auth.register(_email.text, _password.text);
      } else {
        await auth.login(_email.text, _password.text);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Escribe tu correo.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Correo no válido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Escribe tu contraseña.';
    // Same rule as the server's registerSchema (12–128 characters).
    if (_registerMode && v.length < 12) return 'Mínimo 12 caracteres.';
    if (v.length > 128) return 'Máximo 128 caracteres.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = _registerMode ? 'Crear cuenta' : 'Iniciar sesión';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.task_alt, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      'Secure Task Manager',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(title, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                      enabled: !_busy,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: [
                        _registerMode
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        helperText:
                            _registerMode ? 'Al menos 12 caracteres' : null,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: _validatePassword,
                      onFieldSubmitted: (_) => _busy ? null : _submit(),
                      enabled: !_busy,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(title),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _registerMode = !_registerMode;
                                _error = null;
                              }),
                      child: Text(
                        _registerMode
                            ? '¿Ya tienes cuenta? Inicia sesión'
                            : '¿No tienes cuenta? Regístrate',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
