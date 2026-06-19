import '../core/database/database_service.dart';

class AdminRepository {
  
  // ==========================================
  // NEU: Eine komplette Fachrichtung anlegen
  // ==========================================
  Future<void> addFachrichtung(String kuerzel, String name) async {
    final db = await DatabaseService.instance.database;
    await db.insert('fachrichtung', {
      'kuerzel': kuerzel,
      'name': name,
      'beschreibung': 'Manuell hinzugefügte Fachrichtung',
      'icon_name': 'school', // Standard-Icon
    });
  }

  // ==========================================
  // Neues Themengebiet (Oberthema) anlegen
  // ==========================================
  Future<void> addThemengebiet(int fachrichtungId, String name) async {
    final db = await DatabaseService.instance.database;
    
    await db.insert('themengebiet', {
      'fachrichtung_id': fachrichtungId,
      'name': name,
      'beschreibung': 'Neu hinzugefügtes Thema',
      'reihenfolge': 0,
    });
  }

  // ==========================================
  // Komplette Frage mit Antworten speichern
  // ==========================================
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

    // 2. Die dazugehörigen Antworten anlegen (NUR bei Multiple Choice)
    if (typ == 'multiple_choice') {
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

  // ==========================================
  // Alle Fragen eines Themengebiets löschen
  // ==========================================
  Future<void> clearThemengebietFragen(int themengebietId) async {
    final db = await DatabaseService.instance.database;
    
    await db.delete(
      'antwort_option',
      where: 'frage_id IN (SELECT id FROM frage WHERE themengebiet_id = ?)',
      whereArgs: [themengebietId],
    );
    
    await db.delete(
      'frage',
      where: 'themengebiet_id = ?',
      whereArgs: [themengebietId],
    );
  }

  // ==========================================
  // Eine einzelne Frage anhand ihrer ID löschen
  // ==========================================
  Future<void> deleteFrage(int frageId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('antwort_option', where: 'frage_id = ?', whereArgs: [frageId]);
    await db.delete('frage', where: 'id = ?', whereArgs: [frageId]);
  }
}