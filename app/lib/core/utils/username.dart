/// Permite iniciar sesión / crear usuarios con un "usuario" simple (sin email).
///
/// Supabase Auth trabaja con email, así que a un usuario sin "@" le agregamos
/// un dominio interno fijo. El trabajador solo ve/escribe su usuario (ej: "juan").
/// Si escribe un email completo (tiene "@"), se usa tal cual (para los admins).
const String kUsernameDomain = 'iupi.app';

String emailFromLogin(String input) {
  final v = input.trim().toLowerCase();
  if (v.isEmpty) return v;
  if (v.contains('@')) return v;
  return '$v@$kUsernameDomain';
}
