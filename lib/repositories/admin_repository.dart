import '../core/database/database_service.dart';

/// **Repository Pattern: AdminRepository**
/// Diese Klasse kapselt alle schreibenden und löschenden Datenbankzugriffe (CRUD), 
/// die für die Verwaltung des Fragenkatalogs notwendig sind.
/// Die Benutzeroberfläche (z.B. ein verstecktes Admin-Dashboard) ruft nur diese 
/// Dart-Methoden auf und kommt nie direkt mit SQL-Code in Berührung.
class AdminRepository {
  
  // ==========================================
  // NEU: Eine komplette Fachrichtung anlegen
  // ==========================================
  /// Fügt eine neue Hauptkategorie (z.B. "IT-Sicherheit") in die Datenbank ein.
  Future<void> addFachrichtung(String kuerzel, String name) async {
    final db = await DatabaseService.instance.database;
    
    // Wir nutzen die typsichere .insert() Methode von sqflite, 
    // anstatt rohe SQL-Strings (INSERT INTO...) zu schreiben.
    await db.insert('fachrichtung', {
      'kuerzel': kuerzel,
      'name': name,
      // Hardcodierte Standardwerte für optionale Felder (Defensive Programmierung)
      'beschreibung': 'Manuell hinzugefügte Fachrichtung',
      'icon_name': 'school', 
    });
  }

  // ==========================================
  // Neues Themengebiet (Oberthema) anlegen
  // ==========================================
  /// Fügt ein neues Themengebiet hinzu und verknüpft es via Fremdschlüssel 
  /// (fachrichtungId) mit der übergeordneten Fachrichtung.
  Future<void> addThemengebiet(int fachrichtungId, String name) async {
    final db = await DatabaseService.instance.database;
    
    await db.insert('themengebiet', {
      'fachrichtung_id': fachrichtungId,
      'name': name,
      'beschreibung': 'Neu hinzugefügtes Thema',
      'reihenfolge': 0, // Sortierung standardmäßig ans Ende oder den Anfang setzen
    });
  }

  // ==========================================
  // Komplette Frage mit Antworten speichern
  // ==========================================
  /// Ein komplexer Insert-Vorgang, der die relationale Struktur der Datenbank nutzt.
  /// Nimmt eine Frage und eine Liste von Antwort-Maps entgegen und speichert sie verknüpft ab.
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
    // Der .insert() Befehl gibt praktischerweise die von SQLite generierte 
    // Auto-Increment ID als Integer zurück. Diese brauchen wir zwingend für Schritt 2.
    final frageId = await db.insert('frage', {
      'themengebiet_id': themengebietId,
      'frage_text': frageText,
      'typ': typ,
      'bild_pfad': bildPfad,
      'erklaerung': erklaerung,
      'schwierigkeit': 1,
    });

    // 2. Die dazugehörigen Antworten anlegen
    // Nur ausführen, wenn es sich um eine Multiple-Choice-Frage handelt.
    if (typ == 'multiple_choice') {
      for (var i = 0; i < antworten.length; i++) {
        await db.insert('antwort_option', {
          // Hier entsteht die relationale Verknüpfung (Foreign Key Mapping)
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
  /// Löscht massenhaft Daten basierend auf dem Fremdschlüssel.
  Future<void> clearThemengebietFragen(int themengebietId) async {
    final db = await DatabaseService.instance.database;
    
    // LÖSCHVORGANG 1: Kinder (Antworten) löschen, um Waisen-Daten zu verhindern.
    // Ein Sub-Select ermittelt alle Antwort-IDs, die zu Fragen des jeweiligen Themas gehören.
    await db.delete(
      'antwort_option',
      where: 'frage_id IN (SELECT id FROM frage WHERE themengebiet_id = ?)',
      whereArgs: [themengebietId],
    );
    
    // LÖSCHVORGANG 2: Eltern (Fragen) löschen.
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
    
    // --- SQL-INJECTION PRÄVENTION ---
    // Wir nutzen hier BEWUSST parametrisierte Queries (whereArgs: [frageId]).
    // Würden wir stattdessen String-Interpolation nutzen (where: 'id = $frageId'), 
    // wäre die Datenbank anfällig für SQL-Injection-Angriffe!
    await db.delete('antwort_option', where: 'frage_id = ?', whereArgs: [frageId]);
    await db.delete('frage', where: 'id = ?', whereArgs: [frageId]);
  }
}