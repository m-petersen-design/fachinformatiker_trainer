import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/quiz_repository.dart';
import '../models/frage.dart';
import '../models/antwort_option.dart';

final quizRepositoryProvider = Provider((ref) => QuizRepository());

// Provider für die Fragen
final fragenProvider = FutureProvider.family<List<Frage>, int>((ref, themengebietId) async {
  final repo = ref.watch(quizRepositoryProvider); // <-- watch statt read
  return repo.getFragenFuerThema(themengebietId);
});

// Provider für die Antworten
final antwortenProvider = FutureProvider.family<List<AntwortOption>, int>((ref, frageId) async {
  final repo = ref.watch(quizRepositoryProvider); // <-- watch statt read
  return repo.getAntwortenFuerFrage(frageId);
});