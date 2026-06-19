import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';

class QuizScreen extends StatefulWidget {
  final int themengebietId;
  final String themengebietName;

  const QuizScreen({
    super.key, 
    required this.themengebietId,
    required this.themengebietName,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _quizDaten = [];
  
  int _aktuelleFrageIndex = 0;
  int _richtigeAntworten = 0;
  bool _quizBeendet = false;

  // NEU: State Management für die interaktive Auswertung
  bool _frageBeantwortet = false;
  int? _gewaehlteAntwortIndex; 
  final _freitextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ladeGemischtesQuiz();
  }

  @override
  void dispose() {
    _freitextController.dispose();
    super.dispose();
  }

  Future<void> _ladeGemischtesQuiz() async {
    final db = await DatabaseService.instance.database;
    final rawFragen = await db.query('frage', where: 'themengebiet_id = ?', whereArgs: [widget.themengebietId]);
    List<Map<String, dynamic>> spielbareFragen = rawFragen.map((e) => Map<String, dynamic>.from(e)).toList();
    spielbareFragen.shuffle(); 

    List<Map<String, dynamic>> komplettesQuiz = [];

    for (var frage in spielbareFragen) {
      if (frage['typ'] == 'freitext') {
        komplettesQuiz.add({'frage': frage, 'antworten': []});
        continue;
      }
      final rawAntworten = await db.query('antwort_option', where: 'frage_id = ?', whereArgs: [frage['id']]);
      List<Map<String, dynamic>> gemischteAntworten = rawAntworten.map((e) => Map<String, dynamic>.from(e)).toList();
      gemischteAntworten.shuffle(); 

      komplettesQuiz.add({'frage': frage, 'antworten': gemischteAntworten});
    }

    setState(() {
      _quizDaten = komplettesQuiz;
      _isLoading = false;
    });
  }

  // ==========================================
  // LOGIK: MULTIPLE CHOICE AUSWERTEN
  // ==========================================
  void _mcAntwortAuswerten(int index, dynamic istKorrektRaw) {
    if (_frageBeantwortet) return; // Verhindert mehrfaches Klicken

    setState(() {
      _gewaehlteAntwortIndex = index;
      _frageBeantwortet = true;
    });

    int istKorrekt = (istKorrektRaw is int) ? istKorrektRaw : int.tryParse(istKorrektRaw.toString()) ?? 0;
    if (istKorrekt == 1) {
      _richtigeAntworten++;
    }
  }

  // ==========================================
  // LOGIK: FREITEXT AUSWERTEN
  // ==========================================
  void _freitextMusterloesungAnzeigen() {
    if (_freitextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte gib eine Antwort ein!'), backgroundColor: Colors.orange));
      return;
    }
    setState(() {
      _frageBeantwortet = true;
    });
  }

  void _freitextSelbstbewertung(bool warRichtig) {
    if (warRichtig) {
      _richtigeAntworten++;
    }
    _naechsteFrage();
  }

  // ==========================================
  // ZUR NÄCHSTEN FRAGE SPRINGEN
  // ==========================================
  void _naechsteFrage() {
    if (_aktuelleFrageIndex < _quizDaten.length - 1) {
      setState(() {
        _aktuelleFrageIndex++;
        _frageBeantwortet = false;
        _gewaehlteAntwortIndex = null;
        _freitextController.clear();
      });
    } else {
      setState(() {
        _quizBeendet = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(appBar: AppBar(title: Text(widget.themengebietName)), body: const Center(child: CircularProgressIndicator()));
    if (_quizDaten.isEmpty) return Scaffold(appBar: AppBar(title: Text(widget.themengebietName)), body: const Center(child: Text('Keine Fragen vorhanden.')));
    if (_quizBeendet) return _buildErgebnisScreen();

    final aktuelleDaten = _quizDaten[_aktuelleFrageIndex];
    final frage = aktuelleDaten['frage'] as Map<String, dynamic>;
    final antworten = List<Map<String, dynamic>>.from(aktuelleDaten['antworten']);

    return Scaffold(
      appBar: AppBar(title: Text(widget.themengebietName), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Frage ${_aktuelleFrageIndex + 1} von ${_quizDaten.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 20),

            if (frage['bild_pfad'] != null && frage['bild_pfad'].toString().isNotEmpty) ...[
              Container(height: 150, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('🖼️ Bild'))),
              const SizedBox(height: 20),
            ],

            Text(frage['frage_text'].toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),

            // ==========================================
            // UI: MULTIPLE CHOICE
            // ==========================================
            if (frage['typ'] == 'multiple_choice') ...[
              ...antworten.asMap().entries.map((entry) {
                int index = entry.key;
                var antwort = entry.value;
                int istKorrekt = (antwort['ist_korrekt'] is int) ? antwort['ist_korrekt'] : int.tryParse(antwort['ist_korrekt'].toString()) ?? 0;

                // Farb-Logik für Feedback
                Color buttonColor = Colors.white;
                Color textColor = Colors.black87;

                if (_frageBeantwortet) {
                  if (istKorrekt == 1) {
                    buttonColor = Colors.green; // Richtig immer Grün markieren
                    textColor = Colors.white;
                  } else if (_gewaehlteAntwortIndex == index) {
                    buttonColor = Colors.red; // Falsch gewählt = Rot
                    textColor = Colors.white;
                  } else {
                    buttonColor = Colors.grey[200]!; // Rest ausgrauen
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: textColor,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      alignment: Alignment.centerLeft,
                      side: const BorderSide(color: Colors.grey, width: 0.5),
                    ),
                    onPressed: () => _mcAntwortAuswerten(index, antwort['ist_korrekt']),
                    child: Text(antwort['text'].toString(), style: const TextStyle(fontSize: 16)),
                  ),
                );
              }),

              // Weiter-Button für MC (taucht erst nach dem Klick auf)
              if (_frageBeantwortet) ...[
                const SizedBox(height: 20),
                if (frage['erklaerung'] != null && frage['erklaerung'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue[50],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 Erklärung:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 8),
                        Text(frage['erklaerung'].toString()),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blueGrey[900], foregroundColor: Colors.white),
                  onPressed: _naechsteFrage,
                  child: const Text('Nächste Frage ➔', style: TextStyle(fontSize: 18)),
                )
              ]
            ] 
            
            // ==========================================
            // UI: FREITEXT
            // ==========================================
            else ...[
              TextField(
                controller: _freitextController,
                maxLines: 5,
                enabled: !_frageBeantwortet,
                decoration: const InputDecoration(
                  labelText: 'Deine Antwort',
                  border: OutlineInputBorder(),
                  hintText: 'Tippe hier deine ausführliche Antwort ein...',
                ),
              ),
              const SizedBox(height: 20),
              
              if (!_frageBeantwortet)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: _freitextMusterloesungAnzeigen,
                  icon: const Icon(Icons.check),
                  label: const Text('Antwort einloggen & Musterlösung prüfen', style: TextStyle(fontSize: 16)),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green[50], border: Border.all(color: Colors.green)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✅ Musterlösung:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(frage['erklaerung']?.toString() ?? 'Keine Musterlösung hinterlegt.', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text('War deine Antwort sinngemäß richtig?', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100], foregroundColor: Colors.red[900], padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () => _freitextSelbstbewertung(false),
                        child: const Text('❌ Nein (Falsch)'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () => _freitextSelbstbewertung(true),
                        child: const Text('✅ Ja (+1 Punkt)'),
                      ),
                    ),
                  ],
                )
              ]
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErgebnisScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Ergebnis')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉 Quiz beendet!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Du hast $_richtigeAntworten von ${_quizDaten.length} richtig!', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Quiz neu starten'),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _quizBeendet = false;
                  _aktuelleFrageIndex = 0;
                  _richtigeAntworten = 0;
                });
                _ladeGemischtesQuiz();
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zurück zum Menü'),
            )
          ],
        ),
      ),
    );
  }
}