import 'dart:io';
import 'package:flutter/foundation.dart'; // NEU: Für debugPrint
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fachinformatiker_v10.db');
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
        farbe_hex TEXT NOT NULL DEFAULT '#2196F3',
        xp INTEGER NOT NULL DEFAULT 0 
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
        typ TEXT NOT NULL CHECK (typ IN ('multiple_choice','true_false', 'freitext')),
        bild_pfad TEXT, 
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
        naechste_faelligkeit TEXT, 
        intervall_tage INTEGER NOT NULL DEFAULT 0,
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

    debugPrint("✅ Neue DB (v10) mit Spaced Repetition erfolgreich erstellt!");
  }
}