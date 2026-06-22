import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() {
  runApp(const FachinformatikerTrainerApp());
}

class FachinformatikerTrainerApp extends StatelessWidget {
  const FachinformatikerTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Generiere ein sauberes TextTheme mit Poppins
    final TextTheme poppinsTheme = GoogleFonts.poppinsTextTheme().apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return MaterialApp(
      title: 'Fachinformatiker Trainer',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, 
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121419),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF1D2229),
          surface: Color(0xFF1D2229),
          error: Color(0xFFFF5252),
          onPrimary: Colors.black87,
          onSurface: Colors.white,
        ),
        
        // DAS NEUE GLOBALE FONT-THEME
        textTheme: poppinsTheme.copyWith(
          displayLarge: poppinsTheme.displayLarge?.copyWith(fontSize: 32.0, fontWeight: FontWeight.bold),
          titleLarge: poppinsTheme.titleLarge?.copyWith(fontSize: 22.0, fontWeight: FontWeight.w600),
          titleMedium: poppinsTheme.titleMedium?.copyWith(fontSize: 18.0, fontWeight: FontWeight.w500),
          bodyLarge: poppinsTheme.bodyLarge?.copyWith(fontSize: 16.0, color: Colors.white70),
          bodyMedium: poppinsTheme.bodyMedium?.copyWith(fontSize: 14.0, color: Colors.white70),
        ),

        cardTheme: const CardThemeData(
          color: Color(0xFF1D2229), 
          elevation: 0.0, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20.0))),
          margin: EdgeInsets.only(bottom: 16.0),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, 
          elevation: 0.0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black87,
            elevation: 8.0, 
            shadowColor: const Color(0x6600E5FF), 
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}