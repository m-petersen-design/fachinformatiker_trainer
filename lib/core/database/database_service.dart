import 'dart:convert'; // Für jsonDecode: Wandelt Text-Strings in Dart-Objekte (Maps/Listen) um
import 'dart:io'; // Für Platform-Abfragen (prüft, ob die App auf Windows/Linux läuft)
import 'package:flutter/foundation.dart'; 
import 'package:flutter/services.dart'; // Ermöglicht das asynchrone Laden von lokalen Assets (wie der JSON-Datei)
import 'package:path/path.dart'; // Hilft beim plattformunabhängigen Zusammenbauen von Dateipfaden
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Der C++ Treiber für SQLite auf Desktop-Systemen

/// **Singleton-Klasse `DatabaseService`**
/// Diese Klasse ist das Herzstück der Datenhaltungsschicht (Data Layer) eurer Architektur.
/// Sie nutzt das Singleton-Entwurfsmuster (Design Pattern), um sicherzustellen, dass
/// zur Laufzeit der App immer nur exakt EINE Verbindung zur SQLite-Datenbank existiert.
/// Das verhindert kritische "Database Locked"-Fehler durch gleichzeitige Zugriffe.
class DatabaseService {
  // Privater Konstruktor: Verhindert, dass jemand von außen 'new DatabaseService()' aufruft.
  DatabaseService._();
  
  // Die einzige, global verfügbare Instanz dieser Klasse.
  static final DatabaseService instance = DatabaseService._();
  
  // Die eigentliche SQLite-Datenbankverbindung. Sie ist nullable (?), da sie beim App-Start noch nicht existiert.
  Database? _database;

