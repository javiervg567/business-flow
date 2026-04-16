import 'package:supabase_flutter/supabase_flutter.dart';

/// Punto único de acceso a Supabase.
/// El resto de la app nunca importa supabase_flutter directamente.
class SupabaseService {
  /// Debe llamarse una sola vez al arrancar, antes de runApp().
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static User? get currentUser => auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
}
