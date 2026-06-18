import '../core/database/database_service.dart';

class AdminRepository {
  
  // Funktion: Neues Themengebiet (Oberthema) in die Datenbank schreiben
  Future<void> addThemengebiet(int fachrichtungId, String name) async {
    final db = await DatabaseService.instance.database;
    
    await db.insert('themengebiet', {
      'fachrichtung_id': fachrichtungId,
      'name': name,
      'beschreibung': 'Neu hinzugefügtes Thema', // Standard-Beschreibung
      'reihenfolge': 0,
    });
  }

  // Hier kommt später die Funktion für "addFrage" hin!
}