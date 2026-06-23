class Fachrichtung {
  final int id;
  final String name;
  final String kuerzel;
  final String beschreibung;
  final String farbeHex;
  final int xp;

  Fachrichtung({
    required this.id,
    required this.name,
    required this.kuerzel,
    this.beschreibung = '',
    this.farbeHex = '#00E5FF', // Standardmäßig unser neues Cyan
    this.xp = 0,
  });

  factory Fachrichtung.fromMap(Map<String, dynamic> map) {
    return Fachrichtung(
      id: map['id'] as int,
      name: map['name'] as String,
      kuerzel: map['kuerzel'] as String,
      beschreibung: map['beschreibung']?.toString() ?? '',
      farbeHex: map['farbe_hex']?.toString() ?? '#00E5FF',
      xp: map['xp'] as int? ?? 0,
    );
  }

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