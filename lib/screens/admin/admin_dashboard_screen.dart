import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../models/fachrichtung.dart';
import '../../models/themengebiet.dart';
import '../../repositories/fach_repository.dart';
import '../../repositories/admin_repository.dart';
import 'admin_frage_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _themaFormKey = GlobalKey<FormState>();
  final _themaController = TextEditingController();
  
  // Controller für neue Fachrichtung
  final _fachFormKey = GlobalKey<FormState>();
  final _fachKuerzelController = TextEditingController();
  final _fachNameController = TextEditingController();

  Fachrichtung? _selectedFachrichtung;
  Themengebiet? _selectedThema; // NEU: Damit der Import weiß, wohin genau!
  
  List<Fachrichtung> _fachrichtungen = [];
  List<Themengebiet> _themen = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ladeFachrichtungen();
  }

  Future<void> _ladeFachrichtungen() async {
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
    });
  }

  // ==========================================
  // NEU: FACHRICHTUNG ANLEGEN (Uni / Berufsschule)
  // ==========================================
  Future<void> _fachrichtungSpeichern() async {
    if (_fachFormKey.currentState!.validate()) {
      final adminRepo = AdminRepository();
      await adminRepo.addFachrichtung(
        _fachKuerzelController.text, 
        _fachNameController.text
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Fachrichtung erfolgreich angelegt!'), backgroundColor: Colors.green)
        );
        _fachKuerzelController.clear();
        _fachNameController.clear();
        _ladeFachrichtungen(); // Dropdown aktualisieren
      }
    }
  }

  // ==========================================
  // THEMA ANLEGEN
  // ==========================================
  Future<void> _themaSpeichern() async {
    if (_themaFormKey.currentState!.validate() && _selectedFachrichtung != null) {
      final adminRepo = AdminRepository();
      await adminRepo.addThemengebiet(_selectedFachrichtung!.id, _themaController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Neues Thema erfolgreich angelegt!'), backgroundColor: Colors.green)
        );
        _themaController.clear(); 
        _ladeThemen(_selectedFachrichtung!.id); // Dropdowns aktualisieren
      }
    }
  }

  // ==========================================
  // IMPORTIERT JETZT KORREKT INS THEMA!
  // ==========================================
  Future<void> _importiereKlausur(List<Map<String, dynamic>> klausurDaten) async {
    // DER ENTSCHEIDENDE FIX: Wir prüfen auf das THEMA, nicht auf die Fachrichtung
    if (_selectedThema == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Bitte wähle zuerst ein Themengebiet im Dropdown aus!'), backgroundColor: Colors.red)
      );
      return;
    }

    final adminRepo = AdminRepository();
    int importierteFragen = 0;
    final zielThemengebietId = _selectedThema!.id; // HIER IST DER FIX!

    for (var frage in klausurDaten) {
      await adminRepo.addFrageMitAntworten(
        themengebietId: zielThemengebietId,
        frageText: frage['frage_text'],
        typ: frage['typ'] ?? 'multiple_choice',
        erklaerung: frage['erklaerung'],
        antworten: frage['antworten'] != null ? List<Map<String, dynamic>>.from(frage['antworten']) : [],
      );
      importierteFragen++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🎉 $importierteFragen Fragen in "${_selectedThema!.name}" importiert!'), backgroundColor: Colors.purple)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔒 Creator Mode'), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView( 
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // ----------------------------------------------------
                // BEREICH 1: NEUE FACHRICHTUNG (Uni / Berufsschule)
                // ----------------------------------------------------
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _fachFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('1. Neue Fachrichtung anlegen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: _fachKuerzelController,
                                  decoration: const InputDecoration(labelText: 'Kürzel (z.B. UNI)', border: OutlineInputBorder()),
                                  validator: (v) => v!.isEmpty ? 'Pflichtfeld' : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _fachNameController,
                                  decoration: const InputDecoration(labelText: 'Name (z.B. Universität)', border: OutlineInputBorder()),
                                  validator: (v) => v!.isEmpty ? 'Pflichtfeld' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                            icon: const Icon(Icons.school),
                            label: const Text('Fachrichtung speichern'),
                            onPressed: _fachrichtungSpeichern,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ----------------------------------------------------
                // BEREICH 2: THEMA ANLEGEN & JSON IMPORT
                // ----------------------------------------------------
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _themaFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('2. Themen verwalten & JSON Upload', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          
                          DropdownButtonFormField<Fachrichtung>(
                            value: _selectedFachrichtung,
                            decoration: const InputDecoration(labelText: 'Welche Fachrichtung?', border: OutlineInputBorder()),
                            items: _fachrichtungen.map((fach) => DropdownMenuItem(value: fach, child: Text('${fach.kuerzel} - ${fach.name}'))).toList(),
                            onChanged: (value) {
                              setState(() => _selectedFachrichtung = value);
                              if (value != null) _ladeThemen(value.id);
                            },
                          ),
                          const SizedBox(height: 16),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _themaController,
                                  decoration: const InputDecoration(labelText: 'Neues Thema (z.B. Mathe)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.folder)),
                                  validator: (value) => value == null || value.isEmpty ? 'Name eingeben' : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
                                onPressed: _themaSpeichern,
                                child: const Text('Anlegen'),
                              ),
                            ],
                          ),
                          
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(thickness: 2),
                          ),

                          const Text('Ziel-Ordner für den JSON-Import auswählen:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                          const SizedBox(height: 10),
                          
                          // HIER WÄHLT MAN JETZT DEN ZIELORDNER FÜR DAS JSON
                          DropdownButtonFormField<Themengebiet>(
                            value: _selectedThema,
                            decoration: const InputDecoration(labelText: 'Ziel-Thema (z.B. Mathe)', border: OutlineInputBorder()),
                            items: _themen.map((thema) => DropdownMenuItem(value: thema, child: Text(thema.name))).toList(),
                            onChanged: (value) {
                              setState(() => _selectedThema = value);
                            },
                          ),
                          const SizedBox(height: 16),

                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Fragen (JSON) in diesen Ordner importieren', style: TextStyle(fontSize: 16)),
                            onPressed: () async {
                              if (_selectedThema == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte wähle zuerst oben ein Ziel-Thema aus!'), backgroundColor: Colors.red));
                                return;
                              }
                              try {
                                const XTypeGroup typeGroup = XTypeGroup(label: 'JSON', extensions: <String>['json']);
                                final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

                                if (file != null) {
                                  String jsonString = await file.readAsString();
                                  List<dynamic> jsonData = jsonDecode(jsonString);
                                  await _importiereKlausur(List<Map<String, dynamic>>.from(jsonData));
                                }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminFrageScreen())),
                  child: const Text('Zum manuellen Fragen-Editor (Löschen & Bearbeiten) ->', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
    );
  }
}