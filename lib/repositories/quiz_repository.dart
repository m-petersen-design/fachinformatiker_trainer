import '../core/database/database_service.dart';
import '../models/frage.dart';
import '../models/antwort_option.dart';

class QuizRepository {
  // Holt alle Fragen für ein bestimmtes Thema (z.B. Netzwerktechnik)
  Future<List<Frage>> getFragenFuerThema(int themengebietId) async {
    final db = await DatabaseService.instance.database;
    final maps = await db.query(
      'frage', 
      where: 'themengebiet_id = ?', 
      whereArgs: [themengebietId]
    );
    return maps.map((m) => Frage.fromMap(m)).toList();
  }

  // Holt die 4 Antworten zu einer bestimmten Frage
  Future<List<AntwortOption>> getAntwortenFuerFrage(int frageId) async {
    final db = await DatabaseService.instance.database;
    final maps = await db.query(
      'antwort_option', 
      where: 'frage_id = ?', 
      whereArgs: [frageId]
    );
    return maps.map((m) => AntwortOption.fromMap(m)).toList();
  }
}