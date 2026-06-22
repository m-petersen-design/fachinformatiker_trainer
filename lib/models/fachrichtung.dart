class Fachrichtung {
  final int id;
  final String kuerzel;
  final String name;
  final int xp; // NEU: Nimmt die XP aus der Datenbank auf

  Fachrichtung({
    required this.id,
    required this.kuerzel,
    required this.name,
    this.xp = 0,
  });

  factory Fachrichtung.fromMap(Map<String, dynamic> map) {
    return Fachrichtung(
      id: map['id'],
      kuerzel: map['kuerzel'],
      name: map['name'],
      xp: map['xp'] ?? 0, // NEU: Liest die XP sicher aus
    );
  }
}