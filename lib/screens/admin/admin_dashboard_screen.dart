import 'package:flutter/material.dart';
import '../../models/fachrichtung.dart';
import '../../repositories/fach_repository.dart';
import '../../repositories/admin_repository.dart';

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

  // Lädt die Fachrichtungen (FISI, FIAE, FIDP) für das Dropdown-Menü
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
      
      await adminRepo.addThemengebiet(
        _selectedFachrichtung!.id,
        _themaController.text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Neues Thema erfolgreich angelegt!'), 
            backgroundColor: Colors.green,
          ),
        );
        _themaController.clear(); // Textfeld wieder leeren
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔒 Creator Mode'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Neues Oberthema anlegen',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  
                  // Dropdown für FISI, FIAE oder FIDP
                  DropdownButtonFormField<Fachrichtung>(
                    value: _selectedFachrichtung,
                    decoration: const InputDecoration(
                      labelText: 'Zu welcher Fachrichtung?',
                      border: OutlineInputBorder(),
                    ),
                    items: _fachrichtungen.map((fach) {
                      return DropdownMenuItem(
                        value: fach,
                        child: Text('${fach.kuerzel} - ${fach.name}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFachrichtung = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Textfeld für den Namen des Themas (z.B. "Subnetting")
                  TextFormField(
                    controller: _themaController,
                    decoration: const InputDecoration(
                      labelText: 'Name des Themas',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.folder),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bitte gib einen Namen ein';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueGrey[900],
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text('Thema in Datenbank speichern', style: TextStyle(fontSize: 16)),
                    onPressed: _themaSpeichern,
                  ),
                ],
              ),
            ),
          ),
    );
  }
}