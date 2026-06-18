import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/quiz_controller.dart'; // <-- Der Controller wird importiert
import '../../models/themengebiet.dart';

class QuizScreen extends ConsumerWidget {
  final Themengebiet thema;

  const QuizScreen({super.key, required this.thema});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fragenAsync = ref.watch(fragenProvider(thema.id));
    
    // Hier klinken wir den Controller ein!
    final quizState = ref.watch(quizControllerProvider);
    final quizNotifier = ref.read(quizControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(thema.name),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: fragenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Fehler: $err')),
        data: (fragen) {
          if (fragen.isEmpty) {
            return const Center(
              child: Text('Hier gibt es bald spannende Fragen!', style: TextStyle(fontSize: 18)),
            );
          }

          // Wenn das Quiz durchgespielt ist, zeige den Endbildschirm
          if (quizState.aktuelleFrageIndex >= fragen.length) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Quiz beendet! 🎉", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text("Dein Score: ${quizState.punkte} / ${fragen.length}", style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      quizNotifier.reset(); // Controller für das nächste Mal zurücksetzen
                      Navigator.pop(context);
                    },
                    child: const Text("Zurück zu den Themen"),
                  )
                ],
              ),
            );
          }

          // Wir holen die Frage basierend auf dem Controller-Index
          final aktuelleFrage = fragen[quizState.aktuelleFrageIndex];
          final antwortenAsync = ref.watch(antwortenProvider(aktuelleFrage.id));

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Frage ${quizState.aktuelleFrageIndex + 1} / ${fragen.length}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(
                  aktuelleFrage.frageText,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                Expanded(
                  child: antwortenAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Fehler: $err')),
                    data: (antworten) {
                      // Wir suchen heraus, an welcher Stelle die korrekte Antwort steht
                      int richtigeOptionIndex = antworten.indexWhere((a) => a.istKorrekt);

                      return ListView.builder(
                        itemCount: antworten.length,
                        itemBuilder: (context, index) {
                          final antwort = antworten[index];

                          // Farb-Logik für Grün/Rot
                          Color buttonColor = Colors.blueAccent;
                          if (quizState.hatGeantwortet) {
                            if (index == richtigeOptionIndex) {
                              buttonColor = Colors.green;
                            } else if (index == quizState.ausgewaehlteOptionIndex) {
                              buttonColor = Colors.red;
                            } else {
                              buttonColor = Colors.grey;
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                quizNotifier.antwortAuswaehlen(index, richtigeOptionIndex);
                              },
                              child: Text(antwort.text, style: const TextStyle(fontSize: 18)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                
                // Der "Weiter"-Button taucht erst auf, wenn geantwortet wurde
                if (quizState.hatGeantwortet)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => quizNotifier.naechsteFrage(),
                      child: const Text("Nächste Frage", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}