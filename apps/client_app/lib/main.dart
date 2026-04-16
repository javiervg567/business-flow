import 'package:flutter/material.dart';
import 'package:core/core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await SupabaseService.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const ClientApp());
}

class ClientApp extends StatelessWidget {
  const ClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Business Flow — Cliente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF16A34A)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = SupabaseService.isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Flow'),
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('App de clientes', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Text(
              isLoggedIn
                  ? '✓ Supabase conectado y usuario logueado'
                  : '✓ Supabase conectado (sin sesión)',
              style: TextStyle(
                fontSize: 14,
                color: isLoggedIn ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
