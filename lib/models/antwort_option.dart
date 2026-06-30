/// **Datenmodell: AntwortOption**
/// Diese Klasse repräsentiert eine einzelne Antwortmöglichkeit für eine Multiple-Choice-Frage.
/// Sie spiegelt exakt eine Zeile der Tabelle `antwort_option` in der SQLite-Datenbank wider.
/// Durch die Nutzung dieser Klasse (statt roher Maps) profitieren wir von Typsicherheit,
/// Autovervollständigung in der IDE und verhindern Tippfehler bei Map-Keys.
class AntwortOption {
  // --- EIGENSCHAFTEN (Attribute) ---
  // Das Keyword 'final' macht diese Klasse "immutable" (unveränderlich).
  // Das ist Best Practice in Flutter für Datenmodelle: Sobald eine Antwort aus der DB 
  // geladen wurde, darf sie zur Laufzeit im Speicher nicht mehr manipuliert werden.
  final int id;
  final int frageId; // Fremdschlüssel (Foreign Key), der diese Antwort mit einer Frage verknüpft
  final String text;
  final bool istKorrekt;
  final int reihenfolge; // Dient zur festen oder gemischten Sortierung der Buttons im UI

  /// **Konstruktor**
  /// Nutzt "Named Parameters" (geschweifte Klammern) und das 'required'-Keyword.
  /// Das zwingt den Entwickler dazu, beim Erstellen eines Objekts alle Werte 
  /// explizit und fehlerfrei mitzugeben.
  AntwortOption({
    required this.id,
    required this.frageId,
    required this.text,
    required this.istKorrekt,
    required this.reihenfolge,
  });

  /// **Factory-Konstruktor: fromMap**
  /// Ein Factory-Konstruktor in Dart erzeugt nicht zwingend eine komplett neue Instanz von Grund auf,
  /// sondern kann bestehende Daten (hier: ein Datenbank-Ergebnis) "umwandeln" und zurückgeben.
  /// Diese Methode ist unser "Übersetzer" zwischen der SQLite-Datenbank und der Dart-Welt.
  factory AntwortOption.fromMap(Map<String, dynamic> map) {
    return AntwortOption(
      // Die Keys im Map-Array (z.B. 'frage_id') entsprechen exakt den Spaltennamen in der SQL-Tabelle.
      id: map['id'],
      frageId: map['frage_id'],
      text: map['text'],
      
      // -- DER SQLITE-BOOLEAN-TRICK --
      // SQLite besitzt nativ keinen Datentyp für 'boolean' (true/false).
      // Es speichert Wahrheitswerte als Integer (0 = false, 1 = true).
      // Dart ist jedoch streng typisiert und benötigt ein echtes 'bool'. 
      // Der Ausdruck `map['ist_korrekt'] == 1` löst dieses Problem elegant während der Instanziierung:
      // Wenn in der DB eine 1 steht, evaluiert der Ausdruck zu 'true', ansonsten zu 'false'.
      istKorrekt: map['ist_korrekt'] == 1,
      
      // Der Null-Coalescing-Operator '??' dient als Fallback. 
      // Sollte die DB aus irgendeinem Grund 'null' bei der Reihenfolge zurückgeben, wird der Standardwert 0 gesetzt.
      reihenfolge: map['reihenfolge'] ?? 0,
    );
  }
}