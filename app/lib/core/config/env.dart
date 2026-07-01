/// Configuración de entorno.
///
/// Los valores por defecto apuntan al proyecto Supabase de IUPI. La **anon key**
/// está pensada para vivir en el cliente: no es un secreto, los datos los protege
/// Row Level Security (ver supabase/migrations/0005_rls.sql). Aun así, se pueden
/// sobreescribir en tiempo de compilación con --dart-define, por ejemplo para
/// apuntar a un proyecto de pruebas:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
class Env {
  const Env._();

  static const String _defaultUrl = 'https://tvvyyhtujpklovajgodq.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2dnl5aHR1anBrbG92YWpnb2RxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3NjI0ODksImV4cCI6MjA5ODMzODQ4OX0.2b7Vlc9GDTDP6QBUz-QFj503rYJwOl65jaJAnvpPVlQ';

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultUrl);
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _defaultAnonKey);

  /// Verdadero si hay credenciales. La app muestra una pantalla de ayuda si faltan.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
