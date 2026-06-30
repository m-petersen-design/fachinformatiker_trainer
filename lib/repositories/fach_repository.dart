import '../core/database/database_service.dart';
import '../models/fachrichtung.dart';
import '../models/themengebiet.dart';

/// **Repository: FachRepository**
/// Diese Klasse ist nach dem Repository-Entwurfsmuster aufgebaut.
/// Sie dient als Abstraktionsschicht zwischen der SQLite-Datenbank und der 
/// Benutzeroberfläche (UI). Die UI ruft nur diese Methoden auf und kommt 
/// dadurch niemals mit SQL-Befehlen in Berührung (Separation of Concerns).
class FachRepository {
  
  /// **Lädt alle Hauptkategorien (Fachrichtungen)**
  /// Asynchrone Methode, die eine typsichere Liste von Fachrichtung-Objekten zurückgibt.
  Future<List<Fachrichtung>> getFachrichtungen() async {
    // 1. Holt sich die aktive, threadsichere Datenbank-Instanz (Singleton)
    final db = await DatabaseService.instance.database;
    
    // 2. Führt den SQL-SELECT auf die Tabelle 'fachrichtung' aus.
    // Das Ergebnis ist eine unstrukturierte Liste von Key-Value-Maps.
    final List<Map<String, dynamic>> maps = await db.query('fachrichtung');
    
    // 3. Transformation (Deserialisierung)
    // List.generate durchläuft die rohen Datenbankzeilen und nutzt den Factory-Konstruktor 
    // '.fromMap', um aus jeder Zeile ein echtes, objektorientiertes Dart-Objekt zu pressen.
    return List.generate(maps.length, (i) => Fachrichtung.fromMap(maps[i]));
  }

  /// **Lädt alle Unterkategorien (Themengebiete) für eine spezifische Fachrichtung**
  /// Die Suche erfolgt typsicher über den Integer-Fremdschlüssel (fachrichtungId).
  Future<List<Themengebiet>> getThemengebiete(int fachrichtungId) async {
    final db = await DatabaseService.instance.database;
    
    // SQL-Abfrage mit Parameter-Binding zum Schutz vor SQL-Injection
    final List<Map<String, dynamic>> maps = await db.query(
      'themengebiet', 
      where: 'fachrichtung_id = ?', 
      whereArgs: [fachrichtungId], // ? wird sicher durch fachrichtungId ersetzt
    );
    
    // Wandelt die gefilterten rohen SQL-Daten in saubere 'Themengebiet'-Objekte um.
    return List.generate(maps.length, (i) => Themengebiet.fromMap(maps[i]));
  }
}