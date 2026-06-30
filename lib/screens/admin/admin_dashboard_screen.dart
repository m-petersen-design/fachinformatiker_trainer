import 'dart:convert'; // Für jsonDecode
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart'; // Zugriff auf den nativen Datei-Explorer (Windows/Linux)
import '../../models/fachrichtung.dart';
import '../../models/themengebiet.dart';
import '../../repositories/fach_repository.dart';
import '../../repositories/admin_repository.dart';
import 'admin_frage_screen.dart';

/// **UI-Komponente: AdminDashboardScreen**
/// Ein StatefulWidget, das den Zustand (State) der Formulareingaben und Dropdowns
/// während der gesamten Laufzeit dieses Bildschirms verwaltet.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

/// **Die State-Klasse (Zustandsverwaltung)**
/// Hier liegt die eigentliche Logik und das UI-Rendering für das Dashboard.
class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  
  // --- FORMULAR-STEUERUNG (Controllers & Keys) ---
  // GlobalKeys sind nötig, um Formulare auf Knopfdruck validieren zu können.
  final _themaFormKey = GlobalKey<FormState>();
  final _themaController = TextEditingController();
  
  final _fachFormKey = GlobalKey<FormState>();
  final _fachKuerzelController = TextEditingController();
  final _fachNameController = TextEditingController();

  // --- LOKALER ZUSTAND (State Variables) ---
  Fachrichtung? _selectedFachrichtung; // Aktuell im Dropdown gewählte Fachrichtung
  Themengebiet? _selectedThema;        // Aktuell gewähltes Unterthema (für den JSON-Fallback)
  
  List<Fachrichtung> _fachrichtungen = [];
  List<Themengebiet> _themen = [];
  bool _isLoading = true; // Steuert den Ladekreis beim ersten Aufruf

  // --- WIDGET LIFECYCLE ---
  /// **initState()** wird exakt einmal aufgerufen, bevor der Bildschirm gezeichnet wird.
  /// Perfekt, um asynchrone Datenbankabfragen (wie das Laden der Fachrichtungen) zu starten.
  @override
  void initState() {
    super.initState();
    _ladeFachrichtungen();
  }

  /// **Datenbank-Lesezugriff: Fachrichtungen**
  Future<void> _ladeFachrichtungen() async {
    final repo = FachRepository();
    final daten = await repo.getFachrichtungen();
    
    // setState() zwingt Flutter, die build()-Methode neu auszuführen 
    // und das UI mit den frisch geladenen Daten zu aktualisieren.
    setState(() {
      _fachrichtungen = daten;
      _isLoading = false;
    });
  }

  /// **Datenbank-Lesezugriff: Themengebiete**
  /// Wird aufgerufen, sobald der User im ersten Dropdown eine Fachrichtung auswählt.
  Future<void> _ladeThemen(int fachId) async {
    final repo = FachRepository();
    final themen = await repo.getThemengebiete(fachId);
    setState(() {
      _themen = themen;
      _selectedThema = null; // Reset: Verhindert, dass ein altes Thema aus einer anderen Fachrichtung ausgewählt bleibt.
    });
  }

  // --- CRUD OPERATIONEN (Schreiben) ---

  /// **Neue Fachrichtung (z.B. UNI) speichern**
  Future<void> _fachrichtungSpeichern() async {
    // 1. Validierung: Prüft, ob alle Pflichtfelder ('validator'-Callbacks) ausgefüllt sind.
    if (_fachFormKey.currentState!.validate()) {
      final adminRepo = AdminRepository();
      
      // 2. Schreibt in die DB
      await adminRepo.addFachrichtung(
        _fachKuerzelController.text, 
        _fachNameController.text
      );
      
      // 3. UI-Feedback (Defensives Programmieren mit 'mounted')
      // 'mounted' prüft, ob der User den Screen in der Zwischenzeit nicht schon verlassen hat.
      // Andernfalls würde der SnackBar-Aufruf zum Absturz führen.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Fachrichtung erfolgreich angelegt!'), backgroundColor: Colors.green)
        );
        // Formular leeren und Dropdown neu laden
        _fachKuerzelController.clear();
        _fachNameController.clear();
        _ladeFachrichtungen();
      }
    }
  }

  /// **Neues Themengebiet (z.B. Datenbanken) speichern**
  Future<void> _themaSpeichern() async {
    if (_themaFormKey.currentState!.validate() && _selectedFachrichtung != null) {
      final adminRepo = AdminRepository();
      await adminRepo.addThemengebiet(_selectedFachrichtung!.id, _themaController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Neues Thema erfolgreich angelegt!'), backgroundColor: Colors.green)
        );
        _themaController.clear(); 
        // Lade die Themen-Liste neu, damit das neue Thema sofort im Fallback-Dropdown erscheint
        _ladeThemen(_selectedFachrichtung!.id);
      }
    }
  }

  /// **ETL-Prozess: Der manuelle Datei-Import**
  /// Iteriert über ein geparstes JSON-Array und fügt jede Frage in die Datenbank ein.
  Future<void> _importiereKlausur(List<dynamic> klausurDatenRaw) async {
    final adminRepo = AdminRepository();
    int importierteFragen = 0;
    int uebersprungeneFragen = 0;

    for (var rawFrage in klausurDatenRaw) {
      final Map<String, dynamic> frage = Map<String, dynamic>.from(rawFrage);
      
      int? finaleId;
      
      // -- FALLBACK-LOGIK FÜR RELATIONALES MAPPING --
      // Priorität 1: Die ID steht direkt in der JSON-Datei der Frage.
      if (frage['themengebiet_id'] != null && frage['themengebiet_id'] is int && frage['themengebiet_id'] > 0) {
        finaleId = frage['themengebiet_id']; 
      } 
      // Priorität 2: Es steht keine ID im JSON. Dann nutzen wir das Themengebiet, 
      // das der Admin im UI-Dropdown (Fallback-Ordner) ausgewählt hat.
      else if (_selectedThema != null) {
        finaleId = _selectedThema!.id; 
      }

      // Wenn weder im JSON noch im UI eine Ziel-ID gefunden wurde, ignorieren wir die Frage (Schutz vor DB-Fehlern).
      if (finaleId == null) {
        uebersprungeneFragen++;
        continue;
      }

      // Arrays (wie die Antworten) müssen für sqflite tiefen-gecastet werden.
      List<Map<String, dynamic>> saubereAntworten = [];
      if (frage['antworten'] != null) {
        saubereAntworten = List<dynamic>.from(frage['antworten'])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      await adminRepo.addFrageMitAntworten(
        themengebietId: finaleId,
        frageText: frage['frage_text'],
        typ: frage['typ'] ?? 'multiple_choice',
        erklaerung: frage['erklaerung'],
        antworten: saubereAntworten,
      );
      importierteFragen++;
    }

    if (!mounted) return;

    // Dynamisches UI-Feedback, wie viele Fragen geschafft wurden.
    String meldung = '🎉 $importierteFragen Fragen erfolgreich importiert!';
    if (uebersprungeneFragen > 0) {
      meldung += ' ($uebersprungeneFragen übersprungen, da keine ID im JSON und kein Ziel-Ordner gewählt war).';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(meldung), backgroundColor: Colors.purple, duration: const Duration(seconds: 4))
    );
  }

  // --- UI-RENDERING (Der Flutter-Widget-Tree) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔒 Creator Mode'), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
      
      // Ternary Operator (? :): Zeigt den Ladekreis, solange die DB noch rödelt.
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView( // Wichtig für Desktop, wenn das Fenster klein skaliert wird
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // --- KARTEN-WIDGET 1: Neue Fachrichtung ---
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _fachFormKey, // Bindet das Formular an den GlobalKey
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('1. Neue Fachrichtung anlegen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 1, // Nimmt 1/3 der Breite ein
                                child: TextFormField(
                                  controller: _fachKuerzelController,
                                  decoration: const InputDecoration(labelText: 'Kürzel (z.B. UNI)', border: OutlineInputBorder()),
                                  // Die Validierungsregel: Feld darf nicht leer sein
                                  validator: (v) => v!.isEmpty ? 'Pflichtfeld' : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2, // Nimmt 2/3 der Breite ein
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
                            onPressed: _fachrichtungSpeichern, // Löst die Validierung & DB-Speicherung aus
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- KARTEN-WIDGET 2: Themenverwaltung & Dateiupload ---
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
                          
                          // Dropdown 1: Fachrichtung auswählen
                          DropdownButtonFormField<Fachrichtung>(
                            value: _selectedFachrichtung,
                            decoration: const InputDecoration(labelText: 'Welche Fachrichtung?', border: OutlineInputBorder()),
                            items: _fachrichtungen.map((fach) => DropdownMenuItem(value: fach, child: Text('${fach.kuerzel} - ${fach.name}'))).toList(),
                            onChanged: (value) {
                              setState(() => _selectedFachrichtung = value);
                              // Trigger: Sobald ein Fach gewählt wird, lade die passenden Themen (z.B. FISI -> Netzwerke)
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

                          const Text('Ziel-Ordner (Fallback) für JSON-Import:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                          const SizedBox(height: 10),
                          
                          // Dropdown 2: Zielthema für den Import
                          DropdownButtonFormField<Themengebiet>(
                            value: _selectedThema,
                            decoration: const InputDecoration(labelText: 'Ziel-Thema auswählen (Optional)', border: OutlineInputBorder()),
                            items: _themen.map((thema) => DropdownMenuItem(value: thema, child: Text(thema.name))).toList(),
                            onChanged: (value) {
                              setState(() => _selectedThema = value);
                            },
                          ),
                          const SizedBox(height: 16),

                          // --- DER FILE-PICKER BUTTON (JSON UPLOAD) ---
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.purple[700], foregroundColor: Colors.white),
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Fragen (JSON) importieren', style: TextStyle(fontSize: 16)),
                            onPressed: () async {
                              try {
                                // Öffnet den nativen Windows-Datei-Explorer (gefiltert auf .json-Dateien)
                                const XTypeGroup typeGroup = XTypeGroup(label: 'JSON', extensions: <String>['json']);
                                final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

                                if (file != null) {
                                  // Einlesen, dekodieren und an die Import-Logik übergeben
                                  String jsonString = await file.readAsString();
                                  dynamic decodedData = jsonDecode(jsonString);
                                  
                                  List<dynamic> rawList = [];
                                  
                                  // Fängt verschiedene JSON-Architekturen ab
                                  if (decodedData is List) {
                                    rawList = decodedData;
                                  } else if (decodedData is Map && decodedData.containsKey('fragen')) {
                                    rawList = decodedData['fragen'];
                                  } else {
                                    throw Exception("Unbekanntes JSON-Format. Erwarte eine Liste [ ... ]");
                                  }

                                  await _importiereKlausur(rawList);
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                // Navigation zum reinen Lösch/Editier-Bildschirm
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