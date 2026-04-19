import 'package:flutter/material.dart';
import 'package:core/core.dart';
import 'screens/login_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await SupabaseService.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es')],
      title: 'Business Flow — Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D6FEB),
          primary: const Color(0xFF1D6FEB),
          onPrimary: Colors.white,
          secondary: const Color(0xFF16A34A),
          surface: Colors.white,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1D6FEB),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          headerBackgroundColor: const Color(0xFF1D6FEB),
          headerForegroundColor: Colors.white,
          dayOverlayColor: WidgetStateProperty.all(const Color(0x1A1D6FEB)),
          todayBorder: const BorderSide(color: Color(0xFF1D6FEB), width: 1.5),
          todayForegroundColor: WidgetStateProperty.all(
            const Color(0xFF1D6FEB),
          ),
          rangePickerBackgroundColor: Colors.white,
          rangePickerHeaderBackgroundColor: const Color(0xFF1D6FEB),
          rangePickerHeaderForegroundColor: Colors.white,
          rangeSelectionBackgroundColor: const Color(0xFFEEF5FF),
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return const Color(0xFF0F172A);
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF1D6FEB);
            }
            return Colors.transparent;
          }),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
