class Themengebiet {
  final int id;
  final int fachrichtungId;
  final String name;
  final String? beschreibung;
  final int reihenfolge;

  Themengebiet({
    required this.id,
    required this.fachrichtungId,
    required this.name,
    this.beschreibung,
    required this.reihenfolge,
  });

  factory Themengebiet.fromMap(Map<String, dynamic> map) {
    return Themengebiet(
      id: map['id'],
      fachrichtungId: map['fachrichtung_id'],
      name: map['name'],
      beschreibung: map['beschreibung'],
      reihenfolge: map['reihenfolge'] ?? 0,
    );
  }
}