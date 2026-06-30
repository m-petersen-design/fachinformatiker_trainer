/// **Datenmodell: Themengebiet**
/// Diese Klasse repräsentiert eine Unterkategorie in der Lern-App 
/// (z.B. "Netzwerktechnik" als Teil der Fachrichtung "FISI").
/// Sie dient als Data Transfer Object (DTO), um eine Zeile aus der 
/// SQLite-Tabelle `themengebiet` im Arbeitsspeicher abzubilden.
class Themengebiet {
  
  // --- EIGENSCHAFTEN (Immutability & Relationale Abbildung) ---
  // Alle Eigenschaften sind 'final'. Das Objekt ist nach der Erstellung unveränderlich,
  // was unvorhergesehene State-Bugs in der Benutzeroberfläche verhindert.
  final int id;
  
  // Der Fremdschlüssel (Foreign Key). 
  // Das ist der wichtigste architektonische Ankerpunkt dieser Klasse! 
  // Er verbindet N Themengebiete mit genau EINER Fachrichtung (1:n-Beziehung).
  final int fachrichtungId; 
  
  final String name;
  
  // --- SOUND NULL SAFETY ---
  // Das '?' markiert die Beschreibung als "nullable" (kann 'null' sein).
  // Nicht jedes Themengebiet benötigt zwingend einen Erklärtext. 
  // Dart zwingt uns dadurch später im UI, diese Variable sicher zu entpacken,
  // bevor wir sie anzeigen, um Null-Pointer-Exceptions zu vermeiden.
  final String? beschreibung; 
  
  final int reihenfolge; // Dient zur festen Sortierung der Themengebiete im Dashboard

  /// **Konstruktor**
  /// Definiert die Parameter-Übergabe beim Instanziieren des Objekts.
  /// Felder wie die ID und der Name sind 'required' (zwingend erforderlich).
  /// Die Beschreibung ist optional, da der Typ 'String?' dies explizit zulässt.
  Themengebiet({
    required this.id,
    required this.fachrichtungId,
    required this.name,
    this.beschreibung,
    required this.reihenfolge,
  });

  /// **Deserialisierung: fromMap (Datenbank -> Dart-Objekt)**
  /// Dieser Factory-Konstruktor wandelt das generische Map-Format der SQLite-Datenbank
  /// in ein stark typisiertes 'Themengebiet'-Objekt um.
  factory Themengebiet.fromMap(Map<String, dynamic> map) {
    return Themengebiet(
      // Exaktes Mapping der SQL-Spaltennamen auf die Dart-Eigenschaften
      id: map['id'],
      fachrichtungId: map['fachrichtung_id'],
      name: map['name'],
      beschreibung: map['beschreibung'],
      
      // Fallback-Logik (Null-Coalescing Operator '??'):
      // Sollte die Datenbank bei der Sortierung keinen Wert (null) zurückgeben,
      // fällt die App nicht auf die Nase, sondern weist standardmäßig die Reihenfolge 0 zu.
      reihenfolge: map['reihenfolge'] ?? 0,
    );
  }
}