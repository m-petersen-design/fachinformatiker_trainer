import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Wir erzwingen eine neue DB (v4), um die Testfragen zu laden!
    _database = await _initDB('fachinformatiker_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE fachrichtung (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kuerzel TEXT NOT NULL UNIQUE,
        beschreibung TEXT,
        icon_name TEXT,
        farbe_hex TEXT NOT NULL DEFAULT '#2196F3'
      )
    ''');

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

    await db.execute('''
      CREATE TABLE frage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        themengebiet_id INTEGER NOT NULL,
        frage_text TEXT NOT NULL,
        typ TEXT NOT NULL CHECK (typ IN ('multiple_choice','true_false')),
        erklaerung TEXT,
        schwierigkeit INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (themengebiet_id) REFERENCES themengebiet(id) ON DELETE CASCADE
      )
    ''');

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

    await db.execute('''
      CREATE TABLE user_fortschritt (
        frage_id INTEGER PRIMARY KEY,
        korrekt_beantwortet INTEGER NOT NULL DEFAULT 0 CHECK (korrekt_beantwortet IN (0,1)),
        anzahl_versuche INTEGER NOT NULL DEFAULT 0,
        letzter_versuch TEXT,
        FOREIGN KEY (frage_id) REFERENCES frage(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE user_stats (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        xp INTEGER NOT NULL DEFAULT 0,
        streak_tage INTEGER NOT NULL DEFAULT 0,
        letzter_lern_tag TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_themengebiet_fachrichtung ON themengebiet(fachrichtung_id)');
    await db.execute('CREATE INDEX idx_frage_themengebiet ON frage(themengebiet_id)');
    await db.execute('CREATE INDEX idx_antwort_frage ON antwort_option(frage_id)');

    await db.execute("INSERT INTO fachrichtung (kuerzel, name) VALUES ('FISI', 'Systemintegration')");
    await db.execute("INSERT INTO fachrichtung (kuerzel, name) VALUES ('FIAE', 'Anwendungsentwicklung')");
    await db.execute("INSERT INTO fachrichtung (kuerzel, name) VALUES ('FIDP', 'Daten- und Prozessanalyse')");

    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (1, 'Netzwerktechnik & Hardware')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (1, 'Serveradministration (Linux/Windows)')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (2, 'Objektorientierte Programmierung')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (2, 'Softwarearchitektur & Design')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (3, 'Datenbanken & SQL')");
    await db.execute("INSERT INTO themengebiet (fachrichtung_id, name) VALUES (3, 'Datenanalyse & Big Data')");

    // --- HIER SIND DIE NEUEN ZEILEN FÜR DIE TESTFRAGE ---
    await db.execute('''
      INSERT INTO frage (themengebiet_id, frage_text, typ, erklaerung) 
      VALUES (1, 'Welcher Port wird standardmäßig für DNS (Domain Name System) verwendet?', 'multiple_choice', 'DNS nutzt standardmäßig Port 53, sowohl für UDP (Standardabfragen) als auch für TCP (Zonentransfers).')
    ''');

    await db.execute("INSERT INTO antwort_option (frage_id, text, ist_korrekt) VALUES (1, 'Port 80', 0)");
    await db.execute("INSERT INTO antwort_option (frage_id, text, ist_korrekt) VALUES (1, 'Port 22', 0)");
    await db.execute("INSERT INTO antwort_option (frage_id, text, ist_korrekt) VALUES (1, 'Port 53', 1)"); 
    await db.execute("INSERT INTO antwort_option (frage_id, text, ist_korrekt) VALUES (1, 'Port 443', 0)");

    print("✅ Neue DB (v4) mit Testfragen erfolgreich erstellt!");
  }
}