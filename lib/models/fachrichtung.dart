/// **Datenmodell: Fachrichtung**
/// Diese Klasse repräsentiert eine Hauptkategorie in der App (z. B. "FISI" oder "FIAE").
/// Sie fungiert als Data Transfer Object (DTO), das die unstrukturierten Daten 
/// der SQLite-Datenbank in typensichere, saubere Dart-Objekte kapselt.
class Fachrichtung {
  
  // --- EIGENSCHAFTEN (Immutability / Unveränderlichkeit) ---
  // Alle Attribute sind 'final'. Wenn eine Fachrichtung einmal aus der Datenbank 
  // geladen wurde, kann ihr Name oder Kürzel im Arbeitsspeicher nicht mehr 
  // versehentlich überschrieben werden. Das verhindert Seiteneffekte (Side Effects).
  final int id;
  final String name;
  final String kuerzel;
  final String beschreibung;
  final String farbeHex;
  final int xp; // Speichert die gesammelten Erfahrungspunkte des Nutzers in dieser Kategorie

  /// **Konstruktor mit Default-Values (Standardwerten)**
  /// Hier zeigen wir sauberes Design: 'id', 'name' und 'kuerzel' MÜSSEN übergeben werden (required).
  /// Für 'beschreibung', 'farbeHex' und 'xp' definieren wir Fallback-Werte.
  /// Falls beim Erstellen des Objekts keine Farbe mitgegeben wird, fällt das System
  /// automatisch auf unser Standard-Cyan ('#00E5FF') zurück, anstatt abzustürzen.
  Fachrichtung({
    required this.id,
    required this.name,
    required this.kuerzel,
    this.beschreibung = '',
    this.farbeHex = '#00E5FF', 
    this.xp = 0,
  });

  /// **Deserialisierung: fromMap (Datenbank -> Dart-Objekt)**
  /// Ein Factory-Konstruktor, der die rohen SQLite-Daten (Map) entgegennimmt 
  /// und daraus ein stark typisiertes Dart-Objekt formt.
  factory Fachrichtung.fromMap(Map<String, dynamic> map) {
    return Fachrichtung(
      // 'as int' und 'as String' sind explizite Type-Casts. 
      // Sie garantieren dem Compiler, dass wir hier wirklich Zahlen und Texte erwarten.
      id: map['id'] as int,
      name: map['name'] as String,
      kuerzel: map['kuerzel'] as String,
      
      // --- NULL-SAFETY & ERROR HANDLING ---
      // map['beschreibung']?.toString() ?? ''
      // Das ist defensives Programmieren vom Feinsten! 
      // 1. Das '?.' prüft: Ist der Wert überhaupt in der DB vorhanden?
      // 2. 'toString()' stellt sicher, dass selbst Zahlen als Text interpretiert werden.
      // 3. Der Null-Coalescing-Operator '??' sagt: Wenn der linke Teil 'null' ist, nimm den leeren String ''.
      beschreibung: map['beschreibung']?.toString() ?? '',
      farbeHex: map['farbe_hex']?.toString() ?? '#00E5FF',
      xp: map['xp'] as int? ?? 0,
    );
  }

  /// **Serialisierung: toMap (Dart-Objekt -> Datenbank)**
  /// Das exakte Gegenstück zu 'fromMap'. Diese Methode nimmt das aktuelle Objekt
  /// und bricht es in ein Key-Value-Format (Map) herunter, das SQLite versteht.
  /// Wird z. B. benötigt, wenn der Nutzer ein Quiz abschließt und die neuen XP
  /// per SQL-UPDATE wieder in die Datenbank geschrieben werden müssen.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'kuerzel': kuerzel,
      'beschreibung': beschreibung,
      'farbe_hex': farbeHex,
      'xp': xp,
    };
  }
}