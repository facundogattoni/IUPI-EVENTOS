import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;

  Future<Profile?> fetchById(String id) async {
    final data =
        await _client.from('profiles').select().eq('id', id).maybeSingle();
    return data == null ? null : Profile.fromMap(data);
  }

  Future<List<Profile>> fetchAll({bool onlyActive = true}) async {
    var query = _client.from('profiles').select();
    if (onlyActive) query = query.eq('is_active', true);
    final data = await query.order('full_name');
    return (data as List)
        .map((e) => Profile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> update(Profile profile) async {
    await _client
        .from('profiles')
        .update(profile.toUpdateMap())
        .eq('id', profile.id);
  }

  /// Ajusta rol y nombre de un perfil recién creado (lo usa el alta de usuarios).
  Future<void> setRoleAndName({
    required String id,
    required UserRole role,
    required String fullName,
  }) async {
    await _client
        .from('profiles')
        .update({'role': role.db, 'full_name': fullName})
        .eq('id', id);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// Perfil del usuario logueado (incluye su rol). Null mientras no haya sesión.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  return ref.watch(profileRepositoryProvider).fetchById(session.user.id);
});

/// Lista de perfiles activos (para asignar coordinador y trabajadores).
final activeProfilesProvider = FutureProvider<List<Profile>>((ref) async {
  // Se refresca si cambia la sesión.
  ref.watch(sessionProvider);
  return ref.watch(profileRepositoryProvider).fetchAll();
});

/// Todos los perfiles (incluye inactivos) para la administración del equipo.
final allProfilesProvider = FutureProvider<List<Profile>>((ref) async {
  ref.watch(sessionProvider);
  return ref.watch(profileRepositoryProvider).fetchAll(onlyActive: false);
});
