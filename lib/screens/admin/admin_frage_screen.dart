import 'package:flutter/material.dart';
import '../../models/fachrichtung.dart';
import '../../models/themengebiet.dart';
import '../../repositories/fach_repository.dart';
import '../../repositories/admin_repository.dart';
import '../../core/database/database_service.dart'; // Für die Live-Abfrage

class AdminFrageScreen extends StatefulWidget {
  const AdminFrageScreen({super.key});

  @override
  State<AdminFrageScreen> createState() => _AdminFrageScreenState();
}

class _AdminFrageScreenState extends State<AdminFrageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _frageController = TextEditingController();
  final _erklaerungController = TextEditingController();
  
  final List<TextEditingController> _antwortControllers = List.generate(4, (_) => TextEditingController());
  int _richtigeAntwortIndex = 0; 

  String _selectedTyp = 'multiple_choice'; 
  Fachrichtung? _selectedFachrichtung;
  Themengebiet? _selectedThema;
  
  List<Fachrichtung> _fachrichtungen = [];
  List<Themengebiet> _themen = [];
  List<Map<String, dynamic>> _existierendeFragen = []; 
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
      _selectedThema = null; 
      _existierendeFragen = [];
    });
  }

  Future<void> _ladeFragenFuerThema(int themaId) async {
    final db = await DatabaseService.instance.database;
    final fragen = await db.query('frage', where: 'themengebiet_id = ?', whereArgs: [themaId]);
    setState(() {
      _existierendeFragen = fragen;
    });
  }

  Future<void> _frageSpeichern() async {
    if (_formKey.currentState!.validate() && _selectedThema != null) {
      final adminRepo = AdminRepository();
      
      List<Map<String, dynamic>> antworten = [];
      if (_selectedTyp == 'multiple_choice') {
        for (int i = 0; i < 4; i++) {
          antworten.add({
            'text': _antwortControllers[i].text,
            'ist_korrekt': i == _richtigeAntwortIndex ? 1 : 0,
          });
        }
      }

      await adminRepo.addFrageMitAntworten(
        themengebietId: _selectedThema!.id,
        frageText: _frageController.text,
        typ: _selectedTyp, 
        erklaerung: _erklaerungController.text.isNotEmpty ? _erklaerungController.text : null,
        antworten: antworten,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Frage erfolgreich gespeichert!'), backgroundColor: Colors.green),
        );
        _frageController.clear();
        _erklaerungController.clear();
        for (var c in _antwortControllers) {
          c.clear();
        }
        _ladeFragenFuerThema(_selectedThema!.id);
      }
    }
  }

  Future<void> _einzelneFrageLoeschen(int frageId) async {
    final adminRepo = AdminRepository();
    await adminRepo.deleteFrage(frageId);
    if (_selectedThema != null) {
      _ladeFragenFuerThema(_selectedThema!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📝 Fragen verwalten'), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    onChanged: (val) {
                      setState(() {
                        _selectedThema = val;
                      });
                      if (val != null) _ladeFragenFuerThema(val.id);
                    },
                  ),
                  const Divider(height: 40, thickness: 2),

                  const Text('Neue Frage hinzufügen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'multiple_choice', label: Text('Multiple Choice'), icon: Icon(Icons.list)),
                      ButtonSegment(value: 'freitext', label: Text('Freitext'), icon: Icon(Icons.edit_note)),
                    ],
                    selected: {_selectedTyp},
                    onSelectionChanged: (newSelection) {
                      setState(() => _selectedTyp = newSelection.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _frageController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Fragetext', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  if (_selectedTyp == 'multiple_choice') ...[
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
                                validator: (v) => _selectedTyp == 'multiple_choice' && v!.isEmpty ? 'Pflichtfeld' : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  
                  TextFormField(
                    controller: _erklaerungController,
                    decoration: const InputDecoration(labelText: 'Erklärung / Musterlösung (optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green, foregroundColor: Colors.white),
                    icon: const Icon(Icons.save),
                    label: const Text('Frage in DB speichern'),
                    onPressed: _frageSpeichern,
                  ),

                  if (_selectedThema != null) ...[
                    const SizedBox(height: 40),
                    Text('Existierende Fragen in "${_selectedThema!.name}" (${_existierendeFragen.length}):', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 10),
                    if (_existierendeFragen.isEmpty)
                      const Text('Keine Fragen in diesem Thema vorhanden.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _existierendeFragen.length,
                        itemBuilder: (context, index) {
                          final f = _existierendeFragen[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(f['frage_text'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                              subtitle: Text('Typ: ${f['typ']}', style: const TextStyle(fontSize: 12)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _einzelneFrageLoeschen(f['id']),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
    );
  }
}