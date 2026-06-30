import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Zustandsmodell: QuizState**
/// Diese Klasse ist eine reine Datenstruktur. Sie hält den exakten Zustand 
/// eines laufenden Quiz-Durchlaufs zu einem bestimmten Zeitpunkt fest.
/// Wichtig: Sie beinhaltet KEINE Logik, sondern nur Daten.
class QuizState {
  // --- IMMUTABILITY (Unveränderlichkeit) ---
  // Alle Felder sind 'final'. In modernen State-Management-Architekturen (wie Riverpod) 
  // darf ein bestehender Zustand niemals direkt verändert (mutiert) werden. 
  // Wenn sich etwas ändert, wird immer ein komplett neues QuizState-Objekt erzeugt.
  final int aktuelleFrageIndex;
  final int punkte;
  
  // Nullable ('int?'), weil am Anfang der Frage noch keine Option angeklickt wurde.
  final int? ausgewaehlteOptionIndex; 
  final bool hatGeantwortet;

  /// **Konstruktor mit Default-Werten**
  /// Initialisiert ein neues Quiz. Wenn beim Erstellen keine Werte übergeben werden,
  /// startet das Quiz logischerweise bei Frage 0, mit 0 Punkten und ohne Antwort.
  QuizState({
    this.aktuelleFrageIndex = 0,
    this.punkte = 0,
    this.ausgewaehlteOptionIndex,
    this.hatGeantwortet = false,
  });
}

/// **Geschäftslogik: QuizController (StateNotifier)**
/// Diese Klasse ist der "Gehirn"-Teil des Quizzes (Controller/ViewModel).
/// Sie erbt von 'StateNotifier' und überwacht genau ein Objekt vom Typ 'QuizState'.
/// Die Flutter-UI "hört" auf diesen Controller und zeichnet sich automatisch neu, 
/// sobald dieser Controller einen neuen Zustand (state) publiziert.
class QuizController extends StateNotifier<QuizState> {
  
  // Der Konstruktor ruft super() auf und übergibt den Startzustand (ein leeres QuizState-Objekt).
  QuizController() : super(QuizState());

  /// **Methode: Antwort verarbeiten**
  /// Wird von der UI aufgerufen, wenn der Nutzer auf einen Antwort-Button klickt.
  void antwortAuswaehlen(int optionIndex, int richtigeOptionIndex) {
    // --- STATE GUARD (Wächter) ---
    // Verhindert Spam-Klicks. Wenn der User schon geantwortet hat, 
    // bricht die Methode sofort ab (Early Return).
    if (state.hatGeantwortet) return; 

    // Punkte-Logik: Wir lesen den aktuellen Punktestand aus dem 'state' aus.
    int neuePunkte = state.punkte;
    if (optionIndex == richtigeOptionIndex) {
      neuePunkte++; // XP/Punkt vergeben, wenn die Antwort korrekt war
    }

    // --- STATE REBUILD (Zustands-Neubau) ---
    // Hier ist der Beweis für Immutability! Wir machen nicht 'state.punkte++'.
    // Stattdessen überschreiben wir das globale 'state'-Objekt mit einer 
    // komplett neuen Instanz, die die neuen Werte enthält.
    // Das Zuweisen des neuen Objekts signalisiert Riverpod: "Achtung, UI neu zeichnen!"
    state = QuizState(
      aktuelleFrageIndex: state.aktuelleFrageIndex, // Bleibt gleich
      punkte: neuePunkte,                           // Wurde ggf. erhöht
      ausgewaehlteOptionIndex: optionIndex,         // Speichert den Klick des Users
      hatGeantwortet: true,                         // Sperrt weitere Klicks
    );
  }

  /// **Methode: Zur nächsten Frage springen**
  void naechsteFrage() {
    // Erschafft einen neuen Zustand für die kommende Frage.
    state = QuizState(
      aktuelleFrageIndex: state.aktuelleFrageIndex + 1, // Index rückt eins vor
      punkte: state.punkte,                             // Punkte werden übernommen
      ausgewaehlteOptionIndex: null, // Reset: Die neuen Buttons sind wieder unangeklickt
      hatGeantwortet: false,         // Reset: User darf wieder klicken
    );
  }

  /// **Methode: Quiz abbrechen oder neustarten**
  void reset() {
    // Setzt den State einfach wieder auf die Standardwerte des Konstruktors zurück.
    state = QuizState();
  }
}

/// **Provider-Definition: Memory Management**
/// Dieser Provider stellt den QuizController global für die UI zur Verfügung.
/// 
/// Der Modifier '.autoDispose' ist ein mächtiges Architektur-Feature:
/// Er sorgt dafür, dass der Controller (und damit der QuizState) automatisch 
/// aus dem Arbeitsspeicher (RAM) gelöscht wird, sobald der Nutzer den Quiz-Screen 
/// verlässt (z.B. zurück zum Dashboard geht). Startet er ein neues Quiz, 
/// baut Riverpod den Controller komplett frisch auf. Das verhindert Memory Leaks.
final quizControllerProvider = StateNotifierProvider.autoDispose<QuizController, QuizState>((ref) {
  return QuizController();
});