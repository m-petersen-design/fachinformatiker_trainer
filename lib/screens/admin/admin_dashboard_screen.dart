import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart'; // <--- Das neue, offizielle Paket!
import '../../models/fachrichtung.dart';
import '../../repositories/fach_repository.dart';
import '../../repositories/admin_repository.dart';
import 'admin_frage_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _themaController = TextEditingController();
  
  Fachrichtung? _selectedFachrichtung;
  List<Fachrichtung> _fachrichtungen = [];
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
      if (daten.isNotEmpty) {
        _selectedFachrichtung = daten.first;
      }
      _isLoading = false;
    });
  }

  Future<void> _themaSpeichern() async {
    if (_formKey.currentState!.validate() && _selectedFachrichtung != null) {
      final adminRepo = AdminRepository();
      await adminRepo.addThemengebiet(_selectedFachrichtung!.id, _themaController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Neues Thema erfolgreich angelegt!'), backgroundColor: Colors.green));
        _themaController.clear(); 
      }
    }
  }

  Future<void> _importiereKlausur(List<Map<String, dynamic>> klausurDaten) async {
    final adminRepo = AdminRepository();
    int importierteFragen = 0;

    for (var frage in klausurDaten) {
      await adminRepo.addFrageMitAntworten(
        themengebietId: frage['themengebiet_id'],
        frageText: frage['frage_text'],
        typ: frage['typ'],
        erklaerung: frage['erklaerung'],
        antworten: List<Map<String, dynamic>>.from(frage['antworten']),
      );
      importierteFragen++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 $importierteFragen Fragen erfolgreich importiert!'), backgroundColor: Colors.purple));
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Neues Oberthema anlegen', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  DropdownButtonFormField<Fachrichtung>(
                    value: _selectedFachrichtung,
                    decoration: const InputDecoration(labelText: 'Zu welcher Fachrichtung?', border: OutlineInputBorder()),
                    items: _fachrichtungen.map((fach) => DropdownMenuItem(value: fach, child: Text('${fach.kuerzel} - ${fach.name}'))).toList(),
                    onChanged: (value) => setState(() => _selectedFachrichtung = value),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _themaController,
                    decoration: const InputDecoration(labelText: 'Name des Themas', border: OutlineInputBorder(), prefixIcon: Icon(Icons.folder)),
                    validator: (value) => value == null || value.isEmpty ? 'Bitte gib einen Namen ein' : null,
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
                    icon: const Icon(Icons.save),
                    label: const Text('Thema in Datenbank speichern', style: TextStyle(fontSize: 16)),
                    onPressed: _themaSpeichern,
                  ),

                  const SizedBox(height: 40),
                  const Divider(thickness: 2),
                  const SizedBox(height: 40),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminFrageScreen())),
                    child: const Text('Zum manuellen Fragen-Editor ->', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),

                  // ==========================================
                  // DER NEUE DATEI-UPLOAD BUTTON
                  // ==========================================
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Klausur als .json Datei hochladen', style: TextStyle(fontSize: 16)),
                    onPressed: () async {
                      try {
                        // Offizieller Windows-Dateiauswahldialog
                        const XTypeGroup typeGroup = XTypeGroup(
                          label: 'JSON Dateien',
                          extensions: <String>['json'],
                        );
                        
                        final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

                        if (file != null) {
                          String jsonString = await file.readAsString();
                          List<dynamic> jsonData = jsonDecode(jsonString);
                          List<Map<String, dynamic>> klausurDaten = List<Map<String, dynamic>>.from(jsonData);
                          
                          await _importiereKlausur(klausurDaten);
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Import: $e'), backgroundColor: Colors.red));
                      }
                    },
                  ),

                ],
              ),
            ),
          ),
    );
  }
}