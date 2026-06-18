import '../core/database/database_service.dart';

class AdminRepository {
  
  // Funktion: Neues Themengebiet (Oberthema) in die Datenbank schreiben
  Future<void> addThemengebiet(int fachrichtungId, String name) async {
    final db = await DatabaseService.instance.database;
    
    await db.insert('themengebiet', {
      'fachrichtung_id': fachrichtungId,
      'name': name,
      'beschreibung': 'Neu hinzugefügtes Thema',
      'reihenfolge': 0,
    });
  }

  // NEU: Komplette Frage mit Antworten speichern
  Future<void> addFrageMitAntworten({
    required int themengebietId,
    required String frageText,
    required String typ,
    String? bildPfad,
    String? erklaerung,
    required List<Map<String, dynamic>> antworten, 
  }) async {
    final db = await DatabaseService.instance.database;

    // 1. Die Frage anlegen
    final frageId = await db.insert('frage', {
      'themengebiet_id': themengebietId,
      'frage_text': frageText,
      'typ': typ,
      'bild_pfad': bildPfad,
      'erklaerung': erklaerung,
      'schwierigkeit': 1,
    });

    // 2. Die dazugehörigen Antworten anlegen
    for (var i = 0; i < antworten.length; i++) {
      await db.insert('antwort_option', {
        'frage_id': frageId,
        'text': antworten[i]['text'],
        'ist_korrekt': antworten[i]['ist_korrekt'],
        'reihenfolge': i,
      });
    }
  }
}