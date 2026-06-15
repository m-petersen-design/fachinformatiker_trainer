import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/fach_provider.dart';
import '../../models/fachrichtung.dart'; // <-- Dieser Import ist wichtig!
import '../themen/themen_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fachrichtungenAsync = ref.watch(fachrichtungenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fachinformatiker Trainer'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Wähle deine Fachrichtung',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            Expanded(
              child: fachrichtungenAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Fehler: $error')),
                data: (fachrichtungen) {
                  return ListView.builder(
                    itemCount: fachrichtungen.length,
                    itemBuilder: (context, index) {
                      final fach = fachrichtungen[index];
                      
                      IconData icon = Icons.computer;
                      if (fach.kuerzel == 'FIAE') icon = Icons.code;
                      if (fach.kuerzel == 'FIDP') icon = Icons.analytics;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        // KORREKTUR: Wir übergeben das ganze 'fach'-Objekt statt der einzelnen Strings
                        child: _buildFachrichtungCard(context, fach, icon),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Diese Funktion erwartet das gesamte 'Fachrichtung'-Objekt
  Widget _buildFachrichtungCard(BuildContext context, Fachrichtung fach, IconData icon) {
    return Card(
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Icon(icon, size: 40, color: Colors.blueAccent),
        title: Text(fach.kuerzel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        subtitle: Text(fach.name),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ThemenScreen(fachrichtung: fach),
            ),
          );
        },
      ),
    );
  }
}