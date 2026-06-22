import 'package:flutter/material.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() {
  runApp(const FachinformatikerTrainerApp());
}

class FachinformatikerTrainerApp extends StatelessWidget {
  const FachinformatikerTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fachinformatiker Trainer',
      debugShowCheckedModeBanner: false,
      
      // =======================================================================
      // NEUES GLOBAL MODERN DARK THEME
      // =======================================================================
      themeMode: ThemeMode.dark, // Zwinge Dark Mode
      darkTheme: ThemeData(
        useMaterial3: true,
        
        // --- 1. FARBPALETTE DEFINIEREN ---
        scaffoldBackgroundColor: const Color(0xFF121419),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF1D2229),
          surface: Color(0xFF1D2229),
          error: Color(0xFFFF5252),
          onPrimary: Colors.black87,
          onSurface: Colors.white,
        ),
        
        // --- 2. GLOBALER TEXT LOOK ---
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, color: Colors.white),
          titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600, color: Colors.white),
          titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 16.0, color: Colors.white70),
          bodyMedium: TextStyle(fontSize: 14.0, color: Colors.white70),
        ),

        // --- 3. GLOBALER KARTEN LOOK (Schatten & Ecken) ---
        // KORREKTUR: Es muss CardThemeData heißen!
        cardTheme: const CardThemeData(
          color: Color(0xFF1D2229), 
          elevation: 0.0, 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20.0)),
          ),
          margin: EdgeInsets.only(bottom: 16.0),
        ),

        // --- 4. GLOBALER APPBAR LOOK ---
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, 
          elevation: 0.0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 24.0, fontWeight: FontWeight.bold),
        ),

        // --- 5. GLOBALER BUTTON LOOK ---
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black87,
            elevation: 8.0, 
            shadowColor: const Color(0x6600E5FF), 
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16.0)),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}