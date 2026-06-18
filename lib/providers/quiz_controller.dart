import 'package:flutter_riverpod/flutter_riverpod.dart';

// Diese Klasse hält den aktuellen Zustand deines Quiz-Durchlaufs
class QuizState {
  final int aktuelleFrageIndex;
  final int punkte;
  final int? ausgewaehlteOptionIndex;
  final bool hatGeantwortet;

  QuizState({
    this.aktuelleFrageIndex = 0,
    this.punkte = 0,
    this.ausgewaehlteOptionIndex,
    this.hatGeantwortet = false,
  });
}

// Der Controller verwaltet die Logik (Antwort prüfen, nächste Frage)
class QuizController extends StateNotifier<QuizState> {
  QuizController() : super(QuizState());

  void antwortAuswaehlen(int optionIndex, int richtigeOptionIndex) {
    if (state.hatGeantwortet) return; // Nichts tun, wenn man schon geklickt hat

    int neuePunkte = state.punkte;
    if (optionIndex == richtigeOptionIndex) {
      neuePunkte++; // Punkt vergeben, wenn richtig
    }

    state = QuizState(
      aktuelleFrageIndex: state.aktuelleFrageIndex,
      punkte: neuePunkte,
      ausgewaehlteOptionIndex: optionIndex,
      hatGeantwortet: true,
    );
  }

  void naechsteFrage() {
    state = QuizState(
      aktuelleFrageIndex: state.aktuelleFrageIndex + 1,
      punkte: state.punkte,
      ausgewaehlteOptionIndex: null, // Reset für die neue Frage
      hatGeantwortet: false,
    );
  }

  void reset() {
    state = QuizState();
  }
}

// autoDispose sorgt dafür, dass das Quiz zurückgesetzt wird, wenn du den Screen verlässt
final quizControllerProvider = StateNotifierProvider.autoDispose<QuizController, QuizState>((ref) {
  return QuizController();
});