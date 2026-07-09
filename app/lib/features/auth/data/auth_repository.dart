import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/supabase_providers.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

  /// Crea una cuenta para un trabajador/coordinador SIN cerrar la sesión del
  /// admin. Usa un cliente temporal (sesión en memoria) para que el signUp no
  /// pise la sesión guardada del administrador. Devuelve el id del nuevo usuario.
  Future<String> createAccount({
    required String email,
    required String password,
  }) async {
    final temp = SupabaseClient(Env.supabaseUrl, Env.supabaseAnonKey);
    try {
      final res = await temp.auth.signUp(
        email: email.trim(),
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw const AuthException('No se pudo crear la cuenta.');
      }
      return user.id;
    } finally {
      await temp.dispose();
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
