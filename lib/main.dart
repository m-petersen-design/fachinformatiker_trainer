import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/dashboard/dashboard_screen.dart';

// Globaler Notifier für den Theme-Wechsel (Jedi vs. Sith)
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isJedi = prefs.getBool('isJedi') ?? false;
  themeNotifier.value = isJedi ? ThemeMode.light : ThemeMode.dark;
  
  runApp(const FachinformatikerTrainerApp());
}

class FachinformatikerTrainerApp extends StatelessWidget {
  const FachinformatikerTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        // --- SITH MODE (DARK) ---
        final TextTheme darkTextTheme = GoogleFonts.poppinsTextTheme().apply(bodyColor: Colors.white, displayColor: Colors.white);
        final darkTheme = ThemeData(
          useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF121419), cardColor: const Color(0xFF1D2229),
          colorScheme: const ColorScheme.dark(primary: Color(0xFF00E5FF), secondary: Color(0xFF1D2229), surface: Color(0xFF1D2229), error: Color(0xFFFF5252), onPrimary: Colors.black87, onSurface: Colors.white),
          textTheme: darkTextTheme.copyWith(
            displayLarge: darkTextTheme.displayLarge?.copyWith(fontSize: 32.0, fontWeight: FontWeight.bold),
            titleLarge: darkTextTheme.titleLarge?.copyWith(fontSize: 22.0, fontWeight: FontWeight.w600),
            titleMedium: darkTextTheme.titleMedium?.copyWith(fontSize: 18.0, fontWeight: FontWeight.w500),
            bodyLarge: darkTextTheme.bodyLarge?.copyWith(fontSize: 16.0, color: Colors.white70),
            bodyMedium: darkTextTheme.bodyMedium?.copyWith(fontSize: 14.0, color: Colors.white70),
          ),
          appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0.0, iconTheme: IconThemeData(color: Colors.white)),
        );

        // --- JEDI MODE (LIGHT) ---
        final TextTheme lightTextTheme = GoogleFonts.poppinsTextTheme().apply(bodyColor: const Color(0xFF1A1A24), displayColor: const Color(0xFF1A1A24));
        final lightTheme = ThemeData(
          useMaterial3: true, brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF4F6F9), cardColor: Colors.white,
          colorScheme: const ColorScheme.light(primary: Color(0xFF0D47A1), secondary: Color(0xFFE3E8EF), surface: Colors.white, error: Color(0xFFD32F2F), onPrimary: Colors.white, onSurface: Color(0xFF1A1A24)),
          textTheme: lightTextTheme.copyWith(
            displayLarge: lightTextTheme.displayLarge?.copyWith(fontSize: 32.0, fontWeight: FontWeight.bold),
            titleLarge: lightTextTheme.titleLarge?.copyWith(fontSize: 22.0, fontWeight: FontWeight.w600),
            titleMedium: lightTextTheme.titleMedium?.copyWith(fontSize: 18.0, fontWeight: FontWeight.w500),
            bodyLarge: lightTextTheme.bodyLarge?.copyWith(fontSize: 16.0, color: Colors.black87),
            bodyMedium: lightTextTheme.bodyMedium?.copyWith(fontSize: 14.0, color: Colors.black54),
          ),
          appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0.0, iconTheme: IconThemeData(color: Color(0xFF1A1A24))),
        );

        return MaterialApp(
          title: 'Fachinformatiker Trainer',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: lightTheme,
          darkTheme: darkTheme,
          home: const DashboardScreen(),
        );
      },
    );
  }
}