  /// **Getter `database` (Lazy Initialization)**
  /// Liefert die Datenbankverbindung zurück. Falls die Verbindung noch nicht existiert,
  /// wird sie hier einmalig initialisiert. Danach wird immer die bestehende Verbindung recycelt.
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDB('fachinformatiker_v11.db');
    return _database!;
  }

  /// **Initialisierung der Datenbank**
  /// Konfiguriert die nativen Treiber und legt den Speicherort der `.db`-Datei fest.
  Future<Database> _initDB(String filePath) async {
    // Desktop-Umgebungen (Windows/Linux) benötigen eine spezielle C-Schnittstelle (FFI),
    // da sie keine nativen mobilen SQLite-Bibliotheken besitzen.
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Ermittelt den sicheren Standard-Pfad für App-Daten auf dem jeweiligen Betriebssystem.
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Öffnet die Datenbank und triggert _createDB, falls es die Datei noch nicht gibt.
    return await openDatabase(
      path,
      version: 1,
      // onConfigure wird VOR onCreate ausgeführt. Zwingend nötig, da SQLite
      // standardmäßig keine Foreign Keys (Fremdschlüssel) erzwingt!
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
    );
  }

  /// **Datenbank-Aufbau & Master-Seeding**
  /// Diese Methode wird nur ein einziges Mal ausgeführt: Wenn die `.db`-Datei noch nicht existiert.
  /// Hier wird das relationale Schema (Tabellen) gebaut und die Initiale Befüllung (Seeding) durchgeführt.
  Future _createDB(Database db, int version) async {
    
    // --- 1. DDL (Data Definition Language) - Tabellenstrukturen ---

    // Stammdaten: Die großen Überkategorien (z.B. FISI, FIAE)
    await db.execute('''
      CREATE TABLE fachrichtung (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kuerzel TEXT NOT NULL UNIQUE,
        beschreibung TEXT,
        icon_name TEXT,
        farbe_hex TEXT NOT NULL DEFAULT '#2196F3',
        xp INTEGER NOT NULL DEFAULT 0 
      )
    ''');

    // Stammdaten: Die Unterkategorien. Verknüpft mit der Fachrichtung.
    // ON DELETE CASCADE: Wird eine Fachrichtung gelöscht, löscht die DB automatisch alle dazugehörigen Themen.
    await db.execute('''
      CREATE TABLE themengebiet (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fachrichtung_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        beschreibung TEXT,
        reihenfolge INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (fachrichtung_id) REFERENCES fachrichtung(id) ON DELETE CASCADE
      )
    ''');

    // Stammdaten: Die eigentlichen Prüfungsfragen.
    // CHECK-Constraint: Garantiert auf Datenbank-Ebene, dass keine falschen Fragentypen eingeschleust werden.
    await db.execute('''
      CREATE TABLE frage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        themengebiet_id INTEGER NOT NULL,
        frage_text TEXT NOT NULL,
        typ TEXT NOT NULL CHECK (typ IN ('multiple_choice','true_false', 'freitext')),
        bild_pfad TEXT, 
        erklaerung TEXT,
        schwierigkeit INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (themengebiet_id) REFERENCES themengebiet(id) ON DELETE CASCADE
      )
    ''');

    // Stammdaten: Antwortmöglichkeiten für Multiple-Choice-Fragen.
    await db.execute('''
      CREATE TABLE antwort_option (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        frage_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        ist_korrekt INTEGER NOT NULL DEFAULT 0 CHECK (ist_korrekt IN (0,1)),
        reihenfolge INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (frage_id) REFERENCES frage(id) ON DELETE CASCADE
      )
    ''');

    // Bewegungsdaten: Speichert den individuellen Lernfortschritt des Nutzers pro Frage.
    // Das Herzstück eures "Spaced Repetition" Algorithmus (intervallbasiertes Lernen).
    await db.execute('''
      CREATE TABLE user_fortschritt (
        frage_id INTEGER PRIMARY KEY,
        korrekt_beantwortet INTEGER NOT NULL DEFAULT 0 CHECK (korrekt_beantwortet IN (0,1)),
        anzahl_versuche INTEGER NOT NULL DEFAULT 0,
        letzter_versuch TEXT,
        naechste_faelligkeit TEXT, 
        intervall_tage INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (frage_id) REFERENCES frage(id) ON DELETE CASCADE
      )
    ''');

    // Bewegungsdaten: Globale Nutzerstatistiken. 
    // CHECK (id = 1) verhindert, dass versehentlich ein zweiter Statistik-Eintrag generiert wird.
    await db.execute('''
      CREATE TABLE user_stats (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        xp INTEGER NOT NULL DEFAULT 0,
        streak_tage INTEGER NOT NULL DEFAULT 0,
        letzter_lern_tag TEXT
      )
    ''');

    // --- Performance-Optimierung (Indizes) ---
    // Indizes funktionieren wie das Register in einem dicken Buch. Wenn später das Quiz
    // 100 Fragen zu einem Themengebiet sucht, verhindert der Index einen langsamen Full-Table-Scan.
    await db.execute('CREATE INDEX idx_themengebiet_fachrichtung ON themengebiet(fachrichtung_id)');
    await db.execute('CREATE INDEX idx_frage_themengebiet ON frage(themengebiet_id)');
    await db.execute('CREATE INDEX idx_antwort_frage ON antwort_option(frage_id)');

    // --- 2. DML (Data Manipulation Language) - Manuelles Seeding ---
    // Injektion der unveränderlichen Basis-Kategorien.
    await db.execute("INSERT INTO fachrichtung (kuerzel, name, xp) VALUES ('FISI', 'Systemintegration', 0)");
    await db.execute("INSERT INTO fachrichtung (kuerzel, name, xp) VALUES ('FIAE', 'Anwendungsentwicklung', 0)");
    await db.execute("INSERT INTO fachrichtung (kuerzel, name, xp) VALUES ('FIDP', 'Daten- und Prozessanalyse', 0)");
    await db.execute("INSERT INTO fachrichtung (kuerzel, name, xp) VALUES ('UNI', 'Universität', 0)");
    await db.execute("INSERT INTO fachrichtung (kuerzel, name, xp) VALUES ('BS', 'Berufsschule', 0)");

    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (1, 'Netzwerktechnik & Hardware')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (1, 'Serveradministration (Linux/Windows)')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (2, 'Objektorientierte Programmierung')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (2, 'Softwarearchitektur & Design')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (3, 'Datenbanken & SQL')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (4, 'Theoretische Informatik (UNI)')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (4, 'Höhere Mathematik (UNI)')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (5, 'Wirtschaft & Sozialkunde (BS)')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (3, 'Datenerfassung & Datenquellen')");

    // 3. AUTOMATISCHER EINBAU: JSON-Fragenkatalog parsen und einspielen
    try {
      // Lädt die Datei direkt aus den App-Ressourcen
      final String jsonString = await rootBundle.loadString('assets/basis_fragen.json');
      final dynamic decodedData = jsonDecode(jsonString);
      
      List<dynamic> fragenListe = [];
      if (decodedData is List) {
        fragenListe = decodedData;
      } else if (decodedData is Map && decodedData.containsKey('fragen')) {
        fragenListe = decodedData['fragen'];
      }

      // Schleife über alle Fragen im JSON
      for (var rawFrage in fragenListe) {
        final frage = Map<String, dynamic>.from(rawFrage);
        
        // Frage in die Tabelle einfügen und die automatisch generierte ID abfangen
        final int frageId = await db.insert('frage', {
          'themengebiet_id': frage['themengebiet_id'] ?? 1,
          'frage_text': frage['frage_text'] ?? '',
          'typ': frage['typ'] ?? 'multiple_choice',
          'bild_pfad': frage['bild_pfad'],
          'erklaerung': frage['erklaerung'],
          'schwierigkeit': frage['schwierigkeit'] ?? 1,
        });

        // Wenn die Frage Antwortoptionen besitzt (Multiple Choice), diese einspeisen
        if (frage['antworten'] != null) {
          final antworten = List<dynamic>.from(frage['antworten']);
          for (var rawAntwort in antworten) {
            final antwort = Map<String, dynamic>.from(rawAntwort);
            await db.insert('antwort_option', {
              'frage_id': frageId,
              'text': antwort['text'] ?? '',
              'ist_korrekt': antwort['ist_korrekt'] ?? 0,
              'reihenfolge': antwort['reihenfolge'] ?? 0,
            });
          }
        }
      }
      debugPrint("✅ Erststart-Aktion: basis_fragen.json erfolgreich in neue DB migriert!");
    } catch (e) {
      debugPrint("❌ Warnung beim automatischen JSON-Import: $e");
    }

    // --- 3. ETL-Prozess (Extract, Transform, Load) - Das JSON-Seeding ---
    try {
      // Extract: Lädt die Datei als langen String aus dem Dateisystem der App.
      final String jsonString = await rootBundle.loadString('assets/basis_fragen.json');
      // Transform: Wandelt den String in lesbare Dart-Maps/Listen um.
      final dynamic decodedData = jsonDecode(jsonString);
      
      List<dynamic> fragenListe = [];
      // Fängt unterschiedliche JSON-Strukturen ab (direktes Array vs. verschachtelt in 'fragen')
      if (decodedData is List) {
        fragenListe = decodedData;
      } else if (decodedData is Map && decodedData.containsKey('fragen')) {
        fragenListe = decodedData['fragen'];
      }

      // Load: Iteriert über jede erkannte Frage im JSON und pumpt sie in die relationale Struktur.
      for (var rawFrage in fragenListe) {
        final frage = Map<String, dynamic>.from(rawFrage);
        
        // db.insert() liefert praktischerweise direkt die generierte Auto-Increment-ID zurück.
        final int frageId = await db.insert('frage', {
          'themengebiet_id': frage['themengebiet_id'] ?? 1,
          'frage_text': frage['frage_text'] ?? '',
          'typ': frage['typ'] ?? 'multiple_choice',
          'bild_pfad': frage['bild_pfad'],
          'erklaerung': frage['erklaerung'],
          'schwierigkeit': frage['schwierigkeit'] ?? 1,
        });

        // Wenn die soeben eingefügte Frage Antwortoptionen besitzt (Array),
        // werden diese in einem Sub-Loop mit der generierten `frageId` (Fremdschlüssel) verknüpft.
        if (frage['antworten'] != null) {
          final antworten = List<dynamic>.from(frage['antworten']);
          for (var rawAntwort in antworten) {
            final antwort = Map<String, dynamic>.from(rawAntwort);
            await db.insert('antwort_option', {
              'frage_id': frageId, // Hier passiert die relationale Magie!
              'text': antwort['text'] ?? '',
              'ist_korrekt': antwort['ist_korrekt'] ?? 0,
              'reihenfolge': antwort['reihenfolge'] ?? 0,
            });
          }
        }
      }
      debugPrint("✅ Erststart-Aktion: basis_fragen.json erfolgreich in neue DB migriert!");
    } catch (e) {
      // Fehler-Handling: Fängt Syntax-Fehler im JSON ab, damit die App nicht crasht.
      debugPrint("❌ Warnung beim automatischen JSON-Import: $e");
    }

    debugPrint("✅ Neue DB (v11) mit Spaced Repetition erfolgreich erstellt!");
  }
}