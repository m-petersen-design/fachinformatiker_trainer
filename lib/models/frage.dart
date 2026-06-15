class Frage {
  final int id;
  final int themengebietId;
  final String frageText;
  final String typ;
  final String? erklaerung;
  final int schwierigkeit;

  Frage({
    required this.id,
    required this.themengebietId,
    required this.frageText,
    required this.typ,
    this.erklaerung,
    required this.schwierigkeit,
  });

  factory Frage.fromMap(Map<String, dynamic> map) {
    return Frage(
      id: map['id'],
      themengebietId: map['themengebiet_id'],
      frageText: map['frage_text'],
      typ: map['typ'],
      erklaerung: map['erklaerung'],
      schwierigkeit: map['schwierigkeit'] ?? 1,
    );
  }
}