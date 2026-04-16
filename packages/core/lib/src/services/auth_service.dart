import 'package:core/core.dart';

/// Gestiona login, logout y estado de sesión.
class AuthService {
  /// Inicia sesión con email y contraseña.
  /// Devuelve el perfil del usuario si todo va bien.
  /// Lanza una excepción con mensaje legible si falla.
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    // 1. Autenticar contra Supabase Auth
    final response = await SupabaseService.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('No se pudo iniciar sesión');
    }

    // 2. Obtener el perfil del usuario (rol, nombre, business_id...)
    final profile = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', response.user!.id)
        .single();

    return profile;
  }

  /// Cierra la sesión actual.
  static Future<void> signOut() async {
    await SupabaseService.auth.signOut();
  }

  /// Devuelve el perfil del usuario actual (si hay sesión activa).
  static Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;

    final profile = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return profile;
  }
}
