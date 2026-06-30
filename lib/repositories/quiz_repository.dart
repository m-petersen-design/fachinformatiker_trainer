import '../core/database/database_service.dart';
import '../models/frage.dart';
import '../models/antwort_option.dart';

/// **Repository: QuizRepository (Read-Only)**
/// Diese Klasse ist nach dem Repository-Entwurfsmuster aufgebaut.
/// Sie kapselt ausschließlich lesende Datenbankzugriffe (SELECT-Queries), 
/// die für den laufenden Betrieb des Quizzes benötigt werden.
class QuizRepository {
  
  /// **Holt alle Fragen für ein spezifisches Themengebiet**
  /// Asynchrone Methode, die eine typsichere Liste von [Frage]-Objekten zurückgibt.
  Future<List<Frage>> getFragenFuerThema(int themengebietId) async {
    // 1. Holt die aktive Datenbankverbindung (Singleton)
    final db = await DatabaseService.instance.database;
    
    // 2. Führt die SQL-Abfrage aus. 
    // Wir nutzen whereArgs (Parameter-Binding), um SQL-Injections zu verhindern.
    final maps = await db.query(
      'frage', 
      where: 'themengebiet_id = ?', 
      whereArgs: [themengebietId]
    );
    
    // 3. Transformation (Funktionale Programmierung trifft OOP)
    // .map() iteriert über die Liste der rohen SQL-Maps.
    // Für jeden Eintrag wird der Factory-Konstruktor 'Frage.fromMap()' aufgerufen,
    // der die Map in ein echtes Dart-Objekt umwandelt. .toList() macht daraus wieder ein Array.
    return maps.map((m) => Frage.fromMap(m)).toList();
  }

  /// **Holt alle Antworten zu einer spezifischen Frage**
  /// (Meist 4 Stück bei Multiple Choice).
  Future<List<AntwortOption>> getAntwortenFuerFrage(int frageId) async {
    final db = await DatabaseService.instance.database;
    
    // Fragt die Kind-Tabelle 'antwort_option' über den Fremdschlüssel 'frage_id' ab.
    final maps = await db.query(
      'antwort_option', 
      where: 'frage_id = ?', 
      whereArgs: [frageId]
    );
    
    // Wandelt die Datenbankzeilen typsicher in AntwortOption-Objekte um.
    return maps.map((m) => AntwortOption.fromMap(m)).toList();
  }
}