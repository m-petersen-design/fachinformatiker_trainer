/// **Datenmodell: Frage**
/// Diese Klasse repräsentiert eine einzelne Prüfungsfrage im System.
/// Sie dient als zentrales Data Transfer Object (DTO), um eine Zeile aus der 
/// Tabelle `frage` der SQLite-Datenbank typsicher im Arbeitsspeicher abzubilden.
class Frage {
  
  // --- EIGENSCHAFTEN (Immutability) ---
  // Alle Eigenschaften sind 'final', was das Objekt nach der Instanziierung unveränderlich macht.
  // Das ist wichtig, da Prüfungsfragen statische Stammdaten sind, die der Nutzer
  // zur Laufzeit nicht manipulieren darf.
  final int id;
  final int themengebietId; // Fremdschlüssel: Ordnet die Frage z.B. "Netzwerktechnik" zu
  final String frageText;
  final String typ; // z.B. 'multiple_choice' oder 'freitext'
  
  // --- SOUND NULL SAFETY ---
  // Das '?' hinter String bedeutet: Dieser Wert ist "nullable". 
  // Er darf absichtlich 'null' sein. Nicht jede Frage in unserer Datenbank 
  // hat zwingend eine vorgefertigte Musterlösung/Erklärung hinterlegt.
  // Durch diese Typisierung zwingt uns der Dart-Compiler später im UI-Code,
  // zu prüfen, ob die Erklärung existiert, bevor wir sie auf dem Bildschirm rendern.
  final String? erklaerung; 
  
  final int schwierigkeit;

  /// **Konstruktor**
  /// Definiert die Parameter-Übergabe beim Erzeugen eines neuen Frage-Objekts.
  /// Alle Felder außer der Erklärung sind 'required' (zwingend erforderlich),
  /// da eine Frage ohne Text oder Typ systemtechnisch keinen Sinn ergeben würde.
  Frage({
    required this.id,
    required this.themengebietId,
    required this.frageText,
    required this.typ,
    this.erklaerung, // Optional, da nicht jede Frage eine Erklärung besitzt
    required this.schwierigkeit,
  });

  /// **Deserialisierung: fromMap (Datenbank -> Dart-Objekt)**
  /// Dieser Factory-Konstruktor ist unser "Übersetzer". Er nimmt das Dictionary (Map),
  /// das uns das 'sqflite'-Paket nach einem SELECT-Befehl zurückgibt, und formt
  /// daraus ein echtes 'Frage'-Objekt für unsere Geschäftslogik.
  factory Frage.fromMap(Map<String, dynamic> map) {
    return Frage(
      // Mappt die Spaltennamen der SQL-Tabelle direkt auf die Dart-Eigenschaften
      id: map['id'],
      themengebietId: map['themengebiet_id'],
      frageText: map['frage_text'],
      typ: map['typ'],
      erklaerung: map['erklaerung'],
      
      // Fallback-Logik (Null-Coalescing Operator):
      // Sollte in der Datenbank bei Schwierigkeit ein fehlerhafter NULL-Wert stehen,
      // stürzt die App nicht ab, sondern setzt die Schwierigkeit standardmäßig auf 1 (leicht).
      schwierigkeit: map['schwierigkeit'] ?? 1,
    );
  }
}