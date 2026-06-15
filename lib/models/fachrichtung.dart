class Fachrichtung {
  final int id;
  final String name;
  final String kuerzel;
  final String? beschreibung;
  final String? iconName;
  final String farbeHex;

  Fachrichtung({
    required this.id,
    required this.name,
    required this.kuerzel,
    this.beschreibung,
    this.iconName,
    required this.farbeHex,
  });

  factory Fachrichtung.fromMap(Map<String, dynamic> map) {
    return Fachrichtung(
      id: map['id'],
      name: map['name'],
      kuerzel: map['kuerzel'],
      beschreibung: map['beschreibung'],
      iconName: map['icon_name'],
      farbeHex: map['farbe_hex'] ?? '#2196F3',
    );
  }
}