import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            _buildFachrichtungCard('FISI', 'Systemintegration', Icons.computer),
            const SizedBox(height: 16),
            _buildFachrichtungCard('FIAE', 'Anwendungsentwicklung', Icons.code),
            const SizedBox(height: 16),
            _buildFachrichtungCard('FIDP', 'Daten- und Prozessanalyse', Icons.analytics),
          ],
        ),
      ),
    );
  }

  // Ein kleines Hilfs-Widget für die Karten
  Widget _buildFachrichtungCard(String kuerzel, String name, IconData icon) {
    return Card(
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Icon(icon, size: 40, color: Colors.blueAccent),
        title: Text(kuerzel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        subtitle: Text(name),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // Hier kommt später die Navigation zum Quiz hin
          print('$kuerzel wurde geklickt!');
        },
      ),
    );
  }
}