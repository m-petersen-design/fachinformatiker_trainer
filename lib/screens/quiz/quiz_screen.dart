import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/quiz_controller.dart';
import '../../models/themengebiet.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final Themengebiet thema;
  const QuizScreen({super.key, required this.thema});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  bool _zeigeLoesung = false;
  final _notizController = TextEditingController();

  @override
  void dispose() {
    _notizController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fragenAsync = ref.watch(fragenProvider(widget.thema.id));
    final quizState = ref.watch(quizControllerProvider);
    final quizNotifier = ref.read(quizControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.thema.name),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: fragenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Fehler: $err')),
        data: (fragen) {
          if (fragen.isEmpty) {
            return const Center(child: Text('Hier gibt es bald spannende Fragen!', style: TextStyle(fontSize: 18)));
          }

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
                      quizNotifier.reset();
                      Navigator.pop(context);
                    },
                    child: const Text("Zurück zu den Themen"),
                  )
                ],
              ),
            );
          }

          final aktuelleFrage = fragen[quizState.aktuelleFrageIndex];

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Frage ${quizState.aktuelleFrageIndex + 1} / ${fragen.length}  (${aktuelleFrage.typ == "freitext" ? "Offene Frage" : "Multiple Choice"})',
                  style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(
                  aktuelleFrage.frageText,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // ==========================================
                // LOGIK 1: FREITEXT FRAGEN
                // ==========================================
                if (aktuelleFrage.typ == 'freitext') ...[
                  if (!_zeigeLoesung) ...[
                    Expanded(
                      child: TextField(
                        controller: _notizController,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          hintText: 'Mache dir hier Notizen oder überlege dir die Antwort...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      onPressed: () {
                        setState(() {
                          _zeigeLoesung = true;
                        });
                      },
                      child: const Text('Musterlösung anzeigen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    Expanded(
                      child: SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Musterlösung:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                              const SizedBox(height: 10),
                              Text(aktuelleFrage.erklaerung ?? 'Keine Musterlösung hinterlegt.', style: const TextStyle(fontSize: 16, height: 1.5)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Wie gut wusstest du die Antwort?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () {
                              quizNotifier.antwortAuswaehlen(0, 1); // Zählt als Falsch
                              setState(() { _zeigeLoesung = false; _notizController.clear(); });
                              quizNotifier.naechsteFrage();
                            },
                            child: const Text('Wusste ich NICHT'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () {
                              quizNotifier.antwortAuswaehlen(1, 1); // Zählt als Richtig
                              setState(() { _zeigeLoesung = false; _notizController.clear(); });
                              quizNotifier.naechsteFrage();
                            },
                            child: const Text('Wusste ich'),
                          ),
                        ),
                      ],
                    )
                  ]
                ]

                // ==========================================
                // LOGIK 2: MULTIPLE CHOICE FRAGEN
                // ==========================================
                else ...[
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final antwortenAsync = ref.watch(antwortenProvider(aktuelleFrage.id));
                        return antwortenAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, stack) => Center(child: Text('Fehler: $err')),
                          data: (antworten) {
                            if (antworten.isEmpty) return const Text("Keine Antworten gefunden.");
                            int richtigeOptionIndex = antworten.indexWhere((a) => a.istKorrekt);

                            return ListView.builder(
                              itemCount: antworten.length,
                              itemBuilder: (context, index) {
                                final antwort = antworten[index];
                                Color buttonColor = Colors.blueGrey[800]!;
                                
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
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => quizNotifier.antwortAuswaehlen(index, richtigeOptionIndex),
                                    child: Text(antwort.text, style: const TextStyle(fontSize: 18)),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (quizState.hatGeantwortet)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        onPressed: () => quizNotifier.naechsteFrage(),
                        child: const Text("Nächste Frage", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}