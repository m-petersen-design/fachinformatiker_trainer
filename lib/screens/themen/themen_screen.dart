import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/fach_provider.dart';
import '../../models/fachrichtung.dart'; 
import '../quiz/quiz_screen.dart'; // <-- Import ist schon da, super!

class ThemenScreen extends ConsumerWidget {
  final Fachrichtung fachrichtung;

  const ThemenScreen({super.key, required this.fachrichtung});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themenAsync = ref.watch(themengebieteProvider(fachrichtung.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Themen: ${fachrichtung.kuerzel}'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: themenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Fehler: $error')),
        data: (themen) {
          if (themen.isEmpty) {
            return Center(
              child: Text('Noch keine Themen für ${fachrichtung.kuerzel} verfügbar.', style: const TextStyle(fontSize: 18)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: themen.length,
            itemBuilder: (context, index) {
              final thema = themen[index];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.folder, color: Colors.white)),
                  title: Text(thema.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  trailing: const Icon(Icons.play_arrow, color: Colors.green, size: 30),
                  
                  // ==========================================
                  // HIER IST DIE ÄNDERUNG:
                  // ==========================================
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizScreen(thema: thema),
                      ),
                    );
                  },
                  // ==========================================
                  
                ),
              );
            },
          );
        },
      ),
    );
  }
}