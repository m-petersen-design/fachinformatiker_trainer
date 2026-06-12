class Fachrichtung {
  final int id;
  final String name;
  final String kuerzel;

  Fachrichtung({
    required this.id,
    required this.name,
    required this.kuerzel,
  });

  factory Fachrichtung.fromMap(
    Map<String, dynamic> map,
  ) {
    return Fachrichtung(
      id: map["id"],
      name: map["name"],
      kuerzel: map["kuerzel"],
    );
  }
}