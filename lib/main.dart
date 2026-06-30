import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Für das Speichern kleiner Key-Value-Daten auf dem Gerät
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/database/database_service.dart';
import 'screens/dashboard/dashboard_screen.dart';

/// **Globales State Management (Theme)**
/// Ein ValueNotifier ist ein einfacher, aber sehr effizienter Weg in Flutter, 
/// um einen globalen Zustand (hier: das gewählte Design-Theme) zu verwalten.
/// Die UI "lauscht" auf diesen Notifier und zeichnet sich automatisch neu, 
/// sobald sich der Wert ändert (z. B. wenn der Nutzer den Sith/Jedi-Schalter drückt).
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

/// **Der Einstiegspunkt (Entry Point) der Applikation**
/// Die 'main'-Funktion wird asynchron ('async') ausgeführt, da wir vor dem
/// Rendern der ersten Pixel wichtige System-Ressourcen laden müssen.
void main() async {
  
  // 1. SYSTEM-BINDING
  // Diese Zeile ist zwingend erforderlich, wenn asynchroner Code (wie await) 
  // vor 'runApp' ausgeführt wird. Sie stellt sicher, dass die Flutter-Engine 
  // komplett hochgefahren ist und mit dem nativen Betriebssystem kommunizieren kann.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. DESKTOP-TREIBER (Cross-Platform-Logik)
  // Überprüft das Betriebssystem. Falls die App auf Windows oder Linux läuft,
  // werden die speziellen C++ (FFI) Datenbanktreiber geladen.
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 3. DATENBANK-WARMUP
  // Wir triggern hier explizit das Singleton unseres DatabaseServices.
  // Das stellt sicher, dass die SQlite-Datei erstellt wird, alle Tabellen (DDL) 
  // aufgebaut werden und das JSON-Basisfragen-Set importiert wird (ETL-Prozess),
  // bevor der User auf dem Dashboard landet.
  await DatabaseService.instance.database;

  // 4. LOKALE PRÄFERENZEN LADEN
  // 'SharedPreferences' greift auf den lokalen Speicher des Betriebssystems zu 
  // (ähnlich wie Cookies im Browser). Hier lesen wir aus, ob der Nutzer beim 
  // letzten App-Start den 'Jedi'-Modus aktiv hatte. 
  // Der Operator '?? false' fängt den Fall ab, dass die App zum allerersten Mal gestartet wird.
  final prefs = await SharedPreferences.getInstance();
  final isJedi = prefs.getBool('isJedi') ?? false;
  themeNotifier.value = isJedi ? ThemeMode.light : ThemeMode.dark;
  
  // 5. BOOTSTRAP DER UI
  // Übergibt die Haupt-Widget-Klasse an die Flutter-Render-Engine.
  runApp(const FachinformatikerTrainerApp());
}

/// **Root Widget: FachinformatikerTrainerApp**
/// Dies ist das Wurzel-Widget der App. Es ist 'Stateless', da es seinen eigenen 
/// Zustand nicht ändert, sondern nur auf den globalen 'themeNotifier' reagiert.
class FachinformatikerTrainerApp extends StatelessWidget {
  const FachinformatikerTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder ist ein reaktives Widget. Es hört auf den 'themeNotifier'.
    // Jedes Mal, wenn sich ThemeMode ändert, wird NUR die 'builder'-Funktion neu ausgeführt, 
    // was extrem ressourcenschonend ist.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        
        // ==========================================
        // SITH MODE (Dark Theme)
        // Fokus auf Neon-Kontraste (Cyan) auf dunklen Hintergründen.
        // ==========================================
        final TextTheme darkTextTheme = GoogleFonts.poppinsTextTheme().apply(
          bodyColor: Colors.white, 
          displayColor: Colors.white,
        );
        final darkTheme = ThemeData(
          useMaterial3: true, // Nutzt die modernen Material-Design-Richtlinien
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121419), // Sehr dunkles Grau, kein reines Schwarz
          cardColor: const Color(0xFF1D2229),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E5FF), // SHifthappens Cyan
            secondary: Color(0xFF1D2229),
            surface: Color(0xFF1D2229),
            error: const Color(0xFFFF5252),
            onPrimary: Colors.black87, // Textfarbe auf primären Buttons (für guten Kontrast)
            onSurface: Colors.white,
          ),
          // Typografie-Konfiguration mit Poppins
          textTheme: darkTextTheme.copyWith(
            displayLarge: darkTextTheme.displayLarge?.copyWith(fontSize: 32.0, fontWeight: FontWeight.bold),
            titleLarge: darkTextTheme.titleLarge?.copyWith(fontSize: 22.0, fontWeight: FontWeight.w600),
            titleMedium: darkTextTheme.titleMedium?.copyWith(fontSize: 18.0, fontWeight: FontWeight.w500),
            bodyLarge: darkTextTheme.bodyLarge?.copyWith(fontSize: 16.0, color: Colors.white70),
            bodyMedium: darkTextTheme.bodyMedium?.copyWith(fontSize: 14.0, color: Colors.white70),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0.0,
            iconTheme: IconThemeData(color: Colors.white),
          ),
        );

        // ==========================================
        // JEDI MODE (Light Theme)
        // Sauberer, heller Code-Editor-Look.
        // ==========================================
        final TextTheme lightTextTheme = GoogleFonts.poppinsTextTheme().apply(
          bodyColor: const Color(0xFF1A1A24), 
          displayColor: const Color(0xFF1A1A24),
        );
        final lightTheme = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF4F6F9),
          cardColor: Colors.white,
          colorScheme: const ColorScheme.light(
            primary: const Color(0xFF0D47A1), // Dunkles, sattes Blau
            secondary: const Color(0xFFE3E8EF),
            surface: Colors.white,
            error: const Color(0xFFD32F2F),
            onPrimary: Colors.white,
            onSurface: const Color(0xFF1A1A24),
          ),
          textTheme: lightTextTheme.copyWith(
            displayLarge: lightTextTheme.displayLarge?.copyWith(fontSize: 32.0, fontWeight: FontWeight.bold),
            titleLarge: lightTextTheme.titleLarge?.copyWith(fontSize: 22.0, fontWeight: FontWeight.w600),
            titleMedium: lightTextTheme.titleMedium?.copyWith(fontSize: 18.0, fontWeight: FontWeight.w500),
            bodyLarge: lightTextTheme.bodyLarge?.copyWith(fontSize: 16.0, color: Colors.black87),
            bodyMedium: lightTextTheme.bodyMedium?.copyWith(fontSize: 14.0, color: Colors.black54),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0.0,
            iconTheme: IconThemeData(color: Color(0xFF1A1A24)),
          ),
        );

        // --- MaterialApp: Der App-Container ---
        return MaterialApp(
          title: 'Fachinformatiker Trainer',
          debugShowCheckedModeBanner: false, // Entfernt das nervige rote "DEBUG" Banner
          themeMode: currentMode, // Steuert reaktiv, welches Theme gerade aktiv ist
          theme: lightTheme, // Die Konfiguration für ThemeMode.light
          darkTheme: darkTheme, // Die Konfiguration für ThemeMode.dark
          home: const DashboardScreen(), // Der initiale Screen beim Start der App
        );
      },
    );
  }
}