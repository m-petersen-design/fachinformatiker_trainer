import 'package:flutter/material.dart';
import '../../models/fachrichtung.dart';
import '../../models/themengebiet.dart';
import '../../repositories/fach_repository.dart';
import '../../repositories/admin_repository.dart';

class AdminFrageScreen extends StatefulWidget {
  const AdminFrageScreen({super.key});

  @override
  State<AdminFrageScreen> createState() => _AdminFrageScreenState();
}

class _AdminFrageScreenState extends State<AdminFrageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _frageController = TextEditingController();
  final _erklaerungController = TextEditingController();
  
  // Controller für die 4 Antworten
  final List<TextEditingController> _antwortControllers = List.generate(4, (_) => TextEditingController());
  int _richtigeAntwortIndex = 0; // Standardmäßig ist Antwort 1 richtig

  Fachrichtung? _selectedFachrichtung;
  Themengebiet? _selectedThema;
  
  List<Fachrichtung> _fachrichtungen = [];
  List<Themengebiet> _themen = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ladeDaten();
  }

  Future<void> _ladeDaten() async {
    final repo = FachRepository();
    final daten = await repo.getFachrichtungen();
    setState(() {
      _fachrichtungen = daten;
      _isLoading = false;
    });
  }

  Future<void> _ladeThemen(int fachId) async {
    final repo = FachRepository();
    final themen = await repo.getThemengebiete(fachId);
    setState(() {
      _themen = themen;
      _selectedThema = null; // Reset Thema bei Fachwechsel
    });
  }

  Future<void> _frageSpeichern() async {
    if (_formKey.currentState!.validate() && _selectedThema != null) {
      final adminRepo = AdminRepository();
      
      // Antworten zusammenbauen
      List<Map<String, dynamic>> antworten = [];
      for (int i = 0; i < 4; i++) {
        antworten.add({
          'text': _antwortControllers[i].text,
          'ist_korrekt': i == _richtigeAntwortIndex ? 1 : 0,
        });
      }

      await adminRepo.addFrageMitAntworten(
        themengebietId: _selectedThema!.id,
        frageText: _frageController.text,
        typ: 'multiple_choice', // Fürs erste Formular fest auf MC
        erklaerung: _erklaerungController.text.isNotEmpty ? _erklaerungController.text : null,
        antworten: antworten,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Frage gespeichert!'), backgroundColor: Colors.green),
        );
        // Formular leeren für die nächste Frage
        _frageController.clear();
        _erklaerungController.clear();
        for (var c in _antwortControllers) {
          c.clear();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📝 Neue Frage anlegen'), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- KATEGORIE WAHL ---
                  DropdownButtonFormField<Fachrichtung>(
                    value: _selectedFachrichtung,
                    decoration: const InputDecoration(labelText: 'Fachrichtung', border: OutlineInputBorder()),
                    items: _fachrichtungen.map((f) => DropdownMenuItem(value: f, child: Text(f.kuerzel))).toList(),
                    onChanged: (val) {
                      setState(() => _selectedFachrichtung = val);
                      if (val != null) _ladeThemen(val.id);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Themengebiet>(
                    value: _selectedThema,
                    decoration: const InputDecoration(labelText: 'Themengebiet', border: OutlineInputBorder()),
                    items: _themen.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                    onChanged: (val) => setState(() => _selectedThema = val),
                  ),
                  const Divider(height: 40, thickness: 2),

                  // --- FRAGE ---
                  TextFormField(
                    controller: _frageController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Fragetext', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // --- ANTWORTEN ---
                  const Text('Antwortmöglichkeiten (Markiere die Richtige):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...List.generate(4, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: index,
                            groupValue: _richtigeAntwortIndex,
                            onChanged: (val) => setState(() => _richtigeAntwortIndex = val!),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _antwortControllers[index],
                              decoration: InputDecoration(labelText: 'Antwort ${index + 1}', border: const OutlineInputBorder()),
                              validator: (v) => v!.isEmpty ? 'Darf nicht leer sein' : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  
                  // --- ERKLÄRUNG (Optional) ---
                  TextFormField(
                    controller: _erklaerungController,
                    decoration: const InputDecoration(labelText: 'Erklärung (optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green, foregroundColor: Colors.white),
                    icon: const Icon(Icons.save),
                    label: const Text('Frage speichern', style: TextStyle(fontSize: 18)),
                    onPressed: _frageSpeichern,
                  ),
                ],
              ),
            ),
          ),
    );
  }
}