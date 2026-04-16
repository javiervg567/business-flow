import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Lee y valida las variables de entorno del .env.
class AppConfig {
  static Future<void> load({String fileName = '.env'}) async {
    await dotenv.load(fileName: fileName);
    _validate();
  }

  /// Comprueba que las variables obligatorias existan.
  static void _validate() {
    final required = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'];
    final missing = required
        .where((key) => (dotenv.env[key] ?? '').trim().isEmpty)
        .toList();

    if (missing.isNotEmpty) {
      throw Exception('Faltan variables en el .env: ${missing.join(', ')}');
    }
  }

  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;
}
