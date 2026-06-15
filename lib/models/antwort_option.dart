class AntwortOption {
  final int id;
  final int frageId;
  final String text;
  final bool istKorrekt;
  final int reihenfolge;

  AntwortOption({
    required this.id,
    required this.frageId,
    required this.text,
    required this.istKorrekt,
    required this.reihenfolge,
  });

  factory AntwortOption.fromMap(Map<String, dynamic> map) {
    return AntwortOption(
      id: map['id'],
      frageId: map['frage_id'],
      text: map['text'],
      // Hier der Trick: Wenn 1 in der DB steht, wird istKorrekt zu 'true'
      istKorrekt: map['ist_korrekt'] == 1,
      reihenfolge: map['reihenfolge'] ?? 0,
    );
  }
}