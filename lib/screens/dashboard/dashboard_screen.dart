import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/fach_provider.dart';
import '../../models/fachrichtung.dart';
import '../themen/themen_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fachrichtungenAsync = ref.watch(fachrichtungenProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
            );
          },
          child: const Text('Fachinformatiker Trainer'),
        ),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(fachrichtungenProvider);
        },
        child: Padding(
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
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: fachrichtungen.length,
                      itemBuilder: (context, index) {
                        final fach = fachrichtungen[index];
                        
                        // ICON MAPPING FÜR ALLE 5 CATEGORIES
                        IconData icon = Icons.computer;
                        if (fach.kuerzel == 'FISI') icon = Icons.dns; 
                        if (fach.kuerzel == 'FIAE') icon = Icons.code;
                        if (fach.kuerzel == 'FIDP') icon = Icons.analytics;
                        if (fach.kuerzel == 'UNI') icon = Icons.school;
                        if (fach.kuerzel == 'BS') icon = Icons.menu_book;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildFachrichtungCard(context, ref, fach, icon),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFachrichtungCard(BuildContext context, WidgetRef ref, Fachrichtung fach, IconData icon) {
    int aktuelleXP = fach.xp;
    int aktuellesLevel = (aktuelleXP / 100).floor() + 1; 
    int xpFuerNaechstesLevel = aktuellesLevel * 100;
    double balkenFortschritt = (aktuelleXP % 100) / 100.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ThemenScreen(fachrichtung: fach),
            ),
          );
          ref.invalidate(fachrichtungenProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, size: 36, color: Colors.blueAccent),
                ),
                title: Text(fach.kuerzel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                subtitle: Text(fach.name, style: TextStyle(color: Colors.grey[700])),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Level $aktuellesLevel', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 16)),
                        Text('$aktuelleXP / $xpFuerNaechstesLevel XP', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: balkenFortschritt,
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}