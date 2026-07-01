import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente global de Supabase. Se inicializa en main() antes de runApp().
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Stream del estado de autenticación (login / logout / refresh de token).
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Sesión actual (o null si no hay usuario logueado).
final sessionProvider = Provider<Session?>((ref) {
  // Se recalcula ante cada cambio de authState.
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession;
});
