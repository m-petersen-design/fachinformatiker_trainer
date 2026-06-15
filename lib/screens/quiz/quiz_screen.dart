import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/quiz_provider.dart';
import '../../models/themengebiet.dart';

class QuizScreen extends ConsumerWidget {
  final Themengebiet thema;

  const QuizScreen({super.key, required this.thema});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Wir laden alle Fragen für das angeklickte Thema
    final fragenAsync = ref.watch(fragenProvider(thema.id));

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
          // Fallback, falls ein Thema noch keine Fragen hat
          if (fragen.isEmpty) {
            return const Center(
              child: Text('Hier gibt es bald spannende Fragen!', style: TextStyle(fontSize: 18)),
            );
          }

          // Für unseren ersten Test nehmen wir direkt die erste gefundene Frage
          final aktuelleFrage = fragen.first;
          
          // 2. Wir laden die Antworten genau zu dieser Frage
          final antwortenAsync = ref.watch(antwortenProvider(aktuelleFrage.id));

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Frage 1 / ${fragen.length}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
                // Die eigentliche Frage
                Text(
                  aktuelleFrage.frageText,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                // Die Antwort-Buttons laden und anzeigen
                Expanded(
                  child: antwortenAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Fehler: $err')),
                    data: (antworten) {
                      return ListView.builder(
                        itemCount: antworten.length,
                        itemBuilder: (context, index) {
                          final antwort = antworten[index];
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                // Simple Logik: Ist es richtig oder falsch?
                                if (antwort.istKorrekt) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('✅ Richtig!'), backgroundColor: Colors.green),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('❌ Falsch!'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              child: Text(antwort.text, style: const TextStyle(fontSize: 18)),
                            ),
                          );
                        },
                      );
                    },
